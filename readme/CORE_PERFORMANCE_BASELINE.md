# 内核性能基线

环境为 Windows amd64（OS build 26300）、AMD Ryzen 9 9955HX、Go 1.25.14。Windows 常规二进制使用 `GOAMD64=v3`、`CGO_ENABLED=0`、`with_gvisor` 和 `-trimpath`。

## Go 日志写入

同一 v1.19.34 集成副本，修改日志缓冲区前后各运行三次，`GOMAXPROCS=1`。以写满 512 条后的稳态写入为准。

| 指标 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 中位数 | 29.13 ns/op | 19.83 ns/op |
| 摊销分配 | 80 B/op | 0 B/op |

基准命令为 `go test -tags=with_gvisor -run '^$' -bench '^BenchmarkRecordFullLogHistory$' -benchmem -count=3 .`。该基准只覆盖写入。读取会复制日志快照，以便在编码 JSON 前释放读锁。日志界面加载耗时为 NOT VERIFIED。

## Windows 进程与配置

使用临时目录和相同的最小配置，通过本机回环连接内核。启动计时从创建进程到控制连接建立，配置计时覆盖 `setupConfig` RPC。每组七次，两组反向运行顺序。

| 指标 | v1.19.33 | v1.19.34 |
| --- | ---: | ---: |
| 两组启动中位数 | 121.27 / 61.66 ms | 121.26 / 77.59 ms |
| 两组加载中位数 | 26.11 / 9.17 ms | 16.82 / 9.54 ms |
| Windows amd64 二进制 | 60,866,560 B | 60,761,088 B |

本机负载变化明显，这些启动和加载样本不足以判断性能趋势。空闲与峰值内存、CPU、DNS 延迟、真实连接成功率、切换恢复、吞吐、资源泄漏和整包体积为 NOT VERIFIED。

## Fluxora 内存回收与异步测速

在同一份 v1.19.34 工作区上构建前后两个 Windows amd64 二进制，使用 Go 1.25.14、`GOAMD64=v1` 和 `with_gvisor`。配置基准使用 1,000 个本地节点和 3,000 条域名规则。两份二进制交替运行，每份累计 120 个样本，统计 `setupConfig` 的 RPC 耗时和 `GODEBUG=gctrace=1` 的强制回收次数。测速在每个进程发送 12,000 个不同的已移除节点名，取三次独立运行的 GC 后堆对象增长中位数。

| 指标 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 配置加载耗时 P50 | 46.43 ms | 42.57 ms |
| 配置加载耗时 P95 | 50.57 ms | 46.11 ms |
| 每次配置加载强制 GC | 3 | 2 |
| 释放系统内存或关闭内核时强制 GC | 2 | 1 |
| 测速压测后堆对象净增长 | 12,131 | 73 |
| Windows amd64 内核体积 | 60,815,872 B | 60,805,632 B |

Go 桥接测试通过。Windows 回环验证覆盖配置热重载、监听器重启、策略选择及 65 次并发测速请求，测速上游实测峰值为 50。Linux amd64、macOS arm64 和 Android arm64 内核交叉构建通过。真实订阅、Android 真机、整包、RSS 和外网连接性能为 NOT VERIFIED。

## Mihomo 规则解析与子规则校验

同一 Windows amd64 环境用 Go 1.25.14、`with_gvisor`、`GOMAXPROCS=1` 跑三轮 Go 基准，以下是中位数。子规则样本是 14 层共享分支，每层两个子规则引用上一层的同一组子规则。

| 微基准 | 修改前 | 修改后 |
| --- | ---: | ---: |
| `DOMAIN-SUFFIX` 解析 | 182.3 ns，160 B，4 次分配 | 93.33 ns，48 B，1 次分配 |
| `IP-CIDR` 解析 | 226.1 ns，176 B，4 次分配 | 110.8 ns，64 B，1 次分配 |
| `AND` 解析 | 402.8 ns，368 B，6 次分配 | 218.4 ns，128 B，2 次分配 |
| 14 层共享子规则校验 | 8.857 ms，901,376 B | 6.144 µs，2,235 B |

完整配置加载使用 1,000 个节点、3,000 条域名规则和上述共享子规则。独立对照保留一个不共享的子规则。前后两个内核交替运行，每个样本组各收集 120 次 `setupConfig` 耗时，强制 GC 均为两次。

| 配置样本 | 修改前 P50 / P95 | 修改后 P50 / P95 |
| --- | ---: | ---: |
| 14 层共享子规则 | 52.52 / 56.41 ms | 44.71 / 47.89 ms |
| 单个子规则 | 45.24 / 49.87 ms | 44.22 / 48.84 ms |

规则解析、缺失引用、直接和间接循环引用测试通过。Windows 回环验证了通过子规则放行和拒绝流量、热重载和监听重启。Windows amd64、Linux amd64、macOS arm64、Android arm64 内核构建通过。Android 16 KB ELF 对齐已核对，真机和真实订阅为 NOT VERIFIED。

## 控制器修复后的配置与 GC 回归

同机对照使用 Go 1.25.14、Windows amd64 v1 和 `with_gvisor`。基线是采用本轮规则解析与 GC 优化前的 v1.19.34 集成二进制。最终版含这些优化及控制器鉴权修复。每版、每种配置各 120 次，交替运行。

| 配置样本 | 基线 P50 / P95 | 最终版 P50 / P95 |
| --- | ---: | ---: |
| 1,000 节点、3,000 规则、14 层共享子规则 | 57.12 / 62.58 ms | 45.84 / 48.31 ms |
| 相同节点与规则、单个子规则 | 49.34 / 52.84 ms | 45.23 / 50.13 ms |
| 单次配置加载的强制 GC | 3 次 | 2 次 |
| 释放系统内存或关闭内核的强制 GC | 2 次 | 1 次 |

Windows 回环验证包括成功热重载、无效规则被拒后已有路由继续转发、策略切换、监听重启、DNS A/AAAA、IPv4/IPv6 转发和 65 条批量测速请求。配置 secret 时，本地控制与调试端点均正确拒绝缺失或错误的密钥。Flutter 定向套件、Go 桥接和 Mihomo 定向套件通过。Windows、Linux、macOS 和 Android 内核均已构建，Android Debug Kotlin 编译通过。

## Windows 10 分钟空闲基线

使用相同的 1,000 节点和 3,000 条规则，开启本机混合代理与带密钥的回环控制器，关闭 TUN 和 DNS。预热 15 秒后每 15 秒采样，共 41 点，结束时验证控制器与内核在线并正常关闭。RSS 取 Windows 进程工作集，CPU 取累计用户与内核 CPU 时间差除以墙钟时间，以一个逻辑核为 100%。Go Heap 是 `HeapAlloc`，goroutine 来自核心状态 RPC。采样本身计入进程开销。

| 指标 | GC / 解析优化前 | GC / 解析优化后 | 控制器修复后 |
| --- | ---: | ---: | ---: |
| 进程 RSS 中位数 | 27.60 MiB | 26.01 MiB | 30.74 MiB |
| 进程 RSS 首次 / 最后 | 28.31 / 27.43 MiB | 28.23 / 25.83 MiB | 28.28 / 30.94 MiB |
| 平均 CPU | 0.078% | 0.026% | 0.023% |
| Go Heap 首次 / 最后 | 3.76 / 3.80 MiB | 3.76 / 3.80 MiB | 3.76 / 3.80 MiB |
| Go Heap 中位数 / 最高采样点 | 4.46 / 5.12 MiB | 4.47 / 5.18 MiB | 4.49 / 5.18 MiB |
| Goroutine 首次 / 最后 / 最高采样点 | 7 / 7 / 7 | 7 / 7 / 8 | 7 / 7 / 7 |

前两列在同一时段运行，最后一列稍后启动并部分重叠。最终版 RSS 中位数比最初基线高 3.14 MiB。三份运行结束时堆和 goroutine 接近，但单轮样本不能归因 RSS 波动，也不足以判断长期泄漏或宣称降低常驻 CPU。数小时运行、持续连接负载和 Android 真机待测。

运行 `python tool/measure_core_idle_windows.py <core.exe> <output.json> --duration 600 --interval 15` 可复现单版测试。三份原始采样分别为 `build/core-rule-pass/idle-before.json`、`idle-current.json` 和 `idle-hardened.json`。

## P0 隔离内存复测

Windows amd64，单进程串行运行，内置 Mihomo v1.19.34。A 为 GC 与规则优化前，B 为上轮鉴权修复后的版本。顺序 A/B/B/A/A/B。1,000 节点、3,000 规则，控制器和代理只绑定回环。预热 8 秒后，每进程依次运行 18 秒空闲、HTTP 64 KiB 连续传输、热重载及并发 32 的延迟测试。每 3 秒记录 RSS、Private Bytes、HeapAlloc 和 goroutine。以下为各阶段每轮中位数的中位数。第六轮在首次重载 RPC 等待超时后重跑，完整样本来自重跑。

| 场景 | RSS A / B，MiB | Private Bytes A / B，MiB | Go Heap A / B，MiB | Goroutine A / B |
| --- | ---: | ---: | ---: | ---: |
| 空闲 | 29.61 / 29.23 | 31.90 / 31.45 | 4.29 / 4.25 | 7 / 7 |
| 连续流量 | 36.02 / 35.52 | 38.02 / 37.27 | 5.82 / 5.44 | 7 / 7 |
| 重复重载 | 36.34 / 36.59 | 39.29 / 39.42 | 5.55 / 5.58 | 7 / 7 |
| 批量测速 | 43.07 / 43.07 | 46.62 / 46.75 | 4.85 / 4.82 | 7 / 7 |
| 停止负载、主动回收后 | 39.56 / 40.20 | 43.30 / 43.63 | 4.45 / 4.35 | 7 / 7 |

先前空闲工作集约 3 MiB 增幅未复现，Private Bytes 和 Go Heap 也没有同向增加。负载过后的两版工作集和私有提交量都高于空闲，主动回收后均下降，goroutine 回到 7。结果与工作集及运行时保留内存波动一致，无法分解历史样本里的每一类驻留页。连续流量和测速按相同时间与节拍驱动，完成量有差异。数小时、外网长期负载及 Android 真机为 NOT VERIFIED。原始样本与脚本位于 `build/core-p0`。[Windows 计数器定义](https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-process_memory_counters_ex)

仅空闲的补充组按 B/A/A/B 串行运行，每个进程预热 8 秒后测 60 秒，每 5 秒一采。A/B 的中位数为 RSS 30.16 / 29.80 MiB、Private Bytes 32.46 / 32.03 MiB、Go Heap 4.77 / 4.72 MiB、goroutine 7 / 7。两组的空闲结果方向一致。

## P0 DNS 键候选

现有 LRU/ARC 及 singleflight 都以 `Question.String()` 为键，包含域名的呈现格式及转义、查询类型、类。用结构体直接替代会改变部分等价转义名的键。试验补丁保留完全相同的字符串表示，在普通域名路径缩减中间字符串，并让一次查询的缓存、并发合并、重试及后台刷新复用键。候选通过 30,053 次键等价 fuzz 和真实 UDP 语义回归。

| Go Resolver 查询，四轮中位数 | 现有实现 | 试验补丁 |
| --- | ---: | ---: |
| 缓存命中 | 3.717 µs，592 B/op，19 allocs/op | 3.352 µs，552 B/op，17 allocs/op |
| 唯一域名、真实 UDP 上游 | 447.33 µs，11,191 B/op，129 allocs/op | 399.06 µs，11,000 B/op，120 allocs/op |

另以独立 Windows 内核的真实 UDP 监听器做两组对照。每个模式、每版、每组各 3 个进程，每进程 6,000 条查询，第二组反转运行顺序。表中 P50/P95 为三轮统计中位数，CPU 为内核进程平均每次查询的 CPU 工时中位数。

| 回环 UDP 测试 | P50/P95 原版 → 候选，µs | CPU 原版 → 候选，µs/查询 |
| --- | ---: | ---: |
| 第一组缓存命中 | 123.40/239.50 → 95.00/225.30 | 130.21 → 106.77 |
| 第二组缓存命中 | 75.70/202.49 → 77.80/204.10 | 83.33 → 98.96 |
| 第一组缓存未命中 | 543.55/795.99 → 663.90/922.88 | 531.25 → 666.67 |
| 第二组缓存未命中 | 497.70/770.19 → 507.90/783.37 | 505.21 → 541.67 |

内部查询减少分配，真实回环响应时间与 CPU 未获得可重复的收益。生产补丁已撤回，保留真实 DNS 的 LRU/ARC、A/AAAA/TXT、类型及类隔离、独立 resolver、缓存拷贝、取消、调用端超时、合并、过期刷新测试及 Go 基准。原始结果见 `build/core-p0/dns-*.log` 和 `dns-ab*.jsonl`。

## P0 运行时指标候选

`HeapInuse` 映射到 `heap/objects + heap/unused`，`HeapIdle - HeapReleased` 映射到 `heap/free`，`StackInuse` 映射到 `heap/stacks`，堆对象数可读 `/gc/heap/objects:objects`，goroutine 可读 `/sched/goroutines:goroutines`。核心状态的最近一次 GC 时间仍需保留原语义。同一暂停内的映射由 Go 运行时测试核对，相邻但不同时刻的读数会受分配和回收影响，实验中一次有 48 KiB 差异。[Go 运行时字段对照](https://go.dev/src/runtime/metrics_test.go)

首页内存卡的常规节拍是 2 秒一次。Windows 对同一内核交替运行有轮询、无轮询、无轮询、有轮询，每段 20 秒。两轮实际 RPC 的中位耗时为 618 / 536 µs。Windows 进程 CPU 增量两轮有轮询均为 0 计时刻度，两轮无轮询为 15.625 / 0 ms，差异低于有效分辨率。Go 紧循环对照（GOMAXPROCS=2）中位耗时 62.88 µs → 0.590 µs。按每秒 0.5 次折算约 31 µs/s 墙钟时间，不代表总 CPU 收益。当前生产实现沿用 `ReadMemStats`。

## Core X Stage 1 — Windows TCP/UDP 转发和资源回收（#9）

Windows 11 Pro 26300、Ryzen 9 9955HX（16 核 / 32 线程）、约 15.2 GiB RAM、Go 1.25.14、Python 3.14.4。源码为 `cbd8a6a7` 加现有工作树，Mihomo `v1.19.34` / `0455d0d28c4526937380505153e65a843d8612e8`。两个 Core 均为 Windows amd64 v1、CGO 关闭、`-trimpath -tags=with_gvisor`，保留符号供 pprof。真实桥接 RPC 启动独立核心，回环混合入口用 SOCKS5，出站 `MATCH,DIRECT` 至受控 Python TCP/UDP echo。控制器仅绑定回环并鉴权，`log-level: debug` 供 pprof，关闭 TUN。吞吐为双向应用净荷总量，P50/P95/P99 是每轮百分位的中位数。`B/op`、`allocs/op` 和 CPU 工时为带回环监测开销的内核进程增量，除以收到的回包数。

| 负载 | 直连 / 经 Mihomo，MiB/s | 经 Mihomo P50 / P95 / P99，µs | 经 Mihomo CPU µs/op / B/op / allocs/op | 经 Mihomo 到达 / 发送 |
| --- | ---: | ---: | ---: | ---: |
| TCP 16 KiB，1 连接 | 221.23 / 105.49 | 255 / 510 / 679 | 196.2 / 157 / 2.24 | 19,209 / 19,209 |
| TCP 64 KiB，4 连接 | 1,078.90 / 570.72 | 837 / 1,217 / 1,428 | 584.6 / 302 / 4.14 | 27,505 / 27,505 |
| UDP 256 B，1 会话，逐包 | 6.69 / 3.07 | 115 / 334 / 468 | 107.6 / 1,753 / 42.14 | 37,937 / 37,937 |
| UDP 1,200 B，4 会话，每批 16 包 | 61.50 / 50.29 | 1,673 / 2,619 / 3,252 | 100.9 / 2,864 / 42.20 | 134,480 / 134,496 |

直连组与转发组各 4 轮，每次 1.5 秒，交替顺序。TCP 采样中约 80% 的累积 CPU 时间落在 Windows `WSASend` 路径。UDP 初始 pprof 显示 `bytes.Join` 占分配字节约 36%，独立复测为 42%，来源为 SOCKS5 回包拼装。新增回包缓冲池复用，以下 A/B 都经过相同 Mihomo 路径。不限速 ABBAABBA，每版各 4 个新进程，每负载 2.5 秒。等速 BAABBAAB，每进程发 32,000 包，四会话各每 4 ms 发送一批 16 包。吞吐包含收齐最后一批或等待读超时的时间。

| 负载 | 吞吐 A → B，MiB/s | P50 / P95 / P99 A → B，µs | CPU A → B，µs/op | B/op A → B | allocs/op A → B | 丢包 A → B |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| UDP 256 B | 2.77 → 2.95 | 135/355/469 → 124/339/459 | 114.69 → 111.84 | 1,750 → 1,460 | 42.10 → 41.10 | 0/57,790 → 0/60,395 |
| UDP 1,200 B，尽力发送 | 47.44 → 48.28 | 1,890/2,821/3,453 → 1,647/2,559/3,082 | 114.91 → 105.11 | 2,854 → 1,512 | 42.17 → 41.13 | 13/216,288 → 42/226,720 |
| UDP 1,200 B，等速发送 | 35.42 → 35.99 | 1,809/3,080/3,687 → 1,648/2,618/3,146 | 137.47 → 122.81 | 2,866 → 1,536 | 42.18 → 41.14 | 18/128,000 → 19/128,000 |
| TCP 64 KiB，对照 | 580.84 → 582.95 | 825/1,157/1,347 → 824/1,171/1,368 | 565.75 → 583.90 | 306 → 300 | 4.19 → 4.20 | 0/43,676 → 0/47,257 |

各组批内乱序均为 0。等速高负载的 P95 四轮原始值为 A `3935/3543/2617/2447 µs`、B `3317/2419/2747/2489 µs`，区间有重叠，保留补丁的主要依据是重复获得的每包分配降幅。等速试验收尾 RSS / Private Bytes / Heap 中位数为 A `32.42 / 35.42 / 2.48 MiB`、B `32.25 / 35.40 / 2.50 MiB`。两版独立采集 CPU/heap/allocs；候选的回包 `bytes.Join` 热点消失，包读取、地址转换与 Windows 写包仍有开销。锁竞争和小时级内存趋势 NOT VERIFIED。

两版通过 TCP 半关闭验证。UDP `/connections` 会话计数随真实转发从 0→1→0，A/B 空闲过期为 60.09/60.06 秒；在同一 UDP 源端口重发后拿到新 ID，验证旧会话被释放。关闭 SOCKS5 控制连接后 UDP tracker 在空闲到期前仍可出现；断开不是现有 UDP 会话删除触发条件。首次使用 UDP 后约 32 个工作 goroutine 留作内核级包处理队列，过期后回收会话相关 goroutine，进程关闭与端口释放通过。计数来自 tracker 快照，未给 NAT 表增加生产观测接口。

候选额外核对了主动关闭。关闭 SOCKS5 控制连接后仍有 1 个 UDP tracker，鉴权 `DELETE /connections/{id}` 后降至 0，goroutine 回到 39（7 个初始运行时任务加 32 个 UDP 工作线程）。详情见 `build/core-relay/recovery-full/recovery.json`。

复现时从基线和加补丁的工作副本各在 `core` 目录执行同一构建命令，分别保存为 A 和 B。然后回到仓库根目录运行基准。

```powershell
$env:CGO_ENABLED = '0'
$env:GOAMD64 = 'v1'
go build -mod=readonly -trimpath '-ldflags=-X github.com/metacubex/mihomo/constant.Version=v1.19.34' -tags=with_gvisor -o ../build/core-relay/core.exe .

python tool/benchmark_core_relay_windows.py <A.exe> build/core-relay
python tool/benchmark_core_relay_windows.py <A.exe> build/core-relay --candidate <B.exe>
python tool/benchmark_core_relay_windows.py <A.exe> build/core-relay --candidate <B.exe> --paced
python tool/benchmark_core_relay_windows.py <B.exe> build/core-relay/recovery-full --recovery-only
```

原始记录在 `build/core-relay/relay.json`、`relay-ab.json`、`relay-paced.json` 及 `profile-A/`、`profile-B/`。A/B SHA-256 为 `0e5ef2598578e627d328a589cbcfa5feb7e0ab2cd6bff7903fb28d4a7feebaa0` / `4f0b0de98dee6abe6efa8a33dcba0c3bfdd77846fd369fd39e999e48461ea84e`。这些是本轮未剥离符号的测试构建。

## Core X Stage 2 — Windows 连接建立分段（#3/#4/#5/#15）

基线 A 使用相同回环控制器和 SOCKS5 入口，本地权威测试 DNS、临时 CA 信任的 HTTPS 目标和唯一域名，每组成功请求 160 次。对照 IP 不解析目标主机。加延迟组人为加入约 40 ms DNS、25 ms HTTP 应答。SOCKS5 命令 ACK 早于异常或成功的目标拨号；目标 TCP 列用上游 DNS 应答后至目标 `accept` 的差值，包含核心调度，TLS 列从 `accept` 计时至客户端握手完成。IP 组的目标 TCP 列由 SOCKS5 ACK 起计。

| 负载 | 本地 TCP P50/P95/P99 | SOCKS5 问候 / ACK P95 | DNS 上游 P50/P95/P99 | 目标 TCP 近似 P50/P95/P99 | TLS P50/P95/P99 | HTTP TTFB P50/P95/P99 | 首流量 P50/P95/P99 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| IP | 0.53/18.95/24.79 | 0.36/0.28 | — | 0.93/1.50/1.95 | 2.55/3.33/3.83 | 0.64/1.16/1.44 | 5.76/24.01/30.94 |
| 唯一域名 | 0.58/19.79/23.76 | 0.36/0.30 | 0.07/0.10/0.12 | 1.04/1.65/2.00 | 2.68/3.30/3.74 | 0.67/1.16/1.50 | 6.82/27.12/30.14 |
| 人为延迟 | 0.57/17.82/21.21 | 0.34/0.30 | 40.48/40.82/40.90 | 1.44/1.93/2.65 | 2.77/3.49/3.88 | 26.47/26.95/27.30 | 74.01/90.04/93.18 |

单位均为毫秒。4 个新进程启动→桥接 P50/P95/P99 `103.71/132.68/132.68 ms`、`setupConfig` `11.23/12.25/12.25 ms`、`startListener` `1.08/1.73/1.73 ms`，启动→首流量 `146.36/169.63/169.63 ms`。少量冷样本的尾部分位只是最大观测值。3 次明确 TCP 拒绝的端到端失败 P50/P95 `2984/3590 ms`，日志显示同目标多次退避重试。DNS 持续不响应、单上游丢首包两组各 3 次，均约 5 秒失败，各次只观测到一次上游查询。验证局部失败分类及 TLS 验证，维持拨号和重试语义。下一轮先测目标暂拒后恢复及各平台错误包装，再评估是否收敛永久拒绝的重试。外网上游、移动网络和不可达 IPv6 与可达 IPv4 的并存场景 NOT VERIFIED。

最终二进制复验 480/480 成功，额外 4 次新进程均收到首字节，3 次明确拒绝、3 次 DNS 超时、3 次单上游丢首包均失败。IP / 唯一域名 / 人为延迟的首流量 P95 为 23.45 / 25.05 / 91.76 ms，启动→首流量 P50/P95 为 134.03/177.26 ms。两批在不同时段运行，中位 CPU 为 3.65 / 3.32 ms/条，收尾 RSS 28.12 / 28.47 MiB，Private Bytes 29.98 / 29.55 MiB，Heap 3.37 / 3.38 MiB，goroutine 均为 7。视为回归复验，暂不归因到 UDP 补丁。最终日志在 `build/core-relay/connect-candidate/`。

运行 `python tool/benchmark_core_connect_windows.py <core.exe> <openssl.exe> build/core-relay/connect-run` 可重复。原始请求分段、资源快照和受控 DNS 日志见 `build/core-relay/connect.json` 和 `connect-*.log`。Windows、Android 真机 TUN 需在专门的测试环境另行验收。

## Core X 连续验证（Stage 2-B 至 Stage 10）

- **#4/#5 建连** · Windows ABBA，每版 8 次持续拒绝，两个批次 P50 的中位数 2,935 → 2,010 ms，P95 3,292 → 2,883 ms。550 ms 后同地址同端口恢复，两版各 16/16 成功。DNS 超时与丢首包约 5 秒，后续请求恢复。证书错误和无效 SOCKS 命令按预期失败。撤销并发后连接归零。
- **#6/#10/#14 网络栈** · Linux WSL 隔离 TUN 的 gVisor/system/mixed 各 15 个 64 KiB 请求成功。受控 DNS 查询被接管。原出口上线后 17/15/15 ms 恢复，接口、IPv4 路由和策略清理通过。Windows 模拟 IPv6 挂起时约 300 ms 选择同主机 IPv4，落选连接关闭。真实 A/AAAA 两组各 8/8，P95 29.83/22.17 ms。隔离 Linux TAYGA NAT64 16/16，受控 AAAA 经翻译抵达 IPv4 原站。运营商 IPv6、Windows/Android TUN、休眠唤醒待验。
- **#11/#12 链路** · 直连及 1/2/3 跳各 40 个 TCP 64 KiB 回包，含建连的 P50 为 4.89/8.29/13.97/20.36 ms，P95 为 19.74/18.04/16.40/33.56 ms。逐跳拨号计数、坏中间跳及连接清理通过。WireGuard mips/gVisor 各 3 轮真实握手，变更 UDP 端口后使用同一密钥与对端重建均成功。个别重建约 5.2 秒，真实 WARP 和不中断的端点热更新待验。
- **#7/#8/#13 配置和测速** · 1,000 节点、3,000 规则，首条/末条/规则集/子规则/未命中各 40 次。初始 P50 2.38–2.46 ms，短 profile 中套接字调用占主导。非法配置旧内核重启失败，补丁后沿用同端口和原规则。3 × 65 次异步测速成功，实际并发峰值 50，分发到结果 P50/P95/P99 176/319/323 ms。goroutine 7 → 7，连接归零。真实订阅与高抖动节点待验。
- **#16/#18 构建** · PGO 使用 TCP、UDP、规则 profile，固定负载 A/B 各 4 轮。TCP CPU 402.34→410.16 µs，P95 1.322→1.235 ms。UDP CPU 166.02→155.76 µs，P95 2.206→2.287 ms。无丢包，内核 60,809,216→60,840,448 B。保留非 PGO。Windows amd64、arm64、Go 1.20 兼容，Android armv7/arm64 和 macOS arm64 编译通过。Go 1.20 回环烟测 3/3。
- **实际本地包** · Windows Inno 未签名包 54,639,365→54,650,986 B，ZIP 67,124,957→67,197,791 B。组件锚点与核心/助手重新匹配。Android 原验证包 201,532,749 B，其中有 20,034,417 B 旧内核条目残留。通过 ZIP 中央目录顺序为两包重写所有有效条目，统一 DEFLATE、`zipalign -P 16 4` 和调试 v2 签名后，APK 为 165,890,337→169,531,681 B（+2.20%）。对比 APK 内有效条目，只有 arm64 的 libclash 变化，未压缩为 53,009,488→64,277,680 B。两平台基线与候选的包体变化不能归因于本轮两处局部补丁。现有 APK 对照使用 Debug，正式包大小待验。
- **#17 安全** · 实际控制器 4 个端点缺失与错误 Bearer 凭据均 401，有效凭据均成功。响应不含配置令牌，普通 HTTP 查询参数令牌无效。脱敏定向回归通过，构建哈希校验通过，篡改隔离副本时按预期拒绝。Android Debug APK v2 校验通过，正式签名待发布环境。

Android arm64 APK 的旧内核未使用 `with_gvisor`。同源重编译进一步隔离了这一变量。Go 1.25.14 和 NDK 28.2，`-buildmode=c-shared -pgo=off -trimpath`，链接剥除调试信息，16 KiB ELF 对齐。两处补丁修改前（临时 Go overlay）和修改后都带 `with_gvisor`，体积 64,277,512 → 64,277,576 B。仅移去该标签的同源临时参考库为 52,946,536 B，说明原 APK 差值的主要来源是标签所选的网络栈。参考库只用于归因，发布构建继续启用该栈。记录与三份测试库在 `build/core-x/packaging/`。

原始记录及复现路径见 [执行检查点](CORE_X_EXECUTION_PROGRESS.md)。

### Linux WSL 三栈双栈复测

用最终 Linux 二进制在独立网络命名空间逐栈运行 `tool/verify_core_tun_linux.sh`。每种地址族分别承载 15 次完整 64 KiB HTTP、128 个 1,200 B UDP 往返与一次 DNS 劫持查询。

| 栈 | TCP IPv4 / IPv6 | UDP IPv4 / IPv6（全批耗时） | IPv4 接口恢复后首个 HTTP |
| --- | --- | --- | --- |
| gVisor | 15/15 · 15/15 | 128/128 · 128/128（67/52 ms） | 16 ms |
| system | 15/15 · 15/15 | 128/128 · 128/128（44/38 ms） | 12 ms |
| mixed | 15/15 · 15/15 | 128/128 · 128/128（47/46 ms） | 12 ms |

A/AAAA 查询均由 TUN 接管，受控上游未收到对应探针。两种地址族在接口断开时均失败，恢复后继续使用同一出站。停止后核对 IPv4/IPv6 的全路由表及策略规则。各栈一次，表内耗时用于复验连接正常，样本量不足以比较栈间性能。IPv6 恢复做功能断言，未单独计时。

### Vision 并发回归与构建

Windows Go 1.25.14，全量 race 的首轮结果为 64 个 Go 包通过、`listener/inbound` 失败。已有用例在相同进程中报告 Vision 共享状态和 smux/TLS 依赖缓冲区竞态。去除本轮拨号与配置补丁的临时基线中，原 gRPC Vision 用例仍报竞态。修复后在 raw、gRPC、WebSocket 回环上定向 race 五轮通过。

同机固定 `GOMAXPROCS=2`，同样的三个真实传输测试每进程跑三遍，以 ABBA、BAAB 顺序交替，每版 12 个新进程。旧/新 CPU 中位数 2,687.50 / 2,664.06 ms，墙钟中位 1,707.5 / 1,722.5 ms，24 组均正常。保留补丁的依据为并发正确性，样本未显示可量化的性能提升。原始记录为 `build/core-x/vision-candidate/ab-repeat.json` 与 `build/core-x/inbound-vision-integrated-race.txt`。

含 Vision 修复的 Windows Inno 54,649,981 B，便携 ZIP 67,200,226 B。Android 同工序 Debug 验证包 169,535,777 B，基线仍为 165,890,337 B。Android 包仅更新 arm64 ABI，两平台产物用于本地验收。完整路径和哈希见 [升级与回滚](CORE_UPGRADE_GUIDE.md)。

### Windows 两小时重载稳态

使用含拨号和配置修复、先于 Vision 同步补丁构建的二进制。1,000 节点、3,000 规则，回环 SOCKS5 持续请求，每约 30 秒重载同一配置。实跑 7,200.01 秒，1,429 个资源样本，无采样失败，正常关闭。

| 指标 | 实测 |
| --- | --- |
| 请求 | 136,416/136,425 成功（99.9934%）。6 次连接中止、2 次 reset、1 次 EOF |
| 成功请求 P50 / P95 / P99 | 2.701 / 19.283 / 24.139 ms |
| 重载 | 239/239 成功，P50 / P95 / P99 为 27.446 / 39.762 / 54.113 ms |
| 核心 CPU | 平均 3.823%，以单逻辑核为 100% |
| goroutine | 首次 7、峰值 9、最后 7 |
| 核心 RSS 中位数 | 第 15–30 分钟 40.36 MiB，最后 15 分钟 33.90 MiB |
| Private Bytes 中位数 | 44.13 → 47.96 MiB，最后两个 15 分钟窗口 47.98 / 47.96 MiB，峰值 49.04 MiB |
| Go HeapAlloc 中位数 | 5.90 → 6.24 MiB，峰值 8.80 MiB |

失败顺序已保存，缺少精确时戳与连接生命周期关联，无法判断是否与重载同窗。Go HeapAlloc 与私有提交衡量不同内容，现有样本无法归类增加的私有页。最后半小时趋稳，未确认持续 Go 堆或 goroutine 泄漏。宿主同时执行其他验收，且缺少同负载、同长度的前后 A/B，结果只作运行观察。

含 Vision 修复的最终 Windows 核心同配置实跑 600.01 秒。11,262/11,263 个请求成功，1 次 EOF，20/20 次重载成功，goroutine 7→9→7，正常关闭。请求 P95 18.278 ms，重载 P95 31.044 ms。原始记录为 `build/core-x/soak-2h/soak.json` 与 `build/core-x/soak-vision/soak.json`。

### smux 写入缓冲区对照

对照使用同一上游提交、Go 1.25.14、Windows amd64、`GOMAXPROCS=2`、项目的 sing 和 x/sys 版本。原有 `BenchmarkConnSmux` 通过真实 TCP 回环发送 128 KiB 块。两版各 12 个新进程，ABBA/BAAB 交替，每组至少 1.2 秒。

| 指标（中位数） | 修复前 | 修复后 |
| --- | ---: | ---: |
| 传输速度 | 816.94 MB/s | 810.84 MB/s |
| 单次写入 | 160,444 ns/op | 161,650 ns/op |
| 分配字节 | 134,995 B/op | 134,547 B/op |
| 分配次数 | 61 allocs/op | 61 allocs/op |

超时后队列仍引用调用方缓冲区的断言在原版 0/3 通过，修复版 3/3 通过。吞吐约低 0.75%，在现有负载下保留修复以消除共享缓冲区。数据为 Windows 回环基准，未测移动设备的写入开销。原始记录在 `build/core-x/smux-ownership/`。

### 重载窗口与内存分类

四个 Windows 回环进程交替执行，无重载→每 30 秒重载→每 30 秒重载→无重载。每组 180 秒。运行中 1,000 个节点、3,000 条规则，使用相同 SOCKS5 流量。

| 条件 | 成功率 | 前后各一分钟 Private Bytes 中位数（MiB） |
| --- | --- | --- |
| 无重载 | 7,055/7,055 | 40.47→41.58，39.77→40.80 |
| 30 秒重载 | 6,960/6,961，12/12 次重载成功 | 39.45→41.28，40.50→42.13 |

失败发生在运行后第 120.783–120.785 秒，落在第 120.75–120.79 秒的一次重载中。以只带诊断日志的 Go overlay 运行 100 次加速重载，306 个新连接成功，另 3 个被重置。三个客户端端口均与暂停路由应用期间的 `Inner` 拒绝日志一致。该路径解释加速复现中的三次断连，历史两小时样本缺少逐连接时间戳。

每组首尾从 pprof 读取 Go 的 `MemStats`。`Sys - HeapReleased` 增加 1.86–2.75 MiB，`StackInuse` 增加 0.66–1.34 MiB，`HeapAlloc` 减少 0.39–3.94 MiB。Go 统计是估算，不能逐页等同于 Windows Private Bytes。短测结果显示增长在两种条件中均出现，尚不足以说明两小时的全部增长。原始结果在 `build/core-x/soak-diagnostic-*/` 及 `build/core-x/reload-window/`。

### TCP 重载准入与 Restls 并发门禁

Windows 回环 1,000 节点、3,000 规则，每进程 100 次有效配置应用，ABBA 两轮每版。组选关闭持久化，测试在每次应用时显式选中 DIRECT，默认项会拒绝请求。测试只统计实际收到预期数据的连接。

| 指标 | 基线 | 候选 |
| --- | ---: | ---: |
| 请求完成 | 603/611 | 587/587 |
| 连接中止 / EOF | 6 / 2 | 0 / 0 |
| 成功请求 P50 / P95 | 2.482 / 21.143 ms | 2.401 / 17.822 ms |

每轮请求量受重载和测试调度影响，以上数据用于验证断连及组选保护。超时、满槽、内部请求和显式暂停取消经 Go race 单测覆盖。原始数据为 `build/core-x/reload-window/compare.json`。此记录覆盖 TCP 回环新连接，UDP 和大型远程 provider 的长重载没有复用这一结论。

Restls 固定发行源码除了四处调试日志参数外逐文件一致。先在隔离替换模块验证，再按正式 Go 模块接入复跑。Windows 七组 Restls 回环各三轮 race 通过，包括 TLS 1.2 和 1.3 的现有测试；记录为 `build/core-x/restls-logging/integrated-race.txt`。上游 Docker 测试模块在替换前后均因既有模块图无法以 `-mod=readonly` 解析，当前主机也未找到 Docker 命令。本轮的通过结果覆盖 Mihomo 主测试模块。

最终核心的 MIPS TUN 在隔离 WSL Linux 中验证了 IPv4/IPv6 各 15 个 64 KiB HTTP 请求、各 128 个 1,200 B UDP 往返、A/AAAA DNS 接管与双栈路由清理。UDP 两批分别耗时 45/40 ms，IPv4 出站接口恢复后首个 HTTP 请求为 13 ms，IPv6 恢复后请求也成功。gVisor、system、mixed 同一构建复验通过。这组单轮数据用于功能验收。MIPS 记录见 `build/core-x/tun-reload-restls-mips.txt`。[MIPS 项目](https://github.com/MetaCubeX/mipstack)

### 四栈 TUN 短流和批量传输

同一隔离 WSL 环境、veth 对端、TUN MTU 9,000 和 `fluxora-linux-reload-restls` 内核。短流与大流量各六轮，四栈每轮交替正反顺序。每栈、每地址族短流样本为 90 个 64 KiB HTTP 请求和 768 个 1,200 B UDP 往返。大流样本为 18 次 64 MiB HTTP 下载，每三次从 Go 子进程 `/proc/<pid>/stat` 取用户态与内核态 tick 差值。所有 TCP 内容长度与 UDP 回包均通过校验。CPU 指标仅计核心进程，未计独立对端和其余系统 CPU。

| TUN 栈 | TCP 首字节 P95 ms IPv4 / IPv6 | UDP 128 包耗时中位数 ms IPv4 / IPv6 | TCP 下载中位数 MiB/s IPv4 / IPv6 | 内核 CPU-s/GiB 中位数 IPv4 / IPv6 |
| --- | ---: | ---: | ---: | ---: |
| system | 1.474 / 1.353 | 33 / 34 | 1,596.0 / 1,570.7 | 0.693 / 0.667 |
| gVisor | 1.848 / 1.631 | 49 / 46 | 92.4 / 85.4 | 11.173 / 11.813 |
| mixed | 1.622 / 1.355 | 44 / 43 | 1,631.4 / 1,630.7 | 0.640 / 0.693 |
| MIPS | 1.648 / 1.859 | 41 / 40 | 1,351.9 / 1,328.4 | 1.867 / 1.813 |

四栈在隔离环境验证 A/AAAA 接管及路由清理，短流轮次原出站恢复后的首个成功 IPv4 请求在 9–13 ms。数据反映本机路径和该构建下的栈差异。维持现有默认栈，Windows/Android 负载、功耗及兼容性继续实机验收。日志及命令在 `build/core-x/{tun-stack-comparison,tun-bulk-comparison,compare-tun-stacks.sh,prepare-tun-bulk.py}`。

### Linux 双上联切换

最终诊断候选在独立 WSL 用户和网络命名空间使用两组 veth，分别为同一双栈 HTTP 服务提供可达路径。保留同一个 `fixture-uplink` 出站，开启 TUN 默认接口自动检测。每栈三次断开第一接口再恢复，服务端以 HTTP 正文返回连接的源地址。各次均核对 IPv4、IPv6 分别走预期接口，退出后接口 `corextun` 消失，IPv4/IPv6 路由及策略规则的排序后快照一致。快照前等待两接口 IPv6 链路本地地址完成重复地址检测。

| 压测栈 | 首次移除第一上联至双栈应答 | 后两次 | 回到第一上联 |
| --- | ---: | ---: | ---: |
| mips | 1,746 ms | 833–862 ms | 1,158–1,160 ms |
| mixed | 5,795 ms | 831–834 ms | 1,156–1,162 ms |
| gVisor | 2,691 ms | 832–883 ms | 1,156–1,160 ms |
| system | 4,836 ms | 832–834 ms | 1,158–1,159 ms |

时延包含接口命令、探针轮询及双栈首个确认回包。首轮差距较大，单轮数据不能用来比较栈性能。DNS A/AAAA 接管和 UDP 往返在切换前通过。原始记录 `build/core-x/delay-diagnostics/uplink-{mips,mixed,gvisor,system}.log`，复现脚本在同目录。

续测在两个实际 UDP DNS 端点返回查询的源 IP，使用新查询名避免缓存。每栈在起始、切换和回切后分别查询 A（IPv4 上游）及 AAAA（IPv6 上游），四栈客户端与上游均记录 **56/56** 个预期应答，结束后路由清理通过。首次切至第二接口耗时 1,635–4,777 ms，其中等待默认接口回调占 1,620–4,706 ms，回调后直到双栈 HTTP 均得到正文仅 15–71 ms。这个场景覆盖无连接 UDP 上游换路，DoH 或 DoT 长连接仍待独立验证。原始记录 `build/core-x/delay-diagnostics/uplink-dns-{mips,mixed,gvisor,system}.log`。

`sing-tun v0.4.29` 的 Linux 事件节流和默认接口防抖均为一秒。候选保持节流，将防抖改为由首个事件触发的固定窗口。在 mips、system 各跑 ABBA，基线、候选各四个进程。首次切换中位数 1,724.5 → 752.5 ms，但回到原上联最慢 1,171 → 2,021 ms，重复切换中位数 814.5 → 868.5 ms。两版各 56/56 DNS 及全部双栈 HTTP 通过。该候选未进入生产。记录 `build/core-x/delay-diagnostics/timer-*-*-*.log`。

第二个候选仅在 Linux 原接口已下线时加速接口检测，同样试验中首次切换中位数 2,196.5 → 776.0 ms，重复切换 876 → 871 ms，回到原上联却由 1,021 → 2,022 ms，候选 12 次回切都在 2,019–2,038 ms。两版各 56/56 DNS 及全部双栈 HTTP 成功，路由清理通过。该候选也未进入生产。两个实验的依赖副本和临时 Go 模块文件均在 `build/` 内，生产 `go.mod` 与依赖版本维持原样。第二个对照原始数据 `build/core-x/delay-diagnostics/linkdown-*-*-*.log` 及 `linkdown-comparison.json`。

### 私有 DoH 覆写前后对照

同一 Windows Mihomo 二进制使用 Flutter/Dart 修复前后生成的上游配置，ABBA 两轮。HTTPS DoH 回环服务用测试实例内显式信任的证书，域名和证书验证照常执行。基线把路径含 `cloudflare` 的私有上游移除，0/4 次连通，目标解析只到达现有 bootstrap。修复后 4/4 次真实 HTTPS DNS 查询进入私有端点，代理成功建立 HTTP CONNECT 并转发测试数据。这里只测连通性。对照命令与日志见 `build/core-x/check-private-doh.{dart,py}` 及 `private-doh-compare.txt`。

### HTTP 规则提供器和 UDP 重载

Windows 隔离回环首次通过 HTTP 下载 10,001 条 CIDR，再反复重载已缓存的提供器及 1,000 个节点、3,000 条域名规则。每版两进程，每进程 48 次应用配置。内部提供器下载明确使用本地直连，每次配置均由测试调用方指定同一组选项。代理只访问本地 HTTP 提供器和 TCP/UDP echo 服务。

| 路径 | `windows-reload-restls.exe` | `windows-reload-restls-final.exe` |
| --- | ---: | ---: |
| 96 次配置重载耗时中位数 | 99.23 ms | 100.55 ms |
| 已建 UDP 会话 | 117/165 | 125/173 |
| 新 UDP 会话 | 72/93 | 59/85 |
| 新 TCP | 546/547 | 550/550 |

两版的 UDP 失败请求全部在重载 RPC 期间开始。临时调试构建另跑 48 次重载，把 24 个既有会话超时和 5 个新会话超时全部对应到 `Inner` 状态拒收日志与客户端端口。未修改正式 UDP 转发。后续对比有界缓冲的丢包、时延和资源，验证内部 DNS 与显式停止不会被延迟。复现脚本与原始输出为 `build/core-x/reload-provider-udp.py`、`reload-provider-udp/results.json`、`reload-provider-udp-trace/`。

### UDP 重载暂存对照

同一 Windows 回环负载，ABBA，每版 96 次重载。A 为含 TCP 等待的 `windows-reload-restls-final.exe`，B 为加 UDP 暂存的 `windows-reload-udp-candidate.exe`。每次 UDP 超时会推迟脚本的下一次请求，因此两版的总样本数不同。

| 指标 | A | B |
| --- | ---: | ---: |
| 已建 UDP 会话成功率 | 71/119 | 674/674 |
| 新 UDP 会话成功率 | 51/81 | 104/104 |
| 新 TCP 会话成功率 | 506/506 | 521/521 |
| 已建 UDP 成功样本 P95 | 0.90 ms | 61.68 ms |
| 新 UDP 成功样本 P95，含关联建立 | 162.89 ms | 175.11 ms |
| 配置重载 P50 / P95 | 87.84 / 104.24 ms | 88.95 / 105.96 ms |

成功时延只统计收到回包的请求。A 的 78 个 UDP 失败达到超时门限。B 的尾延迟包含等待配置生效的时间。额外通过实际 HTTP 提供器暂停应用，确认新 UDP 在 `REJECT→DIRECT` 后才可达，同样的包在 `DIRECT→REJECT` 后未到达测试上游。应用被阻塞超过 1 秒时，旧包已过期，恢复后新包正常转发。Go race 覆盖挂起、过期、满槽和再次重载。

无重载 UDP 定速测试每版发 128,000 包，A 收到 127,973，B 收到 127,962，四轮的吞吐中位数均为 36.64 MiB/s。中位 CPU 工时 70.81 → 67.89 µs/回包，运行时分配 1,522 → 1,533 B/回包。有限样本未确认 CPU 或稳态丢包的趋势。

另各运行一次 48 次重载并等待自然过期。A、B 分别从 29、54 个活跃 UDP 会话降至 0，耗时 59.89、60.01 秒，goroutine 都回落到 39。过期后 Go Heap 为 7.42、7.38 MiB，Private Bytes 为 47.21、50.43 MiB。当前数据不足以解释约 3.2 MiB 私有提交差异。原始记录在 `build/core-x/reload-provider-udp-{abba,reclaim}/`、`reload-udp-steady/` 与 `check-udp-reload-routing.log`。

### 单次强制 GC 候选

两版均含 UDP 暂存，仅在 Go overlay 中省略热重载结束时第二次强制 GC，保留冷启动的主动释放。Windows 同一 10,001 条规则的 HTTP 提供器夹具，ABBA 每版各 96 次。`gctrace=1` 确认每进程强制 GC 总计 101 → 52，含预热和关闭。UDP 与 TCP 回包两版均得到完整响应。

| 指标 | 现行两次 | 候选一次 |
| --- | ---: | ---: |
| 重载 P50 / P95 | 76.19 / 82.03 ms | 72.94 / 96.80 ms |
| 进程 CPU 工时增量，48 次重载 | 17.08–17.50 s | 13.73–15.91 s |
| 预热后 Private Bytes | 35.19 MiB | 43.70–44.78 MiB |
| 压测后 Private Bytes | 46.03–46.20 MiB | 45.34–48.11 MiB |
| 压测后 Go Heap | 6.50–6.55 MiB | 6.49–6.54 MiB |

候选改善 CPU 和中位数，尾延迟及预热后私有提交上升。维持现行生产路径。样本、GC 日志及候选 overlay 位于 `build/core-x/reload-single-gc-abba/`、`single-gc-reload-overlay.json`。

### 规则提供器分配定位

相同规则负载用临时诊断构建执行 48 次热重载，读取预热前后差分 `alloc_space`，共采样 4,615.48 MiB。`rulesParse` 累计 3,643.93 MiB，占 78.95%。它反复为 YAML 规则逐行构造解析器，`yaml.Unmarshal` 累计 3,586.33 MiB，占 77.70%。进程 CPU profile 捕获 24.65 CPU 秒，`runtime.gcDrain` 累计占 41.26%。进程版 profile 用于避免重载时控制器重建切断在线采样连接。诊断轮的最长重载为 431.97 ms，300 ms 接收门限下有 4 个 UDP 超时，本轮不作为稳定性对照。生产解析器未改动，后续优先对照常见 CIDR 行的分配与 YAML 兼容性。数据在 `build/core-x/reload-provider-udp-profile/`，其中 `alloc-cum.txt` 是调用链的分配归因。

### CIDR 规则提供器快路径

Windows 11 26300、Ryzen 9 9955HX、Go 1.25.14。两版用同一工作树、相同 `with_gvisor` 和 `-pgo=off`，旧版只通过 Go overlay 恢复 `rules/provider/provider.go`。Go 基准使用 10,000 条 CIDR，每版 5 轮、每轮至少 500 ms，取中位数。

| 解析 10,000 条 | 旧版 | 候选 |
| --- | ---: | ---: |
| 时间 | 41.58 ms | 1.90 ms |
| 累计分配 | 79,710,221 B | 5,307,478 B |
| 分配次数 | 540,207 | 10,094 |

本地 HTTP 首次下载 10,001 条 CIDR 后进行缓存热重载，同时保持已有 UDP 关联、反复新建 UDP 关联和 TCP 连接。配置含 1,000 个节点和 3,000 条顶层规则。执行两轮 ABBA，每个独立进程 48 次重载，共 192 次/版。百分位使用最近秩，流量时延只计成功样本。

| 指标 | 旧版 | 候选 |
| --- | ---: | ---: |
| 热重载 P50 / P95 / P99 | 74.68 / 82.10 / 96.60 ms | 27.86 / 32.73 / 37.55 ms |
| 48 次重载的进程 CPU 工时增量 | 13.66–15.97 s | 4.91–7.34 s |
| 负载期间每次重载平均累计分配 | 95.46–95.51 MiB | 24.33–24.36 MiB |
| 已建 UDP 成功数 / 总数，P95 | 1,335/1,335，49.77 ms | 1,309/1,309，3.27 ms |
| 新 UDP 成功数 / 总数，P95 | 211/211，154.71 ms | 166/166，138.94 ms |
| 新 TCP 成功数 / 总数，P95 | 941/942，61.45 ms | 888/888，23.93 ms |
| 负载结束后 Private Bytes | 45.31–46.54 MiB | 43.95–45.42 MiB |
| 负载结束后 Go Heap | 6.45–6.53 MiB | 7.65–7.79 MiB |

重载较快的进程结束较早，因此总流量请求数不同。Private Bytes 和 Go Heap 为负载结束时的快照，不是峰值。候选减轻了本夹具的分配与重载压力，不能据此推断长期常驻内存或其他 YAML 负载。Windows Mihomo、Go 桥接普通全量及规则、CIDR、配置、控制器、隧道定向 race 通过。Android arm64/armv7 共享库编译与桥接导出核验通过，arm64 `LOAD` 对齐为 16 KiB。Android 未连接设备。

在 `core/Clash.Meta` 执行 `go test -mod=readonly -tags=with_gvisor ./rules/provider -run TestCIDRYamlRuleParseCompatibility -bench BenchmarkCIDRYamlRuleParse -benchmem -benchtime 500ms -count 5`。旧版使用只指向旧 `provider.go` 的 `-overlay`。从项目根执行 `python -B tool/benchmark_core_cidr_reload_windows.py <before.exe> <after.exe> <new-output-folder>`。原始输出为 `build/core-x/cidr-rules-benchmark-{before,after}.txt`、`reload-cidr-yaml-abba*/results.json`。

48 次热重载的候选差分分配 profile 共采样 1,163.98 MiB。`rulesParse` 累计 236.39 MiB，剩余较大的单条路径是节点选项解码 `decodeStructFromMap`，累计 504.81 MiB（43.37%）。这轮只用于热点定位。记录见 `build/core-x/reload-cidr-yaml-profile/alloc-cum.txt`。

Windows Flutter 静态分析及生命周期/DNS 覆写定向共 27 项通过。Linux amd64 在 WSL 独立网络命名空间通过 system、gVisor、mixed、mips 四栈双栈 TUN、DNS 与路由清理烟测。macOS arm64 通过交叉构建，运行待验。

### 节点选项解码的字段元数据

上轮候选的分配 profile 中，`decodeStructFromMap` 逐字段复制 `reflect.StructField` 到切片的行采样约 422.31 MiB。两次 `strings.Split` 的累计采样约为 29.50 MiB 和 29.00 MiB。候选为单次切分标签，字段队列只保留名称、值和可选标志。没有增加全局类型缓存。

以已含 CIDR 快路径的二进制为基线，另一版只用 Go overlay 替换结构解码器。使用同一 1,000 节点、10,001 CIDR 的 Windows 回环脚本，两轮 ABBA 共 192 次重载/版。

| 指标 | 旧解码器 | 候选 |
| --- | ---: | ---: |
| 重载 P50 / P95 / P99 | 27.90 / 32.20 / 39.98 ms | 23.82 / 26.79 / 33.96 ms |
| 负载期间每次重载平均累计分配 | 24.33–24.37 MiB | 17.55–17.58 MiB |
| 48 次重载的进程 CPU 工时增量 | 5.73–6.83 s | 5.52–6.41 s |
| 已建 UDP 成功数 / 总数，P95 | 1,310/1,310，2.91 ms | 1,243/1,243，4.43 ms |
| 新 UDP 成功数 / 总数，P95 | 170/170，140.01 ms | 162/162，140.24 ms |
| 新 TCP 成功数 / 总数，P95 | 909/909，23.91 ms | 859/859，24.08 ms |
| 负载结束后 Private Bytes | 44.16–45.41 MiB | 45.03–45.39 MiB |

保留约 28% 的重载分配降幅与两轮均一致的 P50/P95 改善。CPU 工时与结束时私有提交范围重叠，没有确认整进程 CPU 或常驻内存改善。已有 UDP 关联 P95 上升 1.52 ms，两版均无失败。结果不外推到其他节点类型比例或网络环境。异常标签组合、忽略项、大小写和必填错误用例在旧版与候选上均通过。原始样本见 `build/core-x/reload-structure-field-metadata-abba*/results.json`；行级 profile 在 `reload-cidr-yaml-profile/alloc-decoder-lines.txt`。

最终 Windows 二进制与参加 A/B 的候选 SHA-256 一致。Mihomo 与桥接普通全量通过，配置、解码器、适配器、提供器、控制器和隧道定向 race 通过。运行中控制器四端点鉴权通过，三批 195/195 延迟结果返回，每批并发峰值 50，结束无连接残留。千节点非法配置回滚和重启复验通过。最终 Linux 隔离四栈均通过，Android 双架构共享库与 macOS arm64 构建通过，Android arm64 ELF 为 16 KiB 对齐。

### 运行中规则提供器刷新

最终 Windows 内核通过本地 HTTP 执行 36 次内容更新和 36 个 ETag 304，交替验证匹配直连与未命中拒绝，包含普通 `payload:`、`rules:`、带引号和注释的语法。六次有明确报错的无头文件保留之前已生效的规则。单次功能对照的更新 P95 为 89.62 ms，混合了三类 YAML，不能作为纯 CIDR 快路径时延。

当时的独立失败用例：没有可识别标题且以换行结尾的文件，在 CIDR 优化前后均收到 HTTP 204，把提供器规则数从 10,001 变为 0，原先匹配的连接被拒绝。原始记录为 `build/core-x/cidr-provider-malformed-header/results.json` 与 `cidr-provider-refresh-supported-final/results.json`。后续修复见下节。

### UDP 暂存私有提交归类

用上轮的含 TCP 等待版和 UDP 暂存版重新跑 ABBA，每进程 48 次缓存重载。等到 UDP 会话自然到期，再用现有 `forceGc(true)` 触发一次诊断用 Go 内存归还。此处比较资源快照，未把强制回收加入生产路径。

| 快照，MiB | 无 UDP 暂存 | 有 UDP 暂存 |
| --- | ---: | ---: |
| 自然到期后 Private Bytes | 46.72–47.28 | 50.06–50.68 |
| 自然到期后 Go `Sys - HeapReleased` | 27.75–28.37 | 31.01–31.61 |
| 自然到期后上述指标之差 | 18.91–18.97 | 19.05–19.07 |
| 主动归还后 Private Bytes | 41.89–42.52 | 42.97–43.51 |
| 主动归还后 Go `Sys - HeapReleased` | 23.35–23.82 | 24.44–24.85 |

四个进程均约 60 秒回收全部 UDP 会话，goroutine 都回落到 39。组间 Private Bytes 中点差约 3.37 MiB，Go 运行时占用近似量之差约 3.25 MiB；主动归还后私有提交中点差约 1.03 MiB。结果支持短测差异主要来自 Go 仍持有的内存。两组成功建立的会话数不同，指标是相邻快照和近似值，不能逐页归因或排除数小时增长。复现：`python -B build/core-x/measure-reload-memory.py <without-udp.exe> <with-udp.exe> <new-output-folder>`；样本在 `build/core-x/reload-memory-breakdown-abba/results.json`。保留原回收行为。

### 规则热刷新修复回归

Windows 上运行 `python -B tool/verify_core_rule_refresh_windows.py <core.exe> <output>`。使用本地 HTTP 提供器、带鉴权的 API 和实际 SOCKS 转发。36 次内容更新、36 次 ETag 304、6 次错误响应返回 503，验证拒绝后缓存字节和原路由不变，停止再启监听后仍通。两种显式空列表都安装为 0 条并可重新更新。旧源码的定向 race 捕获策略、刷新时间和内容摘要的并发读写；修复后两包各重复 8 次，以及相邻 7 包定向 race 均通过。

使用 `tool/benchmark_core_cidr_reload_windows.py` 交替运行修复前后同工序二进制。两版各重载千节点和缓存 CIDR 规则 96 次，每次累计分配约为 17.5 MiB。

| 指标 | 修复前 | 修复后 |
| --- | ---: | ---: |
| 配置重载 P95 / P99（ms） | 25.98 / 30.24 | 26.06 / 30.80 |
| 已有 UDP 关联 | 622/622 | 619/619 |
| 新 UDP 关联 | 78/78 | 80/80 |
| 新 TCP | 442/442 | 437/437 |

这组数据用于验证两项正确性修复没有明显改变重载开销。格式混合的单独 HTTP 刷新计时未作因果比较，也没有据此宣称吞吐提升。原始数据见 `build/core-x/reload-rule-refresh-guard-abba/results.json`、`rule-refresh-final/results.json`、`provider-fix-race-repeat.log`。

Windows 桌面进程 race 用仅改变桌面入口构建条件的临时 overlay。带 `--stress-rounds 140` 的回环验证完成 140 次在线更新，后台 819 次状态读取及 796 次 TCP 转发都成功，日志无 race 报告。未经持续消费桥接事件的普通构建，642.68 秒内完成 2,420 次在线更新、10,036 次并发状态读取和 10,005 次 TCP 转发，最终追踪 TCP/UDP 均为 0。

这两次测试的脚本只在发 RPC 时读取桥接事件，和桌面客户端的常驻读取方式不同。一次暂停时捕获的协程快照中，452 个里有 442 个在连接退出时等 `main.send` 的锁；调用负责发送异步连接事件。这个压力结果说明测试端未排空事件时会产生反压，不能当成正常客户端的泄漏证据。测试脚本已加入独立事件读取，避免干扰 RPC 应答和后续刷新的资源观测。原始记录见 `build/core-x/rule-refresh-live-race/`、`rule-refresh-sustained-final/` 和 `rule-refresh-goroutine-stacks/`。

持续消费桥接事件的修复前基线复跑 647.67 秒：2,420 次更新、10,182 次状态读取和 10,025 次 TCP 转发全部成功，转发 P95 为 20.58 ms。26 个资源采样的协程为 7–8，停止负载后回到 7，TCP/UDP 连接追踪均为 0。RSS 起点/峰值/终点为 39.60/50.07/46.71 MiB，Private Bytes 为 43.50/52.53/49.85 MiB，Go Heap 为 6.29/9.77/7.48 MiB。这是约 11 分钟的混合规则刷新，不代替数小时或真机验收。原始报告为 `build/core-x/rule-refresh-sustained-drained/results.json`。

### 带引号和注释的 CIDR 标题

用加入事件读取的 `tool/verify_core_rule_refresh_windows.py <core.exe> <output> --stress-rounds 120` 交替运行新鲜进程，两版各 240 次持续刷新并混合格式，另各抽取 24 次单格式刷新。每次在线切换 10,001 或 10,002 CIDR 条目，校验规则数、缓存字节、后台状态和 SOCKS 转发。一次候选启动前分配回环测试端口失败，未计入数据；补跑沿用项目中先绑定 UDP 的双协议端口分配。

| 指标 | 快路径扩展前 | 快路径扩展后 |
| --- | ---: | ---: |
| 带引号及注释标题 P50 / P95（ms） | 78.83 / 87.89 | 30.64 / 38.94 |
| 普通 `payload:` P50 / P95（ms） | 22.89 / 42.53 | 22.15 / 37.07 |
| 普通 `rules:` 加带引号及注释的单条规则 P50 / P95（ms） | 20.99 / 32.40 | 30.40 / 43.65 |
| 混合负载累计分配（MiB/刷新） | 30.66 | 6.26 |
| 混合负载进程 CPU 工时（ms/刷新） | 103.26 | 23.05 |
| 伴随 TCP 转发（成功/总数） | 1,014/1,014 | 944/944 |
| 伴随状态读取（成功/总数） | 1,023/1,023 | 953/953 |

收益限于相同格式和这批规则。带引号的规则项仍用原解析器。两版测得的协程均为 7–9，最终连接追踪为 0。源码与候选二进制的 SHA-256 均为 `f42dad3e999f42a8bf4583266361d6818b94b586e10343482994047c09b6ab44`。路径：`build/core-x/quoted-cidr-drained-abba/`、`quoted-cidr-source-race.log`、`quoted-cidr-source-refresh/results.json`。

对普通 `rules:` 加带引号规则项单独运行 ABBA，每轮 120 次在线刷新。旧版两个进程的更新 P50/P95 分别为 35.29/45.10 和 35.86/50.44 ms；新版为 35.12/44.50 和 36.68/51.61 ms。相邻对照的 P95 方向不一致，未复现混合试验里的 11.25 ms P95 差距。累计分配两版约 6.21–6.22 MiB/刷新；922/922 → 909/909 TCP 转发和 922/922 → 910/910 状态读取，四轮的连接追踪均回到 0。原始报告在 `build/core-x/plain-rules-drained-abba/`。

用相同的窗口设置再做单次长对照，每版 2,420 次混合格式刷新，每版采样 26 次。后台状态和转发线程按时间运行，因此新版更早结束，后台请求总数不同。

| 指标 | 快路径扩展前 | 快路径扩展后 |
| --- | ---: | ---: |
| 墙钟总时长（s） | 647.67 | 593.15 |
| 更新 P50 / P95 / P99（ms） | 40.50 / 103.27 / 177.40 | 33.67 / 45.05 / 52.16 |
| 进程累计分配（MiB/刷新） | 30.61 | 6.23 |
| 进程 CPU 工时（s） | 221.59 | 59.92 |
| TCP 转发（成功/总数） | 10,025/10,025 | 9,156/9,156 |
| TCP 转发 P50 / P95（ms） | 4.35 / 20.58 | 11.36 / 20.08 |
| 状态读取（成功/总数） | 10,182/10,182 | 9,209/9,209 |
| RSS 最后八次中位数 / 峰值（MiB） | 47.04 / 50.07 | 46.80 / 48.04 |
| Private Bytes 最后八次中位数 / 峰值（MiB） | 50.21 / 52.53 | 49.52 / 50.95 |
| Go Heap 最后八次中位数 / 峰值（MiB） | 7.72 / 9.77 | 8.05 / 9.52 |
| goroutine 范围 / 停止负载后 | 7–8 / 7 | 7–10 / 7 |
| 停止负载后 TCP / UDP 追踪 | 0 / 0 | 0 / 0 |

规则刷新时延和分配下降与短 ABBA 一致。RSS、Private Bytes 和 Go Heap 的末段中位数接近，不能把累计分配下降解释为同等幅度的内存驻留节省。两轮后台请求的时延分布不同，不能用这组数据宣称 TCP 转发性能收益。原始报告：`build/core-x/rule-refresh-sustained-drained/results.json`、`build/core-x/rule-refresh-quoted-sustained-drained/results.json`。

### 整配置重载与规则下载交叠

`python -B tool/verify_core_rule_reload_windows.py <core.exe> <output>` 暂停旧提供器的回环 HTTP 响应，重载至同一缓存路径的新 URL，更新并确认 10,002 条规则，然后才允许旧响应返回。修复前旧请求 204，旧内容覆盖磁盘，再次重载得到 10,001 条。修复后旧请求 503，磁盘、已生效规则及再重载都保留 10,002 条，实际 SOCKS 转发成功。另用 `--bridge` 验证桌面 RPC 路径：控制器随重载重启，旧请求断开，缓存与路由保持新版本。普通及 race 内核均通过，后者仅用构建条件 overlay 启用桌面入口。原始输出在 `build/core-x/retire-provider-checked-*/` 和 `retire-provider-race-*/`。

用 `tool/benchmark_core_cidr_reload_windows.py` 对照每版 96 次千节点及缓存规则重载，持续做 TCP 与新、旧 UDP 转发。

| 指标 | 修复前 | 修复后 |
| --- | ---: | ---: |
| 重载 P50 / P95 / P99（ms） | 23.57 / 28.97 / 37.35 | 23.77 / 29.42 / 33.89 |
| 累计进程分配（MiB/重载） | 17.57 | 17.57 |
| TCP | 441/441 | 452/452 |
| 旧 UDP 关联 | 634/634 | 628/628 |
| 新 UDP 关联 | 81/81 | 84/84 |

此修复保护重载后的规则一致性，没有宣称速度提升。缓存已开始写入时，替换会等当前写入结束；这组对照未覆盖慢存储。报告：`build/core-x/retire-provider-reload-abba/results.json`。

同一源码的 Go 1.20.14 Windows amd64 核心通过上述控制 API 回归，Windows arm64 Go 1.25.14 已交叉编译。普通 amd64 与 Go 1.20 兼容版各通过 4 个接口的鉴权断言、三批 195/195 延迟请求，峰值每批 50，结束时均为 7 个 goroutine、0 TCP/UDP 追踪。短测用于构建兼容性验证。日志 `build/core-x/retire-provider-{controller,go120-controller,go120-rules}.log`。

### 当前内核跨平台稳态采样

复用 `tool/benchmark_core_rules_windows.py <core> <output> --soak-seconds <秒数>` 的 1,000 节点与 3,000 条规则。持续走回环混合端口，每 30 秒热重载；另有线程消费桥接的异步消息，避免将不读日志的测试端开销计入内核。每约 5 秒采样进程与 Go 状态，每约 30 秒补采 `Sys`、`HeapReleased`、GC 等，并记录 `Sys - HeapReleased`。Linux 用 `smaps_rollup` 的 RSS、私有驻留页及 `/proc/<pid>/stat` 工时；私有驻留页与 Windows 的 Private Bytes 口径不同，只做各自的趋势分析。

45 秒烟测 Windows 856/856、隔离 Linux 1,074/1,074 次 TCP 往返，各重载 2 次、获取 2 次完整 Go 内存分类，均无请求或采样错误。随后两项长测中断，最后一条记录分别在 1,133.27 和 255.95 秒。独立进程已按同一负载启动 Windows 7,200 秒和隔离 Linux 1,800 秒任务。目录 `build/core-x/soak-classified-detached-2h/` 与 `soak-linux-detached-30m/`。历史 Windows 两小时采样缺少同口径数据，当前记录用于看趋势。

隔离 Linux 完成 1,800.01 秒，42,708/42,708 个 TCP 往返、60/60 次热重载、359 次采样均成功。TCP P95/P99 为 2.55/3.68 ms，重载 P95/P99 为 38.14/86.33 ms。采样区间 Go 进程耗用 92.28 CPU 秒，约占单个逻辑核 5.13%。goroutine 为 7–9，末次 7，TCP/UDP 追踪均为 0，正常关闭并确认混合端口已释放。

| 中位数（MiB） | 预热 1 分钟后取 5 分钟 | 结束前 5 分钟 |
| --- | ---: | ---: |
| RSS | 54.01 | 56.82 |
| Linux 私有驻留页 | 54.01 | 56.82 |
| Go HeapAlloc（每约 5 秒） | 8.67 | 9.40 |
| Go Sys − HeapReleased（每约 30 秒） | 18.03 | 20.50 |

末段 RSS 与 Go 持有内存都高于前段，goroutine 收敛。两次端点快照中的 HeapAlloc 为 9.44 → 5.07 MiB，HeapReleased 为 10.76 → 4.31 MiB，说明堆分配随回收时点波动。30 分钟样本不足以判定长期趋势或逐页归因。原始记录 `build/core-x/soak-linux-detached-30m/soak.json` 与两份 heap 快照。

Windows 独立长测以自定义 CA 修复前的 `windows-retire-provider.exe` 完成 7,200.01 秒。135,982/135,987 次 TCP 往返成功，237 次重载完成，重载 P50/P95/P99 为 22.88/201.39/893.21 ms。1,413 条成功的状态采样另有 1 次连接重置。请求失败包括第 2,734–2,824 秒的四次超时，以及第 5,486 秒一次重载期间的连接重置。该次重载用时 1.467 秒，超过 TCP 等待上限 1 秒。四次超时的原因尚未确定。同机有其他任务运行。

| 中位数（MiB） | 第 300–2,100 秒 | 结束前 30 分钟 |
| --- | ---: | ---: |
| RSS | 39.50 | 28.46 |
| Windows Private Bytes | 45.34 | 48.59 |
| Go HeapAlloc | 6.04 | 6.36 |
| Go Sys − HeapReleased | 24.60 | 27.39 |

进程耗用 282.97 CPU 秒，约占单个逻辑核 3.93%。goroutine 为 7–10，末次为 7，TCP/UDP 追踪均为 0。Windows 私有提交增长 3.25 MiB，Go 持有量同期增长 2.79 MiB。这是同轮趋势，不能据此逐页归因或判断最终版本的长时回归。原始记录 `build/core-x/soak-classified-detached-2h/{soak,rules}.json`。

最终 CA 候选的首轮 15 分钟任务于第七次重载中止。最后成功完成的状态采样在第 183.14 秒，记录 3,546 次请求尝试、6 次成功重载、0 次采样错误。连接控制 RPC 的 15 秒读取超时触发提前退出。配置开始与完成日志相距 17.52 秒，而内核记录的解析计时为 8 ms。这段时间与 Android Gradle 构建交叠，尚无法区分调度、日志和其他等待因素，不能归因于 CA 解析。原始记录保留在 `build/core-x/soak-trust-final-15m/`。构建结束后，同一最终 CA 二进制、同一负载复跑 **900.01 秒**，18,720/18,720 次请求、30/30 次重载、179/179 次采样均成功。重载 P50/P95/P99 为 25.34/169.51/287.49 ms。进程耗用 40.81 CPU 秒，约占一个逻辑核 4.53%。goroutine 7–9，末次 7，TCP/UDP 追踪均为 0。

| 15 分钟复跑中位数（MiB） | 第 60–360 秒 | 结束前 5 分钟 |
| --- | ---: | ---: |
| RSS | 37.93 | 38.14 |
| Windows Private Bytes | 43.16 | 44.84 |
| Go HeapAlloc | 5.89 | 6.13 |
| Go Sys − HeapReleased | 22.03 | 23.62 |

复跑未重现 15 秒控制 RPC 超时。复跑原始数据 `build/core-x/soak-trust-final-15m-retry/{soak,rules}.json`。

最终 CA 候选随后以相同负载完成 **7,200.01 秒**，140,608/140,608 次 TCP 往返、238/238 次重载和 1,426/1,426 次采样成功。重载 P50/P95/P99 为 22.59/39.06/704.85 ms，TCP P95/P99 为 18.89/21.05 ms。末次 7 个 goroutine，整轮 7–9 个，末次 TCP/UDP 追踪均为 0。采样区间消耗 312.14 CPU 秒，约占一个逻辑核 4.34%。

| 最终版中位数（MiB） | 第 300–2,100 秒 | 结束前 30 分钟 |
| --- | ---: | ---: |
| RSS | 30.92 | 29.49 |
| Windows Private Bytes | 46.22 | 49.02 |
| Go HeapAlloc | 6.17 | 6.19 |
| Go Sys − HeapReleased | 25.23 | 27.86 |

最终版私有提交升 2.80 MiB，Go 持有量升 2.63 MiB，与前次两小时负载的同向变化幅度接近。Go 堆和 goroutine 在此窗口保持稳定。两轮各一次，成功请求量不同，且期间同机有构建与模拟器活动。CPU 工时和尾延迟差异只作观察。原始数据 `build/core-x/soak-trust-final-2h/{soak,rules}.json`。

### Chrome 157 本机代理

`tool/verify_core_browser_proxy_windows.py <chrome.exe> <core.exe> <output>` 用新浏览器配置把两个测试域名交给核心的 SOCKS5 端口。两路均收到对应 IPv4/IPv6 回环服务的正文。直连 localhost 对照触发正常浏览器解析。代理目标各出现一条本地查找，任务计划为 4（缓存）和 9（hosts），返回 -105。按固定 Chrome 157 源码，两者均为本地查询，本样本的目标解析计划没有系统 DNS、DNS 或 DoH 任务。记录 `build/core-x/browser-chrome-dns-local-plan/browser.json`。测试未执行出站抓包、TUN 或 WebRTC。Edge 未成功完成直连对照。[Chromium 157 任务定义](https://raw.githubusercontent.com/chromium/chromium/157.0.8103.52/net/dns/host_resolver_manager.h)

### 官方 Mihomo v1.19.34 独立核心 A/B

官方基线取 [v1.19.34 tag 所指提交](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.34) `0455d0d28c4526937380505153e65a843d8612e8`。本地源码与归档的 1,050 个文件一致。两边使用 Windows amd64、Go 1.25.14、`GOAMD64=v1`、`CGO_ENABLED=0`、`-trimpath -pgo=off -tags=with_gvisor`、`-w -s` 和相同版本注入。Fluxora 嵌入模块通常由 App 桥接启动监听。这里仅通过临时 Go overlay 恢复执行器里的 `updateListeners` 和 `updateTun` 原版调用，TUN 由两个实例的相同测试配置关闭。ABBA 串行各跑两个新进程，`GOMAXPROCS=4`，代理和鉴权控制器均只绑定回环。

| 指标 | 官方 Mihomo | Fluxora Core X | 变化 |
| --- | ---: | ---: | ---: |
| 10,000 条 CIDR 规则缓存热重载 P50 | 83.31 ms | 24.75 ms | -70.3% |
| 同负载重载 P95 | 99.44 ms | 35.23 ms | -64.6% |
| 目标持续拒绝耗时 P50 | 3,219.05 ms | 2,347.82 ms | -27.1% |
| SOCKS5 UDP 每次有效回包分配 | 2,708.87 B | 1,420.77 B | -47.6% |
| UDP 每次有效回包 CPU 工时 | 55.79 µs | 56.15 µs | +0.7% |
| UDP 双向净荷吞吐 | 73.23 MiB/s | 73.20 MiB/s | -0.04% |
| TCP 双向净荷吞吐 | 571.75 MiB/s | 587.88 MiB/s | +2.8% |
| 进程启动至首次 TCP 成功 | 552.84 ms | 534.34 ms | -3.3% |
| 空闲 RSS | 32.99 MiB | 30.33 MiB | -8.1% |
| 空闲 Windows Private Bytes | 34.14 MiB | 31.87 MiB | -6.7% |
| 独立测试核心二进制大小 | 60,644,352 B | 60,681,216 B | +0.06% |

每版 48 次重载和 8 次持续拒绝样本，基线与候选的 UDP 均为 256,000/256,000 回包。TCP 分别 146,402/146,402 与 150,522/150,522。分配及 CPU 工时为 Go 进程采样增量除以收到的回包数。转发列取各进程结果的中位数。启动与空闲仅有每版两个新进程样本，不能推断安装包体积、移动端常驻内存或普遍启动改善。TCP、UDP 吞吐与低个位数的时延、CPU 差异仍需更多样本。此测试使用 1,000 个本地节点、3,000 条域名规则及文件 CIDR 提供器，未测公网、TLS、WARP 或 TUN。

原始数据 `build/core-x/mihomo-standalone-abba-final.{json,log}`。保留基准脚本 `build/core-x/compare-mihomo-standalone-windows.py`、候选 overlay `standalone-fluxora-overlay.json` 和两个二进制 `standalone-official.exe`、`standalone-fluxora-fixture.exe`。首次测量设置 warning 使原版关闭 pprof，修正为同样 debug。候选 CLI 未恢复独立监听入口时的失败记录保留，最终结果采用上述 overlay，两处调用未进入生产源码。

### 外部协议基准对照

固定 Mihomo v1.19.34 上游提交 `0455d0d28c4526937380505153e65a843d8612e8`。在同一独立网络命名空间方案中，用相同的 7 个镜像、依赖解析与 23 个协议顶层用例，轮流运行两套核心代码。临时 overlay 仅限定镜像预加载、适配嵌入监听夹具，并从定向二进制排除引用废弃字段的旧 Trojan XTLS 测试。完整原版套件的编译失败已另存。镜像由 [Docker Hub 公共缓存](https://docs.cloud.google.com/artifact-registry/docs/pull-cached-dockerhub-images) 获取，再在隔离环境运行。

两版各 17 PASS、6 FAIL。相同失败为 VMess WebSocket Xray 0-RTT、Legacy VLESS XTLS、Trojan gRPC、Shadowsocks 基础组、Shadowsocks UoT、Hysteria。明确观察到镜像启动拒绝旧 XTLS 和 Hysteria 配置。对照证实当前核心在这批样本没有新增失败，未据此判断其余失败的具体根因。原始记录 `build/core-x/nested-module/protocol-{expanded,upstream-compare}.log`，镜像摘要在 `podman-cached-images.log`。

随后下载 `ghcr.io/shadowsocks/ssserver-rust@sha256:22240c07d8ce3a36421ede770bd775dcc5fc56d5d829943196957b05452dc36f`。两版各自重跑基础和 2022 两组并通过，前一轮基础组的 3 个失败均为缺镜像。原始记录 `build/core-x/nested-module/protocol-rust-{candidate,upstream}.log`。

使用 [Hysteria v1.3.5 官方发行程序](https://github.com/HyNetworks/hysteria/releases/tag/v1.3.5) 的 Linux amd64 服务端复验旧协议，文件 SHA-256 `41DC8BC3FFF6FC1F031666EB294F10B481B80B66229D7C6ACA88398D0FBA839D`。进程专用证书根下通过 3/3 HTTP、8/8 UDP，证书名不符拒绝。显式配置 CA 的首次生效和删除行为单独测得失配，记录 `build/core-x/nested-module/hysteria-v1-trust-revocation.log`；该用例转入安全回归，原 Hysteria v2 镜像拒绝旧配置的结果保留。

## 批量节点测速调度

Windows 上交替运行旧批次和候选调度，每种负载各五轮。每轮 120 个目标，并发上限 20。Flutter 测试调用生产 `delayTest`，用本机 HTTP 夹具替代核心 RPC 的后端。混合负载每 20 个目标含一个 320 ms 响应，其余延迟 35 ms。等时负载全部延迟 35 ms。数据为每组五轮的中位数。

| 负载和指标 | 旧批次 | 滚动补位 |
| --- | ---: | ---: |
| 混合响应，整组用时 | 2,026 ms | 606 ms |
| 混合响应，前 30 个结果 | 397 ms | 132 ms |
| 等时响应，整组用时 | 313 ms | 306 ms |
| 等时响应，前 30 个结果 | 110 ms | 112 ms |

20 轮均达到并发峰值 20，每轮收到 120/120 个有效 HTTP 回包和 120/120 次结果回调。混合响应下整组耗时减少 70.1%。等时样本未显示明显变化。较早的三轮单独运行也复现混合负载改善。原始数据和夹具在 `build/core-x/delay-batch/{before,after,abba}.log` 和同目录 `{loopback_test,abba_test,baseline_common}.dart`。定向 Dart 分析和 32 项 Flutter 测试通过，覆盖补位、并发上限、换配置取消后续派发、排序和结果归属。真实订阅、移动端及高 RTT 下的完成时间待测。独立核心的上游对比见上一节。

## Android x86_64 Release 包体积与双栈运行

在同一隔离目录、相同 Flutter Release、R8、预览通道和临时签名下，只切换调试快照的 ZIP 压缩例外。完整 APK 大小均为 71,239,180 B，签名后的 SHA-256 相同。两份 797 个条目中均无 `kernel_blob.bin`。Go 核心是最大的单个条目，压缩后 23,249,128 B。对照原始数据 `build/core-x/android-sdk-qa/qa-release-apk-compare.json`。

MuMu Android 12 已安装同哈希 APK，首次启动的 ActivityManager `TotalTime` 为 2,453 ms。双栈 VPN 运行和停止后各采样一次，整个应用进程的 PSS 分别为 191,479 和 192,923 KiB。这是单次端到端验收，不能估计冷启动分布、Go 独立内存或优化幅度。两轮本地探针及路由清理见[接续记录](CORE_X_EXECUTION_PROGRESS.md#2026-11-17-android-release-集成)。

arm64-v8a 完整 Release APK 为 69,053,549 B，未做同架构前后对照。x86_64 与 arm64 的架构、ELF 加载段、压缩包、核心 SHA-256 和签名记录在 `build/core-x/android-sdk-qa/qa-release-{x64,arm64}-elf.json` 和同目录的签名、对齐文件中。

## Chromium 双栈 TUN 与 WebRTC

WSL 中使用 Fedora 44 Chromium 156.0.8078.79。Podman 初始只有回环接口，浏览器、Fluxora 桌面 Go 桥接和可控双栈对端均留在隔离网络。system、gVisor、mixed、mips 分别用 IPv4 和 IPv6 系统 DNS 地址运行，合计八组。每组先关闭 TUN，核对浏览器能获得两个 HTTP 正文、系统 DNS 接收测试域查询、IPv4 和 IPv6 的 STUN 响应均产生外部地址候选。启动 TUN 后，16/16 个 HTTP 正文经配置的代理到达，A/AAAA 通过受控解析器，外侧 DNS 和 STUN 服务均没有收到测试报文。TUN 抓包显示两族 STUN 确实进入接口。各组结束后双栈路由、策略规则和 TUN 接口均恢复。

再用实际 Dart 配置生成器进行同条件对照。已有的重复 WebRTC 拦截规则原本会留在普通 UDP 规则之后，两个地址族的测试 STUN 报文均到达对端。置顶去重后，两族报文均停在 TUN 的拒绝规则，无外部地址候选。两版 HTTP 各 2/2，A/AAAA 均仍由受控解析器回答。另测不支持 UDP 的出站会按上游规则继续匹配，当前无后续规则的样本确实走 DIRECT，显式终止拒绝的样本未到达 STUN 对端。[Mihomo 路由顺序](https://wiki.metacubex.one/en/config/rules/#priority)

日志和夹具在 `build/core-x/chromium-tun-*.log`、`chromium-tun-{qa.sh,fixture.py}`、`chromium-chain-rules-{before,after}.json`。定向 Dart 分析通过，49 项 Flutter 回归与一项夹具生成通过。证据覆盖隔离 Linux、普通 UDP DNS 和测试 STUN 地址及端口。平台真机、浏览器 DoH、其他端口及组合覆写有待单独验证。

### WARP 组合规则

应用先生成链式代理规则，再应用 WARP。旧顺序把 WARP 的智能分流和自定义规则插在已开启的 WebRTC 防护前。候选在同一次插入时保留 WebRTC 段的优先级，WARP 和原订阅规则之间的顺序保持一致。关闭防护时，WARP 仍插到列表前部。

使用实际 Dart 模型生成 WARP 自定义规则，导出同一隔离 Chromium 夹具的有效规则。旧规则使 IPv4 和 IPv6 的 STUN 都命中直连并收到响应，修复后两族 STUN 都命中防护并被拒绝。两轮的 HTTP 各 2/2，经受控解析器的 A/AAAA 查询和路由清理均通过。WARP 智能分流、关闭防护的相对顺序通过 Dart 回归。59 项 Flutter 回归、一项夹具生成和定向分析均通过。夹具只替换本地测试内核的规则列表，真实 WARP 握手及出口另验。日志位于 `build/core-x/chromium-tun-warp-webrtc-{before,after}.log`，配置阶段结果位于 `warp-webrtc-precedence-{before,after}.log`。

## Chromium DoH 证书与双栈出口

在隔离 Fedora 44 Chromium 156.0.8078.79 上，用 system、gVisor、mixed、mips 各对 IPv4、IPv6 DoH 字面地址执行严格模式对照，共八组。浏览器先运行在没有测试 CA 的全新配置中，再将临时根 CA 加入一次性容器的 NSS 数据库并启动新配置。两轮都经过同一实际 Go 核心和 HTTP CONNECT 出站，叶证书同时包含两族 IP SAN。Chromium 的严格模式在 DoH 失败时终止解析。[Chromium 证书管理](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/cert_management.md) [严格模式定义](https://chromeenterprise.google/intl/en_ca/policies/dns-over-https-mode/)

| 场景 | 两族网页正文 | DNS 路径 |
| --- | ---: | --- |
| 严格模式，CA 未导入 | 0/16 | 代理收到 DoH CONNECT，解析器观察到证书拒绝，未接收 HTTPS DNS 报文。外侧和核心普通 DNS 均未见测试域查询。 |
| 严格模式，CA 已导入 | 16/16 | 指定代理转发 DoH，对端均收到 A 和 AAAA 查询。外侧和核心普通 DNS均未见测试域查询。 |
| system + IPv4 DoH，自动模式对照 | 2/2 | 浏览器本轮使用普通 DNS。A 和 AAAA 查询到达 TUN 指定的核心解析器，外侧解析器未收到测试域查询。 |

停机后八组的 TUN 接口、双栈路由与策略规则均回到测试前状态。自动模式样本未观察到先尝试 DoH 再改走普通 DNS，结论只覆盖实际收到的普通查询。解析器地址采用字面量，真实运营商解析器、DoH 域名引导解析和 DoQ 未测。原始结果 `build/core-x/chromium-doh-{system,gvisor,mixed,mips}-{4,6}.log`，模式对照 `chromium-doh-automatic-control.log`。

## 双上联切换与策略加密 DNS

Linux amd64 Core X 在 WSL 的独立 user/network namespace 中轮换两条双栈上联的默认路由优先级，两条链路持续在线。每种 TUN 栈先用两批新域名建立并确认 TCP 复用，再往返切换 3 次。每次先以实际双栈 HTTP 响应的源地址确认新出口，再查新的 DNS 名称。受控 IPv4/IPv6 DNS 上游返回实际请求源地址，并记录连接端口。DoH/DoT 使用临时 CA 和验证过的 IP SAN，信任只作用于测试进程。两版由相同工具链与构建参数生成，除本轮 DNS 修复外使用相同源码。

| 切换后查询（system、gvisor、mixed、mips） | 修复前 | 修复后 |
| --- | --- | --- |
| 策略 IPv4 DoH/DoT，从当前出口返回 | 24/48 | 48/48 |
| 策略 IPv6 DoH/DoT，从当前出口返回 | 24/48 | 48/48 |
| 主 DoH 与策略 UDP，从当前出口返回 | 72/72 | 72/72 |
| 四栈停机后接口、路由及策略规则回到快照 | 4/4 | 4/4 |

修复前策略 IPv4 有 24 次达到夹具的 2 秒等待上限。策略 IPv6 有 24 次返回旧出口，日志确认复用了切换前同一端口。修复后两类问题各 0 次，策略加密查询成功样本 P50 43.99 ms、P95 48.43 ms。DNS 用时从发出查询开始，未包含等待 TUN 发现换网的时间。真实 Wi-Fi/蜂窝、在途 DoT 查询完成后重新入池、DoH HTTP/2、HTTP/3 和 DoQ 仍待验证。

夹具及原始日志在 `build/core-x/delay-diagnostics/`。设置 `COREX_REPO` 指向 WSL 下的仓库路径，并在 `unshare -Urn` 中运行 `bash verify-encrypted-switch-linux.sh <stack> <before|after>`。桥接二进制使用 `GOOS=linux GOARCH=amd64 CGO_ENABLED=0`、`-mod=readonly -pgo=off -trimpath -tags=with_gvisor`，链接注入 v1.19.34。前后 SHA-256 分别为 `04876D5A69572A80A6C1C500FD392BCAAC2E2CA50AA09513F109E25F19200658` 和 `4F2D4428266D7FB5F21286F989415D5FB3F94519E4BDEE7FA5D4562BDA2EA7A1`。

### 切换时仍在响应的 DoT 查询

沿用双上联夹具，先收到 IPv6 DoT 请求并阻塞响应，再切换默认路由。双栈 HTTP 和主 DoH 都已从当前出口返回后，放行旧请求，随即用两个新域名查询同一个 DoT 上游。四种 TUN 栈各往返 3 次。前版已经包含策略池重置，后版只增加在途连接检查。每轮记录 TLS 客户端源地址和端口，确认旧请求和两次后续请求对应的连接。

| 指标 | 前版 | 修复后 |
| --- | --- | --- |
| 换网前发出的查询成功 | 24/24 | 24/24 |
| 随后的新查询使用当前出口 | 0/48 | 48/48 |
| 首条新查询耗时 P50 / P95 | 1.16 / 1.47 ms（旧出口） | 46.24 / 51.29 ms（重连） |
| 第二条新查询耗时 P50 / P95 | 1.21 / 1.50 ms（旧出口） | 1.41 / 2.28 ms（复用新连接） |
| 正常切换探针与停机清理 | 168/168、4/4 | 168/168、4/4 |

修复后 24 个切换周期均确认第二条查询复用首条新建连接。此项改善换网时的出口正确性，首次握手成本保留。只测试隔离 Linux 的 IPv6 DoT 在途场景。真机网络切换、IPv4 DoT 在途、DoH HTTP/2、HTTP/3 和 DoQ 继续待验。

使用同一夹具设 `COREX_HOLD_DOT=1`，运行 `verify-encrypted-switch-linux.sh <stack> after` 和 `verify-encrypted-switch-linux.sh <stack> inflight`。原始日志为 `build/core-x/delay-diagnostics/inflight-dot-<stack>-<version>.log`。前版内核 SHA-256 为 `4F2D4428266D7FB5F21286F989415D5FB3F94519E4BDEE7FA5D4562BDA2EA7A1`，候选为 `79A77DF88DA5EFAC8BC0BA604DD5529C3973A7AAFBE5424DC17F8C71F58404FE`。

### 双上联 DoQ

严格 TLS 的受控 QUIC 上游为每条查询回送客户端源地址。Linux 四栈往返换路 24 次，先阻塞一条 IPv6 DoQ 响应。监控关闭旧连接后，核心沿用已有重试向同一个上游重新发送，日志观察到每个在途域名从旧出口移到新出口。当前出口命中为在途 24/24、随后 48/48、普通双栈 48/48，停机路由清理 4/4。system 另做 6 批各 32 条 IPv6 DoQ 并发查询，192/192 在当前出口返回，每批上游端口唯一。原始日志为 `build/core-x/delay-diagnostics/doq-switch-held-*.log` 和 `doq-switch-burst-system.log`。保持现行 DoQ 实现，真实 Wi-Fi 或蜂窝的重试延迟仍待验证。

### 切换时仍在响应的 HTTP/2 和 HTTP/3 DoH 查询

隔离 Linux 内核通过 system、gvisor、mixed、mips 四栈访问严格 TLS 的受控 DoH 服务。服务端记录实际 HTTP 协议、IPv6 源地址和端口。每种栈往返切换 3 次。旧查询已抵达上游但保持未响应，确认双栈 HTTP 和主 DoH 切路后，在同一个上游发送新查询。给新查询 450 ms 先行完成的窗口，再放行旧查询，随后连续发两条新查询。旧版包含 DNS 策略池重置和 DoT 更新，新版增加 DoH 客户端换路回收。

| 指标 | HTTP/2 前 → 后 | HTTP/3 前 → 后 |
| --- | --- | --- |
| 换路前发出的查询成功 | 0/24 → 24/24 | 22/24 → 24/24 |
| 旧响应放行前，新查询已从当前出口返回 | 24/24 → 24/24 | 0/24 → 24/24 |
| 切换期间和切换后的三条新查询命中当前出口 | 72/72 → 72/72 | 72/72 → 72/72 |
| 先行查询 P50 | 1.35 → 3.37 ms | 393.50 → 3.83 ms |
| 其他双栈 DNS 探针、退出清理 | 376/376、4/4，前后均通过 | 376/376、4/4，前后均通过 |

HTTP/2 先行查询在修复后承担新 TLS 连接的建立开销，三条新查询在每个修复周期均复用同一连接。HTTP/3 的耗时差由夹具等待窗口决定，仅用于证明解除阻塞。旧版 mips 两次 HTTP/3 在途超时的对应切路耗时超过夹具上限 4 秒，不能归因于 DoH 本身。再按修复后、旧版的顺序复跑 mips，切路耗时相近，旧请求双方均 6/6 成功，新请求在放行前完成仍是 0/6 → 6/6，见 `doh-repeat-mips-h3-*.log`。

另外复测四栈的 IPv4 上游。测试命名空间默认启用严格反向路径检查，更换默认接口后旧接口回包无法维持。两版对照均只在命名空间中设宽松检查，使两个接口均可收包。HTTP/2 在途成功 0/24 → 24/24，HTTP/3 在途前后均为 24/24，先行返回 0/24 → 24/24。修复后两协议新查询 144/144 来自当前出口，每个协议前后均通过关停清理。gVisor 的第一轮修复版 H3 在夹具换路等待结束时仍停留在旧接口，独立重跑完整 6 个周期通过。脚本为 `verify-doh-switch-v4-loose-linux.sh`，日志为 `doh-v4-loose-*.log`，gVisor 原失败与复跑均保留。

夹具在 `build/core-x/delay-diagnostics/`。在 WSL 用 `unshare -Urn` 执行 `verify-doh-switch-linux.sh <stack> <binary>`，设置 `COREX_REPO` 为 WSL 仓库路径，设置 `COREX_HOLD=h2` 或 `h3`。使用包含 `with_gvisor` 标签的桥接内核，服务端采用与内核一致的 HTTP 和 QUIC 库。前后 SHA-256 分别为 `8975DAD295D30AE5BE1F624A80A9A1C680FDB6834518FEE765F4E635D5670069` 和 `007D4E98FF44AA462FFA40B50D06E449FC0BFA245D24EFF5C33C326C6B6BAFA4`。原始日志为 `doh-switch-<stack>-<protocol>-<before|after>.log`。Windows DNS 和 config 普通、race，Mihomo 与桥接 Go 全量通过。Windows amd64 与 Android arm64 核心构建通过。

### 旧接口直接失联时的 DoH 查询

在相同的隔离四栈拓扑中等 IPv6 DoH 请求抵达同一个 TLS 上游，然后提升第二条链路的优先级并实际关闭第一接口。双栈 HTTP 与主 DoH 从第二接口返回后才开始测试新的策略 DoH 查询。每栈每种协议将第一接口关闭及恢复各 3 次。通过服务端源地址核对出口，通过 `ss` 检查旧传输端口。恢复原接口后再发双栈探针，关停核心后比较两族路由与规则快照。

| 旧接口失联指标 | HTTP/2 前 → 后 | HTTP/3 前 → 后 |
| --- | --- | --- |
| 失联前发出的在途查询成功 | 0/12 → 0/12 | 0/12 → 0/12 |
| 失联后首条及后续两条查询命中当前接口 | 36/36 → 36/36 | 31/36 → 36/36 |
| 首条新查询在 450 ms 内返回 | 12/12 → 12/12 | 7/12 → 12/12 |
| 未观察到旧传输套接字残留 | 12/12 → 12/12 | 12/12 → 12/12 |
| 其他 DNS 探针与退出清理 | 364/364、4/4，前后均通过 | 364/364、4/4，前后均通过 |

HTTP/3 旧版的 5 条首个新查询达到客户端 2 秒超时，修复版该批首个新查询中位 3.38 ms。HTTP/2 旧链路切断后，修复版在途查询会按原查询时限结束。旧网已断时没有可返回的旧响应。新查询在接口切换确认后使用原配置的上游，原出站保持 `fixture-uplink`。mips 的首轮 HTTP/2 端口检查命中了独立的 IPv4 HTTP/1.1 连接，按 IPv6 和目标端口细化后复跑 3/3 通过，使用复跑结果。脚本为 `verify-doh-hard-switch-linux.sh`，日志为 `doh-hard-*.log`。真实 Wi-Fi、蜂窝、休眠恢复及 Windows/Android 仍需各自环境验证。

### 脚本结果解码

在 Windows 使用 Dart AOT，对同一份 1,500 节点、1,500 条规则及分组的 JSON 交替执行 16 组配对。每个样本重复 30 次。JSON 字节与解码后序列化一致，解码和 Dart 递归复制的中位数 2.121 ms，直接使用解码后的对象为 1.476 ms。此数据仅覆盖脚本之后的 Dart 解码，脚本执行、网络资源和核心配置重载耗时需另计。Windows Dart/Rust 桥接另外实测预存选项影响实际代理分组，并读取按选项键返回的图标。原始记录在 `build/core-x/delay-diagnostics/script-json-copy-bench.log`。

后续 Windows Dart AOT 另跑 40 组交替样本。1,500 节点同步解码 P50 1.44 ms，保留现有路径。5,000 节点同步解码 P50 4.98 ms，移至 isolate 后 UI 线程提交 P50 0.024 ms，等待结果 P50 7.17 ms。10,000 节点相应为 18.54、0.029、15.36 ms。大于等于 512 Ki 个 UTF-16 码元的脚本输出使用 worker。数据只涵盖结果解码，实际整次配置加载与真机帧率尚无前后对照。日志 `build/core-x/delay-diagnostics/script-isolate-bench.log`。

### DNS 覆写与节点测速

实际 Dart 配置合并和 Linux 内核 `asyncTestDelay` 对照使用同一个域名节点。订阅明确指定的公共 DNS 地址只绑定在独立命名空间，由本地夹具应答；应用内置的节点引导地址在该拓扑不可用。旧覆写输出的三次测速均返回 -1。保留订阅明确指定的节点解析器后得到 43、32、32 ms，关闭覆写的订阅 DNS 对照为 38、32、32 ms。返回的延迟包含夹具固定等待，不代表公网性能。日志 `build/core-x/delay-diagnostics/override-delay-probe.log` 来自对应的 Dart 和受控网络夹具。

DNS 服务关闭且由 TUN 接管查询时，Linux 隔离环境的 system、gVisor、mixed、mips 四栈均从 SERVFAIL 恢复到系统 DNS 应答，4/4 确认请求抵达受控解析器且退出清理通过。MuMu Android 12 的 A 和 HTTPS 类型查询 RCODE 均从 2 变为 0，A 查询收到地址。DNS 服务开启时，MuMu 原生探针确认覆写 Fake IP 环境下实际完成 HTTP，应用代理页延迟为 76 ms。Windows 定向 Go 及 DNS/race 通过，也构建了 Windows、Linux、macOS arm64 和 Android arm64/x86_64 内核。Chromium 启动命令被自动审批以 `blocked by policy` 拒绝，本轮浏览器实测待验。日志为 `dns-disabled-*-{before,after}.log`、`mumu-dns-disabled-{before,after}.log` 和 `mumu-dns-delay-on-ui.txt`，均在 `build/core-x/delay-diagnostics`。

Android 系统 DNS 的入口同时过滤 VPN 网络和虚拟 TUN DNS 地址。宿主 Go 测试覆盖 IPv4、IPv4 映射 IPv6、本地虚拟地址、空值和合法 IPv6。Android arm64 核心交叉构建及应用 Debug Kotlin 编译通过。手机浏览器、Android 私人 DNS 和 Windows/macOS 实际系统 DNS 尚未复测。

独立补测 DoH 上游以域名配置时的引导。默认解析器查询测试上游域名，按测试环境分别返回 IPv4 或 IPv6，后续查询实际协商 HTTP/2 或 HTTP/3 并校验域名证书。Linux 四栈各六次换路，普通及在途正向探针 472/472，错误的证书域名 4/4 被拒绝且未到达 DoH 请求处理器。退出后恢复路由 4/4。原始日志为 `build/core-x/delay-diagnostics/doh-bootstrap-*-h3.log`。

## 本轮回归验收

- PASS · Flutter 3.47.4 `flutter analyze --no-pub` 无问题，定向 56 项内含 Windows 生命周期 20 项。Go 桥接与定向 Go 包测试通过。Windows race 覆盖 DNS、控制器、配置、规则、SOCKS5 编码及相邻调用包，桥接 race 使用原有临时 overlay。
- PASS · Windows amd64 core、Android arm64 NDK 28.2 `c-shared` 构建。Android ELF `LOAD` 均为 16 KiB 对齐，`invokeAction`、`startTUN`、`stopTun` 存在，产物 SHA-256 为 `0863498f6f732066d498696934c6f4610016d651a7b1d215d956580340d388ad`。
- NOT VERIFIED · Android 实机 UDP、Linux/macOS 实际运行、多小时负载、真机 TUN 和外网/WARP/真实链路。

## P0 回归结果

Windows 生命周期 20 项包含在 56 项通过的 Flutter 定向测试中。Go 桥接及 Mihomo 的 DNS、控制器、配置、规则定向通过。后四组在 Windows amd64 使用带校验的 LLVM-MinGW 工具链运行 `-race` 通过。桥接的普通桌面目标为 CGO 关闭，单独的 Windows CGO race 构建缺少平台兜底函数。用 `build/core-p0` 下的临时测试 overlay 注入现有兜底同等返回值后，桥接 race 套件通过。回环烟测验证了鉴权、DNS A/AAAA、IPv4/IPv6、热重载、失效配置后旧流量、监听重启和 65 次并发测速。

## Mihomo v1.19.34 同步时的构建与回归

| 验证 | 结果 |
| --- | --- |
| Windows amd64 Go 桥接测试、核心启动、RPC、配置加载、版本读取及关闭 | PASS |
| Windows amd64 兼容版 | Go 1.20.14 与 `GOAMD64=v1` 构建成功，回环启动与 Snell 6 配置校验通过 |
| Mihomo Go 测试 | outbound、convert、age、memory、Snell transport 通过。完整 inbound 套件首轮失败，随后 v1.19.33 和 v1.19.34 完整重跑均通过。Snell 6、Shadowsocks 多用户和 Mieru 配置的定向测试也通过 |
| Android arm64 | NDK 28 编译通过，AArch64 ELF `LOAD` 对齐 16 KB，存在 `invokeAction`、`startTUN`、`stopTun` 导出 |
| 真机运行与发布包 | NOT VERIFIED |

| 产物 | SHA-256 |
| --- | --- |
| Windows amd64 | `c0229afc3e77911cd28d2fe9050233a1980de44402df1ad3de49339ee12576c6` |
| Windows amd64 兼容版 | `dea82d662ac25ff06e1565c364f67e3d46f1e8fba2c94840c03b9b4f6f5e8f0c` |
| Android arm64 共享库 | `c6e91f609a378d421e9ea22563165c77a3669851e46a2b0abd28c17c2ab6960c` |
## 2026-11-19 节点列表快照

以本地现有 Core X 为对照，独立构建仅改变测速历史快照复制方式的 Windows amd64 候选。两版均使用 Go 1.25.14、`CGO_ENABLED=0`、with_gvisor、trimpath、无 PGO 和相同版本注入。测试保持系统代理与 TUN 设置原样。

在相同本地 HTTP 204 服务上交替运行 A/B/B/A。每轮包含 1,000 个 direct 出站，分别执行配置重载、真实延迟测试和真实 getProxies RPC，核对新组成员、历史条数与连通性。主对照每个节点写入 10 条测量，四轮 40,000 次探测通过，计时快照请求共 640 次。每个进程正常关闭后核验原混合端口已释放。

| 实测范围 | 对照 | 候选 |
| --- | --- | --- |
| Go JSON 微基准，千节点各 10 条历史 | 13.44–14.23 ms/op | 12.32–12.60 ms/op |
| 真实 RPC，每轮中位数 | 28.04 / 32.41 ms | 31.97 / 31.94 ms |
| 真实 RPC，每轮 P95 | 50.86 / 55.17 ms | 53.08 / 52.61 ms |
| 真实 RPC，每次进程 CPU 工时 | 27.83 / 28.61 ms | 34.57 / 29.69 ms |
| 真实 RPC，每次平均分配字节 | 14,741,246 B | 12,774,700 B |
| 真实 RPC，每次平均分配次数 | 105,782 | 95,772 |

分配改善明确，整体 RPC 的速度与 CPU 收益缺乏支持。候选已经撤回，生产文件与改动前备份哈希相同。三项快照语义测试在两版通过，候选 race 五轮通过，恢复后的 race 三轮通过。本轮没有把微基准收益计入应用性能成果。

原始结果保存在 `build/core-x/profile-switch-20261119/`。其中 `history-before.log` 与 `history-after.log` 为 Go 微基准，`rpc-ten-history/results.json` 为主对照，`rpc-isolated/results.json` 为五条历史对照。两个实验中 goroutine 均为 7，测量前后没有活动 TCP/UDP tracker。这个短时结果不能替代内存长测。

复现命令如下。

```powershell
python tool/benchmark_core_proxy_snapshot_windows.py build/core-x/profile-switch-20261119/before.exe build/core-x/profile-switch-20261119/after.exe build/core-x/profile-switch-20261119/recheck --nodes 1000 --histories 10 --samples 160
```

