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
  <a href="https://t.me/bettboxplus"><img src="https://img.shields.io/badge/Telegram-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Channel" /></a>
</p>

<p align="center">
  <img src="snapshots/home.png" alt="bettbox+" width="720" />
</p>

---

## 📖 项目简介

**bettbox+** 是一款使用 **Mihomo (Clash Meta)** 内核、基于优秀开源项目 **[Bettbox](https://github.com/appshubcc/Bettbox)** 深度重构的多平台网络代理及规则分流客户端。

秉承“流畅、轻量、开箱即用”的理念，bettbox+ 在继承原版高帧率动画、极低后台功耗与优雅界面的基础上，深度优化网络内核与稳定性，并新增创新的**链式代理（Chain Proxy）**功能，致力于为用户提供省心、纯净、可靠的网络代理体验。

---

### ✈️ 社区交流

👉 **官方 Telegram 频道**: [https://t.me/bettboxplus](https://t.me/bettboxplus)

---

## 🚀 核心特性

* **⚡ 前台高帧，后台低耗**：精雕细琢的 UI 交互与动画过渡，前台支持高刷新率，后台智能休眠、近乎零资源消耗。
* **🛠️ 开箱即用**：全平台稳定的 TUN 虚拟网卡与系统代理支持，无需复杂配置即可畅享全局或规则分流。
* **🔗 链式代理支持**：支持将高速跳板节点与落地节点两跳串联，自动隔离跳板池与防回环，有效保护真实 IP。
* **📊 实时仪表与小组件**：内置精美桌面与首页 Widget 小组件，直观掌握实时网络速率、流量统计与出站模式。
* **💻 专业配置编辑**：内置高性能 code-forge 编辑器，轻松阅读与编辑各类复杂配置文件。
* **🔒 安全纯净透明**：开源、无广告、零隐私收集，专注于提供纯粹的代理工具体验。
* **📱 独立共存设计**：Android 端提供独立包名与 `bettbox+` 桌面标识，可与原版 Bettbox 并存安装，互不冲突。

---

## 🔗 链式代理 (Chain Proxy) 简要说明

bettbox+ 内置便捷的**链式代理**（两跳多跳代理）功能：
- **工作机制**：本地流量通过高速前置跳板（如机场优质专线）中转后，再连接至落地节点（如海外住宅 IP 或自建出口），兼顾速度与纯净度。
- **简易导入**：支持各类主流格式混贴与标准 URI 一键导入，自动过滤无效节点。
- **自动防环**：内核独立生成专属跳板池，杜绝规则递归回环，规则/全局双模式即切即连。

---

## ⬇️ 安装与下载

请前往 **[Releases 最新发布页面](https://github.com/Tiam9173/bettboxplus/releases/latest)** 获取最新安装包：

| 平台 | 推荐安装包 | 说明 |
| :--- | :--- | :--- |
| **Android 8.0+** | [`bettbox+-1.19.2-android-arm64-v8a-coexistence.apk`](https://github.com/Tiam9173/bettboxplus/releases/latest) | 独立共存版，桌面显示为 `bettbox+`，支持 TUN 模式 |
| **Windows 10 / 11** | [`bettbox+-1.19.2-windows-amd64-portable.zip`](https://github.com/Tiam9173/bettboxplus/releases/latest) | 绿色便携包，解压即用，双击 `bettbox+.exe` 启动 |

---

## 💖 致谢 (Special Thanks)

- **[Bettbox](https://github.com/appshubcc/Bettbox)**：本项目直接基于 Bettbox 进行重构与扩展，特此向 Bettbox 团队致以最真挚的感谢！
- **[FlClash](https://github.com/chen08209/FlClash)**：优秀的 Flutter 客户端基础设计与界面灵感。
- **[Mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo)**：功能强大、扩展性极致的开源核心。

---

## 📄 开源协议

本项目遵循 **GPL-3.0 License** 开源协议。
