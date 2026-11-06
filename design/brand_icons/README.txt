Fluxora 品牌图标系统交付说明 / 2026-11-06

视觉依据
用户图一的流动双翼 F、轨道圆点、光泽及八种场景；图二仅参考单色简化，图三仅参考多风格选择交互。
最终是参照图一重新生成的高清资产，不是截图裁切，也不是像素级复刻保证。八个 pair 母版均以同一个 official_pair.png 为标记几何参考。
每个 pair 为 1774×887，左深右浅，单枚母版有效分辨率 887×887；发布 PNG 为 1024×1024。放大导出不等于增加原生细节。
AI 生成母版为位图，不冒称其是可无损编辑的矢量；通知/磁贴/简化品牌标记才是矢量。

入口和行为
设置 → 主题 → 应用图标（工具搜索也能检索）。两个图标配色选项、8 套网格、当前项、独立预览、明确应用按钮。
选择尚未应用时只预览；应用成功后保存 ThemeProps.appIconStyle 和原有 useDarkIcon。保留页面 themeMode、primaryColor、全部其他配置与自定义侧栏图片。
Android 打开页面先查询真正启用的 launcher 组件；查询失败时禁止应用并提供重试。
Android 原生切换成功后才写偏好；保存失败尝试恢复旧组件；原生失败/回滚失败后重新查询真实状态并显示错误，不宣称成功。
桌面可保存应用内标记；界面明确说明系统安装图标不支持本实现的动态更换。自定义侧栏图片仍优先，选择图标不会删除它。
进程重启/页面重开可恢复；卸载会受系统数据清理影响，不保证卸载重装记住选择。

八套资产（每套 dark / light 两版）
official    官方默认：深青/午夜蓝与冰白；双翼、轨道、圆点。
classic     经典：电光蓝与冰蓝。
aqua        水色：深青水纹与浅水晶绿水纹。
premium     高级版：紫红流光与浅紫粉丝绸。
speed       极速：深蓝速度轨迹与浅蓝彩色光轨。
sky         天空：蔚蓝白云与浅天蓝白云。
sunset      日落：紫红/橙金云霞与桃粉晨光。
blue_night  蓝夜：午夜星空/地平弧线与浅蓝星空/地平弧线。

目录与规格
assets/images/brand_<style>_<dark|light>.png：16 枚 1024×1024 透明圆角图标，Flutter 实际引用。
source/<style>_pair.png：8 个原始母版，保存生成工具原始输出。
source/reference.png：用户图一，作为参照保留。
source/prompts.json：生成提示词；source/catalog.json：母版尺寸与 SHA-256。
official_dark.ico 等：16 个 ICO，每个含 16/24/32/48/64/128/256。
preview.png：实际导出图标的深浅总览，下方 QS 配色仅是示意，系统实际配色由 ROM 决定。
inventory.json：137 个交付资源及母版的 SHA-256 清单。
status_<white|black>_<16|20|24|32|48>.png：10 枚专用简化实心 F；无背景、无彩色纹理。
assets/images/icon_{white,black}.{png,ico}：真实托盘使用的实心 F；tray_{white,black}_stopped.{png,ico}：断开状态空心轮廓。
assets/images/fluxora_mark{,_light,_mono}.svg：简化品牌矢量，来自生成脚本的两条共享曲线。
android/app/src/main/res/drawable-xxxhdpi/brand_*_{background,foreground}.png：32 个 432×432 图层，对应 adaptive 108dp。
android/app/src/main/res/mipmap-anydpi-v26/brand_*.xml：16 个自适应声明，圆形及 OEM 裁切由系统处理。
android/app/src/main/res/drawable/ic_launcher_monochrome.xml：主题图标纯 alpha 剪影，放在中央安全区。
android/app/src/main/res/drawable/ic_notification_{light,dark}.xml：24dp 纯白 alpha F。
android/app/src/main/res/drawable[-night]/ic_tile.xml：24dp 同源 F。
windows/runner/resources/app_icon.ico：安装/EXE 构建实际引用的官方默认。
macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png：16/32/64/128/256/512/1024。
Linux AppImage/deb/rpm 原本引用 assets/images/icon.png，现已更新对应资源；未改打包架构。

真实接入与平台限制
Android：IMPLEMENTED / RUNTIME_UNVERIFIED。复用 app MethodChannel 与旧 MainActivity / MainActivityLight / MainActivityDark，扩展 14 个 alias，不改变组件旧名字或既有深链、电视入口。
API 33+ 使用 PackageManager.setComponentEnabledSettings 一次切换；26–32 先启用目标，再禁用旧入口，失败恢复原始组件状态。
PackageManager 不需要新增权限；未新增权限。LauncherIcons 输入只能是有限风格 ID。
通知点击缓存现在解析系统实际 launcher alias，并在切换后同步失效；small icon 真实改用 ic_notification_light，已不再使用旧的 ic.png。
通知大图标的原有主题跟随逻辑保留；本次不宣称实现通知大图标风格切换。
Android 13+ 用户启用系统主题图标时，monochrome 由系统着色，可能覆盖自选彩色外观。
Windows/macOS/Linux 托盘：IMPLEMENTED / RUNTIME_UNVERIFIED。现有 getTrayIconPath 和 trayManager.setIcon 已改用透明单色专用资产；macOS active 保留 template 模式。
Windows/macOS/Linux 动态系统安装图标：PLATFORM_LIMITATION（本次实现范围）。构建资源已更新；没有伪装成运行时切换。
Android 快捷磁贴：已有功能接线保留，图标已替换。START→ACTIVE，STOP→INACTIVE，PENDING→UNAVAILABLE；图标与背景由系统动态着色。
磁贴点击仍走既有 TempActivity/授权/控制通路，不创建重复引擎，不以预览冒充开关，未在本机实际启动 VPN 测试。
iOS 控制中心/Widget：NOT_IMPLEMENTED。仓库没有 iOS 主工程，不新造扩展。
运行时导入任意外部主题/launcher 图标包：NOT_IMPLEMENTED。现有主题自定义配色、侧栏图片定制能力保留；开放制作通过下述源文件与模板完成。

可再生成与开放制作
无需新的应用依赖；本机已有 Flutter/flutter_svg 和 Python Pillow。
从项目根目录依次执行：
  python tool/generate_brand_icons.py sources
  flutter test --no-pub tool/render_brand_icons.dart
  python tool/generate_brand_icons.py package
  python tool/generate_brand_icons.py check
生成器不启动应用、Core、服务、TUN、DNS 或代理。
修改某套设计：编辑或替换 source/<style>_pair.png，保持 2:1、左深右浅和中心留白，按上述流程重新导出。PNG 母版及脚本保留，不依赖聊天临时目录。
新增风格：同步 BrandIcons.styles、LauncherIcons.styles、Python STYLES/NAMES，并提供对应 pair；运行 sources 会更新编译期 Android aliases。Android 系统图标必须随应用打包，不能把任意下载 SVG 当原生 launcher 图标。
单色轮廓修改：只改生成器 WINGS，两条曲线同时导出通知、磁贴、monochrome 和托盘。
彩色母版生成具有随机性；固定母版后的尺寸导出和打包可重复。提示词并不构成像素级重生成保证。

验证
PASS：flutter analyze --no-pub，0 issues。
PASS：46 项定向 Flutter tests（涵盖旧配置兼容、16 配色往返、预览隔离、保存与重开、320px/200% 字号、Android 查询/成功/失败/保存失败回滚/回滚失败、桌面托盘路径）。
PASS：纯 SVG 渲染测试。
PASS：Python 资产校验（16 款独立、与母版对应、1024 导出、adaptive inset、ICO 7 尺寸、纯黑/白 alpha、alias/资源引用、交付 SHA-256）。
PASS：aapt2 compile --dir android/app/src/main/res；所有 Android 资源可编译。
PASS：用本机 Kotlin 2.2.20 编译器及 Android API 36 单独编译 LauncherIcons.kt、NotificationComponentCache.kt。
PASS：git diff --check（最后执行结果见最终汇报）。
未通过完整 Gradle 编译：JDK 25 与本机工具不兼容；改用已有 Microsoft JDK 17 后进入构建，但离线缓存缺 AndroidX 等依赖（包括 preference:1.2.1、browser:1.9.0）。没有为图标任务更改依赖版本或下载庞大依赖树。
未验证：Android 真机桌面 alias 切换、ROM 刷新、通知点击、QS 真实 VPN、桌面托盘/Dock/安装包视觉。没有生成或安装新 APK/EXE。
未启动真实 Core、SCM、Helper、WinINET、TUN、DNS、系统代理、Windows VM；未修改链式代理 auto Failover 或 Phase 12/14。
未 reset/clean/commit/push/tag；既有图标备份、用户自定义图片、配置与安全辅助代码均保留。
