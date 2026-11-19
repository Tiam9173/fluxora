# Fluxora 内核审计

Fluxora 在 `core/Clash.Meta` 维护 Mihomo 源码，`core/go.mod` 将模块解析到本地目录。`setup.dart` 使用 `with_gvisor` 构建，Android armv7 另外启用 `with_low_memory`。桌面使用独立进程和本地分帧 RPC，Android 使用 CGO 共享库及 JNI。

配置由 Dart 生成，Go 的 `validateConfig` 解析检查，`setupConfig` 读取配置并应用，`startListener` 和 `stopListener` 管理监听器。测速已有 Dart 请求去重、并发限制和 Go URL 测试。链式代理与备用池的状态、评分和诊断已有 Dart 实现，WARP 由 `WarpManager` 和已有 WireGuard 能力接入。

对照 Bettbox 1.19.8 源码，六项升级依赖与 Mihomo v1.19.34 对应。Bettbox 的批量测速和连接统计有独立 RPC 和客户端消费者，Fluxora 当前已有对应的测速请求控制与连接快照，直接移植会改变两端协议。日志历史的增长方式在两份代码中相同，Fluxora 的基准确认了该处的持续分配。

v1.19.34 带来 Snell 6、Shadowsocks 入站多用户和 TUN 自动路由修复，并更新 EasyTier、sing-tun 等依赖。发行版源码沿用 GPLv3 声明。核对过主项目、vendored Mihomo 和 Bettbox 压缩包随附的许可证文件。各传递依赖的逐项许可复审仍为 NOT VERIFIED。[上游发布记录](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.34)

核心协议、TLS、DNS 和 TUN 采用上游发行版增量。Fluxora 的后续补丁包括 Go 桥接日志、内存回收、测速调度，以及 Mihomo 规则解析和子规则校验。完整的 18 项审计、验证范围及后续顺序见 [内核增强矩阵](CORE_ENHANCEMENT_MATRIX.md)。

Core X 本轮核对上游 v1.19.34，实测 Windows 真实 SOCKS5 TCP/UDP 转发、半关闭、UDP 超时与回收，再分段测建连。TCP 样本主要落在 Windows 套接字写入。UDP 回包拼装占初始分配样本约 36%，采用现有缓冲池后，等速回环每包分配约减少 46%。建连日志确认明确 TCP 拒绝时同一目标会重试数秒。连接恢复语义待单独验证。[运行数据](CORE_PERFORMANCE_BASELINE.md#core-x-stage-1--windows-tcpudp-转发和资源回收9)

连续验证确认末次失败之后仍会退避。移除这段等待，保留同一目标及拨号次数。配置解析失败则维持上一份已生效配置，避免之后的停止或重启丢失监听。其他方面实测覆盖隔离 Linux TUN、NAT64、Windows 多跳链、真实 WireGuard 握手、千节点规则和 PGO。PGO 利弊不一致，维持既有构建设置。[连续验证与 18 项状态](CORE_X_EXECUTION_PROGRESS.md)

完整 Go 普通回归通过。全量 race 暴露 Vision 共享状态和 smux/TLS 缓冲区竞态。Vision 同步已通过定向重测，依赖问题和完整入站 race 仍是发布门禁。两小时测试有 9 次请求失败和约 3.8 MiB 私有提交增长，最后半小时趋稳，现有采样不足以定位来源。[性能基准](CORE_PERFORMANCE_BASELINE.md)

后续修正 smux 排队写入的缓冲区归属及 AnyTLS 关闭状态。分组入站 race 独立暴露 Restls v0.1.9 记录状态竞态。较短的重载对照在两组都看到 Go 运行时占用增加，历史两小时增长尚缺同类快照。加速重载通过客户端端口验证 3 个新连接在 `Inner` 状态被关闭。[验证检查点](CORE_X_EXECUTION_PROGRESS.md)

私有 DNS 覆写移除误匹配后，同一 Windows 内核的回环 HTTPS DoH 转发由 0/4 到 4/4。隔离 Linux 四栈完成短流和批量测试。MIPS 的批量吞吐低于 system 和 mixed，高于 gVisor。发布默认栈保持现状，另需 Windows 与 Android 真机验证。[性能基准](CORE_PERFORMANCE_BASELINE.md)

有界 UDP 暂存改善了外部规则提供器重载时的连通性。交替对照成功 122/200 → 778/778，直接拒绝或切回直连时新会话按最终组选处理。自然过期后两版 UDP 会话归零。单次强制 GC 候选使重载尾延迟上升，生产保留现行 GC。[对照基准](CORE_PERFORMANCE_BASELINE.md#udp-重载暂存对照)

采样分配显示规则提供器逐行解码占 77.70%。保留无歧义 CIDR 行解析快路径，其他 YAML 形式沿用旧解析器。两轮 Windows ABBA 中，实际规则提供器缓存热重载 P95 为 82.10 → 32.73 ms。待验证真实订阅分布与跨平台长尾。[实测对照](CORE_PERFORMANCE_BASELINE.md#cidr-规则提供器快路径)

其余重载分配热点来自节点选项解码的字段队列和标签切分。保留两处局部减法，重载累计分配再降约 28%。短测 UDP 私有提交差值主要对应 Go 仍持有的内存，维持原 GC 行为。[解码对照](CORE_PERFORMANCE_BASELINE.md#节点选项解码的字段元数据)

HTTP 规则提供器曾将终止于换行的无头 YAML 当成空集，并在刷新时与匹配、状态读取发生竞态。现拒绝无法识别的标题，保留有意提交空列表的能力，并原子发布构建完成的策略与更新元数据。Windows 实际错误响应后磁盘缓存及路由不变；ABBA 对照没有显示重载开销明显增加。[验证结果](CORE_PERFORMANCE_BASELINE.md#规则热刷新修复回归)

对带引号、注释的已识别 CIDR 标题复用同一快路径后，混合 HTTP 刷新负载的进程累计分配由 30.66 降到 6.26 MiB/次。带引号的规则项依旧使用旧解码器；时延分组差异和脚本修正均纳入基准记录。[格式分组对照](CORE_PERFORMANCE_BASELINE.md#带引号和注释的-cidr-标题)

2,420 次混合刷新长对照复现了时延与分配改善，未看到同等幅度的常驻内存变化。另一场回归发现整配置重载后仍未完成的旧规则下载会覆盖共享缓存，导致再重载退回旧规则。现关闭被替换的提供器，保证旧写完成或被取消后再发布新映射，回环控制 API 和桌面桥接均验证。[重载复现](CORE_PERFORMANCE_BASELINE.md#整配置重载与规则下载交叠)

嵌套 Docker 测试模块与主 Go 套件分开验收。上游 v1.19.34 自带的 Trojan XTLS 测试引用当前不存在的结构字段，隔离编译确认失败。用私有容器 API 及预存镜像独立验证 Snell 四种模式，另按 Fluxora 的监听初始化顺序验证基础 SOCKS。未改生产协议；完整外部协议兼容性仍未验证。[命令与证据](CORE_X_EXECUTION_PROGRESS.md#2026-11-15-重载与规则下载交叠)

Hysteria v1 本地严格证书验证定位到自定义 CA 更新顺序。配置解析构造出站时抓取现有根证书池，执行器随后重建并发布自定义 CA。回环实测首次添加未生效，重载时撤销后还成功一轮。现于构造前创建当前配置专用的信任池，应用成功时发布。Windows TLS CONNECT 与 Linux Hysteria v1 验证首次加入、撤销及严格域名校验。Windows 另验证预检和非法配置不改变运行中的信任。[验证记录](CORE_X_EXECUTION_PROGRESS.md#2026-11-16-自定义-ca-与虚拟机验收)

Linux 构建首次配置因依赖缺失中止时，系统默认安装前缀进入缓存。直接重试能编译执行文件，但把执行文件、插件和资源安装到 `/usr/local`，bundle 只剩核心。保留的修复让默认 bundle 路径在首次配置前确定，并统一核心的安装前缀。已在隔离 Ubuntu 容器复现原故障及修复后重试。[实际验证](CORE_X_EXECUTION_PROGRESS.md#2026-11-16-跨平台门禁接续)

批量测速在应用层整批等待慢节点，造成其他名额闲置。确认滚动补位在相同峰值并发下缩短快慢混合负载的完成时间，保留调度修改。等时负载仅见个位数毫秒差异。[测速对照](CORE_PERFORMANCE_BASELINE.md#批量节点测速调度)

Chromium 四种 Linux TUN 栈的双栈测试通过。开启 WebRTC 防护时，已有的同一条拦截规则会留在较低优先级。使用 Dart 实际生成规则对照，修复前测试 STUN 走直连，置顶去重后在 TUN 内拒绝。两版双栈 HTTP、受控 DNS 和停机清理均通过。证据限于试验规则、地址族和端口。[验证记录](CORE_PERFORMANCE_BASELINE.md#chromium-双栈-tun-与-webrtc)

同一防护还可能被稍后生成的 WARP 分流规则盖过。现在 WARP 插入规则时保留已有的防护前缀。使用实际生成的 WARP 自定义分流规则完成 Chromium 双栈前后对照，修复后两族 STUN 停在 TUN。[组合验证](CORE_PERFORMANCE_BASELINE.md#warp-组合规则)

Chromium 严格 DoH 经四种 Linux TUN 栈、两种解析器地址族共八组通过。未信任 CA 时 DoH 拒绝证书，导入后两族目标均通过，普通 DNS 未出现测试域查询。自动模式本轮发出的普通 DNS 由核心接管，外侧解析器无接收。测试未发现需要改动的核心行为。[证书与出口对照](CORE_PERFORMANCE_BASELINE.md#chromium-doh-证书与双栈出口)

内核 DNS 重置遍历主、默认和备用解析器，但遗漏仅由域名策略引用的传输。两条上联保持可用时，Linux 新请求已切到当前接口，策略 DoH/DoT 仍向旧接口发请求或达到客户端超时。构造解析器时登记实际传输，复用的底层连接池只登记一次，保持既有解析策略和证书校验。四栈切换后的策略加密查询走当前出口由 48/96 提高到 96/96。[双上联对照](CORE_PERFORMANCE_BASELINE.md#双上联切换与策略加密-dns)

DoT 在途请求另有独立问题，旧连接被取出时重置无法访问，得到应答后又归还池。保留在途应答，归还前比较原有锁保护下的连接池代次。四栈各 6 次换路，24 个在途应答前后均通过，48 个后续查询改为从当前出口返回，恢复池复用。交叉构建覆盖 Windows amd64 和 Android arm64，真实换网待验。[在途对照](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-dot-查询)

DoH 原先在客户端锁内立即关闭旧传输。HTTP/2 主动断开正在使用的连接，HTTP/3 等待在途请求释放传输锁，阻塞同一上游的新查询。将新旧客户端的生命周期分开后，在途查询按原截止时间收尾，新查询走当前出口。Windows 普通及 race 定向测试通过。实际网卡失联期间的在途成败需要独立验证。[在途对照](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-http2-和-http3-doh-查询)

隔离四栈实际关闭旧链路后，原在途查询无法取得答复。首个新查询不再等待已失联的 HTTP/3 客户端，36 条新查询全由当前接口返回，旧端口和停机后的双栈路由清理通过。当前记录维持原出站和原上游。[失联对照](CORE_PERFORMANCE_BASELINE.md#旧接口直接失联时的-doh-查询)

Windows Cargokit 包装脚本此前对 Dart 失败返回 0。实际 armv7 Release 已复现签名 APK 缺少 Code Forge，影响覆写脚本。显式传回退出码后，相同原生编译错误令 Gradle 中止。补齐本地 libclang 后完整构建与逐库验证通过。[构建对照](CORE_UPGRADE_GUIDE.md#android-armeabi-v7a-release)

Android 磁贴冷启动会重新读取持久化配置。此前前台初始化了 Rust 脚本桥接，磁贴和开机入口遗漏了初始化。MuMu 用同一已保存脚本交替打开两个版本，旧版日志为桥接未初始化，生成原始分组。修复版生成脚本分组及其规则，VPN 接口建立。脚本启用状态在兼容性检查前持久化。配置页也不再丢弃切换期间的点击，最后一次选择进入原生命周期锁。[验证记录](CORE_X_EXECUTION_PROGRESS.md#脚本冷启动和配置选择)
