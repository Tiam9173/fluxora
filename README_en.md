<div align="center">

<img src="assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora

**Make routing legible. — Clear routes, calm control.**

An open-source, cross-platform Mihomo routing client.
Profiles, connections, rules and traffic state — in one restrained, legible, auditable interface.

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#supported-platforms)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

**[Download](#download)** · **[Issues](https://github.com/Tiam9173/fluxora/issues)** · **[Contributing](#contributing)** · **[License](LICENSE)**

📢 **[Official Telegram Channel](https://t.me/Fluxora_Chanel)** · 💬 **[Official Telegram Group](https://t.me/Fluxora_Grup)**

</div>

---

## Community

- 📢 **[Official Telegram Channel](https://t.me/Fluxora_Chanel)** — Fluxora updates, release announcements and project news
- 💬 **[Official Telegram Group](https://t.me/Fluxora_Grup)** — Community discussion, bug reports and usage help

## Why Fluxora

Most proxy clients treat "it connects" as the finish line, then bury rules, logs and connection state in nested submenus. Fluxora does the opposite: **make the state visible first, then make the actions reachable.**

Built on the Mihomo (Clash Meta) core and written in Flutter, it gives desktop and mobile the same information architecture — nine pages, each with one job: Dashboard, Proxies, Profiles, Tools, Logs, Requests, Resources, Script, Connections. Nothing decorative, nothing hidden.

Three design principles guide it: **restraint** (no ornamental animation or neon glow), **clarity** (state is always more prominent than controls), and **auditability** (open source, no account system, no undeclared closed-source dependencies).

Fluxora is an independent product with no official affiliation to any upstream project. Its origin and licence obligations are recorded in [NOTICE](NOTICE).

## Highlights

- **Modern UI** — a Material 3 design system with unified tokens (colour, type, spacing, radius, motion); not a reskin of an upstream interface.
- **Consistent across platforms** — Windows, macOS, Linux and Android share one Flutter codebase and one information architecture.
- **Full proxy control** — rule / global / direct outbound modes, proxy-group selection, latency testing, chain proxy and pre-landing relays.
- **Network takeover** — TUN virtual adapter and system proxy, plus tray residency and global hotkeys on desktop.
- **Theme system** — light / dark / system, pure-black mode, 7 brand presets, and Material You dynamic colour on Android.
- **Open and auditable** — GPL-3.0, with the core, script engine and dependencies all inspectable. No cloud account.

## Features

### Connection
- System proxy (desktop)
- TUN virtual adapter (stack and route mode options)
- Outbound modes: rule / global / direct
- Connection list with live throughput and per-connection close
- Smart auto-stop: stop the proxy service when joining specified networks

### Nodes
- Proxy groups: select / url-test / fallback / load-balance
- Latency testing and node switching
- Chain proxy (pre-landing relays)

### Profiles
- Multiple profiles (local file / subscription URL)
- Config import and update, rule providers

### Tools
- Network detection, intranet IP, media-unlock checks
- DNS override, Sniffer override, NTP override
- IPv6 switch, memory usage, traffic statistics
- Logs, request records, connection diagnostics
- JavaScript scripting (rule and config processing)

### Personalisation
- Light / dark / follow system
- Pure-black mode (OLED)
- 7 brand presets plus a custom primary colour
- Material You dynamic colour on Android
- Desktop tray, global hotkeys, launch at login

## Screenshots

> UI screenshots and a demo animation are being prepared, and will be added alongside the first stable release.

## Supported platforms

| Platform | Status |
|---|---|
| Windows 10 / 11 | Supported |
| macOS 12+ | Supported |
| Linux | Supported |
| Android 8.0+ | Supported |
| iOS | No official client currently |

## Download

The first stable release is coming soon. Once published, installers will live on **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)**, named `Fluxora-<version>-<platform>`.

This repository has **no releases yet**, so there are no clickable installer links below — please check the Releases page again after the launch.

## Installation

### Windows
1. Download the portable package (`*-windows-amd64-portable.zip`) from Releases.
2. Extract it anywhere (no installation required).
3. Run `Fluxora.exe`.

> An `.exe` installer wizard is still in preparation; use the portable package for now.

### Android
Download the APK for your ABI from Releases and sideload it, or wait for the store build.

### Linux
Download the AppImage / deb / rpm from Releases, depending on what is published.

### macOS
Download the DMG for your architecture from Releases.

> Linux and macOS release packages are not built yet — always refer to the actual contents of the Releases page.

## FAQ

### What is Fluxora?
An open-source, cross-platform network routing client built on the Mihomo (Clash Meta) core and written in Flutter.

### Which platforms are supported?
Windows, macOS, Linux and Android. There is no official iOS client, and none is currently planned.

### How does Fluxora relate to upstream projects?
Fluxora is an **independent product**, not an official release of any upstream project. It is an independent continuation of the Bettbox project, on top of which Fluxora's branding, UI, design system and Windows components were developed independently. See [NOTICE](NOTICE) for the full origin and licence obligations.

### Is it open source? Under what licence?
Yes — **GPL-3.0**. See [LICENSE](LICENSE).

### How do I import a profile?
Add a subscription URL or import a local config file on the Profiles page, select it, then connect. `fluxora://install-config` links are also supported.

### What is the difference between TUN and system proxy?
System proxy only affects applications that honour the system proxy setting. TUN takes over traffic at a lower level through a virtual adapter, covering more applications, and usually requires administrator privileges. Both can be toggled independently on desktop.

### Why are some platforms missing installers?
Each platform's package needs its own build environment (Linux needs the GTK toolchain; macOS needs Xcode signing and notarisation). They will follow with the first stable release.

### Does Fluxora collect my data?
No. There is no cloud account service and no built-in telemetry. Subscriptions, rules and network requests are entirely determined by the configuration you choose.

## Roadmap

### Done
- Independent Fluxora branding (name, icon, package identifiers, URL scheme)
- Material 3 design system and tokens (colour, type, spacing, radius, motion)
- Theme system: light / dark / pure black / 7 presets / dynamic colour
- Dashboard, proxy and node UI redesign
- Self-built Windows loopback exemption tool (`FluxoraLoopbackManager`)
- Release packaging groundwork (licence material shipped with each bundle)

### In progress
- Windows installer (Inno Setup) and portable release
- Linux / macOS package builds and verification
- README and product screenshots

### Planned
- First stable release
- Additional distribution channels
- In-app auto-update
- Documentation and localisation
- Community contribution process

## Development

**Prerequisites**: Flutter (with Dart), Android SDK/NDK and a JDK, plus the build tools for your target platform (Visual Studio Build Tools on Windows, Xcode on macOS, GTK development libraries on Linux). The proxy core and helper are Go / Rust components and need their respective toolchains.

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter run            # or: flutter build windows --release
```

## Contributing

Issues, documentation improvements, bug fixes and code contributions are welcome:

- **Bug reports / feature requests** → [Issues](https://github.com/Tiam9173/fluxora/issues)
- **Code contributions** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

Please make sure your changes do not introduce undeclared closed-source dependencies or remove GPL and third-party licence notices.

## License & Lineage

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is an independent continuation of the [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
