<div align="center">
<img src="assets/images/fluxora_mark.svg" alt="Fluxora" width="96" height="96">

# Fluxora 流序

开源、跨平台的 Mihomo 网络路由客户端。

[下载](https://github.com/Tiam9173/fluxora/releases) · [问题反馈](https://github.com/Tiam9173/fluxora/issues) · [English](README_en.md) · [GPL-3.0](LICENSE)

[Telegram 频道](https://t.me/Fluxora_Channel) · [Telegram 群组](https://t.me/Fluxora_Group1)
</div>

## 版本与下载

已发布正式版为 [v1.1.1](https://github.com/Tiam9173/fluxora/releases/tag/v1.1.1)。`dev` 分支的 **1.1.2-rc.2 预览版（Pre-release）暂缓发布**，正在处理配置切换、图标与界面反馈；源码中的版本号不代表安装包已经发布。版本说明和下载以 [Releases](https://github.com/Tiam9173/fluxora/releases) 为准。

| 平台 | 安装包 | 架构 |
| --- | --- | --- |
| Android 8.0+ | APK | arm64-v8a / armeabi-v7a / x86_64 / universal |
| Windows 10 / 11 | 安装程序、便携 ZIP | amd64 / amd64-compatible / arm64 |
| macOS | DMG | Apple Silicon / Intel / Intel-compatible |
| Linux | AppImage、DEB、RPM | amd64 / amd64-compatible；arm64 提供 DEB |
| iOS | 暂无官方客户端 | — |

以上格式已在 v1.1.1 发布页提供；不表示每个候选版均已产出全部附件。一般设备选常规包，旧 CPU / 系统再考虑 `compatible` 变体。macOS 常规版目标为 12+，兼容版以具体发布说明为准。

Windows 可运行安装程序，或解压便携 ZIP 后打开 `Fluxora.exe`。Android 下载安装对应架构 APK；macOS 打开 DMG；Linux 使用发行版对应安装包。Windows 当前构建使用自签名证书，仍可能出现系统信任或 SmartScreen 提示，见 [签名说明](SIGNING-POLICY.md)。

## 功能

- **连接与路由**：规则 / 全局 / 直连模式，代理组选择、延迟测试、连接与流量记录；按平台提供系统代理、TUN、托盘和快捷键。
- **配置与节点**：本地文件、订阅链接、多配置切换与订阅聚合，规则资源和 JavaScript 配置处理。
- **链式代理**：前置跳板与落地节点、双跳 / 三跳及显式多前置链路，逐跳选择、拓扑和诊断。候选池与手动操作不等于自动故障切换；当前没有链式 auto Failover。
- **Cloudflare WARP**：账户注册、WARP+ 密钥配置、端点 / MTU / UDP 设置和上游拨号器选择；能否连接取决于节点、网络和 Cloudflare 服务。
- **网络工具**：出口 IPv4/IPv6、网络检测、媒体解锁、可选 IP 风险情报、日志与请求记录。超时表示这次探测失败，不能据此断定节点完全不可用；风险评分也不构成匿名性或安全保证。

## 1.1.2 候选版界面

沿用 Flutter 与现有状态管理，提供 Classic、Hybrid Glass 和轻量材质；支持浅色、深色、跟随系统、自定义主色及 Android 动态取色。桌面侧栏可在 208px 图文导航与 68px 图标导航间切换；移动端使用紧凑浮动导航。首页组件可添加、排序、移除，连接主操作保留。

动画与真实状态绑定，并尊重系统减少动画偏好。密集列表保留实体表面；这些实现不等于已经完成所有设备的性能认证。


### 品牌图标

八种风格各有独立深、浅两版：官方默认、经典、水色、高级版、极速、天空、日落、蓝夜。入口为「设置 → 主题 → 应用图标」；图标配色与页面深浅主题分别设置。

![Fluxora 深浅图标目录](design/brand_icons/preview.png)

Android 实现了打包图标之间的 launcher alias 切换；启动器刷新、通知与磁贴仍需真机验收。桌面端保存应用内标记，系统安装图标随构建更新，暂不支持运行时更换。通知 / 托盘 / Android 快捷磁贴采用专用单色 F。iOS 控制中心、运行时下载任意图标包尚未实现。源文件和生成步骤见 [图标目录](design/brand_icons/README.txt)。

## 使用与隐私

1. 在「配置」中导入自己的订阅或本地配置，选择要使用的配置。
2. 在「代理」中选择节点，再启动连接。Fluxora 不提供订阅或代理服务器。
3. TUN 与系统代理按平台和权限工作；系统代理只影响遵循该设置的应用。

订阅更新、测速、出口 IP / 解锁检测和 WARP 注册会联系相应服务。IP 风险情报默认关闭，启用并查询时会把待查 IP 发给情报提供方。不要把“没有 Fluxora 云端账户”理解为“没有第三方网络请求”。分享配置、日志或诊断前请移除订阅地址、密钥与个人信息。

## 开发与验证

需要 Flutter / Dart 和目标平台工具链；核心与 Helper 的构建还需要 Go / Rust。CI 当前固定 Flutter 3.47.4（部分 ARM runner 使用工作流指定版本），具体流程见 [.github/workflows](.github/workflows)。

```sh
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
```

普通源码运行不等于官方签名安装包，Windows 发行构建还会校验 Core / Helper 的文件锚点。

## 参与贡献

欢迎通过 [Issues](https://github.com/Tiam9173/fluxora/issues) 提交平台、版本、复现步骤及脱敏日志，通过 [Pull Requests](https://github.com/Tiam9173/fluxora/pulls) 贡献改进。请保留 GPL 与第三方许可声明。

其他语言：[日本語](readme/README_ja.md) · [한국어](readme/README_ko.md) · [Русский](readme/README_ru.md) · [فارسی](readme/README_fa.md)。翻译可能滞后，当前版本状态以本页和英文主页为准。

## 许可证与项目血缘


Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is based on development of [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
