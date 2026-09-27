<div align="center">

<img src="assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 清晰的路由，平静的掌控。**

开源、跨平台的 Mihomo 网络路由客户端。
把配置、连接、规则与流量状态，收进一个克制、清晰、可审计的界面。

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#支持平台)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

**[下载](#下载)** · **[问题反馈](https://github.com/Tiam9173/fluxora/issues)** · **[参与贡献](#参与贡献)** · **[许可证](LICENSE)**

📢 **[官方 Telegram 频道](https://t.me/Fluxora_Chanel)** · 💬 **[官方 Telegram 群组](https://t.me/Fluxora_Grup)**

</div>

---

## 官方社区

- 📢 **[官方 Telegram 频道](https://t.me/Fluxora_Chanel)** —— 获取 Fluxora 更新、版本发布与项目动态
- 💬 **[官方 Telegram 群组](https://t.me/Fluxora_Grup)** —— 加入社区讨论、反馈问题、交流使用体验

## 为什么是 Fluxora

大多数代理客户端把「能连上」当作终点，把规则、日志和连接状态堆在层层子菜单里。Fluxora 反过来做：**先让状态可见，再让操作可达。**

它基于 Mihomo（Clash Meta）内核，用 Flutter 构建，在桌面端和移动端提供同一套信息架构——仪表盘、代理、配置、工具、日志、请求、资源、脚本、连接，九个页面各司其职，不堆砌、不隐藏。

设计上遵循三条原则：**克制**（不做装饰性动效与霓虹光效）、**清晰**（状态永远比操作更显眼）、**可审计**（开源、无内置账号系统、不引入未声明的闭源依赖）。

Fluxora 是一个独立产品，与任何上游项目没有官方关联。它的来源与许可义务在 [NOTICE](NOTICE) 中有完整记录。

## 核心优势

- **现代界面** — Material 3 设计体系，统一的设计令牌（色彩 / 字号 / 间距 / 圆角 / 动效），不是对上游界面的简单改写。
- **多平台一致** — Windows、macOS、Linux、Android 共用同一套 Flutter 代码与信息架构。
- **完整的代理控制** — 规则 / 全局 / 直连三种出站模式，代理组选择、延迟检测、链式代理与前置落地。
- **网络接管** — TUN 虚拟网卡与系统代理，桌面端托盘常驻与全局快捷键。
- **主题系统** — 浅色 / 深色 / 跟随系统、纯黑模式、7 套品牌预设配色，Android 支持 Material You 动态取色。
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
- 链式代理（前置 / 落地中继）

### 配置
- 多配置文件管理（本地文件 / 订阅链接）
- 配置导入与更新、规则资源（rule providers）

### 工具
- 网络检测、内网 IP、媒体解锁检测
- DNS 覆写、Sniffer 覆写、NTP 覆写
- IPv6 开关、内存占用、流量统计
- 日志、请求记录、连接诊断
- JavaScript 脚本（规则与配置处理）

### 个性化
- 浅色 / 深色 / 跟随系统
- 纯黑模式（OLED）
- 7 套品牌预设配色 + 自定义主色
- Android Material You 动态取色
- 桌面端托盘、全局快捷键、开机自启

## 产品界面

![展示.png](https://picui.ogmua.cn/s1/2026/09/27/6ab8c17a5eab1.webp)
 

## 支持平台

| 平台 | 状态 |
|---|---|
| Windows 10 / 11 | 支持 |
| macOS 12+ | 支持 |
| Linux | 支持 |
| Android 8.0+ | 支持 |
| iOS | 暂无官方客户端 |

## 下载

正式版本即将发布。发布后安装包统一放在 **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)**，命名格式为 `Fluxora-<version>-<platform>`。

当前仓库**尚无任何正式 Release**，因此下方没有可直接点击的安装包链接——请在发布后再回到 Releases 页面获取。

## 安装

### Windows
1. 从 Releases 下载 Windows 便携包（`*-windows-amd64-portable.zip`）。
2. 解压到任意目录（无需安装）。
3. 运行 `Fluxora.exe`。

> 安装程序（`.exe` 安装向导）尚在准备中，当前请使用便携包。

### Android
从 Releases 下载对应架构的 APK 后侧载安装，或等待应用商店版本。

### Linux
从 Releases 下载 AppImage / deb / rpm（视发布内容而定）。

### macOS
从 Releases 下载对应架构的 DMG。

> Linux 与 macOS 的正式安装包尚未构建完成，请以 Releases 页面的实际内容为准。

## FAQ

### Fluxora 是什么？
一个基于 Mihomo（Clash Meta）内核、使用 Flutter 构建的开源跨平台网络路由客户端。

### 支持哪些平台？
Windows、macOS、Linux 与 Android。iOS 目前没有官方客户端，也未列入当前计划。

### Fluxora 与上游项目是什么关系？
Fluxora 是**独立产品**，不是任何上游项目的官方发布。它是 Bettbox 项目的独立延续版本，并在其之上完成了品牌、UI、设计体系与 Windows 组件的独立开发。完整来源与许可义务见 [NOTICE](NOTICE)。

### 是否开源？使用什么许可证？
开源，采用 **GPL-3.0**。全文见 [LICENSE](LICENSE)。

### 如何导入配置？
在「配置」页添加订阅链接或导入本地配置文件，选中后即可连接。也支持 `fluxora://install-config` 链接直接导入。

### TUN 和系统代理有什么区别？
系统代理只影响遵循系统代理设置的应用；TUN 通过虚拟网卡在更底层接管流量，覆盖面更广，通常需要管理员权限。桌面端两者可独立开关。

### 为什么某些平台暂时没有安装包？
各平台发行包需要对应的构建环境（Linux 需要 GTK 工具链，macOS 需要 Xcode 签名与公证）。它们会随首次正式发布陆续补齐。

### 会收集我的数据吗？
不会。Fluxora 不提供云端账号服务，也没有内置统计上报。订阅、规则与网络请求完全由你选择的配置决定。

## Roadmap

### 已完成
- Fluxora 独立品牌迁移（名称 / 图标 / 包标识 / URL Scheme）
- Material 3 设计体系与设计令牌（色彩 / 字号 / 间距 / 圆角 / 动效）
- 主题系统：浅色 / 深色 / 纯黑 / 7 套品牌预设 / 动态取色
- Dashboard、代理与节点界面重做
- Windows 回环豁免工具自研实现（`FluxoraLoopbackManager`）
- 发行打包基础（三平台许可材料随包分发）

### 进行中
- Windows 安装程序（Inno Setup）与便携包发布
- Linux / macOS 发行包构建与验证
- README 与产品截图补全

### 计划中
- 正式发布首个版本
- 更多平台的发行渠道
- 应用内自动更新
- 文档与多语言完善
- 社区贡献流程建设

## 开发

**前置要求**：Flutter（含 Dart）、Android SDK/NDK 与 JDK、对应平台的构建工具（Windows 需 Visual Studio Build Tools，macOS 需 Xcode，Linux 需 GTK 开发库）。代理核心与 Helper 为 Go / Rust 组件，需要相应工具链。

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter run            # 或 flutter build windows --release
```

## 参与贡献

欢迎提交 Issue、改进文档、修复问题或贡献代码：

- **Bug 反馈 / 功能建议** → [Issues](https://github.com/Tiam9173/fluxora/issues)
- **代码贡献** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

提交前请确认变更不会引入未声明的闭源依赖，也不会删除 GPL 或第三方许可声明。

## 许可证与项目血缘

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is an independent continuation of the [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
