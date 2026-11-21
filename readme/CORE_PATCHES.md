# Fluxora 内核补丁

当前上游基线为 Mihomo [v1.19.34](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.34)，提交 `0455d0d28c4526937380505153e65a843d8612e8`。前一基线为 v1.19.33，提交 `3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8`。

| 位置 | 变更与兼容性 |
| --- | --- |
| `core/Clash.Meta` | 合入上游 30 个文件的版本增量，保留已有 Fluxora 补丁。交叉比对时，旧版上游变更路径中只有 `go.sum` 与 Fluxora 原树不同。 |
| `core/go.mod`、`core/go.sum` | 通过 `go mod tidy` 同步桥接模块依赖。Go 最低版本仍为 1.20。 |
| `core/hub.go` | 日志缓冲区写满后覆盖最旧条目。读取时复制有序快照，释放锁后编码 JSON。容量 512、顺序和 RPC 格式维持兼容。 |
| `core/log_history_test.go` | 回归覆盖多次回绕、时间顺序、清空及清空后写入，附满缓冲区写入基准。 |
| `core/common.go`、`core/hub.go` | 配置加载、释放系统内存和关闭时各省去一次重复的强制 GC。异步测速沿用 50 并发上限，结果通过原有回调返回，移除进程级结果缓存。 |
| `core/Clash.Meta/rules/common/base.go`、`core/Clash.Meta/config/config.go` | 规则解析就地修剪字段。子规则校验复用已验证分支，遍历开销与规则和引用数量成正比。规则语法、匹配顺序和循环诊断格式照旧。 |
| `lib/state.dart`、`SwitchCardActivity.kt`、`core/Clash.Meta/hub/route/server.go` | 控制器绑定独立于代理 LAN 设置。Android 卡片复用生效端点及密钥。调试端点沿用控制 API 的 Bearer 鉴权。 |
| `setup.dart`、`core/Clash.Meta/VERSION` | 构建将固定的上游版本写进二进制，现有 Mihomo `/version` 可直接返回该版本。 |

上游既有 Fluxora 差异用 `git diff --no-index` 对比 vendored 目录和同一标签的源码。对比时单独核对版本标记、上游 CI 文件和本地集成文件。

本轮保留 `core/Clash.Meta/dns/resolver_hotpath_test.go` 的本地 UDP 回归与基准。隔离内存复测未证实持久增长，运行时指标在现有采样频率下收益有限，DNS 键试验的真实 CPU/延迟收益未复现。生产内核不增加这三处补丁。[P0 实测](CORE_PERFORMANCE_BASELINE.md#p0-隔离内存复测)

## Core X Stage 1 / Stage 2

- **#9，保留**。`listener/socks/utils.go` 用现有缓冲池封装 SOCKS5 UDP 回包，等待 `WriteTo` 返回后归还。`transport/socks5/socks5.go` 共享编码逻辑并保留原有分配式入口。编码回归覆盖复用旧缓冲、清零保留字段、IPv4、IPv6、域名、空/大报文和无效地址。Windows 1,200 B 等速 A/B 每次有效回包的分配从 2,866 降到 1,536 B，allocs/op 从 42.18 降到 41.14。回滚时撤回这两个文件的本轮改动及 `transport/socks5/udp_packet_test.go`，基准脚本可继续用。
- **#4，NO_PATCH**。回环分段确认 SOCKS5 提前应答和明确 TCP 拒绝的多次退避。待测短暂拒绝恢复和平台错误分类，保留现有重试、TLS 及路由行为。[Stage 1 和 Stage 2 实测](CORE_PERFORMANCE_BASELINE.md#core-x-stage-1--windows-tcpudp-转发和资源回收9)

## Core X Stage 2-B

- **#4，保留**。`tunnel/tunnel.go` 仍尝试最多 10 次，最后一次失败直接返回同一错误。Windows ABBA 每版 8 次确定拒绝，轮次 P50 中位数 2,935 → 2,010 ms，550 ms 暂拒后原目标恢复两版均 16/16。TLS 和 DNS 约 5 秒超时行为不变。回滚只需恢复该函数的原循环条件与失败判断。

## Core X Stage 6

- **#7/#3，保留**。`core/common.go` 用局部变量解析候选配置，解析成功后才替换当前指针。非法规则文件原先会清空重启所需的已生效配置，即使原监听当时仍可转发。Windows 回环验证旧内核失败、新内核在同一端口停止并启动后继续使用原规则。回滚只需恢复原赋值位置。
- **#16，NO_PATCH**。Windows PGO 对照中 CPU 与尾延迟改善方向不一致，保留普通优化构建。

## Core X Stage 9 · 入站并发回归

- **#17，保留**。在 `transport/vless/vision/{conn,filter,vision}.go` 同步读写方向共享的 TLS 探测状态，以原子字段发布填充与连接切换状态。锁仅用于状态访问，不覆盖 socket 读写。保持既有证书检查、填充命令和直接转发判断。补丁前的 gRPC 定向复现检测到数据竞态，补丁后 raw/gRPC/WebSocket 定向 race 五轮通过。同源交替 24 轮的 CPU 和墙钟时间中位差均低于 1%。回滚时只撤回这三个文件的同步改动并重建。全量入站额外发现的 smux/TLS 缓冲区竞态单独记录，依赖版本未变更。

- **#9/#17，smux 写入缓冲区归属**。固定上游 `d0c8756d3141ce2c9aa1046df6a93985441c6033`，MIT 许可证随源码保存在 `core/third_party/smux`。发送队列持有自有缓冲区，复用既有 sing 内存池。入队前失败由调用侧归还，入队后由发送侧在同步 I/O 完成时归还。写入超时或关闭仍会释放调用方，原有分片、流控和 TLS 校验继续使用。回归用例验证超时后队列内容独立于调用方。回滚时移除两个 Go 主模块的 smux `replace`，并移除新增的本地模块和定向 CI 步骤，再重新构建。[固定上游源码](https://github.com/MetaCubeX/smux/tree/d0c8756d3141ce2c9aa1046df6a93985441c6033)

- **#17，AnyTLS 关闭状态**。`transport/anytls/session/stream.go` 用已有 `atomic.TypedValue` 让读、写和关闭安全读取同一个关闭错误。TLS、ShadowTLS、JLS 各八轮入站 race 通过，继续保留原关闭和超时语义。回滚时仅撤回该文件的原子读写。Restls 仍需独立修复，依赖保持原版本。

## Core X Stage 9 · Restls 与 TCP 重载

- **#17，Restls 日志**。本地保存 `v0.1.9` 源码及两个原许可证。逐文件对照发行模块，已有文件的差异仅为 `conn.go` 四条日志中的跨方向计数器参数。握手、认证、计数推进和线上记录格式不变。七组入站 race 各重复三次，原有常规 Mihomo 套件通过。回滚时移除 `core`、`core/Clash.Meta` 和上游 Docker 测试模块的 Restls `replace`，撤回本地模块与对应 NOTICE 增量后重建。[上游版本](https://github.com/MetaCubeX/restls-client-go/tree/v0.1.9)
- **#7，TCP 热重载准入**。应用配置期间为外部新 TCP 保留最多 64 个等待槽，每个最多等待 1 秒。Fluxora 完成组选恢复和监听器更新后释放，显式暂停会取消当前等待。内核内部请求仍按原状态准入。回滚时撤回 TCP 等待、导出入口、调用方和相应测试，重建内核。[对照实测](CORE_PERFORMANCE_BASELINE.md)

## Core X #5 · DNS 覆写端点识别

- **保留**。`lib/common/dns_override.dart` 解析 DNS 端点后按完整 IP 或公共 DNS 服务域匹配。仅在实际匹配本地监听时应用原有 hosts 改写，校验传输和有效端口，支持 IPv6 与默认 DNS 端口。保留私有上游顺序、`#direct` 及既有组选策略。回滚仅需撤回该 Dart 文件中本节的改动及 `test/common/dns_override_test.dart`。公共解析器主机名参考 [Cloudflare](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/)、[Google](https://developers.google.com/speed/public-dns/docs/doh/)、[Quad9](https://docs.quad9.net/services/)、[DNSPod](https://docs.dnspod.cn/notices/mian-fei-ban-dot-dohbu-zai-gong-kai-ipjie-ru-de-gong-gao/)、[AdGuard](https://adguard-dns.io/en/public-dns.html)、[NextDNS](https://github.com/nextdns/nextdns/blob/master/run.go)。

## Core X #7/#9 · UDP 热重载暂存

- **保留**。`tunnel/reload.go` 与 `tunnel/tunnel.go` 在已有重载窗口内暂存最多 64 个外部 UDP 包，截止时间为窗口开启后 1 秒。释放时继续走原分片队列和 NAT 路径，新会话按应用完成后的组选和规则建连。内部 UDP 沿用原准入，外部暂存不占用分片工作协程。满载、过期、显式挂起、重叠重载及无法重新入队时归还包。已有 NAT 会话继续采用既有生命周期。只撤回本节对上述两个文件及 `tunnel/reload_test.go` 的增量即可回滚，前一轮 TCP 等待可独立保留。[对照实测](CORE_PERFORMANCE_BASELINE.md#udp-重载暂存对照)

- **#1/#7，NO_PATCH**。跳过热重载末次强制 GC 的 overlay 减少了 CPU 工时，但重载 P95 与预热后 Private Bytes 上升，生产 GC 调用维持原样。[单次强制 GC 对照](CORE_PERFORMANCE_BASELINE.md#单次强制-gc-候选)

## Core X #1/#2/#7/#13 · CIDR 规则提供器

- **保留**。在 `rules/provider/provider.go` 中，仅对 `ipcidr` YAML 规则集的标准 `payload:` 或 `rules:` 下的无引号 CIDR 项跳过逐行 YAML 解码。开头仍由 YAML 验证，行使用 `netip.ParsePrefix` 门禁，其他语法继续交给原解码器。规则字段优先级、匹配顺序和 CIDR 索引不变。兼容测试在旧解码器和候选上通过。回滚时撤回该文件的 CIDR 快路径与 `cidr_yaml_test.go` 中的本轮用例，重建内核。独立基准脚本可继续使用。[实测对照](CORE_PERFORMANCE_BASELINE.md#cidr-规则提供器快路径)

## Core X #1/#7 · 节点选项解码

- **保留**。`common/structure/structure.go` 不再为每个字段把完整反射元数据排入切片，同一个标签只解析一次。保留既有 `squash`、`remain`、`omitempty` 和忽略项优先级，原来的字段顺序、键查找与错误聚合不变。千节点热重载的累计分配约降 28%。已有 UDP 关联 P95 增 1.52 ms，连接无失败。回滚时仅撤回此解码器改动并重建；两版皆通过的 `TestStructure_FieldTagOptions` 可保留。[实测对照](CORE_PERFORMANCE_BASELINE.md#节点选项解码的字段元数据)

## Core X #7/#13 · 规则热刷新正确性

- **保留**。`rules/provider/provider.go` 区分无标题、不可识别的内容与明确的空规则集。HTTP 无头响应在磁盘写入和规则发布前返回错误；标准 CIDR 快路径不做完整 YAML 解码。撤回当轮 YAML 标题识别、`ErrNoPayload` 和 `yaml_header_test.go` 可单独回滚。
- **保留**。同文件用原子快照发布已经构建完成的规则策略；`component/resource/fetcher.go` 用已有的原子类型保护刷新时间和内容摘要，保持原有写缓存和发布顺序。规则匹配不新增锁。撤回原子字段及对应的 `rules/provider/refresh_test.go`、`component/resource/fetcher_test.go` 可独立回滚；两项回滚后均需重建内核。[对照与回归](CORE_PERFORMANCE_BASELINE.md#规则热刷新修复回归)

## Core X #1/#2/#7/#13 · 带引号和注释的 CIDR 标题

- **保留**。`rules/provider/provider.go` 只在 YAML 探针已经确认标题有效后，才识别带引号或注释的常见 `payload:` 和 `rules:` 标题，复用既有 CIDR 项解析快路径。带引号的规则项、非标准缩进和其他 YAML 结构继续使用原解码。Windows 的源码构建与对照候选 SHA-256 一致。回滚只需恢复此处的标题匹配；兼容测试可保留。[实测对照](CORE_PERFORMANCE_BASELINE.md#带引号和注释的-cidr-标题)

## Core X #7/#13 · 停止旧规则下载覆盖缓存

- **保留**。`hub/executor/executor.go` 在发布替换配置前关闭退出的规则提供器；仍复用的对象不关闭。`component/resource/fetcher.go` 取消下载，并在释放前等正在执行的缓存写入完成，忽略随后到达的旧响应。`tunnel/tunnel.go` 按快照发布供控制 API 使用的提供器映射。回滚时只撤销这三处改动，前一轮策略、摘要和刷新时间的原子修复应保留。[复现与重载对照](CORE_PERFORMANCE_BASELINE.md#整配置重载与规则下载交叠)

- **验证工具，不涉及生产行为**。本轮补齐规则长测的事件消费、Go 内存分类和隔离 Linux 进程采样。回滚时只移除 `tool/benchmark_core_rules_windows.py`、`tool/benchmark_core_relay_windows.py`、`tool/measure_core_idle_windows.py`、`tool/verify_core_rule_refresh_windows.py` 中对应的采样与复用增量。原版嵌套协议测试只通过 `build/core-x/nested-module/` 的临时 overlay 限定验证范围。

## Core X #17/#18 · 配置信任与卸载

- #17 `component/ca` 构建独立信任池，`config` 传给出站和提供器，`hub/executor` 在配置应用时发布。回滚需撤销这三处增量、适配器和 Restls 的根证书传递，调整 `config/tls_trust_test.go` 对新增字段的依赖，再重建。
- #18 `windows/packaging/exe/inno_setup.iss` 增加静默卸载分支，默认保留数据。回滚仅撤销 `InitializeUninstall` 开头分支。带修复包已编译，仍需无人值守复验。[验收记录](CORE_X_EXECUTION_PROGRESS.md#2026-11-16-自定义-ca-与虚拟机验收)

## Core X #18 · Linux 构建重试

- **保留**。`linux/CMakeLists.txt` 在 `project()` 前缓存默认 bundle 前缀，并令核心使用其他产物的安装前缀。显式 CMake 前缀保留。复现一次依赖检查失败后，用同一缓存生成完整 Release bundle，校验包内核心与输入一致并实际启动。回滚只需撤回该文件的前缀初始化和核心安装目标两处增量。已存在的旧错误生成缓存需解除 `CMAKE_INSTALL_PREFIX` 缓存项或清理后再构建。

## Core X #18 · Android 调试快照打包

- `android/app/build.gradle.kts` 将 `kernel_blob.bin` 存为未压缩 ZIP 条目。官方 Android 12 模拟器两次启动原 APK 均在加载快照时失败。快照内容和 Go 核心不变的未压缩对照进入应用初始化。三个单 ABI 调试包均通过签名、对齐和核心字节匹配，x86_64 在 MuMu 实际打开。每个调试包增 76.18 MB。完整 x86_64 Release APK 对照中，两包逐字节一致，确认此规则没有增加该 Release 包的体积。回滚只需删除 `androidResources` 小节并重新构建。[完整 APK 对照](CORE_UPGRADE_GUIDE.md#2026-11-17-android-release-apk)

## Core X #15 · 链式测速的超时原因

- 继续使用 `asyncTestDelay` 回包。Go 仅对可识别的 `context.DeadlineExceeded` 添加 `timedOut: true`，成功延迟和原失败值 `-1` 保留。Dart 链路探针用该字段选择现有的单跳超时状态，旧核心缺字段时沿用原行为。字段省略时不增加成功回包长度，也不暴露异常文本。回滚撤回 `core/{hub,constant}.go` 中的字段增量、Dart 模型及其生成文件和链路探针一处读取。配套 Go 与 Flutter 回归独立可复现。[实测记录](CORE_X_EXECUTION_PROGRESS.md#2026-11-16-跨平台门禁接续)

## Core X #8 · 批量测速补位

- Dart `lib/views/proxies/common.dart` 使用现有并发上限，把空出的名额分给下一节点。派发前核对配置，现有去重、结果写入和排序路径继续使用。回滚只需把 `delayTest` 中的迭代器和工作循环换回分批等待，并移除新添的补位回归。[交替对照](CORE_PERFORMANCE_BASELINE.md#批量节点测速调度)

## Core X #17 · WebRTC 拦截规则的优先级

- 保留 `lib/models/chain_proxy.dart` 的单处配置生成改动。开启既有防护时，把同一组拦截规则规范为一份并置顶。原样保留其余规则的相对顺序。回滚只需将此处恢复为只插入缺失规则的逻辑，并移除 `test/integration/chain_proxy_mihomo_gen_test.dart` 中新增的定向测试。[真实浏览器对照](CORE_PERFORMANCE_BASELINE.md#chromium-双栈-tun-与-webrtc)
- WARP 组合独立修复。应用编排将已经写入的 WebRTC 规则数量交给 WARP，智能分流及自定义分流从该位置插入。两者皆启用时无需重新扫描规则。回滚这一轮只需撤下 `protectedRuleCount` 的传递和三项组合测试，保留上一轮 WebRTC 去重逻辑。[组合对照](CORE_PERFORMANCE_BASELINE.md#warp-组合规则)

## Core X #5/#14 · 换网后的 DNS 连接重置

- 保留 `core/Clash.Meta/dns/resolver.go` 的重置清单。创建底层传输时登记一次，复用同一传输的包装器共用这一条记录，域名策略和代理解析策略均涵盖在内。沿用网络变更事件以及各传输原有的重置方法。配套 `resolver_reset_test.go` 用已入池连接复现策略遗漏。回滚时只撤回本轮两个 Go 文件的增量并重建内核。[四栈实测](CORE_PERFORMANCE_BASELINE.md#双上联切换与策略加密-dns)
- 独立保留 `core/Clash.Meta/dns/dot.go` 的连接池代次检查。在原有锁内取代次及校验，重置时递增。已经发出的请求仍可返回，属于前一代的连接随后关闭，关闭不阻塞交付响应。回滚只撤回 `dot.go` 与 `dot_test.go` 的本轮增量并重建，原先的策略池重置可独立保留。[双上联在途对照](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-dot-查询)
- DoH 换路时在原锁内摘除 HTTP 客户端，新查询用当前出口建连。旧客户端在现有查询完成或超时后关闭，旧请求的错误无法重建已替换的客户端。原有上游、证书校验、查询截止时间和重试上限继续使用。回滚只需撤回 `dns/doh.go` 与 `dns/doh_test.go` 的本轮改动。[HTTP/2 与 HTTP/3 对照](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-http2-和-http3-doh-查询)

## Core X #5 · 订阅中的 DNS 监听

- `dns/server.go` 串行管理 DNS 监听的启动和停止。重复应用同一地址时重试缺失的协议，保留可用的监听，并原子替换内部服务引用。发布成功前确认监听启动。独立回滚本轮 `server.go` 与 `server_test.go` 的修改即可。验证覆盖 TCP 占用期间的 UDP，释放后同地址的 TCP/UDP 应答，真实核心使用独立上游的解析，以及 Windows 定向 race。

## Core X #18 · Windows Cargokit 退出码

- `plugins/code_forge/cargokit/run_build_tool.cmd` 保存 Dart 构建工具的退出码并原样返回。快照失效时沿用一次重建机会，依赖安装或快照编译失败时立即返回。用实际 Dart 无效参数验证错误从 0 变为 1，实际 Android Gradle 原生编译失败也传递为 1。完整 armv7 Release 成功构建并核对原生库。回滚独立撤回该批处理文件的修改。[构建记录](CORE_UPGRADE_GUIDE.md#android-armeabi-v7a-release)

## Core X #5 · DNS 覆写与 Android VPN

- `lib/state.dart` 在节点 DNS 使用应用默认值时，允许 `lib/common/dns_override.dart` 继承订阅明确配置的公共节点解析器。只用于节点引导。显式自定义的应用节点 DNS 保留原合并策略。回滚这两处与 `dns_override_test.dart` 的对应改动。
- Android 的 `Ext.kt` 和 `VpnPlugin.kt` 在兜底发现阶段只读非 VPN 网络。Android 桥接额外排除自身虚拟 DNS 地址，按顺序更新，Mihomo 使用原子快照发布。回滚本轮 Kotlin 与 `core/lib_android.go`、`core/state/state.go` 和 `dns/patch_android.go` 的对应改动。[实测口径](CORE_PERFORMANCE_BASELINE.md#dns-覆写与节点测速)
- `component/resolver/service.go` 在内部 DNS 服务未启用时将 TUN 接管的查询交给系统解析器。配置服务存在时完全沿用它的应答与错误。回滚仅撤回 `service.go` 的这处分支及 `service_test.go`，然后重建内核。

## Core X #3/#7 · 脚本冷启动和配置选择

- 脚本选中状态在兼容性检查前写入偏好，Android 磁贴和开机入口在生成配置前初始化 Code Forge。独立回滚 `main.dart`、`providers/config.dart`、`views/profiles/scripts.dart` 的对应增量。
- 脚本大 JSON 结果解码交给独立 isolate，小结果维持直接解码。独立回滚 `js_runtime_manager.dart` 的分支。
- 配置页在内核切换期间只保留最后一次待处理选择，继续通过同一个生命周期锁应用配置。配套的挂起标识和回归覆盖实际点击。回滚 `controller.dart`、`manager/clash_manager.dart`、`providers/state.dart`、`views/profiles/profiles.dart` 的选择队列增量。

## Core X #5/#3 · Android 首轮 DNS 与磁贴状态同步

- 服务 isolate 在首次测速和 quick/boot start 前有界读取一次当前物理 DNS，避免异步 `dnsChanged` 推送与首轮 `asyncTestDelay` 竞态。读取最多等待 2 秒，失败时沿用原有事件路径。
- VPN 原生启动完成后发送 `START` 状态事件；App 在磁贴或通知启动服务时立即拉取真实 VPN 状态，并在控制器初始化早期再同步一次，避免磁贴显示已启动而 App 仍显示关闭。
- Android 重启路径不再立即触发 `debug.FreeOSMemory()`；连接、fake-IP 和 DNS 缓存清理保留，已有空闲 GC 调度继续负责回收。
- 回滚：撤回 `lib/main.dart`、`lib/controller.dart`、`lib/state.dart` 和 `android/app/src/main/kotlin/io/fluxora/app/plugins/VpnPlugin.kt` 的本节增量。Flutter/Go 定向回归通过，真实 Android 首轮测速与重启耗时仍需设备复测。
## 2026-11-19 节点快照候选

- **#1/#7，NO_PATCH**。尝试直接返回测速队列已经复制出的快照，省去逐项追加生成第二份切片。空历史的 JSON 仍分别保持原有的 `[]` 与 `null`，快照隔离和并发读写回归均通过。
- 千节点真实 RPC 的分配次数下降，但耗时和 CPU 收益没有稳定复现。已用逐字节相同的本地备份恢复 `core/Clash.Meta/adapter/adapter.go`，本轮未保留这处生产补丁。保留 `adapter/history_snapshot_test.go` 与 `tool/benchmark_core_proxy_snapshot_windows.py` 供复现。[数据与边界](CORE_PERFORMANCE_BASELINE.md#2026-11-19-节点列表快照)

