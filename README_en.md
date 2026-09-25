# Fluxora

![Fluxora](assets/images/fluxora_mark.svg)

An open-source, cross-platform Mihomo routing client for clear and reliable rule-based traffic management.

Fluxora runs on Android, Windows, macOS, and Linux. It is designed for users who manage multiple profiles, proxy groups, routing rules, and TUN/VPN connections.

## Quick start

1. Download the package for your platform from the [latest release](https://github.com/Tiam9173/fluxora/releases/latest).
2. Import a subscription URL or add a local configuration.
3. Select a profile and connect.

## Features

- Mihomo core and rule-based routing
- Android, Windows, macOS, and Linux support
- Profile, proxy group, connection, and request management
- TUN/VPN, system proxy, tray, and shortcut controls
- Chain proxy, scripts, rule providers, and connection diagnostics
- Open source and auditable, with no built-in account system

## Supported platforms

| Platform | Status |
|---|---|
| Android 8.0+ | Supported |
| Windows 10/11 | Supported |
| macOS 10.15+ | Supported |
| Linux | Supported |
| iOS | No official client currently |

## Download

Visit [GitHub Releases](https://github.com/Tiam9173/fluxora/releases). Release files use the `Fluxora-<version>-<platform>` naming format.

## Privacy and security

Fluxora does not provide a cloud account service. Subscription, configuration, and network behavior depend on the configuration and destinations selected by the user. Review the privacy policies of your subscription provider, rule sources, and proxy services before use.

## Lineage & Licenses

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](NOTICE) and the relevant component license files.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.

## Development

```bash
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
```

Install the required Flutter, Dart, Go, Rust, Android SDK/NDK, and platform toolchains before building desktop or Android targets.

## Contributing

Issues, documentation improvements, bug fixes, and code contributions are welcome. Do not introduce undeclared closed-source dependencies or remove GPL and third-party license notices.

## License

This project is licensed under GPL-3.0. See [LICENSE](LICENSE) for the complete terms.
