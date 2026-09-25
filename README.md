# Fluxora 流序

![Fluxora](assets/images/fluxora_mark.svg)

开源、跨平台的 Mihomo 网络路由客户端，让配置、连接、规则与流量状态清晰可控。

Fluxora 支持 Android、Windows、macOS 与 Linux，适合需要管理多配置、规则分流、代理节点和 TUN/VPN 连接的用户。

## 快速开始

1. 从 [最新版本](https://github.com/Tiam9173/fluxora/releases/latest) 下载对应平台安装包。
2. 导入订阅链接或添加本地配置。
3. 选择配置并连接。

## 主要能力

- Mihomo 核心与规则分流
- Android、Windows、macOS、Linux 跨平台支持
- 配置、代理组、连接和请求管理
- TUN/VPN、系统代理、托盘和快捷操作
- 链式代理、脚本、规则资源和连接诊断
- 开源、可审计、无内置账号系统

## 支持平台

| 平台 | 状态 |
|---|---|
| Android 8.0+ | 支持 |
| Windows 10/11 | 支持 |
| macOS 10.15+ | 支持 |
| Linux | 支持 |
| iOS | 当前未提供官方客户端 |

## 下载

请访问 [GitHub Releases](https://github.com/Tiam9173/fluxora/releases) 获取安装包。发布文件将使用 `Fluxora-<version>-<platform>` 命名。

## 隐私与安全

Fluxora 不提供云端账户服务。订阅、配置和网络请求由用户选择的配置及其目标服务决定。请在使用前检查订阅来源、规则资源和代理服务的隐私政策。

## Lineage & Licenses

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.

## 开发

```bash
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
```

构建桌面端和 Android 版本前，请安装对应的 Flutter、Dart、Go、Rust、Android SDK/NDK 与平台工具链。

## 参与贡献

欢迎提交 Issue、改进文档、修复问题或贡献代码。提交前请确认变更不会引入未声明的闭源依赖或破坏 GPL 及第三方许可证要求。

## 许可证

本项目使用 GPL-3.0 许可证。完整条款见 [LICENSE](LICENSE)。
