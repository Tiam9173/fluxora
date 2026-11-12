<div align="center">

<img src="assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 清晰的路由，平静的掌控。**

开源、跨平台的 Mihomo 网络路由客户端。
把配置、连接、规则与流量状态，收进一个克制、清晰、可审计的界面。

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#支持平台)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- 文档语言 / Documentation language -->

[![简体中文](https://img.shields.io/badge/简体中文-当前-29D6C7?style=flat-square)](README.md)
[![English](https://img.shields.io/badge/English-4C8DFF?style=flat-square)](README_en.md)

**[下载](#下载)** · **[问题反馈](https://github.com/Tiam9173/fluxora/issues)** · **[参与贡献](#参与贡献)** · **[许可证](LICENSE)**

📢 **[官方 Telegram 频道](https://t.me/Fluxora_Channel)** · 💬 **[官方 Telegram 群组](https://t.me/Fluxora_Group1)**

</div>

---

## 官方社区

- 📢 **[官方 Telegram 频道](https://t.me/Fluxora_Channel)** —— 获取 Fluxora 更新、版本发布与项目动态
- 💬 **[官方 Telegram 群组](https://t.me/Fluxora_Group1)** —— 加入社区讨论、反馈问题、交流使用体验

## 为什么是 Fluxora

大多数代理客户端把「能连上」当作终点，把规则、日志和连接状态堆在层层子菜单里。Fluxora 反过来做：**先让状态可见，再让操作可达。**

它基于 Mihomo（Clash Meta）内核，用 Flutter 构建，在桌面端和移动端提供同一套信息架构——仪表盘、代理、配置、工具、日志、请求、资源、脚本、连接，九个页面各司其职，不堆砌、不隐藏。

设计上遵循三条原则：**克制**（不做装饰性动效与霓虹光效）、**清晰**（状态永远比操作更显眼）、**可审计**（开源、无内置账号系统、不引入未声明的闭源依赖）。

## 核心优势

- **现代界面** — Material 3 设计体系，统一的设计令牌（色彩 / 字号 / 间距 / 圆角 / 动效），不是对上游界面的简单改写。
- **多平台一致** — Windows、macOS、Linux、Android 共用同一套 Flutter 代码与信息架构。
- **完整的代理控制** — 规则 / 全局 / 直连三种出站模式，代理组选择、延迟检测、链式代理与前置落地。
- **网络接管** — TUN 虚拟网卡与系统代理，桌面端托盘常驻与全局快捷键。
- **主题与材质** — 浅色 / 深色 / 跟随系统、纯黑模式，四种材质（经典 / 磨砂玻璃 / 液态玻璃 / 轻量）与「曜石玻璃」主题，支持系统取色与自定义主色。
- **开源可审计** — GPL-3.0，核心、脚本引擎与依赖全部可查，无云端账号体系。

## 功能

### 连接

- 系统代理（桌面端）
- TUN 虚拟网卡（含栈类型与路由模式选择）
- 出站模式：规则 / 全局 / 直连
- 连接列表与实时流量、连接关闭
- 智能启停：连接指定网络后自动停止代理服务

### 节点

- 代理组：选择 / 自动测速 / 故障转移 / 负载均衡
- 延迟检测与节点切换
- 手动切换只做一次性生效，不写入持久锁定；自动选择组会回到实测最低延迟节点

### 链式代理

- 前置跳板 + 落地静态住宅 IP 双跳中继，流量按「前置 → 落地」顺序转发
- 为链式代理生成独立策略组卡片（🔗 链式代理），与普通代理组并列管理
- 逐跳节点选择与状态（前置 / 落地），支持逐跳延迟探测与诊断
- 路由拓扑预览：直观查看各跳的连通性与延迟分布
- 可按订阅单独启用，并支持显式多前置链路

### Cloudflare WARP

- 内置 WARP 出口，生成独立的「🛡️ WARP 出口」策略组，可与任意代理组组合使用
- 一键注册 Cloudflare 账号，支持绑定 WARP+ license key
- 可自定义端点 / 端口、优选 IP（clean IP）、MTU、UDP 开关与远程 DNS 解析
- 路由模式可选，并支持指定上游拨号器（default dialer proxy）

> 能否连通取决于节点、网络环境与 Cloudflare 服务状态。

### 配置

- 多配置文件管理（本地文件 / 订阅链接）
- 配置导入与更新、规则资源（rule providers）
- 支持多订阅聚合
- JavaScript 脚本处理规则与配置

### 工具

- 网络检测、内网 IP、媒体解锁检测
- DNS 覆写、Sniffer 覆写、NTP 覆写
- IPv6 开关、内存占用、流量统计
- 日志、请求记录、连接诊断
- 可选 IP 风险情报（默认关闭）

### 界面与个性化

- 首页组件可添加、排序、移除，连接主操作始终保留
- 桌面侧栏在 208px 图文导航与 68px 图标导航间切换；移动端使用浮动导航
- 浅色 / 深色 / 跟随系统、纯黑模式（OLED）
- 四种材质与「曜石玻璃」主题；透镜强度、通透度可分别调整
- 三种取色来源：品牌配色、系统取色（Android Material You）、自定义主色
- 动效绑定真实状态，并尊重系统「减少动画」偏好
- 桌面端托盘、全局快捷键、开机自启

### 品牌图标

八种风格，各有独立深、浅两版：官方默认、经典、水色、高级版、极速、天空、日落、蓝夜。
入口为「设置 → 主题 → 应用图标」；图标配色与页面深浅主题分别设置。

![Fluxora 深浅图标目录](design/brand_icons/preview.png)

- **Android**：在打包图标之间切换 launcher alias；启动器刷新、通知与磁贴仍需真机验收。
- **桌面端**：保存应用内标记，系统安装图标随构建更新，暂不支持运行时更换。
- **通知 / 托盘 / 快捷磁贴**：使用专用单色标记。

## 产品界面

## 支持平台

| 平台 | 状态 |
|---|---|
| Windows 10 / 11 | 支持 |
| macOS 12+ | 支持 |
| Linux | 支持 |
| Android 8.0+ | 支持 |
| iOS | 暂无官方客户端 |

## 下载

安装包统一发布在 **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)**，命名格式为 `Fluxora-<version>-<platform>`。

当前正式版为 **[v1.1.1](https://github.com/Tiam9173/fluxora/releases/tag/v1.1.1)**。`dev` 分支上的 **1.1.2-rc.2 预览版暂缓发布**，源码中的版本号不代表安装包已经发布——版本状态与下载内容以 Releases 页面为准。

| 平台 | 提供格式 | 架构 |
|---|---|---|
| Windows 10 / 11 | `setup.exe` 安装程序 · `portable.zip` 便携版 | amd64 · amd64-compatible · arm64 |
| macOS 12+ | `.dmg` | arm64 · amd64 · amd64-compatible |
| Linux | `.AppImage` · `.deb` · `.rpm` | amd64 · amd64-compatible（三种格式）· arm64（deb） |
| Android 8.0+ | `.apk` | arm64-v8a · armeabi-v7a · x86_64 · universal |
| iOS | 暂无官方客户端 | — |

> `-compatible` 变体面向较旧的 CPU 与系统环境（如缺少新指令集的老设备），一般设备优先选择常规版本。上表是各平台已支持的格式，不代表每个候选版都产出了全部附件。

## 安装

### Windows

下载 `setup.exe` 安装程序，或解压 `*-windows-amd64-portable.zip` 后直接运行 `Fluxora.exe`。

### Android

从 Releases 下载对应架构的 APK 后侧载安装。

### Linux

按发行版选择 `.AppImage` / `.deb` / `.rpm`。

### macOS

下载对应架构的 DMG 打开安装。

## 使用与隐私

1. 在「配置」中导入自己的订阅或本地配置，选择要使用的配置。
2. 在「代理」中选择节点，再启动连接。Fluxora 不提供订阅或代理服务器。
3. TUN 与系统代理按平台和权限工作；系统代理只影响遵循该设置的应用。

订阅更新、测速、出口 IP / 解锁检测和 WARP 注册会联系相应服务。IP 风险情报默认关闭，启用并查询时会把待查 IP 发给情报提供方。**不要把「没有 Fluxora 云端账户」理解为「没有第三方网络请求」。** 分享配置、日志或诊断前请移除订阅地址、密钥与个人信息。

## FAQ

### Fluxora 是什么？

一个基于 Mihomo（Clash Meta）内核、使用 Flutter 构建的开源跨平台网络路由客户端。

### 支持哪些平台？

Windows、macOS、Linux 与 Android。iOS 目前没有官方客户端，也未列入当前计划。

### 是否开源？使用什么许可证？

开源，采用 **GPL-3.0**。全文见 [LICENSE](LICENSE)。

### 如何导入配置？

在「配置」页添加订阅链接或导入本地配置文件，选中后即可连接。也支持 `fluxora://install-config` 链接直接导入。

### TUN 和系统代理有什么区别？

系统代理只影响遵循系统代理设置的应用；TUN 通过虚拟网卡在更底层接管流量，覆盖面更广，通常需要管理员权限。桌面端两者可独立开关。

### 为什么暂时没有 iOS 版？

iOS 需要独立的 Network Extension 实现与开发者签名分发，尚未列入当前计划。

### 会收集我的数据吗？

不会。Fluxora 不提供云端账号服务，也没有内置统计上报。但订阅更新、测速、IP 与解锁检测等功能会按你的配置联系对应第三方服务。

## 开发

**前置要求**：Flutter（含 Dart）、Android SDK/NDK 与 JDK、对应平台的构建工具（Windows 需 Visual Studio Build Tools，macOS 需 Xcode，Linux 需 GTK 开发库）。代理核心与 Helper 为 Go / Rust 组件，需要相应工具链。

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter run            # 或 flutter build windows --release
```

## 参与贡献

欢迎提交 Issue、改进文档、修复问题或贡献代码：

- **Bug 反馈 / 功能建议** → [Issues](https://github.com/Tiam9173/fluxora/issues)（请附平台、版本、复现步骤及脱敏日志）
- **代码贡献** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

提交前请确认变更不会引入未声明的闭源依赖，也不会删除 GPL 或第三方许可声明。

## 许可证与项目血缘

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is based on development of [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
