# Code signing and release policy

This describes the current `.github/workflows/build.yaml` implementation, not repository protection settings or public certificate trust.

| Trigger | Build | Signing | GitHub Release |
| --- | --- | --- | --- |
| vX.Y.Z tag | All configured platforms | Required for Windows and Android | Stable |
| vX.Y.Z-rc.N tag | All configured platforms | Required for Windows and Android | Pre-release |
| Manual, release_validation=true | Selected platform(s) | Release signing validation | None |
| Manual, release_validation=false | Selected platform(s) | Windows signing disabled; Android still requires release keystore | None |
| main / dev push | Analysis and tests in test.yaml | None | None |

## Windows

GitHub Actions restores a temporary PFX from repository secrets and uses Windows SDK SignTool with SHA-256 and a timestamp server. Core, Helper, the app, Loopback Manager and installer are signed. Missing configuration or a signing command failure stops the build; temporary PFX cleanup runs in an always() step.

The workflow describes the certificate as **self-signed**. Verification requires embedded signer information, not a chain trusted by Windows. This does not promise SmartScreen reputation, a public CA certificate or warning-free installation. There is currently no SignPath submission step.

Core / Helper / runtime asset hashes are measured after signing and verified against the packaged bundle. Integrity checks do not replace operating-system certificate trust.

## Android

A release keystore is required. apksigner verification must succeed and the Android Debug certificate is rejected. Upgrading an existing installation requires the same application ID and signing key.

## macOS and Linux

DMG and Linux packages are built by the workflow. Their presence does not establish Apple notarization or operating-system endorsement. Check the individual release and build logs.

## Publishing

Commit and push the complete candidate first. Check analysis, tests, required platform builds and signing for that candidate; document accepted RC limitations explicitly. Push only the intended tag after the gate is met. Tag builds publish only after all matrix builds succeed.

Official Windows / Android releases must not bypass signing or substitute unsigned validation artifacts. Never relabel binaries from an older commit. Do not publish credentials, PFX files, keystores or user configurations.
