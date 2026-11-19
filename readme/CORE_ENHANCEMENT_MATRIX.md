# Fluxora Mihomo 内核 18 项审计

基线为当前工作区内置的 Mihomo v1.19.34。审计覆盖桌面独立进程、Android 共享库、Flutter 接入层与发布配置。负载假设是单用户长期开启服务，使用千级节点、千级规则，间歇切换节点或触发批量测速。下表的优先级沿用用户附带清单。性能数据见 [基准记录](CORE_PERFORMANCE_BASELINE.md)。

## 逐项结论

| # | 清单项 | 已有实现与证据 | 缺口和对应验证 |
| --- | --- | --- | --- |
| 1 | P0 内存与 GC | 桥接层合并重复强制 GC，移除测速的进程级结果缓存。GeoData 默认使用 `memconservative`。核心状态 RPC 提供堆对象、堆占用和 goroutine 数。见 [桥接](../core/hub.go)、[默认配置](../core/Clash.Meta/config/config.go)。 | Windows UDP 会话回收后，短测私有提交差异主要对应 Go 尚未归还的内存。CIDR 缓存热重载累计分配约 95.5 → 24.4 MiB/次。Android 与跨平台长期负载待测。[资源归类](CORE_PERFORMANCE_BASELINE.md#udp-暂存私有提交归类) |
| 2 | P0 CPU 与 goroutine | 应用侧定时更新流量，内存卡和核心状态面板独立读取。DNS 通过 singleflight 合并同问题查询，取消和过期路径仍可能发起后台任务。见 [定时任务](../lib/state.dart)、[DNS 解析器](../core/Clash.Meta/dns/resolver.go)。 | Windows 两小时回环与重载已测。CIDR 版本 48 次缓存重载的进程 CPU 工时由 13.66–15.97 s 降至 4.91–7.34 s。仍需真机功耗、公网高并发及更多流量模式。 |
| 3 | P0 启动、关闭和重启 | Dart 管理配置应用、监听就绪与重启。Go 检查监听器是否成功启动。Windows 的 20 项生命周期测试现已通过，覆盖回环 TCP 连接、释放、重绑和重复启停。见 [核心服务](../lib/clash/service.dart)、[生命周期测试](../test/services/clash_service_lifecycle_test.dart)。 | Windows 又通过 20 项生命周期测试；4 个新进程启动到 HTTPS 首字节基线已记录。Android 和用户实际配置路径待测。 |
| 4 | P0 建连速度 | Windows 回环分段 480/480 成功。连续拒绝 P50 2,935 → 2,010 ms，删去最后一次失败后的退避，同一目标暂拒 550 ms 时两版各 16/16 恢复。通过证书异常和取消连接校验。见 [执行记录](CORE_X_EXECUTION_PROGRESS.md)。 | 公网节点、高抖动及跨平台真实路径的建连分布待测。 |
| 5 | P0 DNS | 已有 LRU/ARC、默认 4096 容量、缓存过期刷新、按策略选择上游和请求合并。增加 [DNS 覆写](../lib/common/dns_override.dart) 回归，修复误删私有上游及错误改写本地监听。见 [解析器](../core/Clash.Meta/dns/resolver.go)、[DNS 服务](../core/Clash.Meta/dns/server.go)。 | 本地 UDP 缓存、并发合并、取消、超时、过期与语义测试通过。单上游丢首包约 5 秒失败，多个显式上游中一个无响应时 16/16 HTTPS 成功。旧／新私有 DoH 代理连通性 0/4 → 4/4。换网后策略加密 DNS 从当前出口返回 48/96 → 96/96。保留原缓存键。待确认实际运营商和设备的泄漏情况。 |
| 6 | P0 TUN | Mihomo 注册 system、gVisor、mixed、mips。桌面由 sing-tun 管理路由和接口，Android 由 VPN 服务建立 TUN 并接入 Go。Android 共享库构建和 16 KB 对齐已核对，TUN 状态读取测试通过。见 [栈类型](../core/Clash.Meta/constant/tun.go)、[TUN 监听](../core/Clash.Meta/listener/sing_tun/server.go)、[Android 桥接](../core/lib_android.go)。 | 隔离 Linux 四栈双栈 TCP/UDP、DNS 接管、原路恢复和路由清理通过，并对照短流时延、长流吞吐及内核 CPU 工时。Windows 与 Android 的吞吐、CPU、DNS 接管及网络恢复待真机。见 [四栈数据](CORE_PERFORMANCE_BASELINE.md#四栈-tun-短流和批量传输)。 |
| 7 | P0 配置解析与热重载 | 规则切分减少分配，子规则校验复用共享分支。保留 TCP 等待和有界 UDP 暂存。CIDR YAML 常见行复用原索引构造和匹配，节点选项解码收缩字段元数据。 | 两次独立的 Windows 对照中，1,000 节点和 10,001 CIDR 缓存重载 P95 分别 82.10 → 32.73 ms、32.20 → 26.79 ms。真实订阅的冷、热加载待验。[对照数据](CORE_PERFORMANCE_BASELINE.md#cidr-规则提供器快路径) |
| 8 | P1 节点测速 | 保留 Dart 批量测速补位。Windows 普通和 Go 1.20 核心均通过 195/195 回环请求。最终核心在模拟抖动和超时下，845 条回调均按预期返回，超时连接关闭，后续 65/65 恢复，并发峰值 50。 | 应用层 120 节点混合响应中位数 2,026 → 606 ms，峰值 20 和回包数相同。真实高抖动节点和移动端待测。[对照数据](CORE_PERFORMANCE_BASELINE.md#批量节点测速调度) |
| 9 | P1 TCP/UDP 数据路径 | TCP 使用现有 relay，UDP 通过 NAT 表复用会话。内核已有按构建标签区分的 TCP/UDP 缓冲区大小。见 [连接转发](../core/Clash.Meta/tunnel/connection.go)、[NAT 表](../core/Clash.Meta/component/nat/table.go)、[低内存缓冲](../core/Clash.Meta/common/pool/buffer_low_memory.go)。 | Windows TCP/UDP 真实转发、TCP 半关闭、NAT 过期再建及控制器主动关闭通过。已保留 SOCKS5 UDP 回包缓冲复用，等速 B/op 2,866 → 1,536。时延收益有波动，Android、真实出站与长期压测待验。 |
| 10 | P1 IPv4/IPv6 | Windows 双栈各 8/8 HTTPS 请求通过，模拟 IPv6 挂起时约 300 ms 选用同主机的 IPv4 且释放落选 socket。隔离 Linux NAT64 16/16。见 [执行记录](CORE_X_EXECUTION_PROGRESS.md)。 | 运营商 IPv6-only 与 Windows/Android VPN 的出站泄漏待测。 |
| 11 | P1 链式代理 | Windows 回环实际 SOCKS5 单、双、三跳各 40/40 次完成，建连及 64 KiB 回包 P50 为 8.29、13.97、20.36 ms。验证中间跳失效和停止后资源回收。见 [链路探测](../lib/services/chain_probe_service.dart)。 | 真实中转和落地出口待测。 |
| 12 | P1 WARP/WireGuard | 本地 WireGuard 实际完成握手与密文转发，mips 和 gVisor 各三轮，对端端口变化后重建同一对端。WARP 诊断测试通过。见 [WARP 管理](../lib/manager/warp_manager.dart)。 | Cloudflare 生产凭据、真实出口和网络变化下不中断重连待测。 |
| 13 | P1 规则匹配 | 顶层按配置顺序匹配，支持子规则、规则集、协议限制和重匹配。域名/IP 规则集提供专用数据结构。见 [匹配循环](../core/Clash.Meta/tunnel/tunnel.go)、[域名规则集](../core/Clash.Meta/rules/provider/domain_strategy.go)、[IP 规则集](../core/Clash.Meta/rules/provider/ipcidr_strategy.go)。 | 已测首条、末条、规则集、子规则、未命中与重载并发流量。HTTP 更新、ETag、明确空集及旧下载不能覆盖新缓存均通过。规则匹配继续按原顺序。真实大规则集运行期长尾待测。[刷新证据](CORE_PERFORMANCE_BASELINE.md#整配置重载与规则下载交叠) |
| 14 | P1 网络变化与恢复 | TUN 监听默认接口变化并重置 DNS 连接。已补齐域名策略引用的连接池。Android 通知层有按传输类型判断的恢复分支，应用还有连通性和出口探测。见 [TUN 接口监控](../core/Clash.Meta/listener/sing_tun/server.go)、[Android VPN](../android/app/src/main/kotlin/io/fluxora/app/plugins/VpnPlugin.kt)、[应用连通性](../lib/application.dart)。 | 网络指纹及 Linux 四栈换路通过。策略 DoH/DoT 的旧出口和超时各 24 → 0。已验证在途 IPv6 DoT、DoQ、双栈 HTTP/2/3 DoH 和旧接口直接关闭。失联后 HTTP/3 新查询命中当前接口 31/36 → 36/36。真实 Wi-Fi/蜂窝切换和休眠唤醒待验。[失联对照](CORE_PERFORMANCE_BASELINE.md#旧接口直接失联时的-doh-查询) |
| 15 | P1 结构化诊断 | Go 已有核心状态、版本和日志 RPC，链路探测有失败阶段，支持包有脱敏和导出。现有 `asyncTestDelay` 用可省略标记区分确定超时，保留历史数值格式，Windows 回环和 Flutter 回归通过。见 [核心状态](../core/hub.go)、[链路诊断](../lib/services/chain_probe_service.dart)、[诊断导出](../lib/services/chain_diagnostic_export_service.dart)。 | 现有 SOCKS5 ACK、目标 accept、DNS 时间戳及日志能区分 Windows 回环阶段。真实节点、TUN 故障和分类误差仍待验证。 |
| 16 | P1 Go 编译与 PGO | Windows 固定负载 PGO 对照的 CPU 和 P95 各有增减，构建保持非 PGO。Go 1.20 兼容版已构建和回环验证，Windows arm64 已交叉构建。见 [基准](CORE_PERFORMANCE_BASELINE.md)。 | 公网代表性 PGO 与 Windows arm64 实机待测。 |
| 17 | P1 安全与隐私 | 控制 API 鉴权、脱敏、哈希篡改拒绝。协议定向组与固定上游通过及失败集合一致。Chromium 在四种 Linux TUN 栈通过双栈 DNS/STUN、严格 DoH 证书验证，并复验 WebRTC 防护与 WARP 规则顺序。[DoH 对照](CORE_PERFORMANCE_BASELINE.md#chromium-doh-证书与双栈出口) | Android 通知卡片、Windows/Android 真机浏览器出站、完整嵌套套件与正式签名待验。 |
| 18 | P2 构建精简 | x86_64 Release 的调试快照规则对照为 71,239,180 → 71,239,180 B，SHA-256 相同，MuMu 实装及双栈 TUN 通过。arm64-v8a Release 为 69,053,549 B，armeabi-v7a Release 为 68,998,631 B。三架构的 QA 签名、ABI、ZIP 对齐与核心字节核验通过。Windows Cargokit 编译失败的退出码会传给 Gradle。见 [产物清单](CORE_UPGRADE_GUIDE.md)。 | Windows 10 VMware 已验证两组安装、升级与卸载，静默保留数据待复验。Linux x86_64 Release 已通过配置失败重试与解包启动。Android 和 macOS 实机及正式签名待验。 |

## 优先处理的发现

1. **回包分配已降低（#9）。** Windows 等速 A/B 支持保留 SOCKS5 UDP 回包缓冲池复用。优先完成真实出站、移动端和更长持压。
2. **移除最后一次失败后的退避（#4）。** Windows 回环对照证实收益，同一目标的重试次数和暂拒恢复通过回归。
3. **历史候选已经收口（#1/#2/#5）。** 空闲 RSS 升幅未复现，运行时指标替换没有真实 CPU 收益，DNS 键补丁已撤回。

## 阶段顺序与验收

Stage 2-B 至 Stage 10 的每项结果、保留/撤回决定及剩余条件见 [连续执行 18 项状态](CORE_X_EXECUTION_PROGRESS.md#18-项阶段状态)。已新增 Windows 确定拒绝 A/B、隔离 Linux TUN/NAT64、本地三跳和 WireGuard、千节点重载、实际包及哈希验证。

先补生命周期回归与空闲资源基线，再测 DNS、TCP/UDP、TLS、IPv6 和 TUN 的端到端表现。随后复用同一套指标测大配置、测速、链式代理与 WARP，并将实测故障接入已有诊断。发布阶段再对比 PGO 和精简构建，独立记录平台、版本、签名、哈希与回滚路径。[升级与回滚](CORE_UPGRADE_GUIDE.md)

清单里的冷启动减少 15%、空闲 RSS 减少 10%、峰值 CPU 减少 10%、配置加载减少 20%、真实建连 P95 减少 10%、内核体积减少 10%，均为对照目标。当前合成配置的约 15% 加载改善只适用于共享子规则样本。加密、协议兼容、路由恢复和原节点保留以回归测试验收，界面流畅度用 Flutter Profile 单独测量。

实现时优先复用上游解析器、TUN 栈、GeoData 加载器和现有诊断入口。连接恢复沿用用户选择的节点。任何缓存、并发或预连接调整都需验证资源上限。

## 本轮验证

- 本轮 Go 桥接、Mihomo SOCKS5 编码、DNS、控制器、配置、规则等定向测试和 race 通过。桥接 race 使用既有临时 Windows CGO overlay。
- 本轮 Flutter 定向套件 56 项通过，其中 Windows 生命周期 20 项。
- Windows 回环使用同一内核验证启停、热重载、策略路由、批量测速、DNS A/AAAA、IPv4/IPv6 TCP 转发及已配置 secret 的控制器鉴权。
- 本轮 Windows amd64 与 Android arm64 内核构建通过，Android 检查了 16 KiB ELF 对齐及桥接导出。Linux/macOS 构建证据属于上一轮。真机 TUN、真实 WARP/链路、真实订阅、峰值 CPU、发布包、PGO 收益和 DNS 泄漏为 NOT VERIFIED。[基准记录](CORE_PERFORMANCE_BASELINE.md)
