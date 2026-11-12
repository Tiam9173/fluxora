<div align="center">

<img src="assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora

**Make routing legible.**

An open-source, cross-platform Mihomo routing client.
Configuration, connections, rules and traffic state in one calm, legible, auditable interface.

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#supported-platforms)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- Documentation language -->

[![简体中文](https://img.shields.io/badge/简体中文-29D6C7?style=flat-square)](README.md)
[![English](https://img.shields.io/badge/English-当前-4C8DFF?style=flat-square)](README_en.md)

**[Download](#download)** · **[Issues](https://github.com/Tiam9173/fluxora/issues)** · **[Contributing](#contributing)** · **[License](LICENSE)**

📢 **[Telegram Channel](https://t.me/Fluxora_Channel)** · 💬 **[Telegram Group](https://t.me/Fluxora_Group1)**

</div>

---

## Official community

- 📢 **[Telegram Channel](https://t.me/Fluxora_Channel)** — releases, updates and project news
- 💬 **[Telegram Group](https://t.me/Fluxora_Group1)** — discussion, questions and feedback

## Why Fluxora

Most proxy clients treat "it connects" as the finish line, then bury rules, logs and connection state in nested submenus. Fluxora does the opposite: **make the state visible first, then make the action reachable.**

It is built on the Mihomo (Clash Meta) core with Flutter, and offers the same information architecture on desktop and mobile — dashboard, proxies, profiles, tools, logs, requests, resources, scripts and connections, nine pages each with a clear job, nothing piled up and nothing hidden.

Three design rules: **restrained** (no decorative motion or neon glow), **legible** (state always outranks action), **auditable** (open source, no built-in account system, no undeclared closed-source dependencies).

## Highlights

- **Modern interface** — Material 3, with one set of design tokens (colour, type, spacing, radius, motion) rather than a light reskin of the upstream UI.
- **Consistent across platforms** — Windows, macOS, Linux and Android share one Flutter codebase and one information architecture.
- **Full proxy control** — rule / global / direct outbound modes, group selection, latency checks, chain proxy and residential landing.
- **Network takeover** — TUN virtual adapter and system proxy, plus a resident tray and global hotkeys on desktop.
- **Themes and materials** — light / dark / follow system, pure black, four surface materials (classic / frosted glass / liquid glass / reduced) and an Obsidian theme, with system colour picking and custom accents.
- **Open and auditable** — GPL-3.0; the core, the script engine and every dependency are inspectable, with no cloud account system.

## Features

### Connection

- System proxy (desktop)
- TUN virtual adapter, including stack type and routing mode
- Outbound modes: rule / global / direct
- Connection list with live traffic, and connection closing
- Smart auto-stop: stop the proxy service after joining a chosen network

### Nodes

- Proxy groups: select / url-test / fallback / load-balance
- Latency checks and node switching
- A manual switch applies once and is not persisted as a lock; url-test groups return to the measured lowest-latency node

### Chain proxy

- Two-hop relay through an entry hop plus a static residential landing IP, forwarded in entry → landing order
- Chain proxies get their own group card (🔗 chain proxy), managed alongside ordinary groups
- Per-hop node selection and state (entry / landing), with per-hop latency probing and diagnostics
- Route topology preview: see each hop's reachability and latency at a glance
- Enabled per profile, and supports explicit multi-entry chains

### Cloudflare WARP

- A built-in WARP egress with its own "🛡️ WARP egress" group, composable with any proxy group
- One-click Cloudflare account registration, with optional WARP+ license key
- Configurable endpoint / port, clean IPs, MTU, UDP toggle and remote DNS resolution
- Selectable routing mode, plus an optional upstream dialer (default dialer proxy)

> Whether it connects depends on the node, the network and Cloudflare's service state.

### Profiles

- Multiple profiles (local files / subscription links)
- Profile import and update, rule providers
- Subscription aggregation
- JavaScript for rule and config processing

### Tools

- Network checks, LAN IP, media unlock detection
- DNS, Sniffer and NTP overrides
- IPv6 toggle, memory usage, traffic statistics
- Logs, request records, connection diagnostics
- Optional IP risk intelligence (off by default)

### Interface and personalisation

- Dashboard components can be added, reordered and removed; the primary connect action always stays
- The desktop rail switches between a 208px labelled layout and a 68px icon layout; mobile uses a floating navigation
- Light / dark / follow system, pure black (OLED)
- Four surface materials and an Obsidian theme; lens intensity and clarity are adjustable separately
- Three colour sources: brand palette, system colour (Android Material You), custom accent
- Motion is tied to real state and respects the system "reduce motion" preference
- Desktop tray, global hotkeys, launch at login

### Brand icons

Eight styles, each with its own dark and light version: Official, Classic, Aqua, Premium, Speed, Sky, Sunset, Blue Night.
Open **Settings → Theme → App icon**; the icon variant and the page theme are set independently.

![Fluxora icon catalogue](design/brand_icons/preview.png)

## Screenshots

## Supported platforms

| Platform | Status |
|---|---|
| Windows 10 / 11 | Supported |
| macOS 12+ | Supported |
| Linux | Supported |
| Android 8.0+ | Supported |
| iOS | No official client |

## Download

Packages are published on **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)**, named `Fluxora-<version>-<platform>`.

The current stable release is **[v1.1.1](https://github.com/Tiam9173/fluxora/releases/tag/v1.1.1)**. **1.1.2-rc.2 on the `dev` branch is on hold**; the version string in the source tree does not mean a package was published — check Releases for the actual state and downloads.

| Platform | Formats | Architectures |
|---|---|---|
| Windows 10 / 11 | `setup.exe` installer · `portable.zip` | amd64 · amd64-compatible · arm64 |
| macOS 12+ | `.dmg` | arm64 · amd64 · amd64-compatible |
| Linux | `.AppImage` · `.deb` · `.rpm` | amd64 · amd64-compatible (all three formats) · arm64 (deb) |
| Android 8.0+ | `.apk` | arm64-v8a · armeabi-v7a · x86_64 · universal |
| iOS | No official client | — |

> The `-compatible` variants target older CPUs and systems (devices without the newer instruction sets); prefer the regular build on current hardware. The table lists the formats each platform supports — it does not mean every candidate build shipped all of them.

## Installation

### Windows

Download the `setup.exe` installer, or unpack `*-windows-amd64-portable.zip` and run `Fluxora.exe` directly.

### Android

Download the APK for your architecture from Releases and sideload it.

### Linux

Pick the `.AppImage`, `.deb` or `.rpm` that matches your distribution.

### macOS

Download the DMG for your architecture and open it.

## Usage and privacy

1. Import your own subscription or local profile under **Profiles**, then select it.
2. Pick a node under **Proxies**, then connect. Fluxora does not provide subscriptions or proxy servers.
3. TUN and system proxy behave according to platform and permissions; the system proxy only affects apps that honour it.

Subscription updates, latency tests, exit IP / unlock checks and WARP registration contact the relevant services. IP risk intelligence is off by default; when enabled and queried, the IP under investigation is sent to the intelligence provider. **Do not read "no Fluxora cloud account" as "no third-party network requests."** Remove subscription URLs, keys and personal information before sharing profiles, logs or diagnostics.

## FAQ

### What is Fluxora?

An open-source, cross-platform routing client built on the Mihomo (Clash Meta) core with Flutter.

### Which platforms are supported?

Windows, macOS, Linux and Android. There is no official iOS client, and none is planned.

### Is it open source? Under what licence?

Yes — **GPL-3.0**. See [LICENSE](LICENSE).

### How do I import a profile?

Add a subscription link or import a local file under **Profiles**, select it, then connect. `fluxora://install-config` links import directly.

### What is the difference between TUN and the system proxy?

The system proxy only affects apps that honour the system proxy setting. TUN takes over traffic lower down through a virtual adapter, so it covers more, and usually needs administrator rights. On desktop the two toggle independently.

### Why is there no iOS build yet?

iOS needs a separate Network Extension implementation plus developer signing and distribution. It is not on the current roadmap.

### Do you collect my data?

No. Fluxora has no cloud account service and no built-in telemetry. Subscription updates, latency tests, IP and unlock checks do contact third-party services according to your own configuration.

## Development

**Requirements**: Flutter (with Dart), Android SDK/NDK and a JDK, plus the platform toolchains (Visual Studio Build Tools on Windows, Xcode on macOS, GTK development libraries on Linux). The core and helper are Go / Rust components and need their toolchains.

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter run            # or flutter build windows --release
```

## Contributing

Issues, documentation improvements, fixes and code are all welcome:

- **Bug reports / feature requests** → [Issues](https://github.com/Tiam9173/fluxora/issues) (include platform, version, reproduction steps and redacted logs)
- **Code** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

Before submitting, make sure the change introduces no undeclared closed-source dependency and removes no GPL or third-party licence notice.

## License and lineage

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is based on development of [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
