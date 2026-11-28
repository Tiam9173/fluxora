package main

import (
	"context"
	"io"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type speedTestRoundTripper func(*http.Request) (*http.Response, error)

func (f speedTestRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

type speedTestTrackingBody struct {
	read   bool
	closed bool
}

type speedTestWaitBody struct{ ready <-chan struct{} }

func (b speedTestWaitBody) Read([]byte) (int, error) {
	<-b.ready
	return 0, io.EOF
}

func (speedTestWaitBody) Close() error { return nil }

func (b *speedTestTrackingBody) Read(p []byte) (int, error) {
	b.read = true
	return copy(p, "large response"), io.EOF
}

func (b *speedTestTrackingBody) Close() error {
	b.closed = true
	return nil
}

func TestSpeedClientDoesNotFallBackToDirectOnUnknownOutbound(t *testing.T) {
	client := newSpeedClient("missing-speed-test-outbound")
	defer client.CloseIdleConnections()
	transport := client.Transport.(*http.Transport)
	// This must reject the route before resolving or dialing the address.
	conn, err := transport.DialContext(context.Background(), "tcp", "invalid-address")
	if conn != nil || err == nil || !strings.Contains(err.Error(), "missing-speed-test-outbound") {
		t.Fatalf("expected a route rejection without a direct dial, got conn=%v err=%v", conn, err)
	}
}

func TestSpeedWindowMbpsSmoothsOlderBurst(t *testing.T) {
	samples := []speedSample{
		{at: 0, bytes: 0},
		{at: 100 * time.Millisecond, bytes: 100_000_000},
		{at: 600 * time.Millisecond, bytes: 110_000_000},
		{at: 1100 * time.Millisecond, bytes: 120_000_000},
	}
	if got := speedWindowMbps(samples, time.Second); got != 160 {
		t.Fatalf("rolling speed = %v Mbps, want 160 Mbps", got)
	}
	if got := speedWindowMbps(samples[:1], time.Second); got != 0 {
		t.Fatalf("speed with one sample = %v, want 0", got)
	}
}

func TestSpeedAfterRampUsesMeasuredSteadyDuration(t *testing.T) {
	total := int64(10_000_000)
	beforeRamp := int64(2_000_000)
	elapsed := 10 * time.Second
	rampEnd := 2 * time.Second
	got := speedAfterRamp(total, beforeRamp, elapsed, rampEnd)
	if got != 8 {
		t.Fatalf("steady speed = %v Mbps, want 8 Mbps", got)
	}
}

func TestMeasureDownloadWaitsForSamplerToFinish(t *testing.T) {
	secondSample := make(chan struct{})
	releaseSampler := make(chan struct{})
	var samples atomic.Int32
	client := &http.Client{Transport: speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       speedTestWaitBody{ready: secondSample},
			Request:    req,
		}, nil
	})}
	finished := make(chan error, 1)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, err := measureDownload(ctx, client, func(SpeedTestProgress) {
			if samples.Add(1) == 2 {
				close(secondSample)
				<-releaseSampler
			}
		})
		finished <- err
	}()

	select {
	case err := <-finished:
		t.Fatalf("download returned before its sampler stopped: %v", err)
	case <-secondSample:
	}
	select {
	case err := <-finished:
		t.Fatalf("download returned while progress was being reported: %v", err)
	case <-time.After(20 * time.Millisecond):
	}
	close(releaseSampler)
	select {
	case err := <-finished:
		if err != nil {
			t.Fatalf("measureDownload() error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("download did not finish after releasing its sampler")
	}
}

func TestMeasureUploadWaitsForSamplerToFinish(t *testing.T) {
	secondSample := make(chan struct{})
	releaseSampler := make(chan struct{})
	var samples atomic.Int32
	client := &http.Client{Transport: speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		<-secondSample
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader("")),
			Request:    req,
		}, nil
	})}
	finished := make(chan error, 1)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, err := measureUpload(ctx, client, func(SpeedTestProgress) {
			if samples.Add(1) == 2 {
				close(secondSample)
				<-releaseSampler
			}
		}, 10, 10)
		finished <- err
	}()

	select {
	case err := <-finished:
		t.Fatalf("upload returned before its sampler stopped: %v", err)
	case <-secondSample:
	}
	select {
	case err := <-finished:
		t.Fatalf("upload returned while progress was being reported: %v", err)
	case <-time.After(20 * time.Millisecond):
	}
	close(releaseSampler)
	select {
	case err := <-finished:
		if err != nil {
			t.Fatalf("measureUpload() error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("upload did not finish after releasing its sampler")
	}
}

func TestResolveTargetFallsBackToAppleOverHTTPS(t *testing.T) {
	const appleDownloadURL = "https://apple.test/download"
	const appleUploadURL = "https://apple.test/upload"
	transport := speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		if req.URL.Host == "speed.cloudflare.com" {
			return &http.Response{
				StatusCode: http.StatusServiceUnavailable,
				Header:     make(http.Header),
				Body:       io.NopCloser(strings.NewReader("unavailable")),
				Request:    req,
			}, nil
		}
		body := strings.Repeat("x", 256*1024)
		if req.URL.String() == appleConfigURL {
			body = `{"urls":{"large_https_download_url":"` + appleDownloadURL +
				`","https_upload_url":"` + appleUploadURL + `"}}`
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(body)),
			Request:    req,
		}, nil
	})
	client := &http.Client{Transport: transport}
	name, latencyURL, down, up, ok := resolveTarget(context.Background(), client)
	if !ok || name != "Apple" || latencyURL != appleDownloadURL || down != appleDownloadURL || up != appleUploadURL {
		t.Fatalf("target = %q, %q, %q, %q, %v", name, latencyURL, down, up, ok)
	}
}

func TestResolveTargetChoosesFasterPayloadProbe(t *testing.T) {
	const appleDownloadURL = "https://apple.test/download"
	const appleUploadURL = "https://apple.test/upload"
	transport := speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		switch {
		case req.URL.Host == "speed.cloudflare.com":
			time.Sleep(50 * time.Millisecond)
		case req.URL.String() == appleConfigURL:
			return &http.Response{
				StatusCode: http.StatusOK,
				Header:     make(http.Header),
				Body: io.NopCloser(strings.NewReader(
					"{\"urls\":{\"large_https_download_url\":\"" + appleDownloadURL +
						"\",\"https_upload_url\":\"" + appleUploadURL + "\"}}",
				)),
				Request: req,
			}, nil
		case req.URL.Host == "apple.test":
			time.Sleep(5 * time.Millisecond)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(strings.Repeat("x", speedTestProbeBytes))),
			Request:    req,
		}, nil
	})
	client := &http.Client{Transport: transport}

	name, latencyURL, down, up, ok := resolveTarget(context.Background(), client)
	if !ok || name != "Apple" || latencyURL != appleDownloadURL || down != appleDownloadURL || up != appleUploadURL {
		t.Fatalf("target = %q, %q, %q, %q, %v; want faster Apple payload", name, latencyURL, down, up, ok)
	}
}

func TestSpeedtestTargetProbesServersInParallelAndKeepsFastestHTTPSHost(t *testing.T) {
	var mu sync.Mutex
	active, peak := 0, 0
	transport := speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		body := ""
		switch {
		case req.URL.Host == "speed.cloudflare.com" && req.URL.Path == "/meta":
			body = "{\"city\":\"Seattle\"}"
		case req.URL.Host == "www.speedtest.net":
			body = "[{\"host\":\"slow.test\",\"name\":\"Slow\",\"sponsor\":\"S\"},{\"host\":\"fast.test\",\"name\":\"Fast\",\"sponsor\":\"F\"}]"
		case req.URL.Path == "/latency.txt":
			mu.Lock()
			active++
			if active > peak {
				peak = active
			}
			mu.Unlock()
			if req.URL.Host == "slow.test" {
				time.Sleep(50 * time.Millisecond)
			} else {
				time.Sleep(5 * time.Millisecond)
			}
			mu.Lock()
			active--
			mu.Unlock()
		default:
			t.Errorf("unexpected request: %s", req.URL)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(body)),
			Request:    req,
		}, nil
	})
	client := &http.Client{Transport: transport}

	name, latencyURL, down, up, ok := speedtestTarget(context.Background(), client)
	if !ok || name != "F Fast" || latencyURL != "https://fast.test/latency.txt" ||
		down != "https://fast.test/download?size=%d" ||
		up != "https://fast.test/upload" {
		t.Fatalf("target = %q, %q, %q, %q, %v", name, latencyURL, down, up, ok)
	}
	if peak < 2 {
		t.Fatalf("server probes were not concurrent; peak active=%d", peak)
	}
}

func TestAppleTargetRejectsPlainHTTPEndpoints(t *testing.T) {
	client := &http.Client{Transport: speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		body := `{"urls":{"large_https_download_url":"http://apple.test/download",` +
			`"https_upload_url":"https://apple.test/upload"}}`
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(body)),
			Request:    req,
		}, nil
	})}
	if _, _, ok := appleTarget(context.Background(), client); ok {
		t.Fatal("Apple target accepted a plain HTTP download URL")
	}
}

func TestFixedDownloadLatencyProbeClosesWithoutReadingLargeBody(t *testing.T) {
	previous := speedTestDownFixed
	speedTestDownFixed = "https://apple.test/large"
	t.Cleanup(func() { speedTestDownFixed = previous })
	body := &speedTestTrackingBody{}
	client := &http.Client{Transport: speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		if got := req.Header.Get("Range"); got != "bytes=0-0" {
			t.Errorf("Range = %q, want bytes=0-0", got)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       body,
			Request:    req,
		}, nil
	})}
	if _, err := measureLatency(
		context.Background(), client, 1, "https://apple.test/large", true,
	); err != nil {
		t.Fatal(err)
	}
	if body.read || !body.closed {
		t.Fatalf("body read=%v closed=%v, want unread and closed", body.read, body.closed)
	}
}

func TestMeasureLatencyUsesSelectedServerEndpoint(t *testing.T) {
	const latencyURL = "https://fast.test/latency.txt"
	client := &http.Client{Transport: speedTestRoundTripper(func(req *http.Request) (*http.Response, error) {
		if req.URL.String() != latencyURL {
			t.Errorf("latency probe used %s, want %s", req.URL, latencyURL)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader("test")),
			Request:    req,
		}, nil
	})}
	if _, err := measureLatency(context.Background(), client, 1, latencyURL, false); err != nil {
		t.Fatal(err)
	}
}
