<p align="center">
  <strong>简体中文</strong> | <a href="README_en.md">English</a>
</p>

<h1 align="center">⚡ bettbox+</h1>
<p align="center">
  <strong>轻量流畅、功能强大的高性能多平台网络代理及规则分流客户端</strong><br>
  <strong>A lightweight, high-performance cross-platform proxy client based on Bettbox</strong>
</p>

<p align="center">
  <a href="https://github.com/Tiam9173/bettboxplus/releases/latest"><img src="https://img.shields.io/github/v/release/Tiam9173/bettboxplus?style=for-the-badge&logo=github&color=238636&label=Release" alt="Latest Release" /></a>
  <a href="https://github.com/MetaCubeX/mihomo/releases/latest"><img src="https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo" alt="Core" /></a>
  <a href="https://t.me/bettboxplus_grup"><img src="https://img.shields.io/badge/Telegram-Group-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Group" /></a>
  <a href="https://t.me/bettboxplus"><img src="https://img.shields.io/badge/Telegram-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Channel" /></a>
</p>

<p align="center">
  <img src="snapshots/home.png" alt="bettbox+" width="720" />
</p>

---

## 📖 项目简介

**bettbox+** 是一款使用 **Mihomo (Clash Meta)** 内核、基于优秀开源项目 **[Bettbox](https://github.com/appshubcc/Bettbox)** 深度重构的多平台网络代理及规则分流客户端。

秉承“流畅、轻量、开箱即用”的理念，bettbox+ 在继承原版高帧率动画、极低后台功耗与优雅界面的基础上，深度优化网络内核与稳定性，并增强了链式代理中继、Cloudflare WARP 节点赋能、空白分组及全协议手动节点录入等实用特性，致力于为广大用户提供省心、纯净、可靠的网络代理体验。

---

### ✈️ 社区交流

👉 **官方 Telegram 群组 (Group)**: [https://t.me/bettboxplus_grup](https://t.me/bettboxplus_grup)  
👉 **官方 Telegram 频道 (Channel)**: [https://t.me/bettboxplus](https://t.me/bettboxplus)

---

## 🚀 核心特性

* **⚡ 前台高帧，后台低耗**：精雕细琢的 UI 交互与动画过渡，前台支持高刷新率，后台智能休眠、近乎零资源消耗。
* **🛠️ 开箱即用**：全平台稳定的 TUN 虚拟网卡与系统代理支持，无需复杂配置即可畅享全局或规则分流。
* **🔗 链式代理与跳板中继**：支持将高速跳板（如优质专线）与落地出口两跳串联，自动隔离跳板池与防回环，兼顾传输速度与隐私保护。
* **🛡️ 机场节点套 WARP**：支持为节点一键级联 Cloudflare WARP 出口，有效解决 Google 送中与人机验证，解锁流媒体及 AI 服务，内置实时可视化有效性检测卡片。
* **📝 空白分组与全协议手动录入**：支持新建空白配置分组，自由录入与管理个人自建节点；全面覆盖 SOCKS、HTTP(S)、Shadowsocks、ShadowsocksR、VMess、VLESS (含 REALITY / Vision / gRPC / WebSocket / HTTPUpgrade)、Trojan、Trojan Go、Hysteria 1/2、TUIC、WireGuard、AmneziaWG 2/3、Snell (v1-v4)、SSH、ShadowTLS、Juicity、Naïve (NaiveProxy)、Direct 及 Custom Config，支持多行批量分享链接与配置片段一键导入。
* **🔀 订阅分组前置与落地中继**：支持为订阅分组灵活配置前置代理（穿透救砖）与落地代理（IP 伪装与解锁），基于内核原生 `dialer-proxy` 机制平滑级联。
* **📊 实时仪表与小组件**：内置精美桌面与首页 Widget 小组件，直观掌握实时网络速率、流量统计与出站模式。
* **💻 专业配置编辑**：内置高性能 code-forge 编辑器，轻松阅读与编辑各类复杂配置文件。
* **🔒 安全纯净透明**：开源、无广告、零隐私收集，专注于提供纯粹的代理工具体验。

---

## ⬇️ 安装与下载

请前往 **[Releases 最新发布页面](https://github.com/Tiam9173/bettboxplus/releases/latest)** 获取最新安装包：

| 系统平台 | 架构 / 类型 | 安装包下载 | 说明 |
| :--- | :--- | :--- | :--- |
| **Android 8.0+** | ARMv8 (arm64-v8a) | [`Bettbox-1.19.2-android-arm64-v8a.apk`](https://github.com/Tiam9173/bettboxplus/releases/download/v1.19.2/Bettbox-1.19.2-android-arm64-v8a.apk) | 推荐现代 64 位 Android 手机/平板 |
| **Android 8.0+** | ARMv7 (armeabi-v7a) | [`Bettbox-1.19.2-android-armeabi-v7a.apk`](https://github.com/Tiam9173/bettboxplus/releases/download/v1.19.2/Bettbox-1.19.2-android-armeabi-v7a.apk) | 适用于老旧 32 位 Android 设备 |
| **Android 8.0+** | x86_64 | [`Bettbox-1.19.2-android-x86_64.apk`](https://github.com/Tiam9173/bettboxplus/releases/download/v1.19.2/Bettbox-1.19.2-android-x86_64.apk) | 适用于 x86 架构 Android 平板或模拟器 |
| **Android 8.0+** | Universal (全架构) | [`Bettbox-1.19.2-android-universal.apk`](https://github.com/Tiam9173/bettboxplus/releases/download/v1.19.2/Bettbox-1.19.2-android-universal.apk) | 包含全部 CPU 架构，通用安装包 |
| **Windows 10 / 11** | x64 便携版 (Portable) | [`bettbox+-1.19.2.2-windows-amd64-portable.zip`](https://github.com/Tiam9173/bettboxplus/releases/latest) | 绿色免安装便携版，解压即用 |
| **Windows 10 / 11** | x64 安装版 (Setup) | [`Bettbox-1.19.2-windows-amd64-setup.exe`](https://github.com/Tiam9173/bettboxplus/releases/download/v1.19.2/Bettbox-1.19.2-windows-amd64-setup.exe) | Windows 经典安装向导版本 |

> 💡 **提示**：更多平台历史版本与完整资源，请直接查看 **[GitHub Releases](https://github.com/Tiam9173/bettboxplus/releases)** 列表下载。

---

## 💖 致谢 (Special Thanks)

- **[Bettbox](https://github.com/appshubcc/Bettbox)**：本项目直接基于 Bettbox 进行重构与扩展，特此向 Bettbox 团队致以最真挚的感谢！
- **[FlClash](https://github.com/chen08209/FlClash)**：优秀的 Flutter 客户端基础设计与界面灵感。
- **[Mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo)**：功能强大、扩展性极致的开源核心。

---

## 📄 开源协议

本项目遵循 **GPL-3.0 License** 开源协议。
