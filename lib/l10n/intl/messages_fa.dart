// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fa locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'fa';

  static String m0(role) => "افزودن نامزد ${role}";

  static String m1(role) => "افزودن نامزد پشتیبان ${role}";

  static String m2(completed, total) =>
      "در حال بررسی (${completed}/${total})...";

  static String m3(count) => "${count} گره با موفقیت درج شد";

  static String m4(hop) => "🔗 دیالر: ${hop}";

  static String m5(name) => "دیالر: ${name}";

  static String m6(index) => "رله ${index}";

  static String m7(server, port) => "IP خانگی ${server}:${port}";

  static String m8(count) => "${count} گره نامعتبر پاک شد";

  static String m9(name) => "آیا از حذف گره «${name}» مطمئن هستید؟";

  static String m10(error) => "ایجاد گروه ناموفق بود: ${error}";

  static String m11(name) =>
      "گروه خالی «${name}» ایجاد شد، لطفاً گره اضافه کنید";

  static String m12(count) => "${Intl.plural(count, other: '# روز')}";

  static String m13(label) => "آیا از حذف موارد انتخاب شده اطمینان دارید؟";

  static String m14(label) => "آیا از حذف ${label} اطمینان دارید؟";

  static String m15(label) => "${label} نمی‌تواند خالی باشد";

  static String m16(label) => "${label} از قبل وجود دارد";

  static String m17(reason) => "جابه‌جایی ناموفق بود: ${reason}";

  static String m18(node) => "جابه‌جایی موفق بود، به [${node}] تغییر یافت";

  static String m19(count) => "${Intl.plural(count, other: '# ساعت')}";

  static String m20(count) => "${count} گره پروکسی فرود درج شد";

  static String m21(count) => "${count}";

  static String m22(count) => "${Intl.plural(count, other: '# دقیقه')}";

  static String m23(count) => "${Intl.plural(count, other: '# ماه')}";

  static String m24(name) => "گره اضافه شد: ${name}";

  static String m25(name) => "گره حذف شد: ${name}";

  static String m26(name) => "ویرایش ${name}";

  static String m27(name) => "مدیریت گره · ${name}";

  static String m28(proto) => "مثال: هنگ‌کنگ ۰۱ - ${proto}";

  static String m29(label) => "هیچ مورد ${label} یافت نشد";

  static String m30(label) => "${label} باید عدد باشد";

  static String m31(from, to) =>
      "پورت ${from} اشغال است؛ در این نشست از ${to} استفاده می‌شود";

  static String m32(label) =>
      "${label} باید بین ۱۰۲۴ تا ۴۹۱۵۱ باشد (۰ برای غیرفعال)";

  static String m33(name) => "پروکسی مقدماتی و پروکسی فرود · ${name}";

  static String m34(statusCode) =>
      "خطا در دریافت پروفایل. لطفاً شبکه خود را بررسی کرده یا لینک را ریست کنید ( کد خطا: ${statusCode} )";

  static String m35(count) => "${count} مورد انتخاب شده";

  static String m36(error) => "بررسی ناموفق: ${error}";

  static String m37(name) => "همچنان در حال استفاده: ${name}";

  static String m38(label) => "${label} باید یک URL معتبر باشد";

  static String m39(label) => "${label} کپی شد";

  static String m40(colo, ip) =>
      "🎉 عیب‌یابی موفق بود. WARP فعال است (مرکز: ${colo}, خروجی: ${ip})";

  static String m41(name) => "دیالر روی ${name} تنظیم شد";

  static String m42(code) => "گره لبه ${code}";

  static String m43(ip) => "از سریع‌ترین گره ${ip} استفاده می‌شود";

  static String m44(ip) => "از ${ip} استفاده می‌شود";

  static String m45(ip) =>
      "توجه: به خروجی ${ip} متصل شد اما امضای WARP یافت نشد — تنظیمات دیالر را بررسی کنید";

  static String m46(loc) => "منطقه: ${loc}";

  static String m47(label) => "به ${label} تغییر یافت";

  static String m48(count) => "${Intl.plural(count, other: '# سال')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("درباره"),
    "accessControl": MessageLookupByLibrary.simpleMessage("کنترل دسترسی"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "تنها برنامه‌های انتخاب شده از VPN عبور کنند",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیم لیست سیاه/سفید دسترسی برنامه‌ها",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "برنامه‌های انتخاب شده از VPN استثنا شوند",
    ),
    "account": MessageLookupByLibrary.simpleMessage("حساب کاربری"),
    "action": MessageLookupByLibrary.simpleMessage("عملیات"),
    "action_mode": MessageLookupByLibrary.simpleMessage("تغییر حالت"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("پروکسی سیستم"),
    "action_start": MessageLookupByLibrary.simpleMessage("شروع / توقف"),
    "action_tun": MessageLookupByLibrary.simpleMessage("کارت شبکه مجازی (TUN)"),
    "action_view": MessageLookupByLibrary.simpleMessage("نمایش / پنهان"),
    "activeGoroutines": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "add": MessageLookupByLibrary.simpleMessage("افزودن"),
    "addLandingProxy": MessageLookupByLibrary.simpleMessage(
      "افزودن پروکسی فرود",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("افزودن پروفایل"),
    "addRoleCandidate": m0,
    "addRoleFallbackCandidate": m1,
    "addRule": MessageLookupByLibrary.simpleMessage("افزودن قانون"),
    "addTunnel": MessageLookupByLibrary.simpleMessage("افزودن هدایت"),
    "addUser": MessageLookupByLibrary.simpleMessage("افزودن کاربر"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "افزودن به قوانین اصلی",
    ),
    "address": MessageLookupByLibrary.simpleMessage("آدرس"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("آدرس سرور WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "لطفاً آدرس WebDAV معتبری وارد کنید",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "شروع خودکار با دسترسی Admin",
    ),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "اجرای خودکار با دسترسی Admin هنگام بووت",
    ),
    "advancedSettings": MessageLookupByLibrary.simpleMessage("تنظیمات پیشرفته"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "تولید کلید Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "جفت کلید X25519 با موفقیت ساخته شد. لطفاً آن را ذخیره کنید",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "کلید خصوصی Age",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "لطفا ابتدا کلید خصوصی Age صحیح را وارد کنید",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("کلید عمومی Age"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "لطفاً کلید خصوصی معتبری وارد کنید (باید با -AGE-SECRET-KEY شروع شود)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "کلید خصوصی Age (اختیاری)",
    ),
    "aggregateJoin": MessageLookupByLibrary.simpleMessage(
      "عضویت در گروه تجمیعی",
    ),
    "aggregateJoinDesc": MessageLookupByLibrary.simpleMessage(
      "گره‌های این اشتراک را در گروه تجمیعی ادغام می‌کند",
    ),
    "aggregatePrefix": MessageLookupByLibrary.simpleMessage(
      "پیشوند تجمیع (خالی = نام اشتراک)",
    ),
    "ago": MessageLookupByLibrary.simpleMessage("قبل"),
    "agree": MessageLookupByLibrary.simpleMessage("موافقم"),
    "allApps": MessageLookupByLibrary.simpleMessage("همه برنامه‌ها"),
    "allocatedMemory": MessageLookupByLibrary.simpleMessage("تخصیص‌یافته"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("اجازه میانبر VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "اجازه به برخی برنامه‌ها برای عبور مستقیم بدون VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("دسترسی شبکه محلی"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "اجازه دسترسی به پروکسی از شبکه محلی (LAN)",
    ),
    "alreadyInWhitelist": MessageLookupByLibrary.simpleMessage(
      "برنامه قبلاً در لیست سفید قرار دارد",
    ),
    "alwaysShowTitleBar": MessageLookupByLibrary.simpleMessage(
      "دکمه‌های عنوان",
    ),
    "alwaysShowTitleBarDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش همیشگی دکمه‌های نوار عنوان بالا سمت راست",
    ),
    "amneziaObfsParams": MessageLookupByLibrary.simpleMessage(
      "پارامترهای پنهان‌سازی AmneziaWG 2/3 (Jc / Jmin / Jmax / S1 / S2 / H1-H4)",
    ),
    "app": MessageLookupByLibrary.simpleMessage("برنامه"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "کنترل دسترسی برنامه‌ها",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage("تنظیمات مربوط به برنامه"),
    "application": MessageLookupByLibrary.simpleMessage("برنامه"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "مدیریت تنظیمات برنامه",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("صعودی"),
    "authorized": MessageLookupByLibrary.simpleMessage("احراز هویت شده"),
    "auto": MessageLookupByLibrary.simpleMessage("خودکار"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "بررسی خودکار بروزرسانی",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "بررسی خودکار بروزرسانی هنگام اجرای برنامه",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "بستن خودکار اتصالات",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "قطع خودکار اتصالات هنگام تغییر نود",
    ),
    "autoFailover": MessageLookupByLibrary.simpleMessage("جابه‌جایی خودکار"),
    "autoFailoverOffDesc": MessageLookupByLibrary.simpleMessage(
      "خاموش: فقط از طریق دکمه زیر می‌توان به‌صورت دستی تغییر داد",
    ),
    "autoFailoverOnDesc": MessageLookupByLibrary.simpleMessage(
      "هنگام تداوم خطا در زنجیره، به‌طور خودکار به نامزد پشتیبان تغییر می‌کند",
    ),
    "autoInjectGroups": MessageLookupByLibrary.simpleMessage(
      "تزریق خودکار به گروه انتخابگر اصلی",
    ),
    "autoInjectGroupsDesc": MessageLookupByLibrary.simpleMessage(
      "پروکسی‌های فرود فعال‌شده را به‌طور خودکار به گروه‌های مسیریابی اصلی مانند «انتخاب گره» اضافه می‌کند",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("شروع خودکار"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "اجرای خودکار هنگام روشن شدن سیستم",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("اتصال خودکار"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "اتصال خودکار پروکسی پس از باز شدن برنامه",
    ),
    "autoScroll": MessageLookupByLibrary.simpleMessage("پیمایش خودکار"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "تنظیم خودکار DNS سیستم",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("بروزرسانی خودکار"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "فاصله بروزرسانی خودکار (دقیقه)",
    ),
    "back": MessageLookupByLibrary.simpleMessage("بازگشت"),
    "backup": MessageLookupByLibrary.simpleMessage("پشتیبان‌گیری"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری و بازیابی",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "همگام‌سازی داده‌ها از طریق WebDAV یا محلی",
    ),
    "backupPassword": MessageLookupByLibrary.simpleMessage("گذرواژه پشتیبان"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری با موفقیت انجام شد",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("تنظیمات هسته"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "تغییر کلی تنظیمات هسته",
    ),
    "batchCheckingProgress": m2,
    "batchImportLinks": MessageLookupByLibrary.simpleMessage(
      "درج دسته‌ای پیوندها",
    ),
    "batchImportParseFailed": MessageLookupByLibrary.simpleMessage(
      "هیچ پیوند گره معتبری تحلیل نشد. لطفاً قالب را بررسی کنید.",
    ),
    "batchImportPasteHint": MessageLookupByLibrary.simpleMessage(
      "پیوندهای اشتراک گره یا پیکربندی گره (YAML/JSON) را اینجا بچسبانید...",
    ),
    "batchImportShareLinks": MessageLookupByLibrary.simpleMessage(
      "درج دسته‌ای پیوندهای اشتراک",
    ),
    "batchImportSuccess": m3,
    "batchImportSupportHint": MessageLookupByLibrary.simpleMessage(
      "پشتیبانی از پیوندهای تک‌خطی/چندخطی یا بخش‌های گره YAML/JSON:",
    ),
    "batteryOptimization": MessageLookupByLibrary.simpleMessage(
      "بهینه‌سازی باتری",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "درخواست استثنا از بهینه‌سازی باتری",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("اتصال"),
    "blacklist": MessageLookupByLibrary.simpleMessage("لیست سیاه"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("حالت لیست سیاه"),
    "blockComment": MessageLookupByLibrary.simpleMessage("کامنت"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("دامنه‌های استثنا"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "اعمال تنها در صورت فعال بودن پروکسی سیستم",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "استثنای شبکه خصوصی",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "استثنای خودکار آدرس‌های شبکه خصوصی (LAN)",
    ),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "الگوریتم حافظه پنهان",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "حافظه پنهان آسیب دیده است. آیا پاکسازی شود؟",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "مجوز دوربین رد شد",
    ),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "برای اسکن کد QR دسترسی دوربین لازم است. لطفاً از تنظیمات مجوز دهید.",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("لغو"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "لغو فیلتر برنامه‌های سیستم",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("لغو انتخاب همه"),
    "cardFollowMain": MessageLookupByLibrary.simpleMessage(
      "پیروی از انتخاب اصلی",
    ),
    "cardHopValue": m4,
    "cardNodeSelect": MessageLookupByLibrary.simpleMessage("انتخاب گره"),
    "cardSelect": MessageLookupByLibrary.simpleMessage("انتخاب"),
    "categoryAi": MessageLookupByLibrary.simpleMessage("AI"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("همه"),
    "categoryChina": MessageLookupByLibrary.simpleMessage("مستقیم چین"),
    "categoryCrypto": MessageLookupByLibrary.simpleMessage("ارز دیجیتال"),
    "categoryDeveloper": MessageLookupByLibrary.simpleMessage("توسعه‌دهندگان"),
    "categoryGaming": MessageLookupByLibrary.simpleMessage("مرکز بازی"),
    "categorySocial": MessageLookupByLibrary.simpleMessage(
      "پلتفرم‌های اجتماعی",
    ),
    "categoryStreaming": MessageLookupByLibrary.simpleMessage("رسانه‌های جاری"),
    "chainAddRelay": MessageLookupByLibrary.simpleMessage("افزودن سرور میانی"),
    "chainAddRelayDesc": MessageLookupByLibrary.simpleMessage(
      "یک رله در انتهای زنجیره و پیش از خروجی اضافه می‌کند",
    ),
    "chainAvgLatency": MessageLookupByLibrary.simpleMessage("تأخیر متوسط"),
    "chainCreateSupportPackage": MessageLookupByLibrary.simpleMessage(
      "ایجاد بسته پشتیبانی",
    ),
    "chainCreatingPackage": MessageLookupByLibrary.simpleMessage(
      "در حال ایجاد…",
    ),
    "chainDecisionSupport": MessageLookupByLibrary.simpleMessage(
      "پشتیبانی تصمیم",
    ),
    "chainDelete": MessageLookupByLibrary.simpleMessage("حذف"),
    "chainDeleteHop": MessageLookupByLibrary.simpleMessage("حذف این مرحله"),
    "chainDeviceSide": MessageLookupByLibrary.simpleMessage("روی دستگاه"),
    "chainDiagnosticPackage": MessageLookupByLibrary.simpleMessage(
      "بسته تشخیصی",
    ),
    "chainDiagnosticTitle": MessageLookupByLibrary.simpleMessage(
      "تشخیص زنجیره",
    ),
    "chainDialerValue": m5,
    "chainDisabled": MessageLookupByLibrary.simpleMessage("غیرفعال"),
    "chainEdit": MessageLookupByLibrary.simpleMessage("ویرایش"),
    "chainEditLanding": MessageLookupByLibrary.simpleMessage(
      "ویرایش پروکسی خروج",
    ),
    "chainEnabled": MessageLookupByLibrary.simpleMessage(
      "پروکسی زنجیره‌ای فعال شد",
    ),
    "chainEnterServer": MessageLookupByLibrary.simpleMessage(
      "ابتدا آدرس سرور را وارد کنید",
    ),
    "chainEnterServerHint": MessageLookupByLibrary.simpleMessage(
      "آدرس سرور را وارد کنید",
    ),
    "chainEventsLabel": MessageLookupByLibrary.simpleMessage("رویدادها"),
    "chainExportReport": MessageLookupByLibrary.simpleMessage(
      "خروجی گرفتن گزارش",
    ),
    "chainExporting": MessageLookupByLibrary.simpleMessage("در حال خروجی…"),
    "chainFailed": MessageLookupByLibrary.simpleMessage("ناموفق"),
    "chainFailuresLabel": MessageLookupByLibrary.simpleMessage("شکست‌ها"),
    "chainFingerprintGuide": MessageLookupByLibrary.simpleMessage(
      "🎯 راهنمای حساب‌های خارجی و جداسازی اثر انگشت",
    ),
    "chainFollowMain": MessageLookupByLibrary.simpleMessage(
      "پیروی از انتخاب اصلی",
    ),
    "chainGeneratedOn": MessageLookupByLibrary.simpleMessage("ایجاد شده در"),
    "chainHealthLabel": MessageLookupByLibrary.simpleMessage("سلامت"),
    "chainHealthScore": MessageLookupByLibrary.simpleMessage("امتیاز سلامت"),
    "chainHelpHop": MessageLookupByLibrary.simpleMessage(
      "• دیالر (Hop): نخستین رله‌ای که دستگاه به آن وصل می‌شود.",
    ),
    "chainHelpMultiHop": MessageLookupByLibrary.simpleMessage(
      "• چندمرحله‌ای: ترافیک مرحله‌به‌مرحله از دیالر و گره خروجی عبور می‌کند.",
    ),
    "chainHelpTitle": MessageLookupByLibrary.simpleMessage(
      "دیالر و گره خروجی چیست؟",
    ),
    "chainHopExitNode": MessageLookupByLibrary.simpleMessage(
      "پرش سوم (گره خروجی)",
    ),
    "chainHopIncomplete": MessageLookupByLibrary.simpleMessage(
      "زنجیره سه‌پرشی ناقص است: گره رله و گره خروجی را انتخاب کنید",
    ),
    "chainHopMode": MessageLookupByLibrary.simpleMessage("تعداد پرش زنجیره"),
    "chainHopModeDesc": MessageLookupByLibrary.simpleMessage(
      "دو پرش: «پرش ورودی → خروج فرود». سه پرش یک گره رله اضافه می‌کند",
    ),
    "chainHopNotSelected": MessageLookupByLibrary.simpleMessage("انتخاب نشده"),
    "chainHopRelayNode": MessageLookupByLibrary.simpleMessage(
      "پرش دوم (گره رله)",
    ),
    "chainHopUnavailable": MessageLookupByLibrary.simpleMessage(
      "فهرست گره‌های موجود خوانده نشد، بنابراین بررسی دسترس‌پذیری گره انجام نشد",
    ),
    "chainInheritDefault": MessageLookupByLibrary.simpleMessage(
      "خالی = دیالر پیش‌فرض کلی",
    ),
    "chainIntelAnalytics": MessageLookupByLibrary.simpleMessage("تحلیل هوشمند"),
    "chainIpOrDomain": MessageLookupByLibrary.simpleMessage("IP یا دامنه"),
    "chainLandingProxyNone": MessageLookupByLibrary.simpleMessage(
      "پیش‌فرض (هیچ)",
    ),
    "chainMainTargets": MessageLookupByLibrary.simpleMessage(
      "اتصال به سرویس‌های رایج",
    ),
    "chainNeedLanding": MessageLookupByLibrary.simpleMessage(
      "ابتدا حداقل یک پروکسی خروجی اضافه و فعال کنید",
    ),
    "chainNoMatch": MessageLookupByLibrary.simpleMessage(
      "گره‌ای با این فیلتر نیست",
    ),
    "chainNoResidential": MessageLookupByLibrary.simpleMessage(
      "گره خروجی تنظیم نشده",
    ),
    "chainNodeDeviceApp": MessageLookupByLibrary.simpleMessage(
      "اپلیکیشن دستگاه",
    ),
    "chainNodeGroupNodes": MessageLookupByLibrary.simpleMessage("گره‌های گروه"),
    "chainNodeLocal": MessageLookupByLibrary.simpleMessage("محلی"),
    "chainNodePreProxy": MessageLookupByLibrary.simpleMessage("پروکسی مقدماتی"),
    "chainNodeReliability": MessageLookupByLibrary.simpleMessage(
      "قابلیت اطمینان گره",
    ),
    "chainNodeSubscription": MessageLookupByLibrary.simpleMessage("گره اشتراک"),
    "chainNoneDirect": MessageLookupByLibrary.simpleMessage(
      "هیچ (اتصال مستقیم به گره اشتراک)",
    ),
    "chainNotProbed": MessageLookupByLibrary.simpleMessage(
      "بررسی نشده: رنگ فقط تنظیمات را نشان می‌دهد نه سلامت",
    ),
    "chainOpenFolder": MessageLookupByLibrary.simpleMessage("باز کردن پوشه"),
    "chainOptional": MessageLookupByLibrary.simpleMessage("اختیاری"),
    "chainPackageReady": MessageLookupByLibrary.simpleMessage("بسته آماده است"),
    "chainPartialProbe": MessageLookupByLibrary.simpleMessage(
      "برای برخی مراحل نتیجه‌ای نیست؛ گره‌های بررسی‌نشده خنثی می‌مانند",
    ),
    "chainPreProxyNone": MessageLookupByLibrary.simpleMessage("مستقیم (هیچ)"),
    "chainProbeNow": MessageLookupByLibrary.simpleMessage("بررسی زنجیره"),
    "chainProbePassed": MessageLookupByLibrary.simpleMessage(
      "همه مراحل بررسی شد؛ دسترسی واقعی را با درخواست بسنجید",
    ),
    "chainProbing": MessageLookupByLibrary.simpleMessage(
      "در حال بررسی زنجیره…",
    ),
    "chainProxy": MessageLookupByLibrary.simpleMessage("پروکسی زنجیره‌ای"),
    "chainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "پیکربندی پرش ورودی و پروکسی فرود IP مسکونی ثابت",
    ),
    "chainReady": MessageLookupByLibrary.simpleMessage("آماده"),
    "chainRelayIndex": m6,
    "chainResetFilter": MessageLookupByLibrary.simpleMessage("بازنشانی فیلتر"),
    "chainResidentialExample": MessageLookupByLibrary.simpleMessage(
      "مثلاً IP خانگی آمریکا 01",
    ),
    "chainResidentialIp": m7,
    "chainSearchNode": MessageLookupByLibrary.simpleMessage("جستجوی گره"),
    "chainShareLabel": MessageLookupByLibrary.simpleMessage("اشتراک‌گذاری"),
    "chainSpeedTest": MessageLookupByLibrary.simpleMessage("تست"),
    "chainStunBlocked": MessageLookupByLibrary.simpleMessage(
      "STUN/TURN مسدود شده (بدون نشت)",
    ),
    "chainSupportTitle": MessageLookupByLibrary.simpleMessage(
      "پشتیبانی زنجیره",
    ),
    "chainTargetNet": MessageLookupByLibrary.simpleMessage("شبکه هدف"),
    "chainTimeout": MessageLookupByLibrary.simpleMessage("مهلت تمام شد"),
    "chainTopFailureReason": MessageLookupByLibrary.simpleMessage(
      "اصلی‌ترین دلیل شکست",
    ),
    "chainTopology": MessageLookupByLibrary.simpleMessage("توپولوژی زنده"),
    "chainTopologyPreview": MessageLookupByLibrary.simpleMessage(
      "پیش‌نمایش توپولوژی مسیریابی زنجیره‌ای",
    ),
    "chainTz": MessageLookupByLibrary.simpleMessage("منطقه زمانی دستگاه:"),
    "chainTzAdvice": MessageLookupByLibrary.simpleMessage(
      "نکات منطقه زمانی و کنترل ریسک برای ToDetect / Whoer / IPpure",
    ),
    "chainTzWhy": MessageLookupByLibrary.simpleMessage(
      "⚠️ چرا ToDetect منطقه زمانی IP را قرمز می‌کند و چه باید کرد:",
    ),
    "chainWebrtcProtect": MessageLookupByLibrary.simpleMessage(
      "محافظت در برابر نشت WebRTC:",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("بررسی ناموفق بود"),
    "checkFailed": MessageLookupByLibrary.simpleMessage("Timeout"),
    "checkOrAddProfile": MessageLookupByLibrary.simpleMessage(
      "لطفاً ابتدا یک پروفایل اضافه کنید",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("بررسی بروزرسانی"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "شما از آخرین نسخه استفاده می‌کنید",
    ),
    "checkUpdatePrerelease": MessageLookupByLibrary.simpleMessage("پیش‌نمایش"),
    "checkUpdateStable": MessageLookupByLibrary.simpleMessage("پایدار"),
    "checking": MessageLookupByLibrary.simpleMessage("در حال بررسی..."),
    "cipher": MessageLookupByLibrary.simpleMessage("روش رمزنگاری"),
    "cipherLabel": MessageLookupByLibrary.simpleMessage("روش رمزنگاری"),
    "circle": MessageLookupByLibrary.simpleMessage("حلقه"),
    "clear": MessageLookupByLibrary.simpleMessage("پاک کردن"),
    "clearAllRulesAndScripts": MessageLookupByLibrary.simpleMessage(
      "پاک کردن همه قواعد و اسکریپت‌ها",
    ),
    "clearAllRulesAndScriptsTip": MessageLookupByLibrary.simpleMessage(
      "قواعد بازنویسی همه پروفایل‌ها و اسکریپت‌های سراسری حذف می‌شوند. این کار بازگشت‌ناپذیر است.",
    ),
    "clearCacheDesc": MessageLookupByLibrary.simpleMessage(
      "آیا حافظه پنهان FakeIP و DNS پاکسازی شود؟",
    ),
    "clearCacheTitle": MessageLookupByLibrary.simpleMessage(
      "پاکسازی حافظه پنهان",
    ),
    "clearData": MessageLookupByLibrary.simpleMessage("پاکسازی داده‌ها"),
    "clearDataTipDesc": MessageLookupByLibrary.simpleMessage(
      "این عملیات تمامی تنظیمات برنامه را بازنشانی می‌کند. آیا مطمئن هستید؟",
    ),
    "clearDataTipTitle": MessageLookupByLibrary.simpleMessage("عملیات حساس"),
    "clearInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "پاک‌سازی گره‌های غیرقابل‌استفاده",
    ),
    "clearedInvalidCount": m8,
    "clipboard": MessageLookupByLibrary.simpleMessage("حافظه موقت"),
    "clipboardDesc": MessageLookupByLibrary.simpleMessage(
      "دریافت خودکار لینک از حافظه موقت",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "خروجی به حافظه موقت",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "وارد کردن از حافظه موقت",
    ),
    "close": MessageLookupByLibrary.simpleMessage("بستن"),
    "closeAll": MessageLookupByLibrary.simpleMessage("بستن همه"),
    "color": MessageLookupByLibrary.simpleMessage("رنگ"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("پالت‌های رنگی"),
    "columns": MessageLookupByLibrary.simpleMessage("تعداد ستون‌ها"),
    "compatible": MessageLookupByLibrary.simpleMessage("حالت سازگاری"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی برخی ویژگی‌ها جهت سازگاری کامل با Clash",
    ),
    "concurrencyLimit": MessageLookupByLibrary.simpleMessage("محدودیت همزمانی"),
    "concurrencyLimitDesc": MessageLookupByLibrary.simpleMessage(
      "حداکثر تعداد تست همزمان تاخیر",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("تایید"),
    "confirmClearInvalid": MessageLookupByLibrary.simpleMessage(
      "همه IPهای مسکونی که در بررسی ناموفق بودند پاک شوند؟",
    ),
    "confirmDelete": MessageLookupByLibrary.simpleMessage("تأیید حذف"),
    "confirmDeleteNodeMsg": m9,
    "confirmImport": MessageLookupByLibrary.simpleMessage("تأیید درج"),
    "confirmPassword": MessageLookupByLibrary.simpleMessage("تأیید گذرواژه"),
    "connection": MessageLookupByLibrary.simpleMessage("اتصال فعال"),
    "connections": MessageLookupByLibrary.simpleMessage("اتصالات"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "مشاهده اتصالات فعال شبکه",
    ),
    "connectionsSort": MessageLookupByLibrary.simpleMessage(
      "مرتب‌سازی اتصال‌ها",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("وضعیت اتصال:"),
    "contactMe": MessageLookupByLibrary.simpleMessage("تماس با ما"),
    "content": MessageLookupByLibrary.simpleMessage("محتوا"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("پوسته محتوا"),
    "continent": MessageLookupByLibrary.simpleMessage("قاره"),
    "controlSecret": MessageLookupByLibrary.simpleMessage("رمز عبور کنترل"),
    "controlSecretDesc": MessageLookupByLibrary.simpleMessage(
      "رمز عبور دسترسی به RESTful API",
    ),
    "copiedPackageName": MessageLookupByLibrary.simpleMessage(
      "نام پکیج کپی شد",
    ),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "در کلیپ‌بورد کپی شد",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("کپی"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("کپی متغیرهای محیطی"),
    "copyLink": MessageLookupByLibrary.simpleMessage("کپی لینک"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("با موفقیت کپی شد"),
    "core": MessageLookupByLibrary.simpleMessage("هسته"),
    "coreConnected": MessageLookupByLibrary.simpleMessage("متصل شد"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("اطلاعات هسته"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("وضعیت هسته"),
    "coreSuspended": MessageLookupByLibrary.simpleMessage("معلق شد"),
    "country": MessageLookupByLibrary.simpleMessage("منطقه"),
    "countryOrRegion": MessageLookupByLibrary.simpleMessage("کشور / منطقه"),
    "crashTest": MessageLookupByLibrary.simpleMessage("تست خرابی"),
    "create": MessageLookupByLibrary.simpleMessage("ایجاد"),
    "createEmptyGroup": MessageLookupByLibrary.simpleMessage("ایجاد گروه خالی"),
    "createEmptyGroupDesc": MessageLookupByLibrary.simpleMessage(
      "ایجاد یک پیکربندی خالی جدید، با پشتیبانی از ورود دستی و مدیریت گره‌های خودمیزبان در همه پروتکل‌ها",
    ),
    "createEmptyGroupHint": MessageLookupByLibrary.simpleMessage(
      "پس از ایجاد گروه خالی، می‌توانید گره‌های هر پروتکل را به‌صورت دستی وارد کنید یا پیوندهای اشتراک را با یک کلیک به‌صورت دسته‌ای درج کنید.",
    ),
    "createGroupFailed": m10,
    "createGroupSuccess": m11,
    "creationTime": MessageLookupByLibrary.simpleMessage("زمان ایجاد"),
    "custom": MessageLookupByLibrary.simpleMessage("سفارشی"),
    "customConfigHintText": MessageLookupByLibrary.simpleMessage(
      "بخش کامل پیکربندی YAML یا JSON گره را اینجا وارد یا بچسبانید:",
    ),
    "customConfigLabel": MessageLookupByLibrary.simpleMessage(
      "پیکربندی سفارشی (YAML / JSON)",
    ),
    "customConfigNode": MessageLookupByLibrary.simpleMessage(
      "گره پیکربندی سفارشی",
    ),
    "customDashboardTitle": MessageLookupByLibrary.simpleMessage(
      "عنوان سفارشی",
    ),
    "customLandingProxyName": MessageLookupByLibrary.simpleMessage(
      "نام گره فرود سفارشی",
    ),
    "customNodesDefaultName": MessageLookupByLibrary.simpleMessage(
      "گره‌های شخصی",
    ),
    "customPreProxyName": MessageLookupByLibrary.simpleMessage(
      "نام گره مقدماتی سفارشی",
    ),
    "customScriptOptions": MessageLookupByLibrary.simpleMessage(
      "قوانین سفارشی",
    ),
    "customUrl": MessageLookupByLibrary.simpleMessage("آدرس URL سفارشی"),
    "cut": MessageLookupByLibrary.simpleMessage("برش"),
    "dark": MessageLookupByLibrary.simpleMessage("تاریک"),
    "darkIcon": MessageLookupByLibrary.simpleMessage("آیکون تاریک"),
    "darkIconDesc": MessageLookupByLibrary.simpleMessage(
      "تغییر آیکون برنامه به تم تاریک",
    ),
    "dashboard": MessageLookupByLibrary.simpleMessage("داشبورد"),
    "days": m12,
    "dedicatedGroup": MessageLookupByLibrary.simpleMessage(
      "ایجاد گروه اختصاصی پروکسی زنجیره‌ای",
    ),
    "dedicatedGroupDesc": MessageLookupByLibrary.simpleMessage(
      "کارت گروه سیاست مستقل «🔗 پروکسی زنجیره‌ای» را در صفحه پروکسی ایجاد می‌کند",
    ),
    "defaultDialerProxy": MessageLookupByLibrary.simpleMessage(
      "پرش ورودی پیش‌فرض",
    ),
    "defaultDialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "گره یا گروه سیاستی که پروکسی فرود به‌طور پیش‌فرض استفاده می‌کند (گروه انتخاب گره توصیه می‌شود)",
    ),
    "defaultGateway": MessageLookupByLibrary.simpleMessage("دروازه پیش‌فرض"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "سرور نام پیش‌فرض",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "برای تحلیل سرورهای DNS",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("مرتب‌سازی پیش‌فرض"),
    "defaultText": MessageLookupByLibrary.simpleMessage("پیش‌فرض"),
    "delay": MessageLookupByLibrary.simpleMessage("تاخیر"),
    "delayAnimation": MessageLookupByLibrary.simpleMessage("انیمیشن تست"),
    "delayAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "سفارشی‌سازی انیمیشن حین تست تاخیر",
    ),
    "delaySort": MessageLookupByLibrary.simpleMessage(
      "مرتب‌سازی بر اساس تاخیر",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("حذف"),
    "deleteMultipTip": m13,
    "deleteNode": MessageLookupByLibrary.simpleMessage("حذف گره"),
    "deleteTip": m14,
    "deleteTunnel": MessageLookupByLibrary.simpleMessage("حذف هدایت"),
    "desc": MessageLookupByLibrary.simpleMessage(
      "Fluxora یک کلاینت پروکسی بر پایه هسته قدرتمند و انعطاف‌پذیر Mihomo (Clash.Meta) با هدف تجربه کاربری برتر است. چشم‌انداز ما: Clear routes, calm control",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("نزولی"),
    "destination": MessageLookupByLibrary.simpleMessage("آدرس مقصد"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "موقعیت جغرافیایی مقصد",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("شناسه ASN مقصد"),
    "details": MessageLookupByLibrary.simpleMessage("جزئیات"),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "استفاده از API جانبی (صرفاً جهت اطلاع)",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("حالت توسعه‌دهنده"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "حالت توسعه‌دهنده فعال شد.",
    ),
    "diagnosticAdvice": MessageLookupByLibrary.simpleMessage(
      "پیشنهاد عیب‌یابی هوشمند",
    ),
    "dialerIp4pConvert": MessageLookupByLibrary.simpleMessage(
      "فعالسازی تبدیل IP4P",
    ),
    "dialerIp4pConvertDesc": MessageLookupByLibrary.simpleMessage(
      "فعالسازی تبدیل آدرس IP4P شماره‌گیر",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("مستقیم"),
    "directConnection": MessageLookupByLibrary.simpleMessage(
      "DIRECT (بدون پرش)",
    ),
    "directNameserver": MessageLookupByLibrary.simpleMessage("DNS مستقیم"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "برای تحلیل دامنه‌های خروجی مستقیم",
    ),
    "directNameserverFollowPolicy": MessageLookupByLibrary.simpleMessage(
      "DNS مستقیم از سیاست پیروی کند",
    ),
    "disableQuic": MessageLookupByLibrary.simpleMessage("غیرفعال‌سازی QUIC"),
    "disableQuicDesc": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی QUIC برای رفع مشکلات شبکه",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("سلب مسئولیت"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "این نرم‌افزار رایگان و متن‌باز است و صرفاً برای استفاده شخصی و آموزشی ارائه شده است.",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "نسخه جدیدی پیدا شد",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage("نسخه جدید یافت شد"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("تنظیمات مربوط به DNS"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("ربودن DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "هدایت استعلام‌های DNS به ماژول داخلی",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("حالت DNS"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "آیا می‌خواهید مجوز دهید برای:",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("سازمان / دامنه"),
    "domainName": MessageLookupByLibrary.simpleMessage("دامنه"),
    "doubleBounce": MessageLookupByLibrary.simpleMessage("جهش دوگانه"),
    "downLabel": MessageLookupByLibrary.simpleMessage("پایین"),
    "download": MessageLookupByLibrary.simpleMessage("دانلود"),
    "dozeSuspend": MessageLookupByLibrary.simpleMessage("پشتیبانی از Doze"),
    "dozeSuspendDesc": MessageLookupByLibrary.simpleMessage(
      "همگام‌سازی با حالت خواب سیستم (Doze)",
    ),
    "duplicateNodeSkipped": MessageLookupByLibrary.simpleMessage(
      "نام‌های تکراری نادیده گرفته شد (نام‌ها باید یکتا باشند)",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("ویرایش"),
    "editTunnel": MessageLookupByLibrary.simpleMessage("ویرایش هدایت"),
    "emptyLandingTip": MessageLookupByLibrary.simpleMessage(
      "هنوز گره فرود مسکونی وجود ندارد. فرمت‌های رایج ارائه‌دهندگان اصلی IP مسکونی (IPRoyal، LunaProxy، Oxylabs و دیگران) را برای درج با یک کلیک بچسبانید.",
    ),
    "emptyTip": m15,
    "enableChainProxy": MessageLookupByLibrary.simpleMessage(
      "فعال‌سازی پروکسی زنجیره‌ای",
    ),
    "enableChainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "عبور از گره ورودی برای رسیدن به پروکسی فرود، دور زدن محدودیت شبکه و حفظ خروج مسکونی واقعی",
    ),
    "enableCrashReport": MessageLookupByLibrary.simpleMessage("تحلیل خرابی‌ها"),
    "enableCrashReportDesc": MessageLookupByLibrary.simpleMessage(
      "ارسال گزارش خرابی در صورت لزوم",
    ),
    "enableOverride": MessageLookupByLibrary.simpleMessage("فعالسازی اورراید"),
    "enableProfileChain": MessageLookupByLibrary.simpleMessage(
      "فعال‌سازی پروکسی زنجیره‌ای این گروه اشتراک",
    ),
    "enableProfileChainDesc": MessageLookupByLibrary.simpleMessage(
      "پشتیبانی از رله گام‌به‌گام پروکسی مقدماتی و پیکربندی خروجی فرود نهایی",
    ),
    "enableTraySpeed": MessageLookupByLibrary.simpleMessage("نمایش سرعت شبکه"),
    "enableTraySpeedDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش سرعت آپلود و دانلود در نوار منو",
    ),
    "enableUdpForwarding": MessageLookupByLibrary.simpleMessage(
      "فعال‌سازی بازپخش UDP",
    ),
    "encryptBackup": MessageLookupByLibrary.simpleMessage("رمزگذاری پشتیبان"),
    "encryptBackupDesc": MessageLookupByLibrary.simpleMessage(
      "رمزگذاری محتوای پشتیبان با AES-256-GCM. گذرواژه ذخیره نمی‌شود؛ در صورت گم شدن، بازیابی ممکن نیست",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "ارتقای NAT",
    ),
    "endpointIndependentNatConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "فعالسازی Endpoint-Independent NAT ممکن است کارایی را اندکی کاهش دهد. تنها در صورت نیاز استفاده کنید",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "بهینه‌سازی تجربه برنامه‌های UDP و P2P",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("مورد"),
    "exclude": MessageLookupByLibrary.simpleMessage("پنهان‌سازی از پس‌زمینه"),
    "excludeChina": MessageLookupByLibrary.simpleMessage("استثنای چین"),
    "excludeChinaDesc": MessageLookupByLibrary.simpleMessage(
      "مجاز ساختن ترافیک QUIC چین به جای مسدودی کامل",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "پنهان کردن برنامه از لیست برنامه‌های اخیر",
    ),
    "existsTip": m16,
    "exit": MessageLookupByLibrary.simpleMessage("خروج"),
    "expand": MessageLookupByLibrary.simpleMessage("استاندارد"),
    "experimental": MessageLookupByLibrary.simpleMessage("ویژگی‌های آزمایشی"),
    "experimentalDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیمات آزمایشی با احتیاط استفاده شود",
    ),
    "expirationTime": MessageLookupByLibrary.simpleMessage("تاریخ انقضا"),
    "expired": MessageLookupByLibrary.simpleMessage("منقضی شده"),
    "export": MessageLookupByLibrary.simpleMessage("خروجی"),
    "exportFile": MessageLookupByLibrary.simpleMessage("خروجی فایل"),
    "exportLogs": MessageLookupByLibrary.simpleMessage(
      "خروجی گرفتن از گزارش‌ها",
    ),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "خروجی با موفقیت گرفته شد",
    ),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("حس‌آمیز"),
    "externalController": MessageLookupByLibrary.simpleMessage("کنترل خارجی"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "کنترل هسته از طریق پورت آنلاین",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("لینک خارجی"),
    "externalResources": MessageLookupByLibrary.simpleMessage("منابع خارجی"),
    "fadingCircle": MessageLookupByLibrary.simpleMessage("حلقه محوشونده"),
    "fadingFour": MessageLookupByLibrary.simpleMessage("چهار دایره محوشونده"),
    "failover": MessageLookupByLibrary.simpleMessage("جابه‌جایی خودکار"),
    "failoverEnableFirst": MessageLookupByLibrary.simpleMessage(
      "ابتدا پروکسی زنجیره‌ای را فعال کنید",
    ),
    "failoverFailed": m17,
    "failoverInProgress": MessageLookupByLibrary.simpleMessage(
      "در حال جابه‌جایی...",
    ),
    "failoverManualHint": MessageLookupByLibrary.simpleMessage(
      "هنگام تشخیص خطای زنجیره می‌توان به‌صورت دستی به نامزد پشتیبان تغییر داد",
    ),
    "failoverNoCandidates": MessageLookupByLibrary.simpleMessage(
      "هنوز نامزد پشتیبانی پیکربندی نشده است",
    ),
    "failoverNoCandidatesAdvice": MessageLookupByLibrary.simpleMessage(
      "ابتدا برای حداقل یکی از نقش‌های بالا نامزد پشتیبان اضافه کنید و سپس دوباره تلاش کنید",
    ),
    "failoverSuccess": m18,
    "failoverTrigger": MessageLookupByLibrary.simpleMessage("جابه‌جایی فوری"),
    "failoverTriggerReason": MessageLookupByLibrary.simpleMessage(
      "کاربر به‌صورت دستی جابه‌جایی را اجرا کرد",
    ),
    "fakeIpFilterMode": MessageLookupByLibrary.simpleMessage(
      "حالت فیلتر FakeIP",
    ),
    "fakeIpFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "تعیین حالت فیلتر FakeIP",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("لیست فیلتر FakeIP"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("محدوده FakeIP"),
    "fakeipRangeV6": MessageLookupByLibrary.simpleMessage("محدوده FakeIPv6"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("زمان اعتبار FakeIP"),
    "fallback": MessageLookupByLibrary.simpleMessage("فالبک DNS"),
    "fallbackConcurrent": MessageLookupByLibrary.simpleMessage(
      "استعلام همزمان فالبک",
    ),
    "fallbackConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "استعلام همزمان از DNS اصلی و فالبک",
    ),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده برای دامنه‌های خارجی",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("فیلتر فالبک"),
    "fcmOptimization": MessageLookupByLibrary.simpleMessage("بهینه‌سازی FCM"),
    "fcmOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "افزایش پایداری اتصال مستقیم FCM",
    ),
    "fcmTip": MessageLookupByLibrary.simpleMessage(
      "اتصال FCM به دستگاه شما بستگی دارد. برای نتایج دقیق‌تر، گزینه \'میانبر زدن VPN\' را غیرفعال کنید",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("فیدلیتی"),
    "fieldAbuse": MessageLookupByLibrary.simpleMessage("گزارش‌های سوءاستفاده"),
    "fieldAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "fieldBlocklists": MessageLookupByLibrary.simpleMessage("لیست‌های سیاه"),
    "fieldMarkers": MessageLookupByLibrary.simpleMessage("نشانه‌های خطر"),
    "fieldNativeType": MessageLookupByLibrary.simpleMessage("IP بومی"),
    "fieldScenarios": MessageLookupByLibrary.simpleMessage("امتیاز سناریوها"),
    "fieldScore": MessageLookupByLibrary.simpleMessage("امتیاز خلوص"),
    "fieldUnknownNotes": MessageLookupByLibrary.simpleMessage("ناشناخته‌ها"),
    "fieldUsageType": MessageLookupByLibrary.simpleMessage("نوع کاربری"),
    "file": MessageLookupByLibrary.simpleMessage("فایل"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "آپلود فایل پروفایل از حافظه",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "فایل تغییر یافته است. آیا ذخیره شود؟",
    ),
    "filterAll": MessageLookupByLibrary.simpleMessage("همه"),
    "filterError": MessageLookupByLibrary.simpleMessage("خطا/بررسی‌نشده"),
    "filterHealthy": MessageLookupByLibrary.simpleMessage("فقط قابل‌استفاده"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage(
      "فیلتر برنامه‌های سیستم",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("جستجوی پردازش"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "امکان جستجو و تطبیق پردازش‌ها",
    ),
    "flagged": MessageLookupByLibrary.simpleMessage("نشانه‌گذاری‌شده"),
    "followMainSelector": MessageLookupByLibrary.simpleMessage(
      "پیروی از گروه انتخاب گره فعلی (توصیه‌شده)",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("فونت"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("نگاشت اجباری DNS"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "نگاشت اجباری نتایج DNS به اتصالات",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("دامنه‌های اجباری"),
    "forceGCDesc": MessageLookupByLibrary.simpleMessage(
      "آیا آزادسازی اجباری حافظه هسته انجام شود؟ (ازمایشی)",
    ),
    "forceGCTitle": MessageLookupByLibrary.simpleMessage(
      "پاکسازی اجباری حافظه",
    ),
    "formatError": MessageLookupByLibrary.simpleMessage(
      "لطفاً صحت فرمت را بررسی کنید",
    ),
    "fourColumns": MessageLookupByLibrary.simpleMessage("۴ ستون"),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("سالاد میوه"),
    "general": MessageLookupByLibrary.simpleMessage("عمومی"),
    "generalCardCoreDesc": MessageLookupByLibrary.simpleMessage(
      "هسته همیشه روی لوپ‌بک گوش می‌دهد تا کارت بتواند وصل شود",
    ),
    "generalCardCoreTitle": MessageLookupByLibrary.simpleMessage(
      "دسترسی کارت به هسته",
    ),
    "generalDesc": MessageLookupByLibrary.simpleMessage("تغییر تنظیمات عمومی"),
    "generalKeepService": MessageLookupByLibrary.simpleMessage(
      "حفظ سرویس هنگام راه‌اندازی دوباره هسته",
    ),
    "generalKeepServiceDesc": MessageLookupByLibrary.simpleMessage(
      "خاموش: سرویس از هسته پیروی می‌کند و اعلان موقتاً قطع را نشان می‌دهد",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "تولید از کلید خصوصی",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("تولید"),
    "geoData": MessageLookupByLibrary.simpleMessage("داده‌های جغرافیایی"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "کاهش مصرف حافظه GEO",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از لودر کم‌مصرف داده‌های GEO",
    ),
    "geodataUse": MessageLookupByLibrary.simpleMessage("بارگذاری GEO"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("کد GeoIP"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage(
      "دریافت قوانین اصلی",
    ),
    "global": MessageLookupByLibrary.simpleMessage("سراسر جهان"),
    "go": MessageLookupByLibrary.simpleMessage("رفتن"),
    "goDownload": MessageLookupByLibrary.simpleMessage("رفتن به دانلود"),
    "groupName": MessageLookupByLibrary.simpleMessage("نام گروه"),
    "harmonyFont": MessageLookupByLibrary.simpleMessage("ترمیم فونت"),
    "harmonyFontDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از فونت داخلی برای رفع مشکلات نمایش",
    ),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "آیا تغییرات ذخیره شوند؟",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("بررسی دسترس‌پذیری"),
    "healthCheckAll": MessageLookupByLibrary.simpleMessage("بررسی کامل"),
    "healthCheckTimeout": MessageLookupByLibrary.simpleMessage(
      "مهلت زمانی تست",
    ),
    "healthCheckTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "مهلت زمانی تست سلامت نودها",
    ),
    "healthError": MessageLookupByLibrary.simpleMessage(
      "خطا و غیرقابل‌استفاده",
    ),
    "healthHealthy": MessageLookupByLibrary.simpleMessage(
      "سالم و قابل‌استفاده",
    ),
    "healthReport": MessageLookupByLibrary.simpleMessage(
      "گزارش اتصال IP مسکونی",
    ),
    "healthUntested": MessageLookupByLibrary.simpleMessage("بررسی‌نشده"),
    "healthWarning": MessageLookupByLibrary.simpleMessage("تا حدی محدود"),
    "heapObjects": MessageLookupByLibrary.simpleMessage("Objects"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "پنهان‌سازی گره‌های تایم‌اوت",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "گره‌هایی که آخرین آزمون تأخیرشان تایم‌اوت شد نمایش داده نشوند",
    ),
    "highPriority": MessageLookupByLibrary.simpleMessage("اولویت بالا"),
    "highPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "افزایش اولویت پردازش برنامه و هسته",
    ),
    "highRefreshRate": MessageLookupByLibrary.simpleMessage("نرخ نوسازی بالا"),
    "highRefreshRateDesc": MessageLookupByLibrary.simpleMessage(
      "فعالسازی حداکثر نرخ نوسازی صفحه نمایش",
    ),
    "hop": MessageLookupByLibrary.simpleMessage("پرش"),
    "host": MessageLookupByLibrary.simpleMessage("هاست"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage(
      "افزودن Hosts به پروفایل فعلی",
    ),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("تداخل کلید میانبر"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "مدیریت کلیدهای میانبر",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "کنترل برنامه با صفحه کلید",
    ),
    "hours": m19,
    "httpPortSniffer": MessageLookupByLibrary.simpleMessage("اسنیف پورت HTTP"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("هدایت ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "پشتیبانی از پینگ ICMP در صورت فعال بودن",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("تصویر"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage("تنظیمات تصویر"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("سبک آیکون"),
    "import": MessageLookupByLibrary.simpleMessage("وارد کردن"),
    "importFailed": MessageLookupByLibrary.simpleMessage(
      "وارد کردن ناموفق بود",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("وارد کردن از فایل"),
    "importFromCode": MessageLookupByLibrary.simpleMessage(
      "وارد کردن از طریق کد",
    ),
    "importFromURL": MessageLookupByLibrary.simpleMessage("وارد کردن از URL"),
    "importShareLinks": MessageLookupByLibrary.simpleMessage(
      "درج پیوندهای اشتراک",
    ),
    "importSuccessCount": m20,
    "importUrl": MessageLookupByLibrary.simpleMessage("وارد کردن از URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("نامحدود"),
    "inheritDefaultDialer": MessageLookupByLibrary.simpleMessage(
      "ارث‌بری پرش پیش‌فرض سراسری",
    ),
    "init": MessageLookupByLibrary.simpleMessage("راه‌اندازی اولیه"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "لطفاً کلید میانبر معتبری وارد کنید",
    ),
    "inputProxyTextHint": MessageLookupByLibrary.simpleMessage(
      "اطلاعات IP مسکونی را بچسبانید، مثلاً:\n198.51.100.1:8000:username:password\nیا socks5://user:pass@198.51.100.1:8000\nاز چسباندن چندخطی به‌صورت دسته‌ای پشتیبانی می‌کند",
    ),
    "installTime": MessageLookupByLibrary.simpleMessage("زمان نصب"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "انتخاب هوشمند",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("اینترنت"),
    "interval": MessageLookupByLibrary.simpleMessage("فاصله زمانی"),
    "intranetAndGateway": MessageLookupByLibrary.simpleMessage(
      "شبکه داخلی و دروازه",
    ),
    "intranetIP": MessageLookupByLibrary.simpleMessage("IP شبکه محلی"),
    "invalidIpFormat": MessageLookupByLibrary.simpleMessage(
      "فرمت IP یا CIDR نامعتبر است",
    ),
    "ipAddress": MessageLookupByLibrary.simpleMessage("آدرس IP"),
    "ipCheckCoreNotReady": MessageLookupByLibrary.simpleMessage(
      "هسته آماده نیست",
    ),
    "ipCheckTimeout": MessageLookupByLibrary.simpleMessage("گره پاسخ نمی‌دهد"),
    "ipClickBehavior": MessageLookupByLibrary.simpleMessage("تغییر نمایش"),
    "ipPrivacyProtection": MessageLookupByLibrary.simpleMessage(
      "پنهان‌سازی IP",
    ),
    "ipRiskAbuse": MessageLookupByLibrary.simpleMessage("گزارش‌های سوءاستفاده"),
    "ipRiskBlocklists": MessageLookupByLibrary.simpleMessage(
      "فهرست‌های مسدودسازی",
    ),
    "ipRiskBogon": MessageLookupByLibrary.simpleMessage("آدرس رزروشده"),
    "ipRiskEnable": MessageLookupByLibrary.simpleMessage("فعال‌سازی استعلام"),
    "ipRiskFactors": MessageLookupByLibrary.simpleMessage("عوامل امتیاز"),
    "ipRiskFailed": MessageLookupByLibrary.simpleMessage("استعلام ناموفق بود"),
    "ipRiskFieldsTitle": MessageLookupByLibrary.simpleMessage(
      "سفارشی‌سازی فیلدها",
    ),
    "ipRiskHosting": MessageLookupByLibrary.simpleMessage("میزبانی/دیتاسنتر"),
    "ipRiskIntel": MessageLookupByLibrary.simpleMessage("اطلاعات ریسک IP"),
    "ipRiskLimits": MessageLookupByLibrary.simpleMessage(
      "آنچه این داده نمی‌تواند بگوید",
    ),
    "ipRiskMobile": MessageLookupByLibrary.simpleMessage("شبکه موبایل"),
    "ipRiskNativeType": MessageLookupByLibrary.simpleMessage("IP بومی"),
    "ipRiskNotFlagged": MessageLookupByLibrary.simpleMessage("یافت نشد"),
    "ipRiskOpenReport": MessageLookupByLibrary.simpleMessage(
      "باز کردن گزارش کامل",
    ),
    "ipRiskPrivacyNote": MessageLookupByLibrary.simpleMessage(
      "IP شما به شخص ثالث ارسال می‌شود (بدون سیاست حفظ حریم خصوصی)",
    ),
    "ipRiskProxy": MessageLookupByLibrary.simpleMessage("پروکسی"),
    "ipRiskRelay": MessageLookupByLibrary.simpleMessage("رله"),
    "ipRiskScenarios": MessageLookupByLibrary.simpleMessage("امتیاز سناریوها"),
    "ipRiskScore": MessageLookupByLibrary.simpleMessage("امتیاز خلوص منبع"),
    "ipRiskSearchEngineBot": MessageLookupByLibrary.simpleMessage(
      "ربات موتور جستجو",
    ),
    "ipRiskStale": MessageLookupByLibrary.simpleMessage(
      "داده قدیمی (غیر واقعی)",
    ),
    "ipRiskTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipRiskUnknownNotes": MessageLookupByLibrary.simpleMessage(
      "محدودیت‌های ناشناخته",
    ),
    "ipRiskVerdict": MessageLookupByLibrary.simpleMessage("ارزیابی"),
    "ipRiskVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP / ماسک"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "دریافت ترافیک IPv6 فعال باشد",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "ورودی IPv6 مجاز باشد",
    ),
    "isp": MessageLookupByLibrary.simpleMessage("ارائه‌دهنده اینترنت"),
    "itemsCount": m21,
    "jcLabel": MessageLookupByLibrary.simpleMessage("Jc (تعداد بسته‌های زائد)"),
    "juicityPassword": MessageLookupByLibrary.simpleMessage(
      "رمز عبور Juicity (UUID را در بالا وارد کنید)",
    ),
    "just": MessageLookupByLibrary.simpleMessage("همین الان"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "فاصله زمانی TCP Keep-Alive",
    ),
    "key": MessageLookupByLibrary.simpleMessage("کلید"),
    "lanShareAddress": MessageLookupByLibrary.simpleMessage("نشانی اشتراک LAN"),
    "landingProxies": MessageLookupByLibrary.simpleMessage(
      "گره‌های فرود مسکونی",
    ),
    "landingProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ ورود دستی نام گره فرود...",
    ),
    "landingProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "هیچ (استفاده از گره اشتراک به‌عنوان خروجی نهایی)",
    ),
    "landingProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "گره اشتراک به‌عنوان گام پروکسی مقدماتی عمل می‌کند و این گره به خروجی نهایی تبدیل می‌شود. برای پنهان‌سازی IP فرودگاه، زنجیره‌کردن WARP برای جلوگیری از مسدودسازی و بازکردن AI و استریم کاربرد دارد.",
    ),
    "landingProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "۲. پروکسی فرود",
    ),
    "language": MessageLookupByLibrary.simpleMessage("زبان"),
    "lastEdit": MessageLookupByLibrary.simpleMessage("آخرین ویرایش"),
    "layout": MessageLookupByLibrary.simpleMessage("چیدمان"),
    "leftClickBehavior": MessageLookupByLibrary.simpleMessage("کلیک چپ"),
    "legacyBackup": MessageLookupByLibrary.simpleMessage("پشتیبان قدیمی"),
    "light": MessageLookupByLibrary.simpleMessage("روشن"),
    "limitedUnlock": MessageLookupByLibrary.simpleMessage("فقط اختصاصی"),
    "lineWrap": MessageLookupByLibrary.simpleMessage("شکستن خطوط"),
    "list": MessageLookupByLibrary.simpleMessage("فهرست"),
    "listen": MessageLookupByLibrary.simpleMessage("شنود"),
    "local": MessageLookupByLibrary.simpleMessage("محلی"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری داده‌ها در فایل محلی",
    ),
    "localFile": MessageLookupByLibrary.simpleMessage("فایل محلی"),
    "localIpLabel": MessageLookupByLibrary.simpleMessage("IP محلی"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "بازیابی داده‌ها از فایل محلی",
    ),
    "locate": MessageLookupByLibrary.simpleMessage("موقعیت"),
    "log": MessageLookupByLibrary.simpleMessage("گزارش"),
    "logLevel": MessageLookupByLibrary.simpleMessage("سطح گزارش"),
    "logcat": MessageLookupByLibrary.simpleMessage("ثبت گزارش‌ها"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش ورودی گزارش‌ها در صورت فعال بودن",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("گزارش‌ها"),
    "logsDesc": MessageLookupByLibrary.simpleMessage(
      "مشاهده گزارش‌های ثبت شده",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("تست گزارش‌ها"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "ابزار رفع محدودیت Loopback",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "رفع محدودیت Loopback برای برنامه‌های UWP",
    ),
    "loopbackProtection": MessageLookupByLibrary.simpleMessage(
      "محافظت در برابر لوپ‌بک",
    ),
    "loopbackProtectionDesc": MessageLookupByLibrary.simpleMessage(
      "مسدودسازی ترافیک لوپ‌بک ناشی از خطای شبکه",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("باز"),
    "manualAddNode": MessageLookupByLibrary.simpleMessage("افزودن دستی گره"),
    "manualEntry": MessageLookupByLibrary.simpleMessage("ورود دستی"),
    "manualRefreshIp": MessageLookupByLibrary.simpleMessage("دریافت مجدد IP"),
    "maximize": MessageLookupByLibrary.simpleMessage("بزرگ کردن"),
    "mediaUnlock": MessageLookupByLibrary.simpleMessage("تست اتصال"),
    "mediaUnlockColorfulIcons": MessageLookupByLibrary.simpleMessage(
      "نمایش آیکون‌های رنگی به‌صورت پیش‌فرض",
    ),
    "mediaUnlockDetails": MessageLookupByLibrary.simpleMessage(
      "جزئیات تست اتصال",
    ),
    "mediaUnlockDisplaySettings": MessageLookupByLibrary.simpleMessage(
      "تنظیمات نمایش",
    ),
    "mediaUnlockExtraDetails": MessageLookupByLibrary.simpleMessage(
      "نمایش جزئیات بیشتر IP",
    ),
    "mediaUnlockMiscSettings": MessageLookupByLibrary.simpleMessage(
      "تنظیمات متفرقه",
    ),
    "mediaUnlockPinnedSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "امکان انتخاب حداکثر ۴ مورد برای پین کردن در ویجت",
    ),
    "mediaUnlockRefreshOnNodeChange": MessageLookupByLibrary.simpleMessage(
      "به‌روزرسانی خودکار هنگام تغییر گره",
    ),
    "mediaUnlockSelectLimit": MessageLookupByLibrary.simpleMessage(
      "حداکثر می‌توانید ۴ مورد را انتخاب کنید",
    ),
    "mediaUnlocked": MessageLookupByLibrary.simpleMessage("قفل‌گشایی شده"),
    "memoryAndRuntime": MessageLookupByLibrary.simpleMessage(
      "حافظه و زمان اجرا",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("اطلاعات حافظه"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "مقادیر حافظه نشان داده شده صرفاً مربوط به حافظه دینامیک هسته بوده و تمام حافظه برنامه نیست (جهت اطلاع).",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("تست پیام"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "این یک پیام تستی است.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("حداقل"),
    "minimize": MessageLookupByLibrary.simpleMessage("کوچک کردن"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "مینیمایز هنگام خروج",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "تغییر رفتار پیش‌فرض بستن окно",
    ),
    "minutes": m22,
    "mixedPort": MessageLookupByLibrary.simpleMessage("پورت ترکیبی (Mixed)"),
    "mode": MessageLookupByLibrary.simpleMessage("حالت"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("تک‌رنگ"),
    "months": m23,
    "more": MessageLookupByLibrary.simpleMessage("بیشتر"),
    "moreIpInfo": MessageLookupByLibrary.simpleMessage("اطلاعات بیشتر IP"),
    "name": MessageLookupByLibrary.simpleMessage("نام"),
    "nameSort": MessageLookupByLibrary.simpleMessage("مرتب‌سازی بر اساس نام"),
    "nameserver": MessageLookupByLibrary.simpleMessage("سرور نام (Nameserver)"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "برای تحلیل دامنه‌ها",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("سیاست سرور نام"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "تعیین سیاست DNS برای دامنه‌ها",
    ),
    "navBarHapticFeedback": MessageLookupByLibrary.simpleMessage(
      "بازخورد لمسی",
    ),
    "navBarHapticFeedbackDesc": MessageLookupByLibrary.simpleMessage(
      "لرزش هنگام تغییر زبانه‌های نوار پایین",
    ),
    "navConnections": MessageLookupByLibrary.simpleMessage("اتصالات"),
    "navTools": MessageLookupByLibrary.simpleMessage("ابزارها"),
    "network": MessageLookupByLibrary.simpleMessage("شبکه"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("تغییر تنظیمات شبکه"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("تست شبکه"),
    "networkDetectionUrl": MessageLookupByLibrary.simpleMessage(
      "نشانی تشخیص شبکه",
    ),
    "networkErrorRetryLater": MessageLookupByLibrary.simpleMessage(
      "خطای شبکه، لطفاً بعداً دوباره امتحان کنید",
    ),
    "networkFix": MessageLookupByLibrary.simpleMessage("ترمیم شبکه"),
    "networkFixDesc": MessageLookupByLibrary.simpleMessage(
      "رفع مشکل آیکون کره زمین شبکه سیستم",
    ),
    "networkInterface": MessageLookupByLibrary.simpleMessage("رابط"),
    "networkLabel": MessageLookupByLibrary.simpleMessage("لایه انتقال"),
    "networkMatch": MessageLookupByLibrary.simpleMessage("تطبیق شبکه"),
    "networkMatchHint": MessageLookupByLibrary.simpleMessage(
      "IP یا CIDR یا Gateway:IP/CIDR",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("سرعت شبکه"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "اعلان سرعت",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش سرعت شبکه و اشتراک در نوار اعلان",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("نوع شبکه"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("خنثی"),
    "noAnimation": MessageLookupByLibrary.simpleMessage("پیش‌فرض"),
    "noBackupFileFound": MessageLookupByLibrary.simpleMessage(
      "فایل پشتیبان پیدا نشد",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("داده‌ای موجود نیست"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("بدون کلید میانبر"),
    "noIcon": MessageLookupByLibrary.simpleMessage("بدون آیکون"),
    "noInfo": MessageLookupByLibrary.simpleMessage("اطلاعاتی موجود نیست"),
    "noInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "در حال حاضر گره نامعتبر غیرقابل‌استفاده‌ای وجود ندارد",
    ),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage(
      "اطلاعات بیشتری موجود نیست",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("بدون شبکه"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage(
      "برنامه‌های بدون شبکه",
    ),
    "noNodesInGroup": MessageLookupByLibrary.simpleMessage(
      "هنوز گرهی در این گروه وجود ندارد",
    ),
    "noNodesInGroupHint": MessageLookupByLibrary.simpleMessage(
      "روی «افزودن دستی گره» در پایین‌راست یا «درج دسته‌ای پیوندها» در بالا‌راست ضربه بزنید",
    ),
    "noProfileInEffect": MessageLookupByLibrary.simpleMessage(
      "هیچ پیکربندی فعالی وجود ندارد",
    ),
    "noProxy": MessageLookupByLibrary.simpleMessage("بدون پروکسی"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "لطفاً یک پروفایل معتبر ایجاد یا اضافه کنید",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("عدم تحلیل IP"),
    "noStatusAvailable": MessageLookupByLibrary.simpleMessage(
      "وضعیتی یافت نشد",
    ),
    "noUsageData": MessageLookupByLibrary.simpleMessage("بدون آمار مصرف"),
    "nodeAdded": m24,
    "nodeDeleted": m25,
    "nodeDetailCancel": MessageLookupByLibrary.simpleMessage("لغو"),
    "nodeDetailClose": MessageLookupByLibrary.simpleMessage("بستن"),
    "nodeDetailCopied": MessageLookupByLibrary.simpleMessage("کپی شد"),
    "nodeDetailCopyConfig": MessageLookupByLibrary.simpleMessage(
      "کپی پیکربندی",
    ),
    "nodeDetailEdit": MessageLookupByLibrary.simpleMessage("ویرایش"),
    "nodeDetailEditTitle": m26,
    "nodeDetailMissing": MessageLookupByLibrary.simpleMessage(
      "پیکربندی اصلی این گره پیدا نشد — شاید از یک گروه آمده یا با به‌روزرسانی اشتراک جایگزین شده",
    ),
    "nodeDetailModified": MessageLookupByLibrary.simpleMessage("تغییر یافته"),
    "nodeDetailRestore": MessageLookupByLibrary.simpleMessage("بازگردانی اصلی"),
    "nodeDetailRestored": MessageLookupByLibrary.simpleMessage(
      "پیکربندی اصلی بازگردانده شد؛ هسته را دوباره راه‌اندازی کنید",
    ),
    "nodeDetailSave": MessageLookupByLibrary.simpleMessage("ذخیره"),
    "nodeDetailSaved": MessageLookupByLibrary.simpleMessage(
      "ذخیره شد؛ برای اعمال، هسته را دوباره راه‌اندازی کنید",
    ),
    "nodeExclusion": MessageLookupByLibrary.simpleMessage("استثنای نودها"),
    "nodeExclusionDesc": MessageLookupByLibrary.simpleMessage(
      "حذف نودهای مطابقت یافته با عبارت",
    ),
    "nodeExclusionPlaceholder": MessageLookupByLibrary.simpleMessage(
      "HK|ایران|🇮🇷",
    ),
    "nodeManagement": m27,
    "nodeName": MessageLookupByLibrary.simpleMessage("نام گره"),
    "nodeNameHint": m28,
    "nodeNameLabel": MessageLookupByLibrary.simpleMessage("نام گره"),
    "nodeProtocol": MessageLookupByLibrary.simpleMessage("پروتکل گره"),
    "none": MessageLookupByLibrary.simpleMessage("هیچکدام"),
    "notRecommended": MessageLookupByLibrary.simpleMessage("توصیه نمی‌شود"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "گروه پروکسی فعلی قابل انتخاب نیست",
    ),
    "notUnlocked": MessageLookupByLibrary.simpleMessage("مسدود"),
    "notificationHighPriority": MessageLookupByLibrary.simpleMessage(
      "اولویت بالا",
    ),
    "notificationHighPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیم نوار اعلان به اولویت بالا در پیش‌زمینه",
    ),
    "notificationHighPriorityTip": MessageLookupByLibrary.simpleMessage(
      "اعلان‌های با اولویت بالا می‌توانند مشکلات زنده نگه داشتن پس‌زمینه را در برخی سیستم‌ها کاهش دهند. اگر سرویس شما به درستی کار می‌کند، پیشنهاد می‌شود خاموش بماند. آیا فعال شود؟",
    ),
    "ntp": MessageLookupByLibrary.simpleMessage("همگام‌سازی زمان NTP"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از سرویس زمان NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("فاصله بروزرسانی"),
    "ntpPort": MessageLookupByLibrary.simpleMessage("پورت"),
    "ntpServer": MessageLookupByLibrary.simpleMessage("سرور"),
    "ntpStatus": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "فعالسازی سرویس زمان NTP",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "هیچ پروفایلی یافت نشد. لطفاً یکی اضافه کنید",
    ),
    "nullTip": m29,
    "numberTip": m30,
    "obfsModeLabel": MessageLookupByLibrary.simpleMessage("حالت پنهان‌سازی"),
    "obfsNoneOff": MessageLookupByLibrary.simpleMessage("هیچ (خاموش)"),
    "officialCommunity": MessageLookupByLibrary.simpleMessage("جامعه رسمی"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("۱ ستون"),
    "onlinePanel": MessageLookupByLibrary.simpleMessage("پنل آنلاین"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("فقط آیکون"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage(
      "فقط برنامه‌های جانبی",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "آمار ترافیک پروکسی",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "محاسبه ترافیک فقط برای پروکسی‌ها",
    ),
    "openDashboard": MessageLookupByLibrary.simpleMessage("باز کردن Zashboard"),
    "openGateway": MessageLookupByLibrary.simpleMessage("باز کردن دروازه"),
    "openSettings": MessageLookupByLibrary.simpleMessage("باز کردن تنظیمات"),
    "operatorOrAsn": MessageLookupByLibrary.simpleMessage("سازمان / ASN"),
    "options": MessageLookupByLibrary.simpleMessage("گزینه‌ها"),
    "other": MessageLookupByLibrary.simpleMessage("سایر"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "مشارکت‌کنندگان دیگر (ترتیب تصادفی)",
    ),
    "otherSettings": MessageLookupByLibrary.simpleMessage("ابزارهای پیشرفته"),
    "otherSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "تغییر تنظیمات ابزارهای پیشرفته",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("حالت خروجی"),
    "override": MessageLookupByLibrary.simpleMessage("اورراید"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage(
      "اورراید تنظیمات پروکسی",
    ),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "جایگزینی آدرس مقصد",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از نتیجه اسنیفر برای آدرس مقصد",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("اورراید DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "جایگزینی تنظیمات DNS پروفایل",
    ),
    "overrideExperimental": MessageLookupByLibrary.simpleMessage(
      "اورراید تنظیمات آزمایشی",
    ),
    "overrideExperimentalDesc": MessageLookupByLibrary.simpleMessage(
      "جایگزینی تنظیمات آزمایشی پروفایل",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "در حالت اسکریپت اعمال نمی‌شود",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("اورراید NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "جایگزینی تنظیمات NTP پروفایل",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "جایگزینی قوانین اصلی",
    ),
    "overrideSniffer": MessageLookupByLibrary.simpleMessage("اورراید Sniffer"),
    "overrideSnifferDesc": MessageLookupByLibrary.simpleMessage(
      "جایگزینی تنظیمات Sniffer پروفایل",
    ),
    "overrideTestUrl": MessageLookupByLibrary.simpleMessage(
      "جایگزینی آدرس تست",
    ),
    "overrideTunnel": MessageLookupByLibrary.simpleMessage("اورراید تونل"),
    "overrideTunnelDesc": MessageLookupByLibrary.simpleMessage(
      "جایگزینی تنظیمات تونل پروفایل",
    ),
    "packageListPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "مجوز رد شد. امکان دسترسی به لیست برنامه‌ها وجود ندارد.",
    ),
    "packageListPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "برای دسترسی به لیست برنامه‌ها مجوز لازم است. آیا موافقید؟",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("پالت"),
    "parseNoValidNode": MessageLookupByLibrary.simpleMessage(
      "اطلاعات پروکسی معتبری یافت نشد. لطفاً فرمت را بررسی کنید",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage(
      "تحلیل اتصالات IP خالص",
    ),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "تحلیل اتصالات مستقیم IP",
    ),
    "password": MessageLookupByLibrary.simpleMessage("رمز عبور"),
    "passwordAuth": MessageLookupByLibrary.simpleMessage("رمز عبور"),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage(
      "گذرواژه‌ها مطابقت ندارند",
    ),
    "paste": MessageLookupByLibrary.simpleMessage("جایگذاری"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage(
      "چسباندن از کلیپ‌بورد",
    ),
    "peerPublicKey": MessageLookupByLibrary.simpleMessage("کلید عمومی همتا"),
    "pickerLatency": MessageLookupByLibrary.simpleMessage("تأخیر"),
    "pickerName": MessageLookupByLibrary.simpleMessage("نام"),
    "pickerNoDelay": MessageLookupByLibrary.simpleMessage(
      "تأخیری نیست — تا اندازه‌گیری، مرتب‌سازی بر اساس نام",
    ),
    "pickerProbing": MessageLookupByLibrary.simpleMessage("در حال سنجش تأخیر…"),
    "pickerSmart": MessageLookupByLibrary.simpleMessage("هوشمند"),
    "pin": MessageLookupByLibrary.simpleMessage("پین"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "لطفاً به WebDAV متصل شوید",
    ),
    "pleaseCloseSystemProxyFirst": MessageLookupByLibrary.simpleMessage(
      "لطفاً ابتدا پروکسی سیستم را غیرفعال کنید",
    ),
    "pleaseCloseTunFirst": MessageLookupByLibrary.simpleMessage(
      "لطفاً ابتدا حالت TUN را غیرفعال کنید",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "لطفاً نام اسکریپت را وارد کنید",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "لطفاً رمز عبور Admin را وارد کنید",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "لطفاً فایل را آپلود کنید",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "لطفاً تصویر کد QR معتبری آپلود کنید",
    ),
    "port": MessageLookupByLibrary.simpleMessage("پورت"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "لطفاً پورت غیرتکراری وارد کنید",
    ),
    "portFallback": MessageLookupByLibrary.simpleMessage("جایگزینی پورت"),
    "portFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "اگر پورت تنظیم‌شده اشغال باشد، از پورت دیگری استفاده کن",
    ),
    "portFallbackNotice": m31,
    "portLabel": MessageLookupByLibrary.simpleMessage("پورت"),
    "portTip": m32,
    "powerSwitch": MessageLookupByLibrary.simpleMessage("کلید روشن/خاموش"),
    "preProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ ورود دستی نام گره مقدماتی...",
    ),
    "preProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "هیچ (اتصال مستقیم به گره اشتراک)",
    ),
    "preProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "پیش از ورود ترافیک به گره اشتراک، ابتدا از طریق گره مقدماتی تونل‌زده و رله می‌شود. برای نجات گره‌های مسدودشده کاربرد دارد.",
    ),
    "preProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "۱. پروکسی مقدماتی",
    ),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "اولویت استفاده از HTTP/3 در DoH",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "لطفاً کلید را فشار دهید",
    ),
    "preventDnsLeak": MessageLookupByLibrary.simpleMessage(
      "جلوگیری از نشت DNS",
    ),
    "preventDnsLeakDesc": MessageLookupByLibrary.simpleMessage(
      "DNS در داخل تونل حل می‌شود و resolverهای روتر یا ISP با DoH عمومی جایگزین می‌شوند.",
    ),
    "preventWebRtcLeak": MessageLookupByLibrary.simpleMessage(
      "جلوگیری از نشت IP واقعی WebRTC",
    ),
    "preventWebRtcLeakDesc": MessageLookupByLibrary.simpleMessage(
      "کاوش‌های STUN/TURN را مسدود می‌کند تا افشای IP عمومی واقعی متوقف شود و امنیت حساب‌های خارجی و تجارت الکترونیک فرامرزی حفظ گردد",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("پیش‌نمایش"),
    "privateIp": MessageLookupByLibrary.simpleMessage(
      "آدرس IP خصوصی / شبکه محلی",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("کلید خصوصی"),
    "profile": MessageLookupByLibrary.simpleMessage("پروفایل"),
    "profileAndRules": MessageLookupByLibrary.simpleMessage("پروفایل و قوانین"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "لطفاً فرمت زمان معتبری وارد کنید",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("لطفاً فاصله زمانی را وارد کنید"),
    "profileChainDialogTitle": m33,
    "profileChainProxies": MessageLookupByLibrary.simpleMessage(
      "پروکسی ورودی و خروجی",
    ),
    "profileChainSaved": MessageLookupByLibrary.simpleMessage(
      "تنظیمات پروکسی مقدماتی و فرود ذخیره شد",
    ),
    "profileFallbackFailed": MessageLookupByLibrary.simpleMessage(
      "پیکربندی قبلی نیز بازگردانی نشد",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "پروفایل تغییر یافته است. آیا بروزرسانی خودکار غیرفعال شود؟",
    ),
    "profileImportFailed": m34,
    "profileManageNodes": MessageLookupByLibrary.simpleMessage(
      "مدیریت و افزودن گره",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "لطفاً نام پروفایل را وارد کنید",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "خطا در پردازش فایل پروفایل",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "لطفاً یک آدرس URL معتبر وارد کنید",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "لطفاً آدرس URL را وارد کنید",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("پروفایل‌ها"),
    "profilesSort": MessageLookupByLibrary.simpleMessage(
      "مرتب‌سازی پروفایل‌ها",
    ),
    "progress": MessageLookupByLibrary.simpleMessage("پردازش"),
    "project": MessageLookupByLibrary.simpleMessage("پروژه"),
    "protocol": MessageLookupByLibrary.simpleMessage("پروتکل پروکسی"),
    "providers": MessageLookupByLibrary.simpleMessage("ارائه‌دهندگان"),
    "provinceAndCity": MessageLookupByLibrary.simpleMessage("استان / شهر"),
    "proxies": MessageLookupByLibrary.simpleMessage("پروکسی‌ها"),
    "proxiesCount": MessageLookupByLibrary.simpleMessage("گره‌های پروکسی"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("تنظیمات پروکسی"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("زنجیره پروکسی"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("گروه پروکسی"),
    "proxyGroupsCount": MessageLookupByLibrary.simpleMessage("گروه‌های پروکسی"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("DNS پروکسی"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "برای تحلیل دامنه‌های نودهای پروکسی",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("پورت پروکسی"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیم پورت گوش به زنگ Clash",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان پروکسی",
    ),
    "proxyProvidersCount": MessageLookupByLibrary.simpleMessage(
      "مجموعه پروکسی",
    ),
    "pskKey": MessageLookupByLibrary.simpleMessage(
      "کلید از پیش به‌اشتراک‌گذاشته‌شده PSK",
    ),
    "pulse": MessageLookupByLibrary.simpleMessage("پالس"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("حالت مشکی خالص"),
    "qrcode": MessageLookupByLibrary.simpleMessage("کد QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "اسکن کد QR برای دریافت پروفایل",
    ),
    "quicGoDisableEcn": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی QUIC ECN",
    ),
    "quicGoDisableEcnDesc": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی ویژگی ECN در QUIC",
    ),
    "quicGoDisableGso": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی QUIC GSO",
    ),
    "quicGoDisableGsoDesc": MessageLookupByLibrary.simpleMessage(
      "غیرفعال‌سازی ویژگی GSO در QUIC",
    ),
    "quicPortSniffer": MessageLookupByLibrary.simpleMessage("اسنیف پورت QUIC"),
    "quickImport": MessageLookupByLibrary.simpleMessage("درج هوشمند سریع"),
    "quickImportDesc": MessageLookupByLibrary.simpleMessage(
      "درج با یک کلیک از IP:port:user:password، لینک‌ها و دیگر فرمت‌های رایج",
    ),
    "quickResponse": MessageLookupByLibrary.simpleMessage("پاسخ سریع"),
    "quickResponseDesc": MessageLookupByLibrary.simpleMessage(
      "قطع فوری اتصال‌ها هنگام تغییر شبکه",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("رنگین‌کمان"),
    "realTimeSpeed": MessageLookupByLibrary.simpleMessage("سرعت لحظه‌ای"),
    "realityPublicKey": MessageLookupByLibrary.simpleMessage(
      "کلید عمومی REALITY",
    ),
    "reclaimableMemory": MessageLookupByLibrary.simpleMessage("قابل بازیافت"),
    "recovery": MessageLookupByLibrary.simpleMessage("بازیابی"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("بازیابی تمام داده‌ها"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage(
      "فقط بازیابی پروفایل‌ها",
    ),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "استراتژی بازیابی",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "سازگار",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "جایگزینی",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage(
      "بازیابی با موفقیت انجام شد",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("پورت Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("انجام مجدد"),
    "refresh": MessageLookupByLibrary.simpleMessage("بازخوانی"),
    "refreshAppList": MessageLookupByLibrary.simpleMessage(
      "بروزرسانی لیست برنامه‌ها",
    ),
    "refreshAppListConfirm": MessageLookupByLibrary.simpleMessage(
      "آیا لیست برنامه‌ها بروزرسانی شود؟",
    ),
    "regExp": MessageLookupByLibrary.simpleMessage("عبارت باقاعده (RegEx)"),
    "remote": MessageLookupByLibrary.simpleMessage("از راه دور"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "پشتیبان‌گیری داده‌ها روی WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "مقصد از راه دور",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "بازیابی داده‌ها از WebDAV",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("حذف"),
    "rename": MessageLookupByLibrary.simpleMessage("تغییر نام"),
    "replace": MessageLookupByLibrary.simpleMessage("جایگزینی"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("جایگزینی همه"),
    "request": MessageLookupByLibrary.simpleMessage("درخواست"),
    "requests": MessageLookupByLibrary.simpleMessage("درخواست‌ها"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "مشاهده تاریخچه درخواست‌های اخیر",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("بازنشانی"),
    "resetIconCache": MessageLookupByLibrary.simpleMessage(
      "بازنشانی حافظه پنهان آیکون‌ها",
    ),
    "resetIconCacheDesc": MessageLookupByLibrary.simpleMessage(
      "حافظه پنهان محلی آیکون‌ها بازنشانی شود؟ این کار ایمن است، زیرا برنامه دوباره آن‌ها را به‌طور خودکار از پیوندهای راه دور دریافت می‌کند.",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "آیا از بازنشانی اطمینان دارید؟",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("منابع"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "اطلاعات منابع خارجی",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("پیروی از قوانین"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "اتصالات DNS از قوانین پیروی کنند",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("راه‌اندازی مجدد"),
    "restartApp": MessageLookupByLibrary.simpleMessage(
      "راه‌اندازی مجدد برنامه",
    ),
    "restartCore": MessageLookupByLibrary.simpleMessage(
      "راه‌اندازی دوباره هسته",
    ),
    "restartCoreDesc": MessageLookupByLibrary.simpleMessage(
      "آیا هسته به صورت دستی راه‌اندازی مجدد شود؟",
    ),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "هسته دوباره راه‌اندازی شود؟ اتصال‌های فعال لحظه‌ای قطع می‌شوند.",
    ),
    "restartCoreTitle": MessageLookupByLibrary.simpleMessage(
      "راه‌اندازی مجدد هسته",
    ),
    "restartTip": MessageLookupByLibrary.simpleMessage(
      "تغییرات پس از راه‌اندازی مجدد TUN اعمال می‌شود",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("بازیابی"),
    "retest": MessageLookupByLibrary.simpleMessage("بررسی مجدد"),
    "retry": MessageLookupByLibrary.simpleMessage("تلاش مجدد"),
    "rightClickBehavior": MessageLookupByLibrary.simpleMessage("کلیک راست"),
    "roleEntry": MessageLookupByLibrary.simpleMessage("گره ورودی"),
    "roleExit": MessageLookupByLibrary.simpleMessage("خروج فرود"),
    "roleRelay": MessageLookupByLibrary.simpleMessage("گره رله"),
    "rotatingCircle": MessageLookupByLibrary.simpleMessage("چرخش تک‌دایره"),
    "rule": MessageLookupByLibrary.simpleMessage("قوانین"),
    "ruleName": MessageLookupByLibrary.simpleMessage("نام قانون"),
    "ruleProviderWarningsTitle": MessageLookupByLibrary.simpleMessage(
      "برخی مجموعه‌قواعد بارگیری نشدند",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "ارائه‌دهندگان قوانین",
    ),
    "ruleProvidersCount": MessageLookupByLibrary.simpleMessage("مجموعه قوانین"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("مقصد قانون"),
    "rulesCount": MessageLookupByLibrary.simpleMessage("قوانین مسیریابی"),
    "runTime": MessageLookupByLibrary.simpleMessage("مدت زمان اجرا"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("پیکربندی زمان اجرا"),
    "save": MessageLookupByLibrary.simpleMessage("ذخیره"),
    "saveAndApply": MessageLookupByLibrary.simpleMessage("ذخیره و اعمال"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "آیا تغییرات ذخیره شوند؟",
    ),
    "saveNode": MessageLookupByLibrary.simpleMessage("ذخیره گره"),
    "saveTip": MessageLookupByLibrary.simpleMessage(
      "آیا از ذخیره تغییرات اطمینان دارید؟",
    ),
    "scenarioAi": MessageLookupByLibrary.simpleMessage("خدمات هوش مصنوعی"),
    "scenarioEcommerce": MessageLookupByLibrary.simpleMessage(
      "تجارت الکترونیک",
    ),
    "scenarioEmail": MessageLookupByLibrary.simpleMessage("ایمیل"),
    "scenarioGaming": MessageLookupByLibrary.simpleMessage("بازی"),
    "scenarioSocial": MessageLookupByLibrary.simpleMessage(
      "ثبت‌نام شبکه‌های اجتماعی",
    ),
    "scenarioStreaming": MessageLookupByLibrary.simpleMessage("پخش جریانی"),
    "script": MessageLookupByLibrary.simpleMessage("اسکریپت"),
    "scriptDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیمات اسکریپت اورراید سراسری",
    ),
    "scriptUrlNotAScript": MessageLookupByLibrary.simpleMessage(
      "این پیوند یک صفحه وب برگرداند، نه فایل اسکریپت. در GitHub از پیوند Raw استفاده کنید.",
    ),
    "search": MessageLookupByLibrary.simpleMessage("جستجو"),
    "seconds": MessageLookupByLibrary.simpleMessage("ثانیه"),
    "secretCopied": MessageLookupByLibrary.simpleMessage(
      "رمز عبور در حافظه موقت کپی شد",
    ),
    "securityLabel": MessageLookupByLibrary.simpleMessage("امنیت/TLS"),
    "securityNonePlain": MessageLookupByLibrary.simpleMessage("هیچ (متن ساده)"),
    "selectAll": MessageLookupByLibrary.simpleMessage("انتخاب همه"),
    "selectBackupVersion": MessageLookupByLibrary.simpleMessage(
      "انتخاب نسخه پشتیبان",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("انتخاب شده"),
    "selectedCountTitle": m35,
    "serverAddress": MessageLookupByLibrary.simpleMessage("آدرس سرور"),
    "serverAddressHint": MessageLookupByLibrary.simpleMessage("IP یا دامنه"),
    "serverAddressLabel": MessageLookupByLibrary.simpleMessage("آدرس سرور"),
    "serverAddressRequired": MessageLookupByLibrary.simpleMessage(
      "لطفاً آدرس سرور را وارد کنید",
    ),
    "serviceReady": MessageLookupByLibrary.simpleMessage("سرویس آماده است"),
    "serviceRunning": MessageLookupByLibrary.simpleMessage(
      "سرویس در حال اجرا است",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("تنظیمات"),
    "show": MessageLookupByLibrary.simpleMessage("نمایش"),
    "showHiddenItems": MessageLookupByLibrary.simpleMessage(
      "نمایش موارد پنهان",
    ),
    "showMenu": MessageLookupByLibrary.simpleMessage("باز کردن منو"),
    "showPanel": MessageLookupByLibrary.simpleMessage("نمایش پنجره"),
    "showStartSwitch": MessageLookupByLibrary.simpleMessage("دکمه کلید سوئیچ"),
    "showStartSwitchDesc": MessageLookupByLibrary.simpleMessage(
      "نمایش دکمه مستقل روشن/خاموش در صفحه اصلی",
    ),
    "shrink": MessageLookupByLibrary.simpleMessage("فشرده"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("اجرای بی‌صدا"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "اجرا در پس‌زمینه بدون باز کردن پنجره",
    ),
    "size": MessageLookupByLibrary.simpleMessage("اندازه"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "نادیده‌گرفتن بررسی گواهی",
    ),
    "skipCertVerifyDesc": MessageLookupByLibrary.simpleMessage(
      "خطاهای گواهی خودامضا یا دست‌دادن TLS را برطرف می‌کند",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("دامنه‌های مستثنی"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("IP مقصد مستثنی"),
    "skipLocalAuth": MessageLookupByLibrary.simpleMessage(
      "رد شدن از احراز هویت محلی",
    ),
    "skipLocalAuthDesc": MessageLookupByLibrary.simpleMessage(
      "اجازه دسترسی به پروکسی بدون اطلاعات کاربری از سیستم محلی",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("IP مبدا مستثنی"),
    "smartAutoStop": MessageLookupByLibrary.simpleMessage("توقف هوشمند"),
    "smartAutoStopDesc": MessageLookupByLibrary.simpleMessage(
      "توقف سرویس پروکسی هنگام اتصال به شبکه مشخص",
    ),
    "smartAutoStopServiceRunning": MessageLookupByLibrary.simpleMessage(
      "سرویس توقف هوشمند در حال اجرا است",
    ),
    "smartCheckFailed": m36,
    "smartCheckNow": MessageLookupByLibrary.simpleMessage("بررسی کن"),
    "smartChecking": MessageLookupByLibrary.simpleMessage("در حال بررسی…"),
    "smartDelayLaunch": MessageLookupByLibrary.simpleMessage("شروع با تاخیر"),
    "smartDelayLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "اجرا تنها پس از اتصال موفق شبکه",
    ),
    "smartNeedCurrent": MessageLookupByLibrary.simpleMessage(
      "ابتدا این گره را مسیر فعلی کنید",
    ),
    "smartNoData": MessageLookupByLibrary.simpleMessage("داده‌ای نیست"),
    "smartNoScore": MessageLookupByLibrary.simpleMessage("امتیازی نیست"),
    "smartRecheck": MessageLookupByLibrary.simpleMessage("بررسی دوباره"),
    "smartSetAsCurrent": MessageLookupByLibrary.simpleMessage(
      "ابتدا مسیر فعلی کن، سپس بررسی",
    ),
    "smartSuspect": MessageLookupByLibrary.simpleMessage(
      "احتمالاً در دسترس نیست",
    ),
    "snellVersion": MessageLookupByLibrary.simpleMessage("نسخه Snell (۱-۴)"),
    "sniHint": MessageLookupByLibrary.simpleMessage(
      "خالی بگذارید تا با آدرس سرور یکسان شود",
    ),
    "sniLabel": MessageLookupByLibrary.simpleMessage(
      "SNI (ServerName / دامنه پوششی)",
    ),
    "sniffer": MessageLookupByLibrary.simpleMessage("اسنیفر (Sniffer)"),
    "snifferAddressHint": MessageLookupByLibrary.simpleMessage(
      "هر سطر یک آدرس",
    ),
    "snifferDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیمات ردیابی دامنه (Domain Sniffing)",
    ),
    "snifferDomainHint": MessageLookupByLibrary.simpleMessage(
      "هر سطر یک دامنه",
    ),
    "snifferPorts": MessageLookupByLibrary.simpleMessage("پورت‌ها"),
    "snifferPortsHint": MessageLookupByLibrary.simpleMessage(
      "مثال: 80, 8080-8880",
    ),
    "snifferStatus": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "فعالسازی سرویس ردیابی",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("پورت Socks"),
    "sort": MessageLookupByLibrary.simpleMessage("مرتب‌سازی"),
    "source": MessageLookupByLibrary.simpleMessage("منبع"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP مبدا"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("پروکسی ویژه"),
    "specialRules": MessageLookupByLibrary.simpleMessage("قوانین ویژه"),
    "specificDialerProxy": MessageLookupByLibrary.simpleMessage(
      "تعیین پرش اختصاصی",
    ),
    "spinningLines": MessageLookupByLibrary.simpleMessage("خطوط چرخان"),
    "stackMode": MessageLookupByLibrary.simpleMessage("حالت پشته"),
    "standard": MessageLookupByLibrary.simpleMessage("استاندارد"),
    "start": MessageLookupByLibrary.simpleMessage("شروع"),
    "startTest": MessageLookupByLibrary.simpleMessage("تست تاخیر"),
    "startVpn": MessageLookupByLibrary.simpleMessage("در حال شروع..."),
    "status": MessageLookupByLibrary.simpleMessage("وضعیت"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "در صورت غیرفعال بودن از DNS سیستم استفاده می‌شود",
    ),
    "stillUsingProfile": m37,
    "stop": MessageLookupByLibrary.simpleMessage("توقف"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("در حال توقف..."),
    "storeFix": MessageLookupByLibrary.simpleMessage("ترمیم استور"),
    "storeFixDesc": MessageLookupByLibrary.simpleMessage(
      "رفع مشکلات دانلود Google Play Store",
    ),
    "strictRoute": MessageLookupByLibrary.simpleMessage("مسیریابی سخت‌گیرانه"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از حالت مسیریابی سخت‌گیرانه TUN",
    ),
    "style": MessageLookupByLibrary.simpleMessage("سبک"),
    "subRule": MessageLookupByLibrary.simpleMessage("زیرقانون"),
    "submit": MessageLookupByLibrary.simpleMessage("ارسال"),
    "success": MessageLookupByLibrary.simpleMessage("موفقیت‌آمیز"),
    "switchLabel": MessageLookupByLibrary.simpleMessage("کلید"),
    "switchProfileFailed": MessageLookupByLibrary.simpleMessage(
      "تغییر اشتراک ناموفق",
    ),
    "switchProxy": MessageLookupByLibrary.simpleMessage("تغییر"),
    "switchToDomesticIp": MessageLookupByLibrary.simpleMessage(
      "دریافت IP داخلی",
    ),
    "sync": MessageLookupByLibrary.simpleMessage("همگام‌سازی"),
    "syncAll": MessageLookupByLibrary.simpleMessage("همگام‌سازی همه"),
    "syncDelayAnimation": MessageLookupByLibrary.simpleMessage(
      "همگام‌سازی انیمیشن با صفحات دیگر",
    ),
    "syncFailed": MessageLookupByLibrary.simpleMessage("همگام‌سازی ناموفق بود"),
    "system": MessageLookupByLibrary.simpleMessage("سیستم"),
    "systemApp": MessageLookupByLibrary.simpleMessage("برنامه‌های سیستم"),
    "systemDns": MessageLookupByLibrary.simpleMessage("DNS سیستمی"),
    "systemFont": MessageLookupByLibrary.simpleMessage("فونت سیستم"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("پروکسی سیستم"),
    "systemProxyActualOff": MessageLookupByLibrary.simpleMessage(
      "پروکسی سیستمی در واقع خاموش است",
    ),
    "systemProxyActualOn": MessageLookupByLibrary.simpleMessage(
      "پروکسی سیستمی در واقع روشن است",
    ),
    "systemProxyActualStatus": MessageLookupByLibrary.simpleMessage(
      "وضعیت واقعی سیستم",
    ),
    "systemProxyChecking": MessageLookupByLibrary.simpleMessage(
      "در حال بررسی وضعیت واقعی سیستم…",
    ),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیمات پروکسی سیستم",
    ),
    "systemProxyMismatchOff": MessageLookupByLibrary.simpleMessage(
      "پروکسی سیستمی هنوز روشن است",
    ),
    "systemProxyMismatchOn": MessageLookupByLibrary.simpleMessage(
      "تنظیمات درخواست روشن‌بودن را دارد، اما پروکسی سیستمی در واقع روشن نیست",
    ),
    "systemProxyUnknown": MessageLookupByLibrary.simpleMessage(
      "وضعیت پروکسی سیستمی قابل تشخیص نیست",
    ),
    "systemProxyUnsupported": MessageLookupByLibrary.simpleMessage(
      "این پلتفرم از تشخیص وضعیت پروکسی سیستمی پشتیبانی نمی‌کند",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("زبانه"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("اتصال همزمان TCP"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "اجازه به اتصال‌های همزمان TCP",
    ),
    "telegramChannel": MessageLookupByLibrary.simpleMessage("کانال تلگرام"),
    "telegramGroup": MessageLookupByLibrary.simpleMessage("گروه تلگرام"),
    "testAll": MessageLookupByLibrary.simpleMessage("سنجش همه"),
    "testCurrentProxy": MessageLookupByLibrary.simpleMessage(
      "آزمایش دسترس‌پذیری",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("آدرس تست"),
    "testing": MessageLookupByLibrary.simpleMessage("در حال بررسی"),
    "testingHealth": MessageLookupByLibrary.simpleMessage("در حال بررسی..."),
    "textScale": MessageLookupByLibrary.simpleMessage("مقیاس متن"),
    "theme": MessageLookupByLibrary.simpleMessage("پوسته"),
    "themeColor": MessageLookupByLibrary.simpleMessage("رنگ پوسته"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "تنظیمات رنگ و آیکون پوسته",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("حالت پوسته"),
    "threeBounce": MessageLookupByLibrary.simpleMessage("جهش سه گانه"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("۳ ستون"),
    "threeInOut": MessageLookupByLibrary.simpleMessage("سه دایره"),
    "tight": MessageLookupByLibrary.simpleMessage("فشرده"),
    "time": MessageLookupByLibrary.simpleMessage("زمان"),
    "timeoutLabel": MessageLookupByLibrary.simpleMessage("مهلت تمام شد"),
    "tip": MessageLookupByLibrary.simpleMessage("راهنما"),
    "titleColor": MessageLookupByLibrary.simpleMessage("رنگ عنوان"),
    "titleTooLong": MessageLookupByLibrary.simpleMessage(
      "عنوان بیش از حد طولانی است (حداکثر ۲۰ کاراکتر)",
    ),
    "tlsPortSniffer": MessageLookupByLibrary.simpleMessage("اسنیف پورت TLS"),
    "toggle": MessageLookupByLibrary.simpleMessage("تغییر"),
    "tolerateRuleProviderErrors": MessageLookupByLibrary.simpleMessage(
      "نادیده گرفتن خطاهای بارگذاری مجموعه‌قواعد",
    ),
    "tolerateRuleProviderErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "حتی اگر بارگیری برخی مجموعه‌قواعد ناموفق باشد، تنظیمات اعمال شود. در غیر این صورت، هر خطای مجموعه‌قواعد کل تنظیمات را رد می‌کند",
    ),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("تونال اسپات"),
    "tooManyRules": MessageLookupByLibrary.simpleMessage(
      "حداکثر ۵ قانون مجاز است",
    ),
    "tools": MessageLookupByLibrary.simpleMessage("ابزارها"),
    "topologyClient": MessageLookupByLibrary.simpleMessage("کارخواه محلی"),
    "topologyHop": MessageLookupByLibrary.simpleMessage("پرش ورودی"),
    "topologyLanding": MessageLookupByLibrary.simpleMessage("فرود مسکونی"),
    "topologyRelay": MessageLookupByLibrary.simpleMessage("گره رله"),
    "topologyTarget": MessageLookupByLibrary.simpleMessage("سرویس هدف"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("مجموع ترافیک"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("پورت Tproxy"),
    "trafficSinceStart": MessageLookupByLibrary.simpleMessage(
      "از شروع این اجرا",
    ),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("مصرف ترافیک"),
    "trayClickBehavior": MessageLookupByLibrary.simpleMessage(
      "رفتار کلیک روی سینی",
    ),
    "trayEnhancement": MessageLookupByLibrary.simpleMessage("ارتقای منوی سینی"),
    "trayEnhancementDesc": MessageLookupByLibrary.simpleMessage(
      "کنترل گروه‌های پروکسی در منوی سینی سیستم",
    ),
    "trayIconInvert": MessageLookupByLibrary.simpleMessage(
      "معکوس‌سازی آیکون تسک‌بار",
    ),
    "trayIconInvertDesc": MessageLookupByLibrary.simpleMessage(
      "معکوس کردن رنگ آیکون تسک‌بار",
    ),
    "tryManualRefresh": MessageLookupByLibrary.simpleMessage(
      "لطفاً به صورت دستی بروزرسانی کنید",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("کارت شبکه مجازی (TUN)"),
    "tunActualOff": MessageLookupByLibrary.simpleMessage(
      "TUN سیستمی در واقع غیرفعال است",
    ),
    "tunActualOn": MessageLookupByLibrary.simpleMessage(
      "TUN سیستمی در واقع فعال است",
    ),
    "tunActualStatus": MessageLookupByLibrary.simpleMessage("وضعیت واقعی TUN"),
    "tunChecking": MessageLookupByLibrary.simpleMessage(
      "در حال بررسی وضعیت واقعی TUN…",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "مدیریت تمام ترافیک دستگاه با حالت TUN",
    ),
    "tunEnableRequireAdmin": MessageLookupByLibrary.simpleMessage(
      "استفاده از حالت TUN نیازمند دسترسی Admin یا ROOT است",
    ),
    "tunMismatchOff": MessageLookupByLibrary.simpleMessage("TUN هنوز فعال است"),
    "tunMismatchOn": MessageLookupByLibrary.simpleMessage(
      "تنظیمات درخواست روشن‌بودن را دارد، اما TUN سیستمی در واقع فعال نیست",
    ),
    "tunUnknown": MessageLookupByLibrary.simpleMessage(
      "وضعیت واقعی TUN قابل تشخیص نیست",
    ),
    "tunUnsupported": MessageLookupByLibrary.simpleMessage(
      "این پلتفرم وضعیت واقعی TUN را ارائه نمی‌کند",
    ),
    "tunVirtualAddress": MessageLookupByLibrary.simpleMessage(
      "آدرس کارت شبکه مجازی TUN",
    ),
    "tunnel": MessageLookupByLibrary.simpleMessage("تونل"),
    "tunnelAddress": MessageLookupByLibrary.simpleMessage("آدرس گوش به زنگ"),
    "tunnelAddressHint": MessageLookupByLibrary.simpleMessage(
      "مثال: 127.0.0.1:6553",
    ),
    "tunnelDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از تونل هدایت ترافیک",
    ),
    "tunnelList": MessageLookupByLibrary.simpleMessage("لیست هدایت‌ها"),
    "tunnelNetwork": MessageLookupByLibrary.simpleMessage("پروتکل شبکه"),
    "tunnelNetworkHint": MessageLookupByLibrary.simpleMessage("مثال: tcp, udp"),
    "tunnelProxy": MessageLookupByLibrary.simpleMessage("نام پروکسی"),
    "tunnelProxyHint": MessageLookupByLibrary.simpleMessage(
      "مثال: proxy (اختیاری)",
    ),
    "tunnelTarget": MessageLookupByLibrary.simpleMessage("آدرس مقصد"),
    "tunnelTargetHint": MessageLookupByLibrary.simpleMessage(
      "مثال: 114.114.114.114:53",
    ),
    "tvConfigName": MessageLookupByLibrary.simpleMessage(
      "نام پیکربندی (اختیاری)",
    ),
    "tvLocalFile": MessageLookupByLibrary.simpleMessage("فایل پیکربندی محلی"),
    "tvNameHint": MessageLookupByLibrary.simpleMessage(
      "خالی بماند، خودکار تشخیص داده می‌شود",
    ),
    "tvNeedUrl": MessageLookupByLibrary.simpleMessage(
      "ابتدا پیوند اشتراک را وارد کنید",
    ),
    "tvPickFile": MessageLookupByLibrary.simpleMessage(
      "یک فایل .yaml / .yml انتخاب کنید",
    ),
    "tvPushConfig": MessageLookupByLibrary.simpleMessage(
      "🚀 ارسال فایل پیکربندی",
    ),
    "tvPushConnectFailed": MessageLookupByLibrary.simpleMessage(
      "❌ ناموفق: تلویزیون در دسترس نیست:",
    ),
    "tvPushDoneAuto": MessageLookupByLibrary.simpleMessage(
      "✅ به تلویزیون ارسال شد. پیکربندی در حال وارد شدن است…",
    ),
    "tvPushDoneFile": MessageLookupByLibrary.simpleMessage(
      "✅ فایل پیکربندی به تلویزیون ارسال شد",
    ),
    "tvPushFailed": MessageLookupByLibrary.simpleMessage("❌ ناموفق:"),
    "tvPushTitle": MessageLookupByLibrary.simpleMessage(
      "ارسال پیکربندی Fluxora",
    ),
    "tvPushToTv": MessageLookupByLibrary.simpleMessage("🚀 ارسال به تلویزیون"),
    "tvPushing": MessageLookupByLibrary.simpleMessage("در حال ارسال…"),
    "tvReadFailed": MessageLookupByLibrary.simpleMessage(
      "❌ خواندن فایل ممکن نشد",
    ),
    "tvReadingPushing": MessageLookupByLibrary.simpleMessage(
      "در حال خواندن و ارسال…",
    ),
    "tvScanManualUrl": MessageLookupByLibrary.simpleMessage(
      "یا آدرس را مستقیماً در مرورگر گوشی وارد کنید:",
    ),
    "tvScanNoNetwork": MessageLookupByLibrary.simpleMessage(
      "شبکه محلی در دسترس یافت نشد، لطفاً Wi-Fi را بررسی کنید",
    ),
    "tvScanStep1": MessageLookupByLibrary.simpleMessage(
      "مطمئن شوید گوشی و TV به یک شبکه Wi-Fi متصل هستند",
    ),
    "tvScanStep2": MessageLookupByLibrary.simpleMessage(
      "کد QR را با یک دوربین یا مرورگر پشتیبانی‌شده اسکن کنید",
    ),
    "tvScanStep3": MessageLookupByLibrary.simpleMessage(
      "لینک اشتراک را در صفحه وب جای‌گذاری کرده یا فایل پیکربندی را آپلود و ارسال کنید",
    ),
    "tvScanSuccess": MessageLookupByLibrary.simpleMessage(
      "پروفایل دریافت شد، در حال وارد کردن...",
    ),
    "tvScanWaiting": MessageLookupByLibrary.simpleMessage(
      "در انتظار ارسال پروفایل از گوشی...",
    ),
    "tvSubscriptionUrl": MessageLookupByLibrary.simpleMessage("پیوند اشتراک"),
    "tvSubscriptionUrlLabel": MessageLookupByLibrary.simpleMessage(
      "پیوند اشتراک (URL)",
    ),
    "tvUrlHint": MessageLookupByLibrary.simpleMessage(
      "پیوند اشتراک Clash Meta را بچسبانید (https://…)",
    ),
    "twoColumns": MessageLookupByLibrary.simpleMessage("۲ ستون"),
    "udpForwarding": MessageLookupByLibrary.simpleMessage("بازپخش UDP"),
    "udpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "اگر IP مسکونی از UDP پشتیبانی نمی‌کند و خطا ایجاد می‌شود، این گزینه را خاموش کنید",
    ),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "امکان بروزرسانی پروفایل فعلی وجود ندارد",
    ),
    "unauthorized": MessageLookupByLibrary.simpleMessage("احراز هویت نشده"),
    "undo": MessageLookupByLibrary.simpleMessage("واکشی"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("تاخیر یکپارچه"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "حذف تاخیرهای اضافی دست‌تکانی",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("نامشخص"),
    "unlocked": MessageLookupByLibrary.simpleMessage("تکمیل شد"),
    "unnamed": MessageLookupByLibrary.simpleMessage("بدون نام"),
    "unnamedNode": MessageLookupByLibrary.simpleMessage("گره بی‌نام"),
    "unpin": MessageLookupByLibrary.simpleMessage("برداشتن پین"),
    "upLabel": MessageLookupByLibrary.simpleMessage("بالا"),
    "update": MessageLookupByLibrary.simpleMessage("بروزرسانی"),
    "updateTime": MessageLookupByLibrary.simpleMessage("زمان به‌روزرسانی"),
    "upload": MessageLookupByLibrary.simpleMessage("آپلود"),
    "url": MessageLookupByLibrary.simpleMessage("آدرس URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "دریافت پروفایل از طریق آدرس URL",
    ),
    "urlTip": m38,
    "useGlobalScriptOverride": MessageLookupByLibrary.simpleMessage(
      "استفاده از اسکریپت اورراید سراسری",
    ),
    "useHosts": MessageLookupByLibrary.simpleMessage("استفاده از Hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "استفاده از Hosts سیستم",
    ),
    "userAuth": MessageLookupByLibrary.simpleMessage("احراز هویت کاربر"),
    "username": MessageLookupByLibrary.simpleMessage("نام کاربری"),
    "usernameCannotContainColon": MessageLookupByLibrary.simpleMessage(
      "نام کاربری نباید شامل دونقطه (:) باشد",
    ),
    "usernameOptional": MessageLookupByLibrary.simpleMessage(
      "نام کاربری (اختیاری)",
    ),
    "value": MessageLookupByLibrary.simpleMessage("مقدار"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("پررنگ"),
    "view": MessageLookupByLibrary.simpleMessage("مشاهده"),
    "viewDetailedIpData": MessageLookupByLibrary.simpleMessage(
      "مشاهده داده‌های دقیق IP",
    ),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("تنظیمات مربوط به VPN"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "هدایت ترافیک سیستم از طریق VpnService",
    ),
    "vpnSystemProxyConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "استفاده از پروکسی HTTP در موبایل پیشنهاد نمی‌شود مگر در صورت نیاز",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "افزودن پروکسی HTTP به VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "تغییرات پس از راه‌اندازی مجدد VPN اعمال می‌شود",
    ),
    "wakelock": MessageLookupByLibrary.simpleMessage("قفل روشن ماندن صفحه"),
    "wakelockDescription": MessageLookupByLibrary.simpleMessage(
      "جلوگیری از خاموش شدن خودکار صفحه نمایش برای فعال ماندن برنامه‌ها در پس‌زمینه.",
    ),
    "warpCopied": m39,
    "warpDiagOk": m40,
    "warpDialerSet": m41,
    "warpEdgeNode": m42,
    "warpFastestChosen": m43,
    "warpIpChosen": m44,
    "warpModeAll": MessageLookupByLibrary.simpleMessage("همه ترافیک از WARP"),
    "warpModeAllDesc": MessageLookupByLibrary.simpleMessage(
      "تمام ترافیک پروکسی از WARP کپسوله می‌شود و IP واقعی خروجی ارائه‌دهنده پنهان می‌ماند",
    ),
    "warpModeCustom": MessageLookupByLibrary.simpleMessage(
      "مسیریابی با قواعد سفارشی",
    ),
    "warpModeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "بر اساس قواعد دامنه یا IP تصمیم می‌گیرد که از WARP عبور کند یا نه",
    ),
    "warpModeSmart": MessageLookupByLibrary.simpleMessage(
      "هوشمند: باز کردن قفل هوش مصنوعی (پیشنهادی)",
    ),
    "warpModeSmartDesc": MessageLookupByLibrary.simpleMessage(
      "Google، OpenAI، Claude و Gemini از WARP عبور می‌کنند؛ بقیه سرعت اصلی ارائه‌دهنده را حفظ می‌کنند",
    ),
    "warpModeTitle": MessageLookupByLibrary.simpleMessage("حالت مسیریابی"),
    "warpNoSignature": m45,
    "warpRegion": m46,
    "warpRouteProxyOverWarp": MessageLookupByLibrary.simpleMessage(
      "پروکسی از طریق WARP",
    ),
    "warpRouteProxyOverWarpDesc": MessageLookupByLibrary.simpleMessage(
      "پروکسی از طریق WARP (WARP به‌عنوان دیالر برای گره‌های مسدود)",
    ),
    "warpRouteWarpOverProxy": MessageLookupByLibrary.simpleMessage(
      "WARP از طریق پروکسی",
    ),
    "warpRouteWarpOverProxyDesc": MessageLookupByLibrary.simpleMessage(
      "WARP از طریق پروکسی (پیشنهادی: ارائه‌دهنده به‌همراه خروجی WARP)",
    ),
    "warpStr0": MessageLookupByLibrary.simpleMessage("۰ (پیش‌فرض ۲۴۰۸)"),
    "warpStr1": MessageLookupByLibrary.simpleMessage(
      "۱۲۸۰ (پیشنهادی، بهترین برای UDP)",
    ),
    "warpStr10": MessageLookupByLibrary.simpleMessage(
      "MTU روی ۱۴۲۰ تنظیم شد (استاندارد)",
    ),
    "warpStr100": MessageLookupByLibrary.simpleMessage("WARP از طریق پروکسی"),
    "warpStr101": MessageLookupByLibrary.simpleMessage("پروکسی از طریق WARP"),
    "warpStr102": MessageLookupByLibrary.simpleMessage("ساخت دوباره کلیدها"),
    "warpStr103": MessageLookupByLibrary.simpleMessage("بازنشانی"),
    "warpStr104": MessageLookupByLibrary.simpleMessage(
      "بازگشت به تنظیمات پیش‌فرض",
    ),
    "warpStr105": MessageLookupByLibrary.simpleMessage(
      "🎉 لایسنس WARP+ فعال شد",
    ),
    "warpStr106": MessageLookupByLibrary.simpleMessage(
      "🎉 دستگاه و کلیدها ساخته شد",
    ),
    "warpStr107": MessageLookupByLibrary.simpleMessage("👑 دستگاه WARP+"),
    "warpStr108": MessageLookupByLibrary.simpleMessage("💡 کاربرد هر حالت"),
    "warpStr109": MessageLookupByLibrary.simpleMessage(
      "🛡️ جستجوی بومی (عالی)",
    ),
    "warpStr11": MessageLookupByLibrary.simpleMessage(
      "اعتبارنامه‌ها و جزئیات WARP",
    ),
    "warpStr110": MessageLookupByLibrary.simpleMessage("🟢 دستگاه رایگان رسمی"),
    "warpStr111": MessageLookupByLibrary.simpleMessage("🟢 بدون محدودیت"),
    "warpStr12": MessageLookupByLibrary.simpleMessage(
      "WARP به تنظیمات پیش‌فرض بازگشت",
    ),
    "warpStr13": MessageLookupByLibrary.simpleMessage("حالت مسیریابی WARP"),
    "warpStr14": MessageLookupByLibrary.simpleMessage(
      "فعال‌سازی سرعت WARP+ (warp=plus)",
    ),
    "warpStr15": MessageLookupByLibrary.simpleMessage("کلیدهای WireGuard"),
    "warpStr16": MessageLookupByLibrary.simpleMessage("auto (پیش‌فرض)"),
    "warpStr17": MessageLookupByLibrary.simpleMessage(
      "auto یا مثلاً 162.159.193.1",
    ),
    "warpStr18": MessageLookupByLibrary.simpleMessage(
      "⚠️ ممکن است منطقه افشا شود",
    ),
    "warpStr19": MessageLookupByLibrary.simpleMessage(
      "⚡ بررسی وضعیت واقعی WARP",
    ),
    "warpStr2": MessageLookupByLibrary.simpleMessage("۱۳۶۰ (متوازن)"),
    "warpStr20": MessageLookupByLibrary.simpleMessage(
      "⚡ پیروی از انتخاب اصلی (پیشنهادی)",
    ),
    "warpStr21": MessageLookupByLibrary.simpleMessage(
      "⚡ پیروی از انتخاب اصلی (از گره فعال ارائه‌دهنده استفاده می‌شود)",
    ),
    "warpStr22": MessageLookupByLibrary.simpleMessage("⚪ جفت‌کلید محلی"),
    "warpStr23": MessageLookupByLibrary.simpleMessage("✈️ دیالر WARP"),
    "warpStr24": MessageLookupByLibrary.simpleMessage("بهینه‌سازی"),
    "warpStr25": MessageLookupByLibrary.simpleMessage(
      "ساخت جفت‌کلید X25519 و ثبت دستگاه در Cloudflare",
    ),
    "warpStr26": MessageLookupByLibrary.simpleMessage("اجرای عیب‌یابی"),
    "warpStr27": MessageLookupByLibrary.simpleMessage(
      "همان نمای کارت تعویض، با تأخیر زنده",
    ),
    "warpStr28": MessageLookupByLibrary.simpleMessage(
      "انتخاب از فهرست گره‌ها…",
    ),
    "warpStr29": MessageLookupByLibrary.simpleMessage("IP ترجیحی"),
    "warpStr3": MessageLookupByLibrary.simpleMessage("۱۴۲۰ (استاندارد)"),
    "warpStr30": MessageLookupByLibrary.simpleMessage("IP ترجیحی / نام میزبان"),
    "warpStr31": MessageLookupByLibrary.simpleMessage("IP ترجیحی ذخیره شد"),
    "warpStr32": MessageLookupByLibrary.simpleMessage(
      "IP ترجیحی به auto بازگشت",
    ),
    "warpStr33": MessageLookupByLibrary.simpleMessage("اسکن IP ترجیحی"),
    "warpStr34": MessageLookupByLibrary.simpleMessage(
      "IP ترجیحی همان آدرس ورودی است و بر سرعت و پایداری اثر می‌گذارد.",
    ),
    "warpStr35": MessageLookupByLibrary.simpleMessage("نحوه کار"),
    "warpStr36": MessageLookupByLibrary.simpleMessage("استفاده از سریع‌ترین"),
    "warpStr37": MessageLookupByLibrary.simpleMessage("ذخیره"),
    "warpStr38": MessageLookupByLibrary.simpleMessage("بستن"),
    "warpStr39": MessageLookupByLibrary.simpleMessage(
      "IP خروجی را نزدیک‌ترین مسیریابی Cloudflare تعیین می‌کند و تغییر نمی‌کند.",
    ),
    "warpStr4": MessageLookupByLibrary.simpleMessage(
      "باز کردن قفل هوش مصنوعی و استریم",
    ),
    "warpStr40": MessageLookupByLibrary.simpleMessage("IP واقعی خروجی"),
    "warpStr41": MessageLookupByLibrary.simpleMessage("پروکسی دیالر"),
    "warpStr42": MessageLookupByLibrary.simpleMessage("لغو"),
    "warpStr43": MessageLookupByLibrary.simpleMessage("فعال‌سازی WARP"),
    "warpStr44": MessageLookupByLibrary.simpleMessage("کلید عمومی کلاینت"),
    "warpStr45": MessageLookupByLibrary.simpleMessage("کلید خصوصی کلاینت"),
    "warpStr46": MessageLookupByLibrary.simpleMessage("بایت‌های رزرو کلاینت"),
    "warpStr47": MessageLookupByLibrary.simpleMessage(
      "هنوز قاعده‌ای نیست — در این حالت بدون قاعده تقسیمی انجام نمی‌شود",
    ),
    "warpStr48": MessageLookupByLibrary.simpleMessage("هنوز بررسی نشده"),
    "warpStr49": MessageLookupByLibrary.simpleMessage(
      "کلید ذخیره شد؛ در دست‌دادن یا ثبت بعدی اعمال می‌شود",
    ),
    "warpStr5": MessageLookupByLibrary.simpleMessage(
      "کلید عمومی همتای Cloudflare",
    ),
    "warpStr50": MessageLookupByLibrary.simpleMessage("WARP خاموش شد"),
    "warpStr51": MessageLookupByLibrary.simpleMessage(
      "Cloudflare WARP فعال شد",
    ),
    "warpStr52": MessageLookupByLibrary.simpleMessage("WARP فعال شد"),
    "warpStr53": MessageLookupByLibrary.simpleMessage("کلید لایسنس پاک شد"),
    "warpStr54": MessageLookupByLibrary.simpleMessage(
      "روی پیروی از انتخاب اصلی تنظیم شد",
    ),
    "warpStr55": MessageLookupByLibrary.simpleMessage(
      "جفت‌کلید Curve25519 دوباره ساخته شد",
    ),
    "warpStr56": MessageLookupByLibrary.simpleMessage(
      "به پیش‌فرض «WARP از طریق پروکسی» بازگشت",
    ),
    "warpStr57": MessageLookupByLibrary.simpleMessage(
      "حالت «WARP از طریق پروکسی»: همه گره‌های ارائه‌دهنده از تونل WARP عبور می‌کنند و گره‌های مسدودشده توسط GFW را نجات می‌دهد. نیازی به انتخاب دیالر نیست.",
    ),
    "warpStr58": MessageLookupByLibrary.simpleMessage("بررسی نشده"),
    "warpStr59": MessageLookupByLibrary.simpleMessage(
      "برای دقیق‌ترین عدد، پیش از اسکن پروکسی را خاموش کنید.",
    ),
    "warpStr6": MessageLookupByLibrary.simpleMessage(
      "DIRECT (اتصال مستقیم به Cloudflare)",
    ),
    "warpStr60": MessageLookupByLibrary.simpleMessage(
      "توجه: تأخیر اندازه‌گیری‌شده با پروکسی روشن شامل سرباز تونل است.",
    ),
    "warpStr61": MessageLookupByLibrary.simpleMessage("فعال نیست"),
    "warpStr62": MessageLookupByLibrary.simpleMessage("تنظیم نشده"),
    "warpStr63": MessageLookupByLibrary.simpleMessage("گره‌های ارائه‌دهنده"),
    "warpStr64": MessageLookupByLibrary.simpleMessage(
      "نمایش کامل کلیدهای WireGuard",
    ),
    "warpStr65": MessageLookupByLibrary.simpleMessage("در حال بررسی…"),
    "warpStr66": MessageLookupByLibrary.simpleMessage(
      "ثبت دستگاه در Cloudflare و ساخت کلیدها…",
    ),
    "warpStr67": MessageLookupByLibrary.simpleMessage("عیب‌یابی عمیق…"),
    "warpStr68": MessageLookupByLibrary.simpleMessage(
      "ساخت کلید X25519 و ثبت دستگاه…",
    ),
    "warpStr69": MessageLookupByLibrary.simpleMessage(
      "اتصال کلید از طریق API رسمی…",
    ),
    "warpStr7": MessageLookupByLibrary.simpleMessage(
      "بررسی افشای منطقه Google",
    ),
    "warpStr70": MessageLookupByLibrary.simpleMessage(
      "گره قابل‌دسترسی پیدا نشد. شبکه را بررسی کنید یا پروکسی را خاموش کرده و دوباره تلاش کنید.",
    ),
    "warpStr71": MessageLookupByLibrary.simpleMessage(
      "ترافیک ابتدا از WARP و سپس به گره ارائه‌دهنده می‌رود — مناسب وقتی گره مسدود است",
    ),
    "warpStr72": MessageLookupByLibrary.simpleMessage(
      "ترافیک از گره ارائه‌دهنده و سپس از WARP خارج می‌شود — مانع افشای منطقه و بازکننده هوش مصنوعی",
    ),
    "warpStr73": MessageLookupByLibrary.simpleMessage("فعال‌سازی و اتصال"),
    "warpStr74": MessageLookupByLibrary.simpleMessage(
      "برای فعال‌سازی WARP ضربه بزنید",
    ),
    "warpStr75": MessageLookupByLibrary.simpleMessage("ساخت پیکربندی WARP"),
    "warpStr76": MessageLookupByLibrary.simpleMessage(
      "ساخته شد (جفت‌کلید معتبر داخلی بارگذاری شد)",
    ),
    "warpStr77": MessageLookupByLibrary.simpleMessage(
      "مستقیم یا پروکسی معمولی (warp=off)",
    ),
    "warpStr78": MessageLookupByLibrary.simpleMessage("تأیید"),
    "warpStr79": MessageLookupByLibrary.simpleMessage("پورت"),
    "warpStr8": MessageLookupByLibrary.simpleMessage(
      "MTU روی ۱۲۸۰ تنظیم شد (پیشنهادی)",
    ),
    "warpStr80": MessageLookupByLibrary.simpleMessage("پورت"),
    "warpStr81": MessageLookupByLibrary.simpleMessage("شماره پورت"),
    "warpStr82": MessageLookupByLibrary.simpleMessage("پورت به‌روزرسانی شد"),
    "warpStr83": MessageLookupByLibrary.simpleMessage(
      "پورت به ۰ بازگشت (پیش‌فرض ۲۴۰۸)",
    ),
    "warpStr84": MessageLookupByLibrary.simpleMessage("گروه‌های سیاست"),
    "warpStr85": MessageLookupByLibrary.simpleMessage(
      "اتصال کلید لایسنس WARP+",
    ),
    "warpStr86": MessageLookupByLibrary.simpleMessage(
      "از گره ارائه‌دهنده انتخاب‌شده در پنل استفاده می‌کند",
    ),
    "warpStr87": MessageLookupByLibrary.simpleMessage("قواعد سفارشی"),
    "warpStr88": MessageLookupByLibrary.simpleMessage("IPv4 مجازی"),
    "warpStr89": MessageLookupByLibrary.simpleMessage("IPv6 مجازی"),
    "warpStr9": MessageLookupByLibrary.simpleMessage("MTU روی ۱۳۶۰ تنظیم شد"),
    "warpStr90": MessageLookupByLibrary.simpleMessage(
      "عبور از کپچا و قفل منطقه‌ای",
    ),
    "warpStr91": MessageLookupByLibrary.simpleMessage("قطع اتصال"),
    "warpStr92": MessageLookupByLibrary.simpleMessage("کلید لایسنس"),
    "warpStr93": MessageLookupByLibrary.simpleMessage(
      "پورت WireGuard را تنظیم کنید (۰ یعنی پورت پیش‌فرض ۲۴۰۸):",
    ),
    "warpStr94": MessageLookupByLibrary.simpleMessage(
      "IP ترجیحی برای Cloudflare WARP را تنظیم کنید؛ auto را وارد کنید تا از IP بهینه رسمی استفاده شود:",
    ),
    "warpStr95": MessageLookupByLibrary.simpleMessage("پیروی از دیالر"),
    "warpStr96": MessageLookupByLibrary.simpleMessage("مرکز لبه (Colo)"),
    "warpStr97": MessageLookupByLibrary.simpleMessage(
      "اتصال کامل نشد یا بررسی منقضی شد",
    ),
    "warpStr98": MessageLookupByLibrary.simpleMessage("انتخاب دیالر WARP"),
    "warpStr99": MessageLookupByLibrary.simpleMessage("انتخاب MTU WireGuard"),
    "warpSwitchedTo": m47,
    "warpUnknownColo": MessageLookupByLibrary.simpleMessage("گره لبه ناشناخته"),
    "wave": MessageLookupByLibrary.simpleMessage("موج"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "تنظیمات WebDAV",
    ),
    "whitelist": MessageLookupByLibrary.simpleMessage("لیست سفید"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("حالت لیست سفید"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("اعمال به سیستم"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "نیازمند دسترسی مدیریت (Admin)",
    ),
    "wrongBackupPassword": MessageLookupByLibrary.simpleMessage(
      "گذرواژه نادرست است یا پشتیبان دستکاری شده است",
    ),
    "years": m48,
  };
}
