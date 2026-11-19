# Mihomo 同步与回滚

1. 在隔离副本读取 `core/Clash.Meta/VERSION`，核对官方发布记录、旧版标签和目标标签的提交 SHA。
2. 从上游 Git 导出两标签的 `git diff --binary --full-index`。隔离副本先获取上游标签对象，再使用 `git apply --3way --directory=core/Clash.Meta`。逐项确认已有补丁，处理完冲突后更新版本文件。
3. 在 `core` 运行 `go mod tidy`。在桥接模块和 vendored Mihomo 模块分别运行测试，检查正常构建、Go 1.20 兼容构建和 Android arm64 的 C 桥接及 16 KB ELF 对齐。
4. 用临时目录和本机回环地址检查启动、配置校验、配置加载、RPC、版本端点与关闭。真实代理节点、TUN、DNS 和系统路由应在专用测试环境验证。记录二进制哈希和未验证范围。
5. 独立记录上游增量与 Fluxora 增强。发布后需要回滚时，选择此前已签名且已验证的整包，或撤销对应的内核升级提交后重新构建与签名。内核、Android JNI 和桌面桥接随应用整包一起交付。

本轮的代码基线是 `cbd8a6a7`。工作区已有未提交的界面修改，回滚时按内核升级涉及的文件处理。签名与分发按仓库的 [签名政策](../SIGNING-POLICY.md) 执行。

更新核心后重新计算 Windows 核心文件的 SHA-256，以其生成 helper 的 `TOKEN` 和 Flutter 的 `CORE_SHA256`。以最终随包的 core/helper/runtime DLL 生成 `HELPER_ASSET_SHA256`，打包后使用 `setup.dart helper-manifest --verify-dir` 校验。签名构建应在签名完成后计算对应文件的哈希。本地比较须记录真正装进安装包的核心及 ABI，避免混用缓存产物。[连续执行记录](CORE_X_EXECUTION_PROGRESS.md)

| 本地验证产物 | SHA-256 |
| --- | --- |
| `dist/Fluxora-1.1.2-corex-vision-windows-amd64-setup.exe` | `37E10AB17D8C7457E0D10309E074BFC2DB8FDC1D4A7CA07F9BDCD3C9E7ED0C34` |
| `dist/Fluxora-1.1.2-corex-vision-windows-amd64-portable.zip` | `016A1C842F8ED8B57DC930680FD98E2084DBAFFB209FA5A722DE888A8B30F779` |
| `build/core-x/packaging/android-corex-vision-debug.apk` | `9FD7DDB98736A5F8DF71F455BF7AFC716B17F83590B04E7D895F507F8F70F4CB` |

smux 与 AnyTLS 修复后的本地验证包如下。Android 包从同一 Debug APK 重新封装，更新 arm64-v8a 与 armeabi-v7a 两个库，其它 ABI 仍是基线。Windows 安装包未做发布签名。

| 本地路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/Fluxora-1.1.2-corex-racefix-windows-amd64-setup.exe` | 54,658,649 | `AB85EC8F2298EBF384563FE32742D7CAFD2858FDA0E5C5CF5BC6A7C8BADCF9E0` |
| `dist/Fluxora-1.1.2-corex-racefix-windows-amd64-portable.zip` | 67,202,049 | `B4F6C75ABD51C0742911FA2DE35DAF0FCCE8910C5125C9D5B7A3750D3B3F89CC` |
| `build/core-x/packaging/android-corex-racefix-debug.apk` | 173,209,889 | `F05FF0D5A00F82ACEBCC3DF0731D2D13F07A755554B759D2EBEF492A8D70A4A0` |

Restls 与 TCP 重载补丁后的本地验证包如下。Android Debug 包更新 arm64-v8a、armeabi-v7a，并附带 NOTICE。Windows 安装器为本地未签名产物。

| 本地路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/Fluxora-1.1.2-corex-reload-windows-amd64-setup.exe` | 54,663,985 | `1942B3726057444E590D213F106D7D51037DEC34F7C8D1DE6EC78CADD975B282` |
| `dist/Fluxora-1.1.2-corex-reload-windows-amd64-portable.zip` | 67,205,871 | `4C5C428B8805C5A371B9A20A6DF71F4FA76E63E5EE861A99CD4B4881283024EB` |
| `build/core-x/packaging/android-corex-reload-debug.apk` | 173,218,150 | `63A34D3325C9B673A536F4CA18A04C1A0A2C53634F0919357ECD3D34E0DE0E77` |

CIDR 标题快路径对应的本地验证包如下。Windows 为 amd64 兼容预览版，已核对实际包内 helper、运行库和核心的哈希；未执行安装。Android 由上述 Debug 包重封装，除签名外仅替换两个 ARM 核心并逐项核对内容；通过调试签名和 16 KiB 对齐校验。因构建工序不同，不能从这两批包的大小差值推断核心补丁体积。

| 本地路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/Fluxora-1.1.2-corex-cidr-windows-amd64-compatible-setup.exe` | 54,672,390 | `DBF7637C986A17A93BCFFEAA8B5BE38410D5F34381C5A0F249FECB76222B00BD` |
| `dist/Fluxora-1.1.2-corex-cidr-windows-amd64-compatible-portable.zip` | 67,212,256 | `CEBF09A998288314B24A457B0F29E35286057034D015F1FBD7594C459C85BCD9` |
| `build/core-x/packaging/android-corex-cidr-debug.apk` | 173,333,037 | `8F4E041B82EE7D2BFC87543FB828F9C26674CFA8A99B6E16B24F96385B1D1FF3` |

整配置重载保护对应的本地验证包使用 Windows 核心 `windows-retire-provider.exe`（SHA-256 `C989CBB96EF967F374D6C5A676FF8A6C827ACFB643060189F926A72CCCA3B6CD`）。Windows 构建通过包内核心、helper 和运行库一致性检查。Android 从同一个调试基线重封装，校验两套 ARM 库及其余有效内容、16 KiB 对齐和调试签名 v3。其他 ABI 仍为基线。两端未安装或正式签名。

| 本地路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/Fluxora-1.1.2-corex-rules-windows-amd64-compatible-setup.exe` | 54,681,677 | `98F3A2ED2AFA82E1F7A3C29699DE80186819178BE6AAAE94FCC2F479482E218C` |
| `dist/Fluxora-1.1.2-corex-rules-windows-amd64-compatible-portable.zip` | 67,214,319 | `503D64CF26D73130E1863913C9B0B900146ED641820581B2D0638A42DCD95E5C` |
| `build/core-x/packaging/android-corex-rules-debug.apk` | 173,341,229 | `A3CCB789E1F236F88EA27EBDBF80CBE3DF4BC1BDB24885B51F5F8BBA66A04D04` |

断网 Windows Sandbox 中执行安装升级门禁。基线安装包通过 SHA-256 核对。应用控制策略拦截启动，安装器未执行，升级与卸载均保留 BLOCKED。原始结果位于 `build/core-x/windows-sandbox-install/output/result.txt`。


### 2026-11-16 自定义 CA 与安装回归

Windows Sandbox 的策略仍阻止未签名安装器启动。同一验证改在 Win10 VMware 中运行，两组安装、升级及卸载通过，升级后夹具文件保留，运行包内核心哈希匹配。此后加入静默卸载保留数据分支，新安装器已编译，仍待虚拟机无人值守复验。通过验证的旧包与含修复的候选包分别留存，可用各自完整安装包复现。

| 本地路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/Fluxora-1.1.2-corex-trust-uninstall-windows-amd64-compatible-setup.exe` | 54,672,106 | `842AD65BCB83F3C4F9C925357A716F1541D3B2A854BB9BAE7FBD1236474DFA45` |
| `build/core-x/packaging/android-corex-trust-x64-full-debug.apk` | 216,396,190 | `D727A94133706CC0AF9CC2DA01725BD2FE2D2DBCC554F142F17D94F9F1BB16C8` |

本地 x86_64 Debug APK 通过调试签名、16 KiB ZIP 对齐以及包内核心核对。Android 安装使用 `adb install --abi x86_64` 明确指定架构。单独指定 Flutter `--target-platform android-x64` 时，第三方插件仍可能留下其他架构的 .so。这种包仅用于指定架构的调试。发布的 universal 入口选择三个 Flutter 架构，逐架构发布入口用 `--split-per-abi`。已用 Flutter 3.47.4 构建两种入口对应的 Debug 变体，验证每个 ABI 的 Flutter 引擎、原生桥接、Dart JNI、Code Forge，逐一比对经 NDK strip 的候选 Go 核心。三份 split APK 各只有自身 ABI，universal 包同时包含三种。四包均通过 APK 调试签名及 ZIP 对齐，arm64 与 x86_64 Go 核心的 ELF LOAD 段为 16 KiB 对齐。Release 签名与实机仍待验。[MuMu 实测](CORE_X_EXECUTION_PROGRESS.md#2026-11-16-自定义-ca-与虚拟机验收)

| 调试 APK（`build/core-x/packaging/`） | 字节 | SHA-256 |
| --- | ---: | --- |
| `android-corex-trust-universal-debug.apk` | 232,511,212 | `404AB8554E5CDC20811B5C29483BDF0F3587A8F08E99A96C1BB274AC3A7D49DB` |
| `android-corex-trust-arm64-v8a-split-debug.apk` | 131,776,056 | `C81E47200E1BC30722B15BFFAAC8A0B0CFE193F319AF3F15D73C042E13405320` |
| `android-corex-trust-armeabi-v7a-split-debug.apk` | 125,412,136 | `FB23E8C97ECB7106D7A1A50843EB43E4A717E7F02EE89C6A51BA2645C66C25F3` |
| `android-corex-trust-x86_64-split-debug.apk` | 130,111,926 | `F34125F2CC1C69810284F6EE8C1C8BCB2AA2FCAF08787F4337EEF0F360E6F5FF` |

后续修复将 Flutter 的 `kernel_blob.bin` 改为未压缩条目。三份 Gradle 调试产物各增 76,184,180 B，原表保留用于故障对照。新包放在 `build/core-x/android-sdk-qa/`，哈希在同目录 `gradle-stored-artifacts.txt`。包内快照和核心字节一致，三包签名和 16 KiB ZIP 对齐通过。

Flutter `assemble` 以 Release 模式实际生成 armv7、arm64、x86_64 AOT，三份 ELF 架构核对通过。生成的 129 个 Flutter 资源没有 `kernel_blob.bin`。用 Android SDK 36 AAPT2 对同一资源生成两份测试包，只切换 `-0 kernel_blob.bin`，均为 25,463,377 B，整包 SHA-256 相同。此对照覆盖 Flutter 构建与 AAPT2 资源压缩，完整 Gradle APK 对照和正式签名另验。记录 `build/core-x/android-sdk-qa/aot-release-asset-compare.json`。

### 2026-11-17 Android Release APK

在隔离目录用 Flutter Release、R8 和临时 QA 签名生成两份 x86_64 split APK，仅切换 `noCompress.add("kernel_blob.bin")`。两份均为 71,239,180 B，797 个条目逐项一致，SHA-256 同为 `F450BE80AAF745830ED89C95995B9A9759EB7E03806879BFED8A0671BEA638D9`。包内没有调试快照，v2 签名和 16 KiB ZIP 对齐通过，架构为 x86_64，`libclash.so` 与该轮 NDK strip 输出匹配。首轮构建遇 Windows 跨盘 Kotlin 增量和 Gradle 缓存打包报错，在隔离目录关闭相应缓存后重试成功。原始记录 `build/core-x/android-sdk-qa/qa-release-*`。

MuMu Android 12 安装 x86_64 候选并核对设备端 APK 哈希，冷启动成功。启用 IPv6 后两轮各验证 IPv4、IPv6 各 5 个 TCP 回包与 A、AAAA 各 1 个 UDP 应答。两轮停止后接口和两族路由均清理。x86_64 QA 构建采用默认预览通道。

从当前 Go 源码重建 arm64 核心，用 `APP_ENV=stable` 与临时 QA 证书生成 arm64-v8a Release split APK。APK 为 69,053,549 B，SHA-256 `D7401BA6C205DC6A3A2C9C03B3E509668B863CCFDDF42174D359E727EE67575F`。两种 ABI 的 Release APK 均只含各自架构，包内 11 个 ELF 库的加载段满足 16 KiB 对齐，Go 核心与各自 NDK strip 后的输入逐字节一致。arm64 的签名、ZIP 对齐、ABI 和清单检查通过。正式签名和 arm64 实机待验。

### Android armeabi-v7a Release

Windows 在独立工作目录用 NDK 28.2、Go `GOARCH=arm GOARM=7`、`with_gvisor,with_low_memory` 和 Flutter 的稳定通道参数构建 32 位 APK。首次 Rust 编译因 `LIBCLANG_PATH` 缺共享库失败，Flutter 仍输出缺少 `libcode_forge.so` 的 APK。Windows 包装脚本显式返回 Dart 退出码后，以相同编译条件重跑原生 Gradle 任务，正确报告失败。使用已安装的宿主 libclang 与 NDK sysroot 后，构建成功。

完整包为 68,998,631 B，SHA-256 `93C02756253BDF0727867C103B10A1004B8696C740E3A5E1166F115937FA22F3`。仅包含 armeabi-v7a 的 11 个 ELF32 ARM 库，Go 核心与 NDK strip 后的输入一致，Code Forge、Flutter 引擎、Dart JNI 和 AOT 均存在。APK v2 QA 签名与 16 KiB ZIP 对齐检查通过。32 位 ELF 加载段的最小对齐因库而异，逐个数值见 `build/core-x/android-armv7-release-qa/apk-verification.json`。该目录保留原生任务的失败日志、首次被拒绝的 APK 和完整包。使用临时 QA 签名，正式签名待验。

MuMu Android 12 专用实例按 armeabi-v7a 实装，设备端 APK 哈希匹配。临时次用户第一次启动在 `MlKitInitProvider` 报 `MlKitContext is already initialized`。同一包在专用实例的主用户两次冷启动并渲染首屏，`primaryCpuAbi=armeabi-v7a`；已有 arm64 和 x86_64 包也在主用户启动成功。MuMu 通过 native bridge 翻译 ARM 指令。保留截图、Activity 及崩溃日志，移除本轮应用与次用户。ARMv7 真机、多用户启动及 TUN 流量待验。

### Linux Release bundle

Ubuntu 24.04 x86_64、Flutter 3.47.4、Rust 1.100.0。在隔离容器构建后模拟首次 PkgConfig 依赖检查失败，同一构建目录重试成功。默认包内有应用、核心、Flutter 引擎、AOT、插件、资源和许可证。动态依赖均能解析，核心和最终内核输入逐字节一致。显式设置安装前缀时，生成的核心和应用安装规则指向同一前缀。CMake 3.29 起的显式环境默认前缀交给 CMake 处理。[CMake 前缀文档](https://raw.githubusercontent.com/Kitware/CMake/v3.29.0/Help/variable/CMAKE_INSTALL_PREFIX.rst)

| 本地包 | 字节 | SHA-256 |
| --- | ---: | --- |
| `build/core-x/linux-desktop-release/fluxora-linux-release-bundle-fixed.tar` | 136,785,920 | `3991EFDC27F0C872C2D7EF64320F3F37B2796C4E206F94A97335C697AB1D590C` |
| `build/core-x/linux-desktop-release/Fluxora-1.1.2-linux-amd64.deb` | 55,887,694 | `652F0683E2BA7F3FF6A69AED82AEDA8581CC3F44FC00992A665498A874828C54` |
| `build/core-x/linux-desktop-release/Fluxora-1.1.2-linux-amd64.rpm` | 65,143,721 | `680E95E1A56D5949F2244EAE7A4CCEF0996F3758DEE8EDFE3CDBCB38E592BBF2` |

从 tar 解包，以普通用户在仅回环接口的 Xvfb 容器启动。二次打开显示应用窗口，进程树确认从解包目录启动 `FluxoraCore`。已查看首页及从侧栏点击后的空配置页。原始截图为 `linux-runtime-{home,profiles}.png`，同目录还保留 X11 和进程记录。项目自带 `flutter_distributor` 生成 .deb，`dpkg` 安装、已装路径和核心哈希核对及卸载通过。原始日志 `build/core-x/linux-desktop-stage10-deb-install.log`。现有不含系统 D-Bus/NetworkManager 的容器无法覆盖托盘交互和真实连接变化，项目打包器生成 RPM，解包检查程序、AOT、插件、资源、许可证及核心 SHA-256 全部通过。Fedora 44 隔离容器通过 DNF 原生依赖解析与安装、包内核心哈希和权限核对、动态链接检查及卸载。Fedora 桌面交互未验证。实装日志 `build/core-x/linux-desktop-stage10-rpm-fedora.log`。自动审查拦截了包含下载并执行 AppImageKit 工具的命令，AppImage 产物及签名未验证。RPM 日志 `build/core-x/linux-desktop-stage10-rpm.log`。
