# Fluxora Core X 连续执行检查点

基线 `cbd8a6a7` 加既有工作树，Mihomo `v1.19.34` / `0455d0d28c4526937380505153e65a843d8612e8`。保留原编号，完整既有实现与兼容性见 [18 项矩阵](CORE_ENHANCEMENT_MATRIX.md)。本轮原始输出放在 `build/core-x/`。

18 项是瓶颈排查的参考范围。生产补丁须有可复现的用户收益，并通过相关路径的功能和性能回归。收益不明的候选停在实测记录，已有证据充分的方向沿用当前实现。

- Stage 1 · #9 继承 Windows 转发、半关闭、会话回收和 1,200 B UDP 每包分配 2,866 → 1,536 B 的证据。保留既有补丁。
- Stage 2 · #3/#4/#5/#15 继承 480/480 Windows 回环成功及建连分段。普通域名 **端到端首字节** P95 27.12 ms，HTTP 请求写出之后至首字节 P95 为 1.16 ms。
- Stage 2-B · #4/#5 Windows ABBA。保留移除末次拨号失败后等待的补丁；持续拒绝轮次中位 P50 2,935 → 2,010 ms，暂拒 550 ms 时两版同一目标都 16/16 成功。DNS 超时与丢首包约 5 秒；新请求可恢复。证书错误、无效 SOCKS 命令、并发撤销后连接归零均通过。最终二进制重复验证。
- Stage 3 · #6/#14 Linux WSL 独立网络命名空间 PASS。Fluxora 桥接驱动真实 TUN，gVisor/system/mixed 各地址族分别验证 15 次完整 64 KiB HTTP 和 128 个 1,200 B UDP 包，并验证 A/AAAA DNS 接管。双栈断线时均失败，同一出站恢复，关闭后 IPv4/IPv6 路由和规则还原。Windows/Android 实机 TUN、Wi-Fi 和休眠唤醒 BLOCKED，ADB 无在线设备。
- Stage 4 · #10 Windows Go 双栈竞争 8 轮，IPv6 模拟挂起时约 300 ms 选中同主机 IPv4，快速失败后立即选 IPv4，落选 socket 关闭。最终 Windows 二进制经 A/AAAA DNS 和 HTTPS 验证两个地址族，各 8/8。隔离 Linux 使用 TAYGA、测试专用 ULA 前缀及合成 AAAA 到 IPv4 HTTP 原站 16/16；运营商网络与真机泄漏待验。
- Stage 5 · #11 Windows 真实单跳、两跳、三跳 SOCKS5 dialer-proxy 各 40 次，连接及 64 KiB 回包 P50 为 8.29、13.97、20.36 ms，直连对照 4.89 ms。逐跳实际拨号计数正确，结束追踪连接归零，中间跳不可达时失败。#12 本地 WireGuard 真实握手与密文传输通过，mips 和 gVisor 各三轮、每轮两次使用同一对端重建。Cloudflare WARP 生产端点与设备状态变更 BLOCKED，缺隔离的真实账户与出口测试条件。
- Stage 6 · #7 发现并修复拒绝非法配置时覆盖 `currentConfig` 的问题。旧版流量仍通，但停止后不能接着启动。解析完成后再更新指针，新增实进程回归。#8 三批共 195/195，实际上游峰值 50，完成 P95/P99 319/323 ms，空闲连接归零。#13 规则定位 P50 约 2.4 ms，短 profile 主要为 Windows 套接字调用，暂不修改匹配顺序。
- Stage 7 · #1/#2/#3/#15 Windows 回环流量与重载稳态跑满 7,200 秒，136,416/136,425 个请求和 239/239 次重载成功。goroutine 7→峰值 9→7。工作集下降，Private Bytes 后段中位数高于前段。诊断、脱敏和生命周期纳入 Flutter 121 项定向测试，通过。
- Stage 8 · #16 Windows 固定负载 PGO ABBAABBA。TCP CPU 402→410 µs，P95 1.32→1.24 ms。UDP CPU 166→156 µs，P95 2.21→2.29 ms。两组无丢包，二进制 60,809,216→60,840,448 B。结果有取舍，PGO 不进入构建设置。#18 Windows 本地 Inno、ZIP 与 Android 同工序 Debug APK 已比较大小，详见基准。
- Stage 9 · #17 Windows 实际控制 API 四个端点的有效/缺失/错误凭据回归通过，令牌未出现在接口响应。Go race、Flutter 脱敏及保护层检测通过。WSL 三栈 DNS 接管已验，真实浏览器、Windows/Android VPN 出口泄漏与发布签名待专用环境。
- Stage 10 · Mihomo 普通全量 Go、桥接 Go/race、Flutter analyze 通过。Windows Flutter 全量 2,457 通过、6 跳过、1 失败，剩下的 AF_UNIX 用例在 Linux 按原断言通过。Windows Release 与 Inno/ZIP、Android Debug APK、Linux WSL 运行复验通过。阶段编译覆盖 Android arm64/armv7、Windows amd64/arm64、Go 1.20 兼容及 macOS arm64。race 专项和真实设备门禁见下表。

## 2026-11-15 接续

- 上次长稳态在第 2,493.64 秒被宿主中断，留有 44,776 条请求时的采样。更早一次控制器连接重置后失败退出，两次均保留原日志。独立进程重跑 7,200.01 秒，`build/core-x/soak-2h/soak.json` 和正常关闭记录齐全。
- #5 加测配置中两个原生 DNS 上游，其中一个完全不响应。最终核心 16/16 HTTPS 成功，P50/P95 8.27/11.56 ms。单上游丢包仍按约 5 秒超时。无 DNS 生产改动。
- #6/#9/#17 在隔离 Linux 对三个真实 TUN 栈加测 IPv4 和 IPv6。每栈 30/30 TCP、256/256 UDP，指定的 IPv4/IPv6 上游端口 53 没有收到被劫持的 DNS 探针。IPv4 在原出站恢复后的首个成功请求为 16/12/12 ms，三个栈恢复后 IPv6 HTTP 也成功。关闭前后的双栈路由表和策略规则相同。原始记录为 `tun-dual-final-*.txt`。
- 修正 Windows helper 测试装置，补齐沙箱路径、部署及 SCM 状态转移，原断言保留。两套共 14 项通过。Windows 原生 Rust helper 帧读写、鉴权、路径和退出测试 22 项通过。真实 AF_UNIX 用例按原断言在 WSL Linux 容器验证，包含其在内的 41 项 Linux Flutter 定向测试通过。Windows 全量原记录为 `flutter-all-resumed.txt`。
- 比对 APK 的本地文件头与中央目录，早先通过替换条目制作的验证包中有 20,034,417 B 的旧内核残留区域。基线与候选改用同一压缩、对齐和签名工序，165,890,337 → 169,531,681 B，增加 2.20%。同工序两包通过 Android SDK `zipalign` 和 APK 签名 v2 校验。候选为 `build/core-x/packaging/android-corex-debug-verified.apk`。
- 同源 Android arm64 复编译用 Go overlay 隔离两处补丁。同样启用 `with_gvisor` 时两处补丁共增加 64 B。旧包未启用该标签，现内核去掉标签的临时参考库少 11,331,040 B。保留项目现有发布标签。
- Windows Mihomo 全量 `-race` 在 `listener/inbound` FAIL，其余 64 个有测试的包通过。Vision 会话并发读写在撤回前两处补丁的临时基线上也能复现。另有 XHTTP 压力下 smux 与 TLS 依赖间的缓冲区竞态。完整日志为 `mihomo-final-full-race.txt`。全入站压力超过 7 GB 私有内存，停止进程后用 2.5 GiB 限制重试。修复后的较广 XHTTP race 重跑仍达到该上限，整套 race 门禁未通过。
- Vision 同步方案经过 24 轮交替对照后纳入源码。两版全部正常，墙钟中位 1,707.5→1,722.5 ms，CPU 2,687.5→2,664.1 ms。最终源码的 raw/gRPC/WebSocket 定向 race 五轮通过，Mihomo 普通全量回归通过。原因、范围和回滚见 [内核补丁](CORE_PATCHES.md)。
- 含 Vision 修复的 Windows Release、Inno 与便携 ZIP 已重建，core/helper/DLL 哈希锚点校验通过。Android Debug 验证包更新 arm64，APK v2、ZIP 对齐、ELF 16 KiB 和 JNI 导出通过。Linux 最终核心复跑三个 TUN 栈双栈通过。Windows 最终二进制同配置再跑 600.01 秒，11,262/11,263 个请求和 20/20 次重载成功，正常关闭。

## 2026-11-15 入站竞态与重载诊断

- #9/#17 固定 smux 上游提交，本地模块复用缓冲池解决排队写入持有调用方数据的问题。旧版定向回归 0/3，补丁版 3/3。smux 完整 Windows race 51 项通过，包括两条 8 GiB 传输，耗时 1,759 秒。TCP 回环各 12 轮，吞吐约低 0.75%，分配次数相同。
- Windows 入站 race 分成 180 组，首轮 165 组通过、1 组按上游原有 Windows 条件跳过、10 组竞态失败、4 组达到 1.4 GiB 私有内存上限。AnyTLS 使用已有原子值发布关闭错误，TLS、ShadowTLS、JLS 各复跑八轮通过。4 个内存受限组提高上限并拆开 Mekya 串行与并发用例后全部通过。综合为 172 组通过、1 组上游跳过、7 组 Restls 竞态失败。Restls v0.1.9 所检上游 HEAD 与固定 tag 同一提交。Mihomo 其他 64 个有测试的 Go 包及桥接 race 通过。
- #1/#7 回环交替运行两组无重载、两组每 30 秒重载，每组 180 秒。无重载 7,055/7,055 成功，重载组 6,960/6,961 成功。一次中断与重载窗口重叠。另用仅诊断覆盖层的本地二进制做 100 次加速重载，309 个新连接中 3 个失败。三个失败按客户端端口对应到 `Inner` 状态拒绝新连接的日志。保留该状态保护，等待有原配置快照和资源上限保护的修复。
- 堆快照显示四次短测的 `Sys - HeapReleased` 均上升 1.86–2.75 MiB，栈占用增加 0.66–1.34 MiB。短测初末的存活 Go 堆均下降。两小时历史样本未记录同类快照，无法将其私有内存增长全部归类。
- Windows Release、Inno、便携 ZIP 与 Android 调试回归包已重新生成。Windows 核心与 helper/DLL 清单一致，Android arm64 和 armv7 库已更新，arm64 ELF 16 KiB、APK 对齐及 v2 签名已核对。正式发布和真机测试仍是独立门禁。[验证包与哈希](CORE_UPGRADE_GUIDE.md)

## 2026-11-15 Restls 与热重载修复

- #17 Restls 的跨方向读取来自四条诊断日志。同向计数保留。依赖 v0.1.9 采用本地源码与原许可证。隔离和正式接入的七组入站各三轮 race 都通过。新版完整入站 race 拆为 181 组，180 组通过，1 组是上游原有 Windows Sudoku HTTP mask 跳过条件，无失败和内存上限中断。主模块常规全量、桥接和控制器鉴权复验通过。
- #7 通过有限 TCP 等待槽保护重载期间的新连接。ABBA 每版 200 次重载，基线 603/611、新版 587/587。原组选在测试中每次都由调用方指定，超时、满槽及显式暂停取消通过定向 race 测试。
- 单独的上游 Docker 测试模块在 Restls 替换前后都需要刷新旧 Go 模块图，当前主机未找到 Docker 命令。该模块尚未运行。Windows 与 Android 可本地构建，Android ADB 当前无在线设备。
- #6/#10/#14 增补 `mips` TUN 回归。当前应用 `Tun` 和 Mihomo 顶层/监听器配置已默认 `mips`，也保留另外三栈的显式选择。最终 Linux 核心在四栈均通过隔离真实 TUN 的 TCP、UDP、A/AAAA DNS 接管、原出站恢复及路由清理，MIPS 原始日志为 `build/core-x/tun-reload-restls-mips.txt`。[Mihomo TUN 文档](https://wiki.metacubex.one/en/config/inbound/tun/#stack)
- #18 Windows Release、Inno 与便携 ZIP 以及 Android Debug 回归包已再构建，Android 更新 arm64-v8a 与 armeabi-v7a，保留 16 KiB 对齐和 Debug v2 签名校验。macOS arm64 核心已交叉构建。包和哈希见 [升级记录](CORE_UPGRADE_GUIDE.md)。
- #5 新复现 DNS 覆写分类误判。运行 `build/core-x/reload-restls-final/dns-override-probe.dart`，私有 DoH 的 URL 路径中出现公共 DNS 名称即被丢弃。测试只走真实 Dart 配置生成函数，无网络请求。该问题进入下一轮。

## 2026-11-15 DNS 覆写与四栈性能

- #5 DNS 覆写按主机判断已知公共解析器，按主机、有效端口及 DNS 传输判断本地监听。Windows 回环使用同一 Mihomo、受信测试证书和同一 HTTP 代理，交替运行生成的两份配置。旧配置 0/4 转发成功，修复后 4/4。新增 7 项 Dart 回归及相关定向套件共 40 项通过。
- #6/#10/#14 隔离 WSL 上四栈均通过短流与大流量各六轮。MIPS IPv4/IPv6 大流量中位数 1,351.9/1,328.4 MiB/s，CPU 工时 1.867/1.813 CPU-s/GiB。UDP 每批 128 个包，MIPS 两个地址族各 768/768 回包。系统栈和 mixed 在本测的长流吞吐更高，保留现有栈默认值。各轮均验证 DNS 接管、原路径恢复及路由清理。[完整对照](CORE_PERFORMANCE_BASELINE.md#四栈-tun-短流和批量传输)
- 最终 `flutter analyze --no-pub` 无问题。Windows 全量 2,464 通过、6 跳过、1 失败。失败项要求真实 AF_UNIX，Windows 生产代码显式禁用 AF_UNIX 并使用回环 TCP。同一用例此前在隔离 Linux 按原断言通过。Windows 日志为 `build/core-x/dns-override-flutter-final.log`。
- #7/#9 新增实际 HTTP 规则提供器下载、千节点热重载与并发 TCP/UDP 对照。两版各 96 次热重载，当前版新 TCP 550/550 通过。两个 UDP 场景共 74 次超时，均在重载 RPC 期间开始。单独诊断构建按客户端端口确认 29/29 次 UDP 超时对应 `Inner` 状态拒收。先保留现有拒收保护，下一轮验证有界暂存、重载后按生效配置发送以及显式停止。诊断日志只在临时 overlay 中。[原始对照](CORE_PERFORMANCE_BASELINE.md#http-规则提供器和-udp-重载)

## 2026-11-15 UDP 热重载

- #7/#9 保留最多 64 包、1 秒的外部 UDP 暂存。相对于含 TCP 保护的版本，每版 96 次重载，UDP 回包 **122/200 → 778/778**。实际 HTTP 提供器阻塞下，两种切换方向均按最终手选策略处理新流量。配置切换、显式挂起、满槽和超时经 Go race 核对。
- #1 两版自然过期后 UDP 会话归零，goroutine 均为 39，Go 堆分别为 7.42、7.38 MiB。候选版 Private Bytes 仍高 3.2 MiB，需进一步归类。稳态 UDP 吞吐中位数均为 36.64 MiB/s。[对照数据](CORE_PERFORMANCE_BASELINE.md#udp-重载暂存对照)
- #1/#7 单次强制 GC 候选在真实 HTTP 提供器回环中每版 96 次。P95 由 82.03 升至 96.80 ms，预热后 Private Bytes 增约 8.5–9.6 MiB，保留生产版两次强制 GC。原始证据只对应临时 overlay。
- #1/#7/#13 48 次重载的 Go 分配 profile 中，规则提供器 `rulesParse` 占采样分配量 78.95%，其逐行 YAML 解码累计占 77.70%。诊断构建在 300 ms 门限下另有 4 个 UDP 超时，最长重载 431.97 ms。下轮优先检查 CIDR 常见行的同语义低分配解析，诊断版性能与正式 ABBA 分开记录。[分配定位](CORE_PERFORMANCE_BASELINE.md#规则提供器分配定位)
- Windows Mihomo、Go 桥接普通全量，四个 Go 包定向 race 与 Flutter 35 项定向通过。Linux 隔离四栈双栈烟测通过。Android arm64 和 armv7 核心构建通过，ADB 无设备，真机 UDP 和网络切换继续待验。

## 2026-11-15 CIDR 提供器与资源归类

- #1/#2/#7/#13 保留常见 CIDR YAML 行快路径。10,000 条解析 41.58 → 1.90 ms，累计分配 79.71 → 5.31 MB。真实 HTTP 提供器缓存负载各 192 次重载，P95 82.10 → 32.73 ms，重载期间每次累计分配约 95.5 → 24.4 MiB。两版 UDP 全部回包；新 TCP 941/942 → 888/888。[基准与复现](CORE_PERFORMANCE_BASELINE.md#cidr-规则提供器快路径)
- #1 用原 UDP 暂存 A/B 二进制复测。自然到期后组间 Private Bytes 中点差约 3.37 MiB，约 3.25 MiB 对应 Go 仍持有的运行时内存近似量。主动归还后中点差约 1.03 MiB。四轮 UDP 会话都归零，goroutine 均为 39。此处不等同于长期泄漏验收，不改生产 GC。[资源归类](CORE_PERFORMANCE_BASELINE.md#udp-暂存私有提交归类)
- Windows Mihomo 与桥接普通全量、定向 race、Flutter analyze 与生命周期/DNS 定向 27 项通过。Linux 隔离四栈各通过；Android arm64/armv7 和 macOS arm64 核心构建通过，真机待验。
- #1/#7 同轮保留节点选项字段解码增量。行级 profile 定位 422.31 MiB 的反射字段队列，以及两次标签切分。两轮同源对照中每次热重载累计分配约 24.4 → 17.6 MiB，P95 32.20 → 26.79 ms，已有 UDP 关联 P95 2.91 → 4.43 ms，成功率均为 100%。[基准](CORE_PERFORMANCE_BASELINE.md#节点选项解码的字段元数据)
- #7/#13 最终 Windows 实进程验证规则提供器 36 次内容更新、36 次 ETag 未改、6 次错误拒绝；控制器鉴权、测速 195/195 与千节点配置重启通过。独立旧版与最终版均失败的门禁：无可识别 YAML 标题且以换行结尾的响应被接受，已生效规则集被清空。两版均经实际路由复现，此问题不计通过。[证据](CORE_PERFORMANCE_BASELINE.md#运行中规则提供器刷新)

## 2026-11-15 规则热刷新正确性

- #7/#13：修复无头 YAML 以换行结尾时错误清空规则，以及刷新与读者之间的竞态。Windows 回环实进程验证了 36 次内容更新、36 次 ETag 304、6 次返回 503 的无头响应及两种显式空集。无头响应之后缓存字节、规则数、已有路由和停止再启后的转发都未变。
- 与修复前同工序 Windows ABBA，两版各 96 次千节点和 10,001 条 CIDR 缓存重载，P95 25.98 → 26.06 ms，每次累计分配约 17.5 MiB；两版 TCP、UDP 测试流量全部成功。[对照和复现](CORE_PERFORMANCE_BASELINE.md#规则热刷新修复回归)
- Windows 控制器鉴权四个端点、测速 195/195、Mihomo 与桥接普通 Go 全量、相邻 7 个 Go 包的定向 race 通过。Windows 本地实进程 race 完成 140 次刷新、819 次并发状态读取、796 次 TCP 转发。隔离 Linux 回归通过 system、gVisor、mixed 和 mips 四栈。Android arm64/armv7 和 macOS arm64 核心构建通过；Android arm64 ELF 的 LOAD 对齐为 16 KiB，桥接导出仍在。
- Windows Flutter 生命周期与 DNS 定向 27 项通过。独立 Windows 回环长测的 2,420 次更新、10,036 次状态读取、10,005 次 TCP 转发均成功。高点调用栈表明旧脚本未消费异步事件，不能用这组数据判断正常客户端的资源占用。已给脚本补读桥接事件，复测在 `build/core-x/quoted-cidr-drained-abba.log`，随后跑同长度资源对照。

## 2026-11-15 带引号和注释的 CIDR 标题

- #1/#2/#7/#13：常见 CIDR 标题复用既有条目解析。Windows 实际刷新对照，带引号及注释标题 P50 78.83 → 30.64 ms；每版 240 次混合刷新，进程每次分配 30.66 → 6.26 MiB。独立 ABBA 每版 240 次刷新未复现普通 `rules:` 加带引号规则项的墙钟时延回归。两版转发和并发状态都成功，修正脚本后采样协程 7–9 个。源码 Windows 二进制哈希与候选一致；规则与资源定向 race 三轮通过。[分组明细](CORE_PERFORMANCE_BASELINE.md#带引号和注释的-cidr-标题)
- 源码构建的 Windows HTTP 刷新功能回归及 Mihomo 全量通过；隔离 Linux 四栈再通过。Android arm64/armv7、macOS arm64 核心再构建通过。Windows 核心大小保持 60,848,128 B；Android arm64/armv7 核心分别增加 160 B 和 320 B，均未用 APK 大小替代核心大小。
- 补读桥接事件后，Windows 两版各完成 2,420 次混合刷新。P95 103.27 → 45.05 ms，累计分配 30.61 → 6.23 MiB/刷新。两版 TCP 转发与状态读取均无失败，停止负载后协程回到 7，连接追踪归零。最后八次 RSS 中位数 47.04 → 46.80 MiB，未观察到明显驻留差距。[资源和耗时](CORE_PERFORMANCE_BASELINE.md#带引号和注释的-cidr-标题)
- Windows amd64 兼容 Release 及 Inno/ZIP 通过构建和核心哈希核对；Android 两种 ARM 内核的本地 Debug 包通过签名、对齐和 ZIP 内容核对。未安装、未签发正式版。[产物记录](CORE_UPGRADE_GUIDE.md)

## 2026-11-15 重载与规则下载交叠

- #7/#13：Windows 回环复现：整配置换到同缓存路径的新规则提供器，旧请求晚于新请求完成后覆盖缓存。新规则仍在内存中，但再重载时规则数从 10,002 退回 10,001。候选取消旧提供器并等候已进入的缓存写入完成；新提供器的映射按快照发布。控制 API 及桌面桥接的回归均通过，前者旧请求由 204 改为 503，磁盘和路由都保留新规则。
- `tool/verify_core_rule_reload_windows.py` 在修复前失败，普通和 race 内核的两条路径通过；四个 Go 包定向 race 各 3 轮，Linux 隔离四 TUN 栈通过。整配置每版 96 次重载，P95 28.97 → 29.42 ms，三类 TCP/UDP 请求无失败，累计分配同为 17.57 MiB/重载。[重载对照](CORE_PERFORMANCE_BASELINE.md#整配置重载与规则下载交叠)
- Mihomo 和桥接普通 Go 回归通过。Windows amd64、Linux amd64、macOS arm64 与 Android arm64/armv7 核心重新构建；Android arm64 的 ELF LOAD 保持 16 KiB，对外桥接符号仍存在。
- 同一批源码的 Windows 生命周期、控制器、Windows 运行校验及 DNS 覆写 Flutter 定向测试 54 项通过。Windows 兼容安装器、便携包及 Android ARM Debug 验证包已生成并核对哈希。[产物与适用范围](CORE_UPGRADE_GUIDE.md)
- 隔离 WSL 用上游 Snell fixture 镜像 `ghcr.io/icpz/snell-server@sha256:70053f77ffa95b0f6fdbac334d26a1cf827b63157b464e76dc7b87a987345467` 验证 Snell v1、v1 HTTP/TLS obfs、v3 各 3 次 HTTP，以及 v3 的 8 个 UDP 包，全部成功。此项使用 Fluxora 桥接和容器上游，不等于 Go 嵌套 Docker 测试模块已通过；后者依赖和其他镜像仍未齐。记录：`build/core-x/nested-module/snell-interop-fixed-fixture.log`。
- 已下载 Docker Go 客户端，并按原锁定校验值核对。使用与当前核心一致的独立依赖清单编译完整嵌套套件，仍发现 [v1.19.34 原版 Trojan XTLS 测试](https://github.com/MetaCubeX/mihomo/blob/v1.19.34/test/trojan_test.go) 使用当前 `TrojanOption` 不存在的 `Flow`、`FlowShow`。原版和项目测试文件的 SHA-256 一致。完整编译未通过，目录 `build/core-x/nested-module/` 保留编译和下载日志。
- 回环长测增加异步桥接事件消费，并定期记录 Go 内存分类。Windows 与隔离 Linux 45 秒短测分别通过 856/856 和 1,074/1,074 次 TCP 往返、各 2 次重载，另外的 Windows 规则刷新回归完成 12 次连续更新。Windows 两小时和 Linux 半小时正式任务正在运行。[采样口径与记录](CORE_PERFORMANCE_BASELINE.md#当前内核跨平台稳态采样)
- 嵌套模块可独立运行 4 个 Snell 用例和 1 个基础 SOCKS 用例：隔离 WSL 内使用预存镜像和 Podman 私有 Docker API。仅用临时 overlay 缩小预拉取镜像范围，并让 Basic 夹具先应用监听地址与 IP ACL、先绑定回声端口、断言往返超时。Snell 用例及断言未改，覆盖大数据传输、UDP 和读取超时。五项通过；全套仍受旧 Trojan XTLS 与缺少镜像阻塞。日志 `build/core-x/nested-module/snell-fixture-final-suite.log`。
- 当前源码再构建 Windows Go 1.20.14 amd64 兼容核心和 Go 1.25.14 arm64 核心。普通 amd64 和 Go 1.20 构建的控制器鉴权与三批 195 项测速回归均通过；Go 1.20 还通过规则下载重载回归（503，磁盘、内存、再重载均保留 10,002 条）。arm64 仅交叉编译。[基准与构建参考](CORE_PERFORMANCE_BASELINE.md#整配置重载与规则下载交叠)

## 2026-11-16 稳态复跑与独立验收

- 上次 Windows/Linux 进程结束在 1,133.27 / 255.95 秒，未生成 `soak.json`。快照记录到 21,606 / 6,087 次请求尝试、38 / 9 次重载，采样错误为 0。保留中断目录，独立进程自 08:01 启动相同负载，分别写入 `build/core-x/soak-classified-detached-2h/` 和 `soak-linux-detached-30m/`。
- Chrome 157 原生回环代理探针通过 2 个目标。两个代理域名在浏览器中各发生一次本地缓存与 hosts 查找，返回 -105。Chrome 通过 SOCKS5 从核心获得两站内容，核心规则日志匹配各自域名。仅验证指定域名和此模式，Windows/Android TUN、实际出站抓包和 WebRTC 待验。[方法与记录](CORE_PERFORMANCE_BASELINE.md#chrome-157-本机代理)
- 通过 Docker Hub 公共缓存取回 7 个镜像并记录 digest。固定上游 `0455d0d28c4526937380505153e65a843d8612e8` 与当前核心共用镜像、测试断言和临时依赖清单，在离线 WSL 各跑 23 个顶层用例。两边均 17 通过、6 失败。失败名单完全一致，包括新版 Xray 拒绝 Legacy XTLS、新版 Hysteria 拒绝旧配置，以及 VMess Xray 0-RTT、Trojan gRPC、Shadowsocks、Shadowsocks UoT。定向比较未发现新增失败。原始完整模块仍有 Trojan XTLS 编译失败。[证据和范围](CORE_PERFORMANCE_BASELINE.md#外部协议基准对照)
- 断网 Windows Sandbox 通过空目录与基线安装包哈希核对。应用控制策略在启动时拦截该未签名安装程序，尚未执行安装、升级与卸载。原始输出 `build/core-x/windows-sandbox-install/output/result.txt`。[验证包与发布约束](CORE_UPGRADE_GUIDE.md)
- Linux 独立长测跑满 1,800.01 秒，42,708/42,708 次往返及 60/60 次重载成功，359 次采样无错误。进程约占单一逻辑核 5.13%，末次 7 个 goroutine，TCP/UDP 追踪均为 0。起始和末尾五分钟的 RSS 中位约 54.01 → 56.82 MiB，同期 Go 持有内存 18.03 → 20.50 MiB。Windows 独立两小时任务仍运行。[资源分类](CORE_PERFORMANCE_BASELINE.md#当前内核跨平台稳态采样)
- 已取回官方 Shadowsocks Rust 镜像。两版各重跑 Shadowsocks 基础组及 2022 组，均通过。先前基础组 3 个 Rust 子用例因镜像缺失失败，其余 12 个子用例此前已通过。[镜像对照](CORE_PERFORMANCE_BASELINE.md#外部协议基准对照)
- 官方 Hysteria v1.3.5 服务端通过隔离回环 3/3 HTTP、8/8 UDP，域名不匹配的证书被拒绝。单独复现 #17 自定义 CA 生效滞后一轮：只使用本次配置的 CA 时首次建连拒绝，第二次加载同一配置成功，去掉 CA 再加载仍意外通过。实际 Go TLS、服务和负例均使用隔离夹具。当前正在核对配置构建期间的根证书池归属，暂无生产改动。记录 `build/core-x/nested-module/hysteria-v1-trust-revocation.log`。

## 2026-11-16 自定义 CA 与虚拟机验收

- #17 每份配置在构造出站前建立独立根证书池，直接节点与提供器使用同一份信任，配置应用才发布全局引用。Windows TLS CONNECT 测试覆盖初次信任、撤销、内联提供器及配置校验不改变运行状态。回归三轮、Mihomo 全套普通 Go、CA/配置/提供器/出站 race 通过。Linux 实进程与官方 Hysteria v1 复测首次添加 CA 生效，删除 CA 和错误域名拒绝。日志 `build/core-x/trust-scope-{regression,go-full,go-race}.log` 与 `nested-module/hysteria-v1-trust-candidate.log`。
- Windows 每版 96 次热重载，P50/P95/P99 25.34/35.59/211.95 → 24.89/27.42/178.04 ms；分配 17.614 → 17.623 MiB/重载。新 UDP 79/80 → 80/80，其余 TCP 与旧 UDP 全成功。同机另有构建与虚拟机工作，尾延迟仅作兼容观察。原始数据 `build/core-x/trust-scope-reload-abba/results.json`。
- VMware Windows 10 通过两组安装、升级和卸载，实际内核哈希匹配，升级保留夹具文件。旧的卸载流程在静默调用中仍弹出删除用户数据确认。Inno 已改为静默卸载默认保留数据，带分支的安装器已编译，需重新在虚拟机无人值守运行。证据 `build/core-x/windows-sandbox-install/vmware-output/{result,trust-result}.txt` 和 `build/core-x/package-trust-uninstall-windows.log`。
- MuMu Android 12 黑屏复查发现旧的重封装包有 x86_64 Dart JNI 和内核，却缺同架构 Flutter 引擎。Windows 本地 `bindgen` 用正斜杠传递 Android NDK sysroot 与 clang 资源路径后，完整 x86_64 Debug 构建成功。调试签名与 ZIP 对齐通过，包中 x86_64 Go 库和经 NDK strip 的当前候选逐字节一致。普通定向 Debug 包仍混入其他 ABI 的依赖，仅用 `adb install --abi x86_64` 安装作测试。
- MuMu 建立临时 Android 用户，实际显示首页、通过深链接从回环夹具导入配置、启动 VPN。应用内重启后 VPN 网络编号 101 → 102，`tun0` 重新建立。应用内停止后无 VPN 网络、`tun0` 或相应路由。已返回原用户，移除临时用户、回环服务和 ADB reverse。证据 `build/core-x/mumu-x64-{full-startup.log,full-screen.png,vpn-network-active.txt,vpn-network-restarted.txt,vpn-stop.txt}`。执行环境拦截了浏览器测试请求，浏览器 TCP 数据转发、DNS/IPv6/WebRTC 泄漏及真机门禁待验。
- 最终 CA 候选的 Linux 桥接在隔离 WSL 网络命名空间复验 system、gVisor、mixed、mips。每栈 30/30 次 TCP、IPv4 与 IPv6 各 128/128 个 UDP 回包，A/AAAA DNS 接管、原接口恢复和停机后的路由清理均通过。日志 `build/core-x/tun-trust-scope-smoke/`。当前 WSL Flutter 容器与发行版缺 GTK 开发依赖，Linux 桌面 UI 原生构建尚未验证。
- 使用与 CI 同版本的 Flutter 3.47.4 实际构建了完整 universal 与三份单 ABI Debug APK。每份包签名和 ZIP 对齐通过，验证 ABI 集与预期一致，包含 Flutter 引擎、桥接、Dart JNI 和 Code Forge，Go 核心与当轮 NDK strip 后的输入一致。[产物哈希](CORE_UPGRADE_GUIDE.md#2026-11-16-自定义-ca-与安装回归)
- Windows 独立长测完成 7,200.01 秒，135,982/135,987 次请求成功，237 次重载完成。1 次请求重置发生于 1.467 秒重载期间，另 4 次超时原因未定。goroutine 7–10，结束为 7，TCP/UDP 均回到 0。长测使用自定义 CA 修复前的二进制。最终 CA 候选先遇到并行 Android 构建期间的一次 15 秒控制 RPC 超时。构建结束后同负载复跑 900.01 秒，18,720/18,720 次请求、30/30 次重载、179/179 次采样通过。goroutine 7–9，末次 7，TCP/UDP 均为 0。[资源与尾延迟](CORE_PERFORMANCE_BASELINE.md#当前内核跨平台稳态采样)

- 官方 Mihomo v1.19.34 与 Fluxora Core X 独立 CLI ABBA 对照通过。每版 UDP 256,000/256,000 回包，分配 2,708.87 → 1,420.77 B/回包，UDP CPU 工时与吞吐接近。每版 48 次 CIDR 缓存热重载，P95 99.44 → 35.23 ms；持续拒绝 P50 3,219 → 2,348 ms。App 桥接之前的优化结果不混入此表，候选临时恢复独立 CLI 监听入口，生产源码保持原样。[同源版本性能对照](CORE_PERFORMANCE_BASELINE.md#官方-mihomo-v11934-独立核心-ab)

## 2026-11-16 跨平台门禁接续

- MuMu Android 12 在临时用户以调试应用 UID 发起原生 TCP 和 UDP DNS 探针。测试域由私有 DNS 夹具应答，HTTP 代理只接受该测试域，其他目标拒绝。VPN 停止无 tun0 或路由残留，同一配置再起后网络编号 101 → 102。两轮各通过 5/5 次 HTTP 200 正文与 1/1 次 UDP A 应答，原始记录 `build/core-x/mumu-native-vpn-*-restart*.log`、`mumu-native-vpn-restart-network.txt`、`mumu-native-vpn-fixture.log`。测试工具保持请求 stdin 打开直至收到响应。已回到原用户并移除临时用户与两条 ADB reverse。浏览器、移动端 IPv6、WebRTC、受控物理网络切换继续待验。
- 最终 Windows CA 候选 `D1963E5D5BD77A71000CB4880BE0D1E99FCA52B469EFDC9F91D96F6D21E0633F` 完成同配置 7,200.01 秒长测，140,608/140,608 次 TCP 往返、238/238 次重载和 1,426/1,426 次采样成功。末次 7 个 goroutine，TCP/UDP 追踪均为 0。前/末段 Private Bytes 中位数 46.22 → 49.02 MiB，同期 Go 持有量 25.23 → 27.86 MiB。[资源和完整口径](CORE_PERFORMANCE_BASELINE.md#当前内核跨平台稳态采样)
- Android 双栈补测中，MuMu 切换临时用户时 ADB 断开。恢复原实例后确认只剩原用户，没有 ADB reverse。另建的 Android 12 隔离实例能连接 ADB，但系统用户停在 `BOOTING`，MuMu 报 `-30104`，没有安装 APK 或执行探针，测试实例已关闭。四份调试 APK 的 SHA-256 均已重新计算，两个分架构包的文档哈希抄录错误已修正，这两份包已重新通过 `apksigner verify` 和 16 KiB `zipalign` 检查。[产物哈希](CORE_UPGRADE_GUIDE.md#2026-11-16-自定义-ca-与安装回归)
- 同一隔离 MuMu 实例重试后启动成功。从应用界面导入受控 YAML，打开 IPv6。普通应用 UID 经 TUN 分别连接 IPv4、IPv6 本地夹具。初次和停妥后再启两轮，每轮 IPv4 和 IPv6 各 5/5 HTTP 回包，A、AAAA 各 1/1，并核对夹具收到对应 CONNECT 和 DNS 查询。Android VPN 网络编号 101 → 102，两次停止后 `tun0`、IPv4 和 IPv6 路由均清理。过早重按的一次探针返回空响应，没看到第二个网络注册。等到界面回到「服务已就绪」后再启动通过。证据 `build/core-x/android-sdk-qa/mumu-dualstack-*.txt` 和 `fixture.stdout.log`。真机、物理网络变化和浏览器出站泄漏待验。
- Android Emulator Android 12 对 APK 原文件的两次启动均在 Flutter 加载 `kernel_blob.bin` 时报大小无效。校验已安装包与输入 SHA-256 一致。对照包把同一快照改为未压缩条目后，Flutter 进入应用初始化。Gradle 定向保留该条目，三个单 ABI 调试包实际构建、签名、16 KiB 对齐、快照和 Go 核心字节比对均通过。x86_64 的 Gradle 原包在 MuMu 安装后匹配 SHA-256，并实际打开。官方模拟器安装同一 Gradle 包成功，随后主机 QEMU 以 `0xc0000005` 退出，未能检查首屏。原始记录在 `build/core-x/android-sdk-qa/`。每个调试 APK 增 76,184,180 B。构建结束恢复了三个原有 `libclash/android` 输入。
- Linux 容器取得所需 GTK 与 Rust 工具链。首次缺 Keybinder 配置失败，补依赖重试时 Flutter 报构建成功，但原 bundle 只有内核。CMake 缓存保留 `/usr/local`，执行文件、Flutter 资源与许可证被安装到容器内错误目录。补丁在 `project()` 前初始化 bundle 安装前缀，并让内核使用同一前缀。故意禁用 PkgConfig，使全新构建目录首次配置失败。补齐条件后按同一缓存重试，`flutter build linux --release` 生成完整包。明确指定前缀时生成的内核安装目标与其他文件一致。修复包在无外网 Xvfb 容器以 uid 1000 解包并启动，二次打开显示窗口，证实运行的是包内 `FluxoraCore`，并实测首页与空配置页切换。项目打包器生成 amd64 .deb，在隔离 Ubuntu 容器实装、比对已安装核心并卸载通过。没有系统 D-Bus 的环境记录到 Linux 连通性插件的异步错误，托盘和实际 NetworkManager 事件不在此验收范围。[构建与产物](CORE_UPGRADE_GUIDE.md#linux-release-bundle)
- #8 Windows 最终候选通过 12 批各 65 条带延迟和超时的回环测速。624 条正常返回、156 条达到 700 ms 的超时按 ID 和目标 URL 返回，探针端观测到 156 条超时 socket 被关闭。随后一批 65/65 恢复，峰值并发 50，结束时 TCP/UDP 为 0、goroutine 为 7。上游夹具延迟为 15–160 ms，正常派发至回调的 P95 为 179.55 ms，超时 P95 为 743.64 ms，恢复批 P95 为 184.76 ms。无源码改动。记录 `build/core-x/delay-jitter/jitter.json`。
- #18 三架构 Flutter Release AOT 生成并核对 ELF。实际 129 个发布资源中无 `kernel_blob.bin`。Android SDK 36 AAPT2 使用同一资源切换该文件的压缩例外，两份资源测试包同为 25,463,377 B 且 SHA-256 相同。完整 Profile APK 对照停在 `checkProfileAarMetadata`。离线确认 Flutter Profile 引擎及若干 AndroidX 版本无缓存，Windows 两种 TLS 客户端访问官方 Maven 源均在握手时断开，因此未产出 Profile APK。三个暂存内核输入已恢复并逐个核对哈希。记录 `build/core-x/android-sdk-qa/aot-release-asset-compare.json` 和 `aot-profile-dependency-check.log`。
- #15 Windows 独立核心通过真实 HTTP 探针复现同一 `asyncTestDelay` 把进程内超时和明确拒绝都返回 `-1`。候选保留数值，只有 DeadlineExceeded 加 `timedOut: true`。成功仍为正数。Flutter 红灯显示旧探针把中继超时报为 `HOP2_FAILED`，修复后识别为 `HOP2_TIMEOUT`，兼容旧格式，40 项相关测试及定向静态分析通过。Go 桥接普通全量通过，定向覆盖明确拒绝、TLS 证书拒绝、截止时间和成功。Windows race 一轮发生 `0xc0000005`，同一范围随后三轮通过。Race 使用 Windows SDK 导入库和测试专用的桌面 cgo overlay。Windows、Linux、Android x86_64 核心均构建成功。记录 `build/core-x/delay-diagnostics/`。

- #14 Linux 隔离双上联四栈通过。每栈关闭和恢复第一接口各三次，合计 24 次切换。服务端返回的源地址证明两族均走预期接口，出站始终使用 `fixture-uplink`。退出后 TUN、双栈路由和规则清理通过。第一次切至第二接口耗时 1.746–5.795 s，后续 0.831–0.883 s。早期夹具的地址重叠及未等待 IPv6 链路本地地址就绪的日志已保留。真实 Wi-Fi、蜂窝、休眠和递归 DNS 换路另验。[方法与时延](CORE_PERFORMANCE_BASELINE.md#linux-双上联切换)

## 2026-11-16 批量节点测速调度

- #8 原先每批等最慢的节点，剩余并发闲置。应用层改为固定并发内滚动补位，Go 内核不变。120 个节点、峰值 20、混合应答的交替测试中，整组中位数 2,026 → 606 ms，前 30 个结果 397 → 132 ms。等时测试整组 313 → 306 ms。完整 20 轮各 120/120，有效回包和结果回调数一致。32 项定向测试和 Dart 分析通过。真实订阅和移动端待量化。[测量口径及回滚](CORE_PERFORMANCE_BASELINE.md#批量节点测速调度)

## 2026-11-17 Android Release 集成

- #18 在隔离目录以临时 QA 证书完整构建 x86_64 和 arm64-v8a Release APK。x86_64 打开和关闭调试快照规则的包逐字节一致，均为 71,239,180 B。arm64 从当前源码构建核心并采用稳定通道参数，包为 69,053,549 B。两份 APK 签名、16 KiB ZIP 对齐、全部 ELF 加载段、ABI 和 Go 核心字节核对通过。首轮跨盘增量缓存失败已通过隔离构建设置处理。正式签名、armeabi-v7a Release 和 arm64 实机待验。[对照与哈希](CORE_UPGRADE_GUIDE.md#2026-11-17-android-release-apk)
- #6/#10/#17 MuMu Android 12 安装运行同一 APK。从受控本机地址导入配置，先建立 IPv4 VPN，开启 IPv6 后停止再启两轮。双栈阶段网络编号 102 和 103。普通应用 UID 的 TCP IPv4、IPv6 各 10/10，UDP DNS A/AAAA 各 2/2，到达预设夹具。每次停妥均确认界面就绪、`tun0` 和 IPv4/IPv6 路由清理。已移除此次 QA 安装、ADB 转发、临时签名和探针服务，再关闭隔离实例。浏览器泄漏、真实物理网络和真机待验。原始证据 `build/core-x/android-sdk-qa/qa-release-*`。
- Windows 静默卸载候选 SHA-256 与原夹具要求一致。VMware 启动后，`vmrun fileExistsInGuest` 要求来宾登录，后续 Tools 心跳超时。已挂起来宾，原无人值守脚本尚未执行，入口为虚拟机的 `CoreXQA\install-silent.ps1`。

## 2026-11-17 浏览器 TUN 与 WebRTC 防护

- #5/#6/#10/#17 Chromium 156 在 Linux 隔离四栈使用 IPv4、IPv6 系统 DNS 各一轮，八组通过。正向对照绕开 TUN 时 DNS/STUN 夹具有实际接收。经 TUN 后 16/16 HTTP 正文由配置代理转发，测试 A/AAAA 走内核指定解析器，外侧 DNS/STUN 无接收，两族路由与接口清理均通过。
- #17 现有 WebRTC 防护去重会把订阅中的同一拦截规则留在普通 UDP 规则之后。改为将已有保护规则移到前部并保持一份，其他规则的相对顺序保留。用 Flutter 生产配置生成器与同一 Linux Go 内核复验，修复前 IPv4/IPv6 STUN 均走直连，修复后均被拒绝，双栈 HTTP 和 DNS 通过。49 项 Flutter 回归与一项夹具生成通过。浏览器 DoH、组合覆写与物理平台的实际出站待验。[测试口径](CORE_PERFORMANCE_BASELINE.md#chromium-双栈-tun-与-webrtc)
- #12/#17 WARP 的智能分流及自定义规则现在排在已开启的 WebRTC 防护之后。Chromium 复现 WARP 自定义规则将测试 STUN 带到直连，修复后双栈 STUN 被拒绝，HTTP 和 DNS 仍通过。59 项 Flutter 回归与一项夹具生成、定向分析通过，真实 WARP 出口和浏览器 DoH 待验。[组合验证](CORE_PERFORMANCE_BASELINE.md#warp-组合规则)

## 2026-11-17 浏览器 DoH 验证

- #5/#6/#10/#17 隔离 Chromium 经四种 Linux TUN 栈测试 IPv4、IPv6 DoH。严格模式缺少测试 CA 时，两族网页 0/16，DoH 端点均观察到证书拒绝。导入 CA 后 16/16，A 和 AAAA 经配置的代理抵达 DoH 端点。两阶段普通 DNS 均没有测试域查询，停机路由恢复。另做 system 自动模式对照，实际普通 A/AAAA 均由核心接管，外侧解析器无报文。本轮保留原 DNS 源码和策略。[证书、路由及模式对照](CORE_PERFORMANCE_BASELINE.md#chromium-doh-证书与双栈出口)

## 2026-11-17 内核加密 DNS 换网

- #5/#14 修复默认接口变更时仅由 DNS 策略引用的 DoH/DoT 连接池未重置。Linux 隔离四栈各 6 次切换。策略加密 DNS 从当前出口返回 48/96 → 96/96，旧出口和超时各 24 → 0。主 DoH/策略 UDP 两版各 72/72，停机后双栈路由和虚拟接口均恢复。Go 红灯覆盖普通和代理域名策略，修复后通过。Windows DNS、配置普通和三轮定向 race 通过。[基准与复现](CORE_PERFORMANCE_BASELINE.md#双上联切换与策略加密-dns)
- Windows 桥接 Go 全量及 Mihomo 带 `with_gvisor` 的 Go 全量通过。首轮无该标签的 Mihomo 测试因 WireGuard 用例需要 gVisor 失败。
- Windows amd64 和 Android arm64 核心构建通过。Android ELF 为 AArch64，4 个 LOAD 段均 16 KiB 对齐，保留 `invokeAction`、`startTUN`、`stopTun` 导出。当前构建未进入安装包。Windows 和 Android 核心 SHA-256 分别为 `73ACDC771DD25B2A8BAA56A7B141D92DEA6F7AD1F500F174A4DD41284BCCB3BD` 和 `28B6167FE64CFE9C5D717633FC1F712E2DBE3AD9D0A93497DED1E59E23866318`。
- Windows 与 Android 实际网络切换继续待验。

## 2026-11-17 DoT 在途查询

- #5/#14 同一双上联夹具故意让 IPv6 DoT 在默认出口变化时仍等原请求。前后各 24 次切换，在途查询各 24/24 成功。随后查询走正确出口由 0/48 提高到 48/48，24 个切换周期均确认新连接正常复用。其他 DNS 探针各 168/168，路由清理各 4/4。保留 `dot.go` 与 `dot_test.go` 的最小补丁。[指标和复现](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-dot-查询)
- 回归用例在前版失败，修复后 Go DNS 与配置五轮 Windows race、Mihomo 带 `with_gvisor` 的 Go 全量及桥接 Go 全量通过。Windows amd64 和 Android arm64 核心构建通过，Android ELF 四个 LOAD 段 16 KiB 对齐，桥接导出存在。真机换网待验。
- 同一双上联环境的真实 DoQ 上游经四栈验证。在途 IPv6 查询 24/24 经原上游在新路径重试成功，后续 48/48 查询走当前出口，普通双栈查询 48/48，停机清理 4/4。system 栈另外在 6 次换路后各发出 32 条新查询，192/192 成功且每批使用一个 UDP 连接。现行 DoQ 行为覆盖该负载，保留现有代码。[DoQ 对照](CORE_PERFORMANCE_BASELINE.md#双上联-doq)

## 2026-11-17 订阅与 DNS 监听

- #5/#15 隔离运行实际桥接内核和需要 UA 的 provider。空 UA 返回 403、组内为 `COMPATIBLE`；发送与订阅下载相同的默认 UA 后返回 200，组内出现夹具节点。原订阅未联网复测。
- 真实 TCP 端口占用时，两版均能通过独立上游解析。旧版释放端口、应用同一配置后仍拒绝 TCP 连接。现版在原端口恢复实际 DNS 应答，保留已正常运行的 UDP 监听。Windows 相关 Go race 三轮及带 `with_gvisor` 的 Mihomo、桥接模块普通全量通过。Windows amd64 和 Android arm64 核心构建通过。[回滚](CORE_PATCHES.md#core-x-5-订阅中的-dns-监听)
- 应用接上手动测速超时，保留 XHTTP/VLESS 分享参数并校验证书。隔离的 Dart HTTP 测试确认内建检测先上屏 IPv4，随后显示实际返回的 IPv6 及其国家代码。覆盖私有 DNS 优先级与公共 DoH 识别回归。
- 覆写脚本在 Windows 实际 Dart/Rust 桥接验证恢复的开关和图标映射。1,500 节点合成脚本结果的 Dart 解码阶段 P50 2.12 → 1.48 ms，未计入脚本本身和核心应用。[脚本解码对照](CORE_PERFORMANCE_BASELINE.md#脚本结果解码)
- 代理与配置空态共用添加配置入口。桌面 1280 dp 与窄屏 280 dp、1.4 倍字号实际渲染，两个页面均走通导入面板。长标题提供两行和完整提示，HTTP 源空态点击更新会恢复节点计数。Flutter 定向 109 项、已有配置和代理页视觉用例 2 项、全仓 analyze 通过。Rust 脚本单元 30 项通过。
- 真实 Windows/Android 换网、完整应用冷启动、外网节点和正式安装包仍需各自的实际门禁。

## 2026-11-17 DoH 在途换路

- #5/#14 隔离 Linux 四栈各 6 次换路。HTTP/2 在途查询由 0/24 成功到 24/24。HTTP/3 新查询在旧响应放行前完成由 0/24 到 24/24。两个协议修复后 144/144 新查询均命中当前出口，四栈两种协议均通过清理。保留 `dns/doh.go` 和 `dns/doh_test.go`。Windows DNS/config 普通及 race、Go 两模块全量、Windows amd64 和 Android arm64 核心构建通过。[实测与限制](CORE_PERFORMANCE_BASELINE.md#切换时仍在响应的-http2-和-http3-doh-查询)
- 两页无订阅空态去掉重复说明并扩大添加按钮。实际查看桌面浅色及 280 dp、1.4 倍字的深色截图，18 项 Flutter 回归和新文件分析通过。
- 旧接口仍可达的 IPv4 DoH 扩充到 Linux 四栈，HTTP/2 在途成功和 HTTP/3 提前完成各 0/24 → 24/24。gVisor 一次测试先于切路结束，重新运行完整 6 次通过。

## 2026-11-17 旧接口直接失联

- #5/#6/#14 四栈对实际关闭旧接口做前后对照。修复后失联期间 HTTP/2 与 HTTP/3 各 36/36 条新查询命中当前接口。HTTP/3 原版为 31/36，差的 5 条是每轮首个新查询。旧线路上的请求前后均未返回有效结果，旧套接字检查与恢复、退出清理通过。未增加重试或换节点逻辑。[方法与结果](CORE_PERFORMANCE_BASELINE.md#旧接口直接失联时的-doh-查询)
- Windows、Android 真机换网及休眠恢复待验。

## 2026-11-17 Android ARMv7 Release

- #18 隔离生成 68,998,631 B 的 armeabi-v7a Release。发现 Windows Cargokit 批处理吞掉退出码，产出缺少覆写脚本库的半成品。修复后 Dart 负例与 Android Gradle 实际原生编译错误退出 1，完整重建得到 11 个 ARM ELF32 库，通过 QA 签名、ZIP 对齐和核心字节核验。保留 `plugins/code_forge/cargokit/run_build_tool.cmd` 的独立补丁。[构建与哈希](CORE_UPGRADE_GUIDE.md#android-armeabi-v7a-release)
- MuMu 首次临时次用户启动遇到 ML Kit 重复初始化。主用户使用同一 APK 两次安装和启动，实际渲染首屏，验证 ABI 为 armeabi-v7a。已有 arm64 与 x86_64 同环境主用户对照也启动成功。多用户、ARMv7 真机和该构建的 TUN 流量仍待验。保留本轮日志并清理测试实例的安装。下一项独立门禁为 Windows 10 虚拟机静默卸载数据保留复验。

## DNS 覆写与浏览器系统解析

- Windows 10 虚拟机目前不可用，静默卸载门禁继续待验。没有在宿主执行安装器。
- #5/#8 保留订阅明确设置的公共节点解析器，条件为应用节点 DNS 仍用默认值。隔离内核真实测速旧覆写 0/3、修复后 3/3、关闭覆写对照 3/3。Android 过滤 VPN 产生的系统 DNS 记录并原子发布解析器，防止系统解析重新进入自己的 TUN 地址。Flutter 定向 25 项、定向静态分析、桥接 Go 全量、Android arm64 核心构建和 Kotlin 编译通过。[基准与限制](CORE_PERFORMANCE_BASELINE.md#dns-覆写与节点测速)
- #5 补齐 DoH 域名引导换路。Linux 四栈正向探针 472/472 成功，错误域名证书 4/4 拒绝，退出清理 4/4。
- #5 内部 DNS 服务关闭时，TUN 交回系统解析。Linux 四栈 0/4 → 4/4，MuMu A/HTTPS 查询 RCODE 2 → 0。应用内覆写开启测速为 76 ms，同一受控拓扑的原生 HTTP 与 DNS 通过。Windows DNS 定向 Go 与 race 通过，多平台内核构建成功。MuMu Chromium 启动自动审批拒绝，浏览器待验。

## 脚本冷启动和配置选择

- #3/#7 MuMu Android 12 使用两个 APK 和同一份已保存脚本，强停后从磁贴启动。旧版提示 Rust 桥接未初始化并生成原始分组。修复版实际运行脚本、生成脚本分组与规则，VPN 接口建立。日志为 `build/core-x/delay-diagnostics/mumu-cold-script-{before,after}.log`。开机入口复用初始化，重启设备实测待验。
- #7 配置 B 加载时，配置页接受随后对 A、C 的实际点击。C 显示等待，加载记录仅为 A、B、C，最终代理组已刷新。测试渲染默认与排队态，Flutter 定向 29 项与全仓静态分析通过。Windows 实际 Dart/Rust 桥接验证保存选项、图标与大结果解码。Windows 客户端实机快速切换待验。
- #7 大脚本结果解码移出 UI 线程。Windows AOT 10,000 节点解码的 UI 线程作业时间 P50 从 18.54 ms 降到 0.029 ms，等待 worker 结果 15.36 ms。[分段数据](CORE_PERFORMANCE_BASELINE.md#脚本结果解码)

## 18 项阶段状态

| # | 本地已验证与决定 | 未完成条件 |
| --- | --- | --- |
| 1 | 既有 GC 去重、Windows 空闲 A/B、UDP 分配与会话回收。Windows 最终 CA 候选完成两小时长测，RSS 中位 30.92 → 29.49 MiB，私有提交 46.22 → 49.02 MiB，Go 持有量 25.23 → 27.86 MiB，Go 堆 6.17 → 6.19 MiB。Linux 30 分钟 RSS 中位 54.01 → 56.82 MiB。 | 移动端与更长时间的实际网络负载 |
| 2 | Windows 数据路径 CPU profile、测速峰值、DNS 取消后 goroutine 回落。最终候选两小时平均占单逻辑核 4.34%，上一份对照为 3.93%，两轮主机并行任务不同。同量缓存热重载进程工时由 13.66–15.97 s 降到 4.91–7.34 s。 | 移动端低功耗与公网多流压力 |
| 3 | Windows 生命周期、旧配置停止再启动及 Go 1.20 内核烟测。MuMu Android 12 x86_64 启动、应用内核心重启和停止均通过。保留配置发布顺序修复。 | Android 真机重启与后台恢复 |
| 4 | Windows ABBA 证实末次失败快速返回，保留全部拨号尝试。 | 真实节点和公网长尾 |
| 5 | DNS 本地缓存、取消、丢首包、新请求恢复与 TUN 接管通过。MuMu 实测 UDP A 经 TUN 到受控解析器。私有 DoH 误判修复，Windows 回环转发 0/4 → 4/4。Chromium 严格 DoH 四栈八组过；Linux DoH 域名引导换路 472/472，错误证书 4/4 拒绝。覆写测速隔离前后 0/3 → 3/3。 | 真实运营商路径、Android 浏览器系统 DNS 和跨平台泄漏 |
| 6 | 隔离 Linux 四栈通过双栈 TCP、UDP、DNS、路由清理和恢复，并完成短流 TTFB、大流吞吐及 Go 进程 CPU 工时对照。MuMu 完整停止再启动通过，两轮原生 IPv4/IPv6 合计 TCP 20/20、UDP DNS 4/4，两个路由表均验证清理。 | Windows/Android 真机吞吐、耗电、双栈泄漏与物理网络变化 |
| 7 | 千节点、规则集及非法配置后重启通过。保留 TCP 等待与有界 UDP 暂存。两批独立对照中，CIDR 快路径使缓存重载 P95 82.10 → 32.73 ms，收缩节点字段元数据使其 32.20 → 26.79 ms。 | 真实订阅和跨网提供器长重载、平台长时间验收 |
| 8 | 195/195 基础回归；带回环抖动和超时的 845 条均正确返回，156 条超时关闭连接，下一批 65/65 恢复。核心峰值并发 50。应用层滚动补位将混合响应回环组测速中位数从 2,026 降到 606 ms，并发峰值仍为 20。 | 真实高抖动节点和移动端测速 |
| 9 | 继承 SOCKS5 UDP 缓冲池和 Windows TCP/UDP 回收。smux 写入持有自有缓冲区，协议 v1/v2 大流量 race 通过。 | Android 与真实出站及长时高并发 |
| 10 | Windows 双栈竞速及真实 A/AAAA，隔离 Linux NAT64。MuMu 原生 IPv4 与 IPv6 各 10/10 HTTP，A 和 AAAA 各 2/2，正常停止两族路由均清理。 | 运营商 IPv6-only、Windows/Android 真机 VPN 泄漏 |
| 11 | 本地真实单/双/三跳、坏中间跳、延迟和会话清理。 | 真实中转和落地节点 |
| 12 | 本地 WireGuard 密文握手与同一对端换端口后重建。 | Cloudflare WARP 凭据、真实出口和不中断热更新 |
| 13 | 首条、末条、规则集、子规则、未命中各 40 个样本。CIDR YAML 构建开销已下降，保持运行时匹配顺序。Windows HTTP 刷新回归覆盖无头 YAML、并发发布以及整配置重载后旧下载不能覆盖缓存。 | 真实大规则集及跨平台持续更新长尾 |
| 14 | Linux 四栈共 24 次隔离双上联切换，核对双栈源地址和同一出站，关停清理通过。UDP DNS 两种上游地址族换路共 56/56。首次切换长尾主要在接口回调前，两种加快检测的候选均撤回。四栈覆盖 IPv6 DoT/DoQ、双栈 HTTP/2/3 在途及旧接口直接关闭；失联时 HTTP/3 新查询命中当前接口 31/36 → 36/36。 | 受控 Wi-Fi、蜂窝、唤醒及 Windows/Android 用户路径 |
| 15 | 拒绝/超时/TLS 与坏中间跳的可重复诊断。现有测速 RPC 增加可省略的明确超时标记，链路探针通过回归区分超时与一般失败。脱敏导出通过。 | 真实网络误分类率、细分故障种类与诊断开销 |
| 16 | 固定负载 PGO 结果混合，不启用。Windows 旧 Go/arm64 成功构建。 | 代表性公网 PGO 与实机 arm64 |
| 17 | 回环 Bearer 鉴权、导出脱敏、哈希篡改拒绝及隔离 DNS 接管。Windows 入站 race 180 组通过，1 组沿用上游跳过条件。23 项协议镜像对照与上游通过和失败名单一致。Chromium 隔离 Linux 四栈双栈 DNS/STUN 及 DoH 均通过。修复 WebRTC 拦截规则去重和 WARP 组合优先级，浏览器前后对照通过。 | Docker 全套、正式签名、Windows/Android 真机泄漏 |
| 18 | Windows Inno/ZIP、Android universal 与三份分架构 Debug APK 的 ABI、签名、对齐及核心核验通过。x86_64 Release APK 的调试快照规则零体积增量，MuMu 实装与双栈 VPN 通过。arm64-v8a、armeabi-v7a Release APK 通过 QA 签名、ABI、ZIP 对齐及核心比对。Windows Cargokit 的原生依赖编译错误可阻断出包。Linux x86_64 Release 重试、bundle 启动及 .deb、RPM 安装与卸载通过。macOS 核心已交叉编译。Win10 VMware 已通过两组安装、升级及卸载。 | Windows 静默卸载保留数据复验、发布签名、macOS 实机与 Android 真机 |

### 复现与原始记录

- Windows 二进制采用 Go 1.25.14、`GOAMD64=v1`、`CGO_ENABLED=0`、`-pgo=off`、`-trimpath`、`-w -s`、`-tags=with_gvisor`，版本注入 v1.19.34。
- Stage 2-B 与 Stage 4 用 `tool/benchmark_core_faults_windows.py <core.exe> <cert.pem> <key.pem> <output>`。证书是本地自签 fixture，客户端分别使用信任和不信任的上下文，未关闭 TLS 校验。阶段样本在 `faults-*/faults.json`、`dualstack.txt`、`faults-final/`。
- Linux 使用 `bash tool/verify_core_tun_linux.sh <linux-core> <python> <stack>` 和 `bash tool/verify_core_nat64_linux.sh <linux-core> <tayga> <python>`，各自启动独立的 user/network namespace。主机网络保持原样。TAYGA fixture 用 Debian 0.9.2-8，未纳入依赖。[Debian 包](https://packages.debian.org/bookworm/tayga)
- Stage 5 至 9 用 `tool/benchmark_core_chain_windows.py`、`benchmark_core_rules_windows.py`、`benchmark_core_build_windows.py`、`verify_core_controller_windows.py`。输入为候选内核，PGO 对照额外传入同源优化版本。`chain.json`、`rules.json`、`controller.json`、`pgo.json`、`endpoints.txt` 与两个内核 Go 测试位于工作区。
- Windows 普通 Inno/ZIP 与哈希锚点核对已跑。Android Debug 需要 `LIBCLANG_PATH` 与 NDK 的 `BINDGEN_EXTRA_CLANG_ARGS=--sysroot=<sysroot> -resource-dir <clang-resource>`，在 Windows 下传入 bindgen 的 NDK 路径使用正斜杠。未覆盖正式签名；本地打包输出只作验证。

### 下次验收入口

- Windows 普通标题独立 ABBA、两版各 2,420 次混合刷新、整配置重载与规则下载交叠回归，以及 Snell 定向协议验证均已跑完。Windows 两小时与 Linux 半小时稳态结果已归档。完整嵌套套件继续受上游旧测试字段及镜像可用性限制。
- 真机门禁需要独立的 Windows 和 Android 网络环境及 macOS 启动环境。分别记录 TUN、网络切换、休眠唤醒、真实 WARP 和浏览器泄漏结果。正式签名与安装升级继续走发布流程。

## 2026-11-19 配置切换、选择器与脚本反馈

- 上轮 1.1.4-rc.1 预览位于独立预览分支，提交为 `df6a2312`，Android 与 Windows Actions 均成功。核对时远端 dev 仍为 `8ffe6e6b`。本轮应用修复在 `D:/MyASUS/Documents/ChatGPT/box/_wt_preview114rc1` 的本地分支 `fix/profile-switch-and-node-pickers`，尚未提交或推送。原工作区的内核和热点改动继续保留。
- 前置、后置与 WARP 复用链式选择器。测速入口保持可见，非当前配置显示禁用状态；当前配置的实测数值进入共享延迟状态。保留非当前配置的独立节点来源。WARP 修改前源码及回滚命令位于 `../local-backups/warp-before-picker-20261119`。
- 桌面配置切换改为现有热重载路径。切换通知从根 Zone 入队，排队标记保持到应用完成。成功应用过且仍在运行的相同端口设置可复用，冷启动仍执行端口冲突检查。Windows、Android、Linux、macOS 的定向测试均经过真实控制器调用和模拟核心验证，原失败回滚、快速再次选择及迟到响应继续覆盖。Windows helper 的运行识别复用已有桥接状态。
- 脚本选项按需识别，兼容无标记声明及长文件头，非当前脚本也可编辑。规则面板传递脚本图标，SVG data URI 与带查询参数的 SVG 地址可正确分类。主规则按脚本元数据展示，其他规则默认折叠并使用圆角规则图标。原生执行验证选项保存、重新读取及实际传入脚本，不切换当前脚本。
- 应用 `flutter analyze --no-pub` 无问题，定向 Flutter 188 项通过，包含真实 Windows TCP 生命周期和深浅色原生脚本选项交互。Rust 脚本 30 项通过。界面实际查看了窄屏、深浅色、折叠与展开、图标、测速与不可测配置状态。
- **#1/#7，NO_PATCH**。快照复制候选仅降低分配，真实 RPC 的耗时与 CPU 收益不稳定，已恢复生产文件。保留新基准与回归用例，详情见性能基线和补丁记录。Go 桥接全量、adapter/outboundgroup/tunnel 定向测试和恢复后的 adapter race 通过。
- 后续门禁为这批应用改动的 Windows/Android 新构建及真实配置切换。当前没有执行新的安装包构建或真机替换。内核继续优先分析真实 RPC 与配置解析的 CPU profile，避免再次实施本轮已撤回候选。

## 2026-11-19 分支同步与内核预览

- 用户授权提交和推送。此前应用预览 `df6a2312` 及本轮应用修复 `a3b6e13b` 已快进到远端 `dev`，本地原始 Dirty Workspace 未更新或覆盖。
- 原预览分支通过 GitHub 正式改名为 `preview/1.1.4-rc.1`。内核集成仅在独立工作区 `_wt_core_preview114rc1` 的该分支进行，不进入 `dev`。
- 从原工作区按文件与补丁边界提取已保留的 Core X 和必要集成，不包含热点共享、新通知卡片 IPC、系统提权改造或已撤回的节点历史快照候选。完整范围及回滚见 [预览说明](PREVIEW_1_1_4_RC1.md)。
- 集成本地验证：Go 桥接、Mihomo 定向测试、DNS/resource/规则提供器/tunnel race、smux 写入回归、75 项 Flutter 集成测试通过，分析无问题。版本名保持 1.1.4-rc.1，构建号 2026111901。
- 新 GitHub Android/Windows 整包与安装后验收仍为本次后续门禁，不复用旧包的成功状态。

