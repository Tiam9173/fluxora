# 1.1.4-rc.1 预览范围（2026-11-19）

## 分支边界

- `dev` 与应用基线提交 `a3b6e13b` 包含之前预览的应用改动，以及本轮配置热重载、选择器测速、WARP 选择器统一和脚本规则选项修复。
- `preview/1.1.4-rc.1` 在同一应用基线上另加 Core X 补丁。原预览分支已通过 GitHub 改名接口改名，历史提交未改写。
- 内核上游基线保持 Mihomo v1.19.34。此包没有热点透明共享、自动备用节点切换或新增故障转移机制；没有加入已撤回的 DNS 键、PGO、运行时指标和节点历史快照候选。
- `readme/CORE_*` 记录此前本地工程历史和未验证边界，不表示其中所有环境和安装包都已由本次 GitHub 构建重新验证。

## 本次内核增量

- 配置解析和 CIDR 规则提供器减小分配；保留错误配置后的已生效配置。
- TCP/UDP 热重载窗口、UDP 回包缓冲池复用、明确连接拒绝后的无效末次等待移除。
- DNS 单独变更重载、监听器恢复、系统 DNS 快照和换网时加密 DNS 连接池重置。
- 规则提供器原子发布、旧规则下载取消、配置级 CA 信任隔离及现有协议的并发修复。
- 桥接减少重复强制 GC、避免测速结果永久缓存；Flutter 保留受限测速调度并识别真实超时字段。
- 必要的 Android DNS 适配、控制器回环绑定与鉴权测试、第三方补丁源码及许可证一起交付。
- 通知卡片仍使用此前预览的传输方式，本次不混入新的通知卡片 IPC 改造。

## 本地验证

- `flutter analyze --no-pub`：无问题。
- 75 项 Flutter 集成回归通过，覆盖四平台配置切换模拟、Windows 真实 TCP 生命周期、DNS 合并、测速调度、选择器及链路超时分类。
- Go 桥接 `go test -mod=readonly -tags=with_gvisor ./...` 通过。
- Mihomo adapter、structure、CA、resolver、resource、config、DNS、controller、rules、tunnel 及相关 transport 包测试通过。
- Windows race：DNS、resource、规则提供器、tunnel 通过；smux 写入缓冲区归属回归通过。无独立测试的 transport 包没有被算作协议 race 已验证。
- 应用基线此前另有 188 项 Flutter、30 项 Rust 脚本测试通过，以及深浅色界面检查。

GitHub Android/Windows 新整包构建及安装后的真实网络验收，必须分别记录，不能由上述本地测试推定通过。

## 回滚

- 应用基线为 `a3b6e13b`，不依赖此次内核提交。
- 撤销预览分支中的独立 Core X 集成提交并重新构建，即可回到该应用基线；同时恢复其 Go replace、第三方源码和 Android/Dart 配套，勿只替换单个 so/exe。
- 原始未提交工作区未覆盖。WARP 原界面本地备份仍在 `../local-backups/warp-before-picker-20261119`。
