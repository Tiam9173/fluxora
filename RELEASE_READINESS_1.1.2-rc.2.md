# 1.1.2-rc.2 预览版发布核验

核验日期：2026-11-06。候选基于 dev 的 `403ae0d0`，纳入此前授权的图标、导航、材质、动效、IP 情报展示与反馈修复。用户授权发布前先提交推送，只推送 dev 分支；本版本为 Pre-release。

## 提交时检查

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| 版本 | PASS | `1.1.2-rc.2+2026110602` |
| flutter analyze --no-pub | PASS | 0 issues，日志在本机 build/release_rc2/analyze.log |
| 本机 Windows 全量测试 | FAIL | 2335 通过、6 跳过、12 失败；build/release_rc2/flutter-test.log |
| 基线失败比较 | PARTIAL | 既有 4 个 UDS / Helper 测试文件的同一失败集合；前轮已在任务前快照复现，本轮未重跑该快照 |
| Dart 格式 / git diff --check | PASS | 103 个改动 Dart 文件格式无待整理项，差异空白检查通过 |
| 图标资源 | PASS | 16 个不同导出、母版对应、安全边距、ICO 尺寸、单色 alpha、Android alias 和 SHA-256 校验 |
| 界面检查 | PARTIAL | 隔离 Flutter 组件截图与交互；不是实网或原生安装包验收 |
| 本候选提交远端 CI | PENDING | 提交推送后验证，旧 HEAD 的绿色 CI 不认证本候选 |
| 本候选平台构建与签名 | PENDING | 使用 release_validation=true 的手动工作流，不生成 Release |
| 实网 / 真机 / GPU Profile | NOT_EXECUTED | 未启动真实 Core、SCM、Helper、TUN、DNS、系统代理或 VM |
| 工作区保护 | PRESERVED | 发布任务前为 459 个 Dirty 文件保存 SHA-256；未 reset / clean / stash |

## 发布门禁

1. 提交源码、测试、平台资源、文档与图标再生成母版，推送 origin/dev。应用使用的 PNG 是资源；测试截图、PNG 帧、日志、压缩包和临时审计产物留在本地。
2. 候选提交的 test 工作流必须成功。Windows 的既有失败明确列入预览版限制，不删测试或无条件 skip 绕过。
3. 候选提交的全部配置平台构建与要求的签名检查必须成功。手动验证不发布。
4. 门禁满足后才推送 v1.1.2-rc.2。Tag 工作流全部矩阵构建成功后发布 Pre-release，正文读取本版本发布说明。
5. 任何门禁未满足，不创建发布 tag / Release。查看 [Actions](https://github.com/Tiam9173/fluxora/actions) 和最终执行报告确认实际状态。

以上是提交时快照；提交后的远端检查以对应 SHA 的 Actions 记录为准，不将 PENDING 冒称 PASS。

## 文档与风险

中英文主页纠正了“没有正式版 / Windows 无安装程序 / Linux 与 macOS 未出包”的旧描述，移除链式自动回退的错误承诺，解释 IP 情报外部请求和动态图标平台边界。保留 GPL、NOTICE 与上游归属。

设备帧率、ROM 刷新、真实连接 / WARP、安装升级与卸载回收仍未验收。测试绿色不等于全设备视觉或生产稳定性认证。

本轮提交前检查为定向审查，不认证整仓：独立重新评审 17 个关键变动文件，其他文件依赖前轮专项交付及本次自动化检查；完整范围和逐项跳过原因留在本机 build/release_rc2/review-coverage.json。

## 初轮远端结果与修正

提交 18d7d602 的 [Linux CI](https://github.com/Tiam9173/fluxora/actions/runs/42239768791) 静态分析成功，测试为 2274 通过、34 跳过、2 失败。两项均为 Linux runner 上模拟 Android 首页时 VpnButton 被错误过滤；SupportPlatform 的 Linux 分支直接读 Platform.isLinux，绕过了其余分支共用的 System 测试入口。现改为 system.isLinux，真实平台默认行为不变；本机相关 43 项组件与交互测试通过。

初轮 [构建验证](https://github.com/Tiam9173/fluxora/actions/runs/42239928625) 中 Android ARMv7、Linux ARM64 已成功。修正提交会重新运行测试和全平台验证，旧轮构建不作为最终候选的发布凭证。
