import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';

import '../widgets/floating_dock_metrics.dart';

const appName = AppIdentity.displayName;
// No longer `const`: the helper name is dev-aware now, so
// `WindowsHelperIdentity.serviceName` is a getter rather than a constant.
final appHelperService = WindowsHelperIdentity.serviceName;
const coreName = 'clash.meta';
const tunDeviceName = AppIdentity.tunDeviceName;
const browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36';
const packageName = AppIdentity.packageId;
const maxTextScale = 1.4;
const minTextScale = 0.8;

/// Sentinel stored in `AppSettingProps.locale` that means "follow the system
/// language". It is deliberately **not** `null`: `GlobalState.migrateOldData`
/// re-seeds a `null` locale with the concrete system locale on every launch, so
/// an explicit "Default" choice would not survive a restart.
const systemLocaleValue = 'system';
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
// Native core/common.go has 50 delay workers; queue before starting IPC deadlines.
const maxConcurrentDelayTests = 50;
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const mmdbFileName = 'geoip.metadb';
const asnFileName = 'ASN.mmdb';
const geoSiteFileName = 'GeoSite.dat';
const bundleMRSFileName = 'BundleMRS.7z';
final double kHeaderHeight = system.isDesktop
    ? !system.isMacOS
          ? 40
          : 28
    : 0;
const profilesDirectoryName = 'profiles';
const localhost = '127.0.0.1';
const clashConfigKey = 'clash_config';
const configKey = 'config';
const customSidebarIconKey = 'custom_sidebar_icon';
const customDashboardTitleKey = 'custom_dashboard_title';
const double dialogCommonWidth = 300;
const repository = 'Tiam9173/fluxora';
const ipInfoToken = String.fromEnvironment('IPINFO_TOKEN', defaultValue: '');
const defaultExternalController = '127.0.0.1:9090';
const maxMobileWidth = 600;
const maxLaptopWidth = 840;

/// Height the floating dock occupies at the bottom of a mobile page.
///
/// Callers add their own visual gap on top (`16 + reserve` and similar), so this
/// returns **the dock's own height**, not "dock + spacing".
///
/// It reads the height the mobile shell measured ([FloatingDockMetrics]) rather
/// than a constant. The old fixed 84 px was an estimate of the `GNav` dock that
/// Phase 02.2 replaced: the Aurora dock is 77 px at 1.0× and 92 px at 2.0×, so
/// the constant over-reserved at normal text and left the last 8 px of content
/// under the dock at 2.0×. A floor is still needed for the frame before the
/// first post-frame measure lands, and for hosts that mount no dock.
///
/// `viewPadding` — never `padding` — feeds the fallback path. `padding.bottom`
/// carries both the keyboard inset (not ours) and the dock height the shell
/// injects (which would be counted twice: measured on a 390×844 phone it turned
/// the reserve into 154 px and pushed four pages' content 70 px too far up).
double getFloatingBottomBarReserveHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final viewBottom = mediaQuery.viewPadding.bottom;

  // TV keeps its own ladder: the 132 px figure covers the TV bar plus the
  // ten-foot focus ring, and must not be replaced by the mobile dock's height.
  if (globalState.isAndroidTV) {
    return 132.0 + (viewBottom > 12 ? viewBottom - 12 : 0);
  }

  final measured = FloatingDockMetrics.maybeHeightOf(context);
  if (measured > 0) {
    // The measured value already includes the dock's own `SafeArea`, so the
    // system inset must not be added again.
    return measured > _bottomBarReserveFloor
        ? measured
        : _bottomBarReserveFloor;
  }

  return _bottomBarReserveFloor + (viewBottom > 12 ? viewBottom - 12 : 0);
}

/// Floor for the reserve, in logical pixels.
///
/// 84 is the Aurora dock at 1.0× (77 px) plus breathing room. It is a **floor,
/// not an estimate**: a taller dock (large text) wins, a shorter one does not
/// shrink the gap below what the layout was designed around.
const double _bottomBarReserveFloor = 84.0;

double getFloatingBottomBarFABReserveHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  // `viewPadding` only, for the same reason as
  // `getFloatingBottomBarReserveHeight`: `padding.bottom` also carries the dock
  // height that the mobile shell injects, and folding that into the
  // `min(..., 12)` term below silently shrank the FAB's clearance. Measured on
  // a 390×844 phone: the FAB sat 6 px above the dock instead of 18 px — close
  // enough that the button's own shadow merged into the dock.
  //
  // Only affects devices whose bottom inset is under 12 px (desktop, Android
  // without a gesture bar); where the inset is ≥ 12 the `min` already capped the
  // subtraction, so real phones are unchanged.
  final viewBottom = mediaQuery.viewPadding.bottom;

  // Same story as the content reserve: the FAB has to clear the *measured* dock,
  // not a constant. Measured at 2.0× text on a 390×844 shell, the fixed 84 left
  // the FAB overlapping the dock by 8 px (dock 92, FAB bottom at 844-16-84).
  final measured = FloatingDockMetrics.maybeHeightOf(context);
  if (measured > 0) {
    // The measured height already contains the dock's `SafeArea`, so the inset
    // term only belongs to the fallback.
    return measured > _bottomBarReserveFloor
        ? measured
        : _bottomBarReserveFloor;
  }
  return _bottomBarReserveFloor - min(viewBottom, 12.0);
}

const defaultTestUrl = 'https://www.apple.com/library/test/success.html';

// Preset test URLs
const presetTestUrls = [
  'https://g.cn/generate_204',
  'https://www.gstatic.com/generate_204',
  'https://www.google.com/generate_204',
  'https://cp.cloudflare.com/generate_204',
  'https://www.apple.com/library/test/success.html',
];

// Preset NTP servers
const defaultNtpServer = 'time.apple.com';
const presetNtpServers = [
  'ntp.aliyun.com',
  'time.apple.com',
  'ntp.tencent.com',
  'time.windows.com',
  'time.cloudflare.com',
];

// Network detection URL (primary IP source)
// Default must match the previous hardcoded primary source so that
// behavior is unchanged when the user never configures this.
/// Whether the title-bar start switch is shown by default on this platform.
///
/// Android TV always showed it. A phone now does too: the Hero sits at the top
/// of the dashboard grid, but the title-bar switch is the one control that stays
/// reachable **without scrolling** — which is the whole point of having it.
/// Desktop keeps it off, where the tray and the prominent Hero already cover it.
///
/// Extracted so the platform rule is unit-testable via `system.platformOverride`
/// instead of living inline in `GlobalState`'s constructor.
bool defaultShowStartSwitch({required bool isAndroidTV}) =>
    isAndroidTV || system.isAndroid;

const defaultNetworkDetectionUrl = 'http://ip-api.com/json/?lang=zh-CN';

// Preset network detection URLs (deduped from the existing built-in sources)
const presetNetworkDetectionUrls = [
  'http://ip-api.com/json/?lang=zh-CN',
  'http://ip-api.com/json',
  'https://get.geojs.io/v1/ip/geo.json',
  'https://myip.ipip.net/json',
  'https://ip.sb/cdn-cgi/trace',
  'https://api.ip.sb/cdn-cgi/trace',
  'https://www.qualcomm.cn/cdn-cgi/trace',
  'https://www.teamviewer.cn/cdn-cgi/trace',
];

class CommonFilters {
  static final ImageFilter blur = ImageFilter.blur(
    sigmaX: 2,
    sigmaY: 2,
    tileMode: TileMode.mirror,
  );
}

final commonFilter = CommonFilters.blur;

const navigationItemListEquality = ListEquality<NavigationItem>();
const trackerInfoListEquality = ListEquality<TrackerInfo>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const proxiesListStoreKey = PageStorageKey<String>('proxies_list');
const toolsStoreKey = PageStorageKey<String>('tools');
const profilesStoreKey = PageStorageKey<String>('profiles');

/// Fluxora brand primary — "Flux Cyan".
///
/// Was `0xFF00897B` (Material Teal 600) before D4.4; now aligned with the
/// Fluxora mark so the default theme is actually on-brand.
/// Uses the violet accent of the Fluxora mark (`FluxoraColors.brandSeed`).
const defaultPrimaryColor = 0xFF7C75FF;

/// The primary colour Fluxora shipped **before** D4.4 (Material Teal 600).
///
/// Kept so D4.8 can tell "the user never picked a colour" apart from "the user
/// picked one": a stored `primaryColor` equal to this is the *old default*, not
/// a user choice, and may be migrated to [defaultPrimaryColor]. Any other value
/// is treated as a real user choice and must never be overwritten.
const legacyDefaultPrimaryColor = 0xFF00897B;

double getWidgetHeight(num lines) {
  return max(lines * 84 + (lines - 1) * 16, 0).ap;
}

const maxLength = 256;

final mainIsolate = 'FluxoraMainIsolate';

final serviceIsolate = 'FluxoraServiceIsolate';

/// User-saved colours. Examples are shipped separately in BrandIcons.
const defaultPrimaryColors = <int>[];

const scriptTemplate = '''
const main = (config) => {
  return config;
}''';
