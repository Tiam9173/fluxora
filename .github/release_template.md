# bettbox+ vVERSION 正式发布

### 🛡️ 核心新增特性：机场节点套 WARP (WARP on Proxy) 与防送中增强
借鉴 Hiddify 官方模式与实践，在 bettbox+ 中增加**为机场节点套 WARP (WARP on Proxy / 链式 WARP 出口)**功能与高科技感可视化检测面板：
1. **彻底解决 Google 送中与防人机验证**：将机场节点作为前置跳板，在出口处套上 Cloudflare WireGuard 隧道，隐藏机场真实落地 IP，获得纯净 Cloudflare Anycast 出口，彻底规避 Google 频繁弹出 Captcha 人机验证与强制重定向至香港/大陆域名。
2. **解锁受限平台**：轻松解锁被机场机房 IP 拦截的 OpenAI/ChatGPT、Claude、Gemini、流媒体等服务。
3. **智能分流工作模式**：
   - 🛡️ **智能防送中与 AI 解锁 (推荐)**：Google 与 AI 平台智能走 WARP 出口，其余日常流量保持原机场原生极速；
   - 🌐 **全局接管模式**：所有国外代理出站流量全量经过 WARP 二次封装；
   - ⚙️ **自定义分流模式**：随心配置规则分流。
4. **真实有效性检测与可视化卡片**：直连 Cloudflare `cdn-cgi/trace` 诊断，精准检测 `warp=on`/`warp=plus` 状态、真实出口 IP、边缘机房代码（HKG、NRT、SJC...）、Google 防送中评定与端到端延迟。
5. **纯 Dart X25519 密钥引擎与官方账号注册**：内置 RFC 7748 Curve25519 算法，离线秒级生成合法密钥对；支持一键向 Cloudflare 官方注册独立免费设备并提取 Client ID (reserved 3字节)；支持绑定个人 WARP+ 24 位 License Key。

---

<div align="left">

### ✈️ Telegram 社区交流

[![Telegram Group](https://img.shields.io/badge/bettbox+-Group-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/+xtB80V6DWhZmZDVl)
[![Telegram Channel](https://img.shields.io/badge/bettbox+-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/bettboxplus)

---
</div>

### ⬇️ Download / 下载链接

**Note: Android coexistence build can be installed side-by-side with original Bettbox.**
<br>**注意：Android 共存版可与原版 Bettbox 并存安装，桌面显示名称为 bettbox+**

**常用设备平台：android-arm64-v8a, windows-amd64**

---

<div align="left">

| **OS / 系统** | **Requirements / 版本要求** | **Direct Links / 点击直链下载** |
|:---:|:---|:---|
| <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/android/android-original.svg" alt="Android" width="28"/> | Android 8.0+<br>*(桌面显示为 bettbox+，共存版)* |<a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/bettbox+-VERSION-android-arm64-v8a-coexistence.apk"><img src="https://img.shields.io/badge/APK-ARMv8%20(共存版)-32AF6A?logo=android&logoColor=white&style=flat-square&labelColor=222222"></a> <a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/Bettbox-VERSION-android-x86_64.apk"><img src="https://img.shields.io/badge/APK-x64-32AF6A?logo=android&logoColor=white&style=flat-square&labelColor=222222"></a><br><a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/Bettbox-VERSION-android-armeabi-v7a.apk"><img src="https://img.shields.io/badge/APK-ARMv7-32AF6A?logo=android&logoColor=white&style=flat-square&labelColor=222222"></a> <a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/Bettbox-VERSION-android-universal.apk"><img src="https://img.shields.io/badge/APK-Universal-32AF6A?logo=android&logoColor=white&style=flat-square&labelColor=222222"></a> |
| <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/windows11/windows11-original.svg" alt="Windows" width="28"/> | Windows 10 / 11<br>*(绿色免安装便携版)* | <a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/bettbox+-VERSION-windows-amd64-portable.zip"><img src="https://img.shields.io/badge/Portable-x64%20(便携包)-0078D7?logo=windows&logoColor=white&style=flat-square&labelColor=222222"></a> <a href="https://github.com/Tiam9173/bettboxplus/releases/download/vVERSION/Bettbox-VERSION-windows-amd64-setup.exe"><img src="https://img.shields.io/badge/Setup-x64-0078D7?logo=windows&logoColor=white&style=flat-square&labelColor=222222"></a> |
---
</div>

### 🐛 Feedback / 问题反馈

> **Note / 提示：**
> Detailed and well-structured issues will be prioritized (logs / reproduction steps)<br>
> 书写认真、信息完整（包含必要的复现步骤和日志）的 issues 会被优先处理和对待

**Bug Report / 提交故障**: [Click Here / 点击这里](https://github.com/Tiam9173/bettboxplus/issues/new)  
**Feature Request / 需求建议**: [Click Here / 点击这里](https://github.com/Tiam9173/bettboxplus/issues/new)

---

### 💖 致谢与开源协议 / Acknowledgements

- 鸣谢 [Bettbox](https://github.com/appshubcc/Bettbox)、[FlClash](https://github.com/chen08209/FlClash) 与 [Mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo)。
- 本项目遵循 GPL-3.0 License 开源协议。
