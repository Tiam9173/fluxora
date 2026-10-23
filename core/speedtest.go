package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// 测速跑在内核里，走 mihomo 的 dialer——这样测出来的数字是**经过代理**的真实
// 速度。放在 Dart 侧做单连接下载的话，高延迟线路上会严重偏低，用户会以为代理
// 有问题。
const (
	speedTestStreams   = 8
	speedTestLatencyN  = 10
	speedTestDownBytes = 10_000_000
	speedTestUpBytes   = 10_000_000
	speedTestSampleMs  = 200
	// 爬坡窗口：这段时间内的增量不计入最终速度。
	speedTestRampWindow  = 2 * time.Second
	speedTestPhaseIdle   = "idle"
	speedTestPhaseLat    = "latency"
	speedTestPhaseDown   = "download"
	speedTestPhaseUp     = "upload"
	speedTestPhaseDone   = "done"
	speedTestPhaseFailed = "failed"
)

type SpeedTestParams struct {
	// 留空表示走内核当前选中的出站（也就是用户的代理链路）。
	Outbound string `json:"outbound"`
}

// 推给 Dart 的进度帧。字段保持扁平，Dart 侧直接按名字取。
type SpeedTestProgress struct {
	Phase      string  `json:"phase"`
	LatencyMs  int     `json:"latencyMs"`
	JitterMs   int     `json:"jitterMs"`
	DownMbps   float64 `json:"downMbps"`
	UpMbps     float64 `json:"upMbps"`
	Percent    int     `json:"percent"`
	Error      string  `json:"error,omitempty"`
	ProxyUsed  bool    `json:"proxyUsed"`
	ServerName string  `json:"serverName"`
}

const (
	cloudflareDownURL = "https://speed.cloudflare.com/__down?bytes=%d"
	cloudflareUpURL   = "https://speed.cloudflare.com/__up"
	appleConfigURL    = "https://mensura.cdn-apple.com/api/v1/gm/config"
	// speedtest.net 的公开 JS 接口，列表里包含国内三大运营商的节点。
	speedtestServersURL = "https://www.speedtest.net/api/js/servers?engine=js&limit=20&https_functional=true"
	// Cloudflare 的元信息接口，返回当前出口的国家/城市。用它来按**出口位置**
	// 选节点——测速流量是从代理出口发出去的，按本机位置选会挑到绕远的节点。
	cfMetaURL = "https://speed.cloudflare.com/meta"
	// 国内 CDN 镜像的大文件。这类服务器常年高负载运行，比个人测速节点可靠；
	// ls-lR.gz 是 Ubuntu 镜像的目录索引，路径稳定、体积够大。
	aliyunCDNURL  = "https://mirrors.aliyun.com/ubuntu/ls-lR.gz"
	tencentCDNURL = "https://mirrors.cloud.tencent.com/ubuntu/ls-lR.gz"
)

// 本轮实际使用的测速源。auto 时按延迟择优。
var (
	speedTestDownURL = cloudflareDownURL
	speedTestUpURL   = cloudflareUpURL
	speedTestName    = "Cloudflare"
	// Apple 给的是一个固定 URL（自带大小参数），不能按 %d 拼。
	speedTestDownFixed string
)

// 下载地址：Apple 的固定 URL 直接用，Cloudflare 的按本次要拉的字节数拼。
func downURLFor(n int) string {
	if speedTestDownFixed != "" {
		return speedTestDownFixed
	}
	return fmt.Sprintf(speedTestDownURL, n)
}

// 解析 Apple 的 mensura 配置，拿到它给的真实下载/上传地址。
//
// 配置形如 {"urls":{"large_https_download_url":..,"https_upload_url":..}}，
// 不解析就只能拿它当"探活目标"，测的还是 Cloudflare 的数据。
// 真去拉一点数据，确认这个地址在当前网络下能用。
//
// 只看配置能不能取到是不够的：Apple 的 /gm/large 在小流量探测时正常，正式
// 下载却会卡到超时。
func probeUsable(ctx context.Context, client *http.Client, url string) bool {
	pctx, cancel := context.WithTimeout(ctx, 6*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(pctx, http.MethodGet, url, nil)
	if err != nil {
		return false
	}
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false
	}
	buf := make([]byte, 32*1024)
	_, err = io.ReadFull(resp.Body, buf)
	return err == nil
}

func appleTarget(ctx context.Context, client *http.Client) (string, string, bool) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleConfigURL, nil)
	if err != nil {
		return "", "", false
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", "", false
	}
	var cfg struct {
		Urls struct {
			Large  string `json:"large_https_download_url"`
			Upload string `json:"https_upload_url"`
		} `json:"urls"`
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 64*1024)).Decode(&cfg) != nil {
		return "", "", false
	}
	if cfg.Urls.Large == "" || cfg.Urls.Upload == "" {
		return "", "", false
	}
	return cfg.Urls.Large, cfg.Urls.Upload, true
}

// 在几个候选源里挑响应最快的那个。
//
// 国内网络到 Cloudflare 常常绕路，Apple 的 CDN 在境内有节点，所以两个都探一次
// 再决定，而不是写死一家。
func resolveTarget(ctx context.Context, client *http.Client) (string, string, string) {
	type candidate struct {
		name    string
		probe   string
		downURL string
		upURL   string
	}
	cands := []candidate{
		{"Cloudflare", "https://speed.cloudflare.com/__down?bytes=0", cloudflareDownURL, cloudflareUpURL},
	}

	best := cands[0]
	bestMs := 1 << 30
	for _, c := range cands {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.probe, nil)
		if err != nil {
			continue
		}
		start := time.Now()
		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		ms := int(time.Since(start).Milliseconds())
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if ms < bestMs {
			bestMs = ms
			best = c
		}
	}
	// 国内 CDN：只测下载（上传仍走 Cloudflare），但下载这个数最准。
	for _, cdn := range []struct{ name, url string }{
		{"Aliyun CDN", aliyunCDNURL},
		{"Tencent CDN", tencentCDNURL},
	} {
		if probeUsable(ctx, client, cdn.url) {
			return cdn.name, cdn.url, cloudflareUpURL
		}
	}
	if best.name == "Apple" {
		if large, up, ok := appleTarget(ctx, client); ok && probeUsable(ctx, client, large) {
			return "Apple", large, up
		}
		// 配置解析失败、或者它的下载地址根本连不上，就退回 Cloudflare。
		// 光看配置文件能不能取到不够——实测 /gm/large 会直接超时。
		return "Cloudflare", cloudflareDownURL, cloudflareUpURL
	}
	return best.name, best.downURL, best.upURL
}

// 从 speedtest.net 的服务器列表里挑一台最快的。
//
// 这是"国内也能测"的关键：列表里就有中国电信/联通/移动的节点，不需要自建
// 测速服务器。逐个打 /latency.txt 太慢，只探前几台。
// 当前出口在哪。拿不到就返回空，退回按列表顺序选。
func exitLocation(ctx context.Context, client *http.Client) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, cfMetaURL, nil)
	if err != nil {
		return ""
	}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ""
	}
	var meta struct {
		City    string `json:"city"`
		Country string `json:"country"`
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 64*1024)).Decode(&meta) != nil {
		return ""
	}
	if meta.City != "" {
		return meta.City
	}
	return meta.Country
}

func speedtestTarget(ctx context.Context, client *http.Client) (string, string, string, string, bool) {
	listURL := speedtestServersURL
	if loc := exitLocation(ctx, client); loc != "" {
		// 按出口城市搜：这样挑出来的是"离出口近"的节点，而不是离本机近。
		listURL += "&search=" + url.QueryEscape(loc)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, listURL, nil)
	if err != nil {
		return "", "", "", "", false
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", "", "", false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", "", "", "", false
	}
	var servers []struct {
		Host    string `json:"host"`
		Name    string `json:"name"`
		Sponsor string `json:"sponsor"`
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 256*1024)).Decode(&servers) != nil {
		return "", "", "", "", false
	}

	bestHost, bestName, bestMs := "", "", 1<<30
	for i, s := range servers {
		if i >= 6 {
			break // 只探前 6 台，再多就太慢
		}
		if s.Host == "" {
			continue
		}
		start := time.Now()
		req, err := http.NewRequestWithContext(ctx, http.MethodGet,
			"https://"+s.Host+"/latency.txt", nil)
		if err != nil {
			continue
		}
		resp, err := client.Do(req)
		if err != nil {
			continue
		}
		ms := int(time.Since(start).Milliseconds())
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			continue
		}
		if ms < bestMs {
			bestMs = ms
			bestHost = s.Host
			bestName = strings.TrimSpace(s.Sponsor + " " + s.Name)
		}
	}
	if bestHost == "" {
		return "", "", "", "", false
	}
	// speedtest.net 的节点大多在 8080 上跑 http，用 https 连 8080 会直接超时。
	scheme := "https"
	if strings.Contains(bestHost, ":8080") {
		scheme = "http"
	}
	base := scheme + "://" + bestHost
	down := base + "/download?size=" + strconv.Itoa(speedTestDownBytes)
	return bestName, down, base + "/upload", down, true
}

type speedCounter struct {
	total int64
	// 计时过半时记一次总量，用来把爬坡期排除掉。
	halfwayBytes int64
	halfwaySet   int32
}

func newSpeedClient() *http.Client {
	// 内核自己的 dialer 已经处理了出站选择，这里只需要一个够快的 transport。
	return &http.Client{
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout:   10 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			TLSClientConfig:     &tls.Config{InsecureSkipVerify: false},
			MaxIdleConns:        speedTestStreams * 2,
			MaxIdleConnsPerHost: speedTestStreams * 2,
			ForceAttemptHTTP2:   true,
		},
	}
}

var (
	speedTestMu    sync.Mutex
	speedTestState = SpeedTestProgress{Phase: speedTestPhaseIdle}
)

// 供 Dart 轮询：返回最近一帧进度。
func handleSpeedTestStatus(_ *Action, result ActionResult) {
	speedTestMu.Lock()
	current := speedTestState
	speedTestMu.Unlock()
	payload, err := json.Marshal(current)
	if err != nil {
		result.success("{}")
		return
	}
	result.success(string(payload))
}

var speedTestRunning int32

func handleSpeedTest(action *Action, result ActionResult) {
	// 先回一个 ack：Dart 的 invokeAction 在收到第一条消息后才 complete 并关闭
	// 端口。进度走消息通道，这里如果不回一条，那个 Future 会永远挂着、端口也
	// 不释放。
	// 已经有跑着的一轮就别再开：第二轮会重新择优，界面上源名会突然从
	// Apple 变成 Cloudflare，看起来像测速自己换了服务器。
	if !atomic.CompareAndSwapInt32(&speedTestRunning, 0, 1) {
		result.success("busy")
		return
	}
	result.success("started")
	params := SpeedTestParams{}
	if raw, ok := action.Data.(string); ok && raw != "" {
		_ = json.Unmarshal([]byte(raw), &params)
	}

	go func() {
		defer atomic.StoreInt32(&speedTestRunning, 0)
		report := func(p SpeedTestProgress) {
			// 不走消息通道：messagePort 没挂上时 sendMessage 会静默丢弃，
			// 界面上就只剩一个 0。改成写全局状态，Dart 轮询来取。
			speedTestMu.Lock()
			speedTestState = p
			speedTestMu.Unlock()
		}

		client := newSpeedClient()
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()

		name, downURL, upURL := resolveTarget(ctx, client)
		speedTestName, speedTestUpURL = name, upURL
		// 只有带 %d 的模板才交给 Sprintf 填大小；已经拼好的完整 URL 直接存下来，
		// 否则会被塞进一个多余的参数，变成 ...size=20000000%!(EXTRA int=0)。
		if strings.Contains(downURL, "%d") {
			speedTestDownFixed = ""
			speedTestDownURL = downURL
		} else {
			speedTestDownFixed = downURL
		}

		// 1. 延迟：取中位数，不被单次抖动拉偏。
		report(SpeedTestProgress{Phase: speedTestPhaseLat, ServerName: speedTestName})
		latencies, err := measureLatency(ctx, client, speedTestLatencyN)
		if err != nil {
			report(SpeedTestProgress{Phase: speedTestPhaseFailed, Error: err.Error()})
			return
		}
		report(SpeedTestProgress{
			Phase:     speedTestPhaseLat,
			LatencyMs: median(latencies),
			JitterMs:  jitter(latencies),
			Percent:   10,
		})

		// 2. 下载
		dctx, dcancel := context.WithTimeout(ctx, 25*time.Second)
		down, err := measureDownload(dctx, client, report)
		dcancel()
		if err != nil {
			// 小流量探测能过、正式下载却被掐的情况真实存在（Apple 就是这样）。
			// 这时别直接报错，退回 Cloudflare 再跑一次。
			if speedTestName != "Cloudflare" {
				speedTestName = "Cloudflare"
				speedTestDownFixed = ""
				speedTestDownURL = cloudflareDownURL
				speedTestUpURL = cloudflareUpURL
				rctx, rcancel := context.WithTimeout(context.Background(), 25*time.Second)
				down, err = measureDownload(rctx, client, report)
				rcancel()
			}
		}
		if err != nil {
			report(SpeedTestProgress{Phase: speedTestPhaseFailed, Error: err.Error()})
			return
		}

		// 3. 上传
		// 上传单独给一个上限：__up 有时候会吊着连接不返回，卡住就永远没有
		// done 帧，界面上会一直停在"上传中"。
		uctx, ucancel := context.WithTimeout(ctx, 8*time.Second)
		up, err := measureUpload(uctx, client, report, median(latencies), down)
		ucancel()
		if err != nil && up == 0 {
			// 上传失败不该把整轮结果作废：延迟和下载已经测到了，照样给结论。
			report(SpeedTestProgress{
				Phase:      speedTestPhaseDone,
				LatencyMs:  median(latencies),
				JitterMs:   jitter(latencies),
				DownMbps:   down,
				UpMbps:     0,
				Percent:    100,
				ProxyUsed:  true,
				ServerName: speedTestName,
			})
			return
		}

		report(SpeedTestProgress{
			Phase:      speedTestPhaseDone,
			LatencyMs:  median(latencies),
			JitterMs:   jitter(latencies),
			DownMbps:   down,
			UpMbps:     up,
			Percent:    100,
			ProxyUsed:  true,
			ServerName: speedTestName,
		})
	}()
}

func measureLatency(ctx context.Context, client *http.Client, n int) ([]int, error) {
	out := make([]int, 0, n)
	for i := 0; i < n; i++ {
		start := time.Now()
		req, err := http.NewRequestWithContext(ctx, http.MethodGet,
			downURLFor(0), nil)
		if err != nil {
			return nil, err
		}
		resp, err := client.Do(req)
		if err != nil {
			return nil, err
		}
		// 只算到响应头：把 body 下载时间算进延迟会把读数抬高一倍。
		elapsed := int(time.Since(start).Milliseconds())
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		out = append(out, elapsed)
	}
	return out, nil
}

func measureDownload(ctx context.Context, client *http.Client, report func(SpeedTestProgress)) (float64, error) {
	counter := &speedCounter{}
	start := time.Now()
	var wg sync.WaitGroup
	errs := make(chan error, speedTestStreams)

	stopSampling := make(chan struct{})
	go func() {
		ticker := time.NewTicker(speedTestSampleMs * time.Millisecond)
		defer ticker.Stop()
		var last int64
		for {
			select {
			case <-stopSampling:
				return
			case <-ticker.C:
				cur := atomic.LoadInt64(&counter.total)
				if atomic.LoadInt32(&counter.halfwaySet) == 0 &&
					time.Since(start) > speedTestRampWindow {
					atomic.StoreInt64(&counter.halfwayBytes, cur)
					atomic.StoreInt32(&counter.halfwaySet, 1)
				}
				delta := cur - last
				last = cur
				elapsed := time.Since(start).Seconds()
				// 前 30% 是爬坡期，速度还没稳定，报上去只会让人误判。
				percent := 10
				if elapsed > 0 {
					percent = 10 + int(40*float64(cur)/float64(speedTestDownBytes))
					if percent > 50 {
						percent = 50
					}
				}
				report(SpeedTestProgress{
					Phase:      speedTestPhaseDown,
					DownMbps:   mbps(delta, speedTestSampleMs),
					Percent:    percent,
					ServerName: speedTestName,
				})
			}
		}
	}()

	for i := 0; i < speedTestStreams; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req, err := http.NewRequestWithContext(ctx, http.MethodGet,
				downURLFor(speedTestDownBytes/speedTestStreams), nil)
			if err != nil {
				errs <- err
				return
			}
			resp, err := client.Do(req)
			if err != nil {
				errs <- err
				return
			}
			defer resp.Body.Close()
			buf := make([]byte, 64*1024)
			for {
				n, err := resp.Body.Read(buf)
				if n > 0 {
					atomic.AddInt64(&counter.total, int64(n))
				}
				if err != nil {
					if err != io.EOF {
						errs <- err
					}
					return
				}
			}
		}()
	}
	wg.Wait()
	close(stopSampling)
	close(errs)

	if err := <-errs; err != nil && atomic.LoadInt64(&counter.total) == 0 {
		return 0, err
	}
	elapsed := time.Since(start).Seconds()
	if elapsed <= 0 {
		return 0, nil
	}
	// 前一半时间是爬坡（TCP 慢启动、并发流建立），只取后半段的增量算速度。
	// 之前虽然注释这么写，实现却是全程平均，所以读数偏保守。
	half := int64(atomic.LoadInt64(&counter.halfwayBytes))
	tail := atomic.LoadInt64(&counter.total) - half
	if half > 0 && tail > 0 {
		return mbps(tail, int(elapsed*500)), nil
	}
	return mbps(atomic.LoadInt64(&counter.total), int(elapsed*1000)), nil
}

func measureUpload(ctx context.Context, client *http.Client, report func(SpeedTestProgress), latency int, down float64) (float64, error) {
	// 多流上传：单条 TCP 在高延迟链路上跑不满带宽，10MB 单流测出来的数会明显
	// 偏低（实测 14 Mbps 就是被这个限制的）。
	const streams = 4
	chunk := make([]byte, speedTestUpBytes/streams)
	for i := range chunk {
		chunk[i] = byte(i)
	}

	var sent int64
	var wg sync.WaitGroup
	errs := make(chan error, streams)
	start := time.Now()

	stop := make(chan struct{})
	go func() {
		ticker := time.NewTicker(speedTestSampleMs * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				done := atomic.LoadInt64(&sent)
				percent := 50
				if done > 0 {
					percent = 50 + int(50*float64(done)/float64(speedTestUpBytes))
					if percent > 99 {
						percent = 99
					}
				}
				report(SpeedTestProgress{
					Phase:      speedTestPhaseUp,
					UpMbps:     mbps(done, int(time.Since(start).Milliseconds())),
					Percent:    percent,
					LatencyMs:  latency,
					DownMbps:   down,
					ServerName: speedTestName,
				})
			}
		}
	}()

	for i := 0; i < streams; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req, err := http.NewRequestWithContext(ctx, http.MethodPost, speedTestUpURL,
				&countReader{data: chunk, onRead: func(n int) {
					atomic.AddInt64(&sent, int64(n))
				}})
			if err != nil {
				errs <- err
				return
			}
			req.Header.Set("Content-Type", "application/octet-stream")
			resp, err := client.Do(req)
			if err != nil {
				errs <- err
				return
			}
			defer resp.Body.Close()
			_, _ = io.Copy(io.Discard, resp.Body)
		}()
	}
	wg.Wait()
	close(stop)
	close(errs)

	total := atomic.LoadInt64(&sent)
	if err := <-errs; err != nil && total == 0 {
		return 0, err
	}
	elapsed := time.Since(start).Seconds()
	if elapsed <= 0 {
		return 0, nil
	}
	return mbps(total, int(elapsed*1000)), nil
}

// 边读边报进度，用来统计上传过程中实际发出去多少字节。
type countReader struct {
	data   []byte
	off    int
	onRead func(int)
}

func (r *countReader) Read(p []byte) (int, error) {
	if r.off >= len(r.data) {
		return 0, io.EOF
	}
	n := copy(p, r.data[r.off:])
	r.off += n
	if r.onRead != nil {
		r.onRead(n)
	}
	return n, nil
}

func mbps(bytes int64, windowMs int) float64 {
	if windowMs <= 0 {
		return 0
	}
	return float64(bytes) * 8 / 1_000_000 / (float64(windowMs) / 1000)
}

func median(values []int) int {
	if len(values) == 0 {
		return 0
	}
	sorted := append([]int(nil), values...)
	sort.Ints(sorted)
	return sorted[len(sorted)/2]
}

func jitter(values []int) int {
	if len(values) < 2 {
		return 0
	}
	var sum int
	for i := 1; i < len(values); i++ {
		d := values[i] - values[i-1]
		if d < 0 {
			d = -d
		}
		sum += d
	}
	return sum / (len(values) - 1)
}
