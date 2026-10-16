// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
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
  String get localeName => 'ru';

  static String m0(role) => "Добавить кандидата ${role}";

  static String m1(role) => "Добавить резервного кандидата ${role}";

  static String m2(completed, total) => "Проверка (${completed}/${total})...";

  static String m3(count) => "Успешно импортировано узлов: ${count}";

  static String m4(count) => "Удалено недействительных узлов: ${count}";

  static String m5(name) => "Вы уверены, что хотите удалить узел «${name}»?";

  static String m6(error) => "Не удалось создать группу: ${error}";

  static String m7(name) => "Пустая группа «${name}» создана, добавьте узлы";

  static String m8(count) =>
      "${Intl.plural(count, one: 'день', few: 'дня', many: 'дней', other: 'дней')}";

  static String m9(label) => "Удалить выбранные ${label}?";

  static String m10(label) => "Удалить текущий ${label}?";

  static String m11(label) => "${label} не может быть пустым";

  static String m12(label) => "${label} уже существует";

  static String m13(reason) => "Аварийное переключение не удалось: ${reason}";

  static String m14(node) =>
      "Аварийное переключение выполнено, перешли на [${node}]";

  static String m15(count) =>
      "${Intl.plural(count, one: 'час', few: 'часа', many: 'часов', other: 'часов')}";

  static String m16(count) => "Импортировано узлов прокси выхода: ${count}";

  static String m17(count) => "${count}";

  static String m18(count) =>
      "${Intl.plural(count, one: 'минуту', few: 'минуты', many: 'минут', other: 'минут')}";

  static String m19(count) =>
      "${Intl.plural(count, one: 'месяц', few: 'месяца', many: 'месяцев', other: 'месяцев')}";

  static String m20(name) => "Узел добавлен: ${name}";

  static String m21(name) => "Узел удалён: ${name}";

  static String m22(name) => "Управление узлами · ${name}";

  static String m23(proto) => "напр. Гонконг 01 - ${proto}";

  static String m24(label) => "${label} отсутствует";

  static String m25(label) => "${label} должен быть числом";

  static String m26(label) =>
      "${label} должен быть от 1024 до 49151, 0 для отключения";

  static String m27(name) => "Предпрокси и прокси-выход · ${name}";

  static String m28(statusCode) =>
      "Не удалось импортировать профиль. Проверьте состояние сети или попробуйте сбросить ссылку подписки ( код ошибки HTTP: ${statusCode} )";

  static String m29(count) => "Выбрано: ${count}";

  static String m30(label) => "${label} должен быть URL";

  static String m31(count) =>
      "${Intl.plural(count, one: 'год', few: 'года', many: 'лет', other: 'лет')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage(
      "Маршрутизация приложений",
    ),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Только выбранные приложения используют VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка доступа приложений к прокси",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения исключены из VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Переключить режим"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "action_start": MessageLookupByLibrary.simpleMessage("Запуск/Остановка"),
    "action_tun": MessageLookupByLibrary.simpleMessage("Режим TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Показать/Скрыть"),
    "activeGoroutines": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addLandingProxy": MessageLookupByLibrary.simpleMessage(
      "Добавить прокси выхода",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addRoleCandidate": m0,
    "addRoleFallbackCandidate": m1,
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addTunnel": MessageLookupByLibrary.simpleMessage(
      "Добавить перенаправление",
    ),
    "addUser": MessageLookupByLibrary.simpleMessage("Добавить пользователя"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "Добавить к исходным правилам",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("Адрес сервера WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Введите корректный адрес WebDAV",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Автозапуск от администратора",
    ),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Автозапуск с правами администратора",
    ),
    "advancedSettings": MessageLookupByLibrary.simpleMessage(
      "Расширенные настройки",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Генерация ключа Age",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "Пара ключей X25519 создана, сохраните её в надёжном месте",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Приватный ключ",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, сначала введите корректный приватный ключ Age",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Публичный ключ"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите корректный приватный ключ Age (должен начинаться с AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Приватный ключ Age (необязательно)",
    ),
    "ago": MessageLookupByLibrary.simpleMessage(" назад"),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "allApps": MessageLookupByLibrary.simpleMessage("Все приложения"),
    "allocatedMemory": MessageLookupByLibrary.simpleMessage("Выделено"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("Разрешить обход VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Некоторые приложения смогут обходить VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LAN доступ"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ из локальной сети",
    ),
    "alreadyInWhitelist": MessageLookupByLibrary.simpleMessage(
      "Уже в белом списке",
    ),
    "alwaysShowTitleBar": MessageLookupByLibrary.simpleMessage(
      "Кнопки заголовка",
    ),
    "alwaysShowTitleBarDesc": MessageLookupByLibrary.simpleMessage(
      "Всегда показывать кнопки в правом верхнем углу",
    ),
    "amneziaObfsParams": MessageLookupByLibrary.simpleMessage(
      "Параметры обфускации AmneziaWG 2/3 (Jc / Jmin / Jmax / S1 / S2 / H1-H4)",
    ),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Маршрутизация приложений",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage("Настройки приложения"),
    "application": MessageLookupByLibrary.simpleMessage("Приложение"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Настройки приложения",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("По возрастанию"),
    "authorized": MessageLookupByLibrary.simpleMessage("Авторизован"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Проверка обновлений при запуске",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Закрывать соединения при смене узла",
    ),
    "autoFailover": MessageLookupByLibrary.simpleMessage(
      "Автоматическое переключение",
    ),
    "autoFailoverOffDesc": MessageLookupByLibrary.simpleMessage(
      "Выкл.: переключение только вручную кнопкой ниже",
    ),
    "autoFailoverOnDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически переключается на резервный узел при постоянных сбоях цепочки",
    ),
    "autoInjectGroups": MessageLookupByLibrary.simpleMessage(
      "Автовставка в основную группу выбора",
    ),
    "autoInjectGroupsDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически добавляет включённые прокси выхода в основные группы маршрутизации, такие как «Выбор узла»",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запуск при старте системы",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автоподключение"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Подключаться при запуске приложения",
    ),
    "autoScroll": MessageLookupByLibrary.simpleMessage("Автопрокрутка"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автоматически настроить системный DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления (минуты)",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Назад"),
    "backup": MessageLookupByLibrary.simpleMessage("Создать копию"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Синхронизация данных через WebDAV или локально",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование успешно",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Конфигурация ядра"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальное изменение конфигурации ядра",
    ),
    "batchCheckingProgress": m2,
    "batchImportLinks": MessageLookupByLibrary.simpleMessage(
      "Массовый импорт ссылок",
    ),
    "batchImportParseFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось распознать допустимую ссылку на узел. Проверьте формат.",
    ),
    "batchImportPasteHint": MessageLookupByLibrary.simpleMessage(
      "Вставьте сюда ссылки на узлы или конфигурацию узла (YAML/JSON)...",
    ),
    "batchImportShareLinks": MessageLookupByLibrary.simpleMessage(
      "Массовый импорт ссылок",
    ),
    "batchImportSuccess": m3,
    "batchImportSupportHint": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются однострочные/многострочные ссылки или фрагменты узлов YAML/JSON:",
    ),
    "batteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Оптимизация батареи",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Запросить добавление в белый список энергосбережения",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklist": MessageLookupByLibrary.simpleMessage("Чёрный список"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим чёрного списка",
    ),
    "blockComment": MessageLookupByLibrary.simpleMessage("Комментарий"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Исключить домены"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Работает только при включённом системном прокси",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Исключить локальные сети (LAN)",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Направлять локальные IP-адреса в обход прокси",
    ),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "Алгоритм кэширования",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш повреждён. Очистить?",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Доступ к камере запрещён",
    ),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Для сканирования QR-кода требуется доступ к камере. Пожалуйста, предоставьте разрешение в настройках.",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Показать системные приложения",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Отменить выбор"),
    "categoryAi": MessageLookupByLibrary.simpleMessage("AI"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("Все"),
    "categoryChina": MessageLookupByLibrary.simpleMessage("Китай (прямой)"),
    "categoryCrypto": MessageLookupByLibrary.simpleMessage("Криптовалюта"),
    "categoryDeveloper": MessageLookupByLibrary.simpleMessage(
      "Для разработчиков",
    ),
    "categoryGaming": MessageLookupByLibrary.simpleMessage("Игровой центр"),
    "categorySocial": MessageLookupByLibrary.simpleMessage("Сообщество"),
    "categoryStreaming": MessageLookupByLibrary.simpleMessage("Стриминг"),
    "chainAvgLatency": MessageLookupByLibrary.simpleMessage("Средняя задержка"),
    "chainCreateSupportPackage": MessageLookupByLibrary.simpleMessage(
      "Создать пакет поддержки",
    ),
    "chainCreatingPackage": MessageLookupByLibrary.simpleMessage("Создание…"),
    "chainDecisionSupport": MessageLookupByLibrary.simpleMessage(
      "Поддержка решений",
    ),
    "chainDiagnosticPackage": MessageLookupByLibrary.simpleMessage(
      "Диагностический пакет",
    ),
    "chainDiagnosticTitle": MessageLookupByLibrary.simpleMessage(
      "Диагностика цепочки",
    ),
    "chainEventsLabel": MessageLookupByLibrary.simpleMessage("События"),
    "chainExportReport": MessageLookupByLibrary.simpleMessage("Экспорт отчёта"),
    "chainExporting": MessageLookupByLibrary.simpleMessage("Экспорт…"),
    "chainFailuresLabel": MessageLookupByLibrary.simpleMessage("Сбои"),
    "chainGeneratedOn": MessageLookupByLibrary.simpleMessage("Создан"),
    "chainHealthLabel": MessageLookupByLibrary.simpleMessage("Состояние"),
    "chainHealthScore": MessageLookupByLibrary.simpleMessage(
      "Оценка состояния",
    ),
    "chainHopExitNode": MessageLookupByLibrary.simpleMessage(
      "3-й переход (выходной узел)",
    ),
    "chainHopIncomplete": MessageLookupByLibrary.simpleMessage(
      "Цепочка из трёх переходов не полна: выберите транзитный и выходной узлы",
    ),
    "chainHopMode": MessageLookupByLibrary.simpleMessage(
      "Число переходов цепочки",
    ),
    "chainHopModeDesc": MessageLookupByLibrary.simpleMessage(
      "Два перехода: «вход → выход». Три перехода добавляют транзитный узел",
    ),
    "chainHopNotSelected": MessageLookupByLibrary.simpleMessage("Не выбрано"),
    "chainHopRelayNode": MessageLookupByLibrary.simpleMessage(
      "2-й переход (транзитный узел)",
    ),
    "chainHopUnavailable": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать список доступных узлов, поэтому проверка доступности узлов не выполнена",
    ),
    "chainIntelAnalytics": MessageLookupByLibrary.simpleMessage(
      "Интеллектуальная аналитика",
    ),
    "chainLandingProxyNone": MessageLookupByLibrary.simpleMessage(
      "По умолчанию (нет)",
    ),
    "chainNodeDeviceApp": MessageLookupByLibrary.simpleMessage(
      "Приложение устройства",
    ),
    "chainNodeGroupNodes": MessageLookupByLibrary.simpleMessage("Узлы группы"),
    "chainNodeLocal": MessageLookupByLibrary.simpleMessage("Локально"),
    "chainNodePreProxy": MessageLookupByLibrary.simpleMessage("Предпрокси"),
    "chainNodeReliability": MessageLookupByLibrary.simpleMessage(
      "Надёжность узлов",
    ),
    "chainNodeSubscription": MessageLookupByLibrary.simpleMessage(
      "Узел подписки",
    ),
    "chainOpenFolder": MessageLookupByLibrary.simpleMessage("Открыть папку"),
    "chainPackageReady": MessageLookupByLibrary.simpleMessage("Пакет готов"),
    "chainPreProxyNone": MessageLookupByLibrary.simpleMessage("Напрямую (нет)"),
    "chainProbeNow": MessageLookupByLibrary.simpleMessage("Проверить цепочку"),
    "chainProxy": MessageLookupByLibrary.simpleMessage("Цепочка прокси"),
    "chainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Настройте входной переход и статический резидентный IP-выход",
    ),
    "chainShareLabel": MessageLookupByLibrary.simpleMessage("Поделиться"),
    "chainSupportTitle": MessageLookupByLibrary.simpleMessage(
      "Поддержка цепочки",
    ),
    "chainTopFailureReason": MessageLookupByLibrary.simpleMessage(
      "Основная причина сбоя",
    ),
    "chainTopologyPreview": MessageLookupByLibrary.simpleMessage(
      "Предпросмотр топологии цепной маршрутизации",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("Ошибка проверки"),
    "checkFailed": MessageLookupByLibrary.simpleMessage("Timeout"),
    "checkOrAddProfile": MessageLookupByLibrary.simpleMessage(
      "Добавьте профиль",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Установлена последняя версия",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Проверка..."),
    "cipher": MessageLookupByLibrary.simpleMessage("Шифрование"),
    "cipherLabel": MessageLookupByLibrary.simpleMessage("Шифр"),
    "circle": MessageLookupByLibrary.simpleMessage("Круг"),
    "clear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "clearCacheDesc": MessageLookupByLibrary.simpleMessage(
      "Очистить кэш FakeIP и DNS?",
    ),
    "clearCacheTitle": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearDataTipDesc": MessageLookupByLibrary.simpleMessage(
      "Это действие сбросит настройки приложения. Пожалуйста, сделайте резервную копию. Вы уверены, что хотите продолжить?",
    ),
    "clearDataTipTitle": MessageLookupByLibrary.simpleMessage(
      "Опасная операция",
    ),
    "clearInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "Удалить недоступные узлы",
    ),
    "clearedInvalidCount": m4,
    "clipboard": MessageLookupByLibrary.simpleMessage("Буфер обмена"),
    "clipboardDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически получать ссылки из буфера обмена",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("Экспорт в буфер"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("Импорт из буфера"),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Закрыть все"),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Цветовые схемы"),
    "columns": MessageLookupByLibrary.simpleMessage("Колонки"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "Включает полную поддержку Clash с потерей некоторых функций",
    ),
    "concurrencyLimit": MessageLookupByLibrary.simpleMessage(
      "Лимит параллелизма",
    ),
    "concurrencyLimitDesc": MessageLookupByLibrary.simpleMessage(
      "Максимальное количество параллельных тестов задержки",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "confirmClearInvalid": MessageLookupByLibrary.simpleMessage(
      "Удалить все резидентные IP, не прошедшие проверку?",
    ),
    "confirmDelete": MessageLookupByLibrary.simpleMessage(
      "Подтвердите удаление",
    ),
    "confirmDeleteNodeMsg": m5,
    "confirmImport": MessageLookupByLibrary.simpleMessage("Подтвердить импорт"),
    "connection": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр текущих соединений",
    ),
    "connectionsSort": MessageLookupByLibrary.simpleMessage(
      "Сортировка соединений",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Подключение: "),
    "contactMe": MessageLookupByLibrary.simpleMessage("Связаться со мной"),
    "content": MessageLookupByLibrary.simpleMessage("Содержимое"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Контентная тема"),
    "continent": MessageLookupByLibrary.simpleMessage("Континент"),
    "controlSecret": MessageLookupByLibrary.simpleMessage("Пароль управления"),
    "controlSecretDesc": MessageLookupByLibrary.simpleMessage(
      "Пароль для доступа к RESTful API",
    ),
    "copiedPackageName": MessageLookupByLibrary.simpleMessage(
      "Скопировано имя пакета",
    ),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "Скопировано в буфер обмена",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копировать переменные окружения",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Скопировано"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreConnected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("Информация о ядре"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Статус ядра"),
    "coreSuspended": MessageLookupByLibrary.simpleMessage("Приостановлено"),
    "country": MessageLookupByLibrary.simpleMessage("Регион"),
    "countryOrRegion": MessageLookupByLibrary.simpleMessage("Страна / Регион"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест сбоя"),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "createEmptyGroup": MessageLookupByLibrary.simpleMessage(
      "Создать пустую группу",
    ),
    "createEmptyGroupDesc": MessageLookupByLibrary.simpleMessage(
      "Создайте новую пустую конфигурацию с поддержкой ручного ввода и управления собственными узлами всех протоколов",
    ),
    "createEmptyGroupHint": MessageLookupByLibrary.simpleMessage(
      "После создания пустой группы вы можете вручную добавить узлы для каждого протокола или массово импортировать ссылки в один клик.",
    ),
    "createGroupFailed": m6,
    "createGroupSuccess": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("Время создания"),
    "custom": MessageLookupByLibrary.simpleMessage("Пользовательский"),
    "customConfigHintText": MessageLookupByLibrary.simpleMessage(
      "Введите или вставьте сюда полный фрагмент конфигурации узла YAML или JSON:",
    ),
    "customConfigLabel": MessageLookupByLibrary.simpleMessage(
      "Пользовательская конфигурация (YAML / JSON)",
    ),
    "customConfigNode": MessageLookupByLibrary.simpleMessage(
      "Узел с пользовательской конфигурацией",
    ),
    "customDashboardTitle": MessageLookupByLibrary.simpleMessage(
      "Пользовательский заголовок",
    ),
    "customLandingProxyName": MessageLookupByLibrary.simpleMessage(
      "Своё имя узла прокси-выхода",
    ),
    "customNodesDefaultName": MessageLookupByLibrary.simpleMessage(
      "Собственные узлы",
    ),
    "customPreProxyName": MessageLookupByLibrary.simpleMessage(
      "Своё имя узла предпрокси",
    ),
    "customScriptOptions": MessageLookupByLibrary.simpleMessage("Свои правила"),
    "customUrl": MessageLookupByLibrary.simpleMessage("Пользовательский URL"),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "darkIcon": MessageLookupByLibrary.simpleMessage("Тёмная иконка"),
    "darkIconDesc": MessageLookupByLibrary.simpleMessage(
      "Вручную переключить на тёмную иконку приложения",
    ),
    "dashboard": MessageLookupByLibrary.simpleMessage("Главная"),
    "days": m8,
    "dedicatedGroup": MessageLookupByLibrary.simpleMessage(
      "Создать отдельную группу цепочки прокси",
    ),
    "dedicatedGroupDesc": MessageLookupByLibrary.simpleMessage(
      "Создаёт отдельную карточку группы «🔗 Цепочка прокси» на странице прокси",
    ),
    "defaultDialerProxy": MessageLookupByLibrary.simpleMessage(
      "Входной переход по умолчанию",
    ),
    "defaultDialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Узел или группа, используемые прокси выхода по умолчанию (рекомендуется группа выбора узла)",
    ),
    "defaultGateway": MessageLookupByLibrary.simpleMessage("Шлюз по умолчанию"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS по умолчанию",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения DNS-серверов",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delayAnimation": MessageLookupByLibrary.simpleMessage("Анимация задержки"),
    "delayAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка анимации при тестировании",
    ),
    "delaySort": MessageLookupByLibrary.simpleMessage("По задержке"),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteMultipTip": m9,
    "deleteNode": MessageLookupByLibrary.simpleMessage("Удалить узел"),
    "deleteTip": m10,
    "deleteTunnel": MessageLookupByLibrary.simpleMessage(
      "Удалить перенаправление",
    ),
    "desc": MessageLookupByLibrary.simpleMessage(
      "Fluxora основан на мощном и гибком прокси-ядре Mihomo (Clash.Meta) и стремится к созданию лучшего пользовательского опыта. Наше видение: Clear routes, calm control",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("По убыванию"),
    "destination": MessageLookupByLibrary.simpleMessage("Адрес назначения"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Геолокация назначения",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "IP ASN назначения",
    ),
    "details": MessageLookupByLibrary.simpleMessage("Подробности"),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Зависит от сторонних API, только для справки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика включён.",
    ),
    "diagnosticAdvice": MessageLookupByLibrary.simpleMessage(
      "Умные рекомендации по диагностике",
    ),
    "dialerIp4pConvert": MessageLookupByLibrary.simpleMessage(
      "Включить преобразование IP4P",
    ),
    "dialerIp4pConvertDesc": MessageLookupByLibrary.simpleMessage(
      "Включить преобразование IP4P в диалере",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Напрямую"),
    "directConnection": MessageLookupByLibrary.simpleMessage(
      "DIRECT (без перехода)",
    ),
    "directNameserver": MessageLookupByLibrary.simpleMessage(
      "DNS для прямого подключения",
    ),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов с прямым подключением",
    ),
    "directNameserverFollowPolicy": MessageLookupByLibrary.simpleMessage(
      "Прямой DNS учитывает политики DNS",
    ),
    "disableQuic": MessageLookupByLibrary.simpleMessage("Отключить QUIC"),
    "disableQuicDesc": MessageLookupByLibrary.simpleMessage(
      "Отключить QUIC для решения сетевых проблем",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Отказ от ответственности",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Это бесплатное ПО с открытым исходным кодом, предназначенное только для обучения и личного тестирования. Действия прокси-провайдеров не связаны с этим ПО. Соглашаясь, вы подтверждаете, что полностью осведомлены об этом. Если не согласны, пожалуйста, выйдите!",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Доступна новая версия",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage("Доступно обновление"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("Настройки DNS"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Перенаправить разбор в модуль DNS",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("Разрешить"),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "domainName": MessageLookupByLibrary.simpleMessage("Домен"),
    "doubleBounce": MessageLookupByLibrary.simpleMessage("Двойной отскок"),
    "downLabel": MessageLookupByLibrary.simpleMessage("Вниз"),
    "download": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "dozeSuspend": MessageLookupByLibrary.simpleMessage("Поддержка Doze"),
    "dozeSuspendDesc": MessageLookupByLibrary.simpleMessage(
      "Синхронизация с режимом сна Android",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editTunnel": MessageLookupByLibrary.simpleMessage(
      "Изменить перенаправление",
    ),
    "emptyLandingTip": MessageLookupByLibrary.simpleMessage(
      "Резидентных узлов выхода пока нет. Вставьте распространённые форматы основных провайдеров резидентных IP (IPRoyal, LunaProxy, Oxylabs и другие) для импорта в один клик.",
    ),
    "emptyTip": m11,
    "enableChainProxy": MessageLookupByLibrary.simpleMessage(
      "Включить цепочку прокси",
    ),
    "enableChainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Промежуточное подключение через входной узел к прокси выхода, обход сетевых ограничений с сохранением реального резидентного выхода",
    ),
    "enableCrashReport": MessageLookupByLibrary.simpleMessage("Анализ сбоев"),
    "enableCrashReportDesc": MessageLookupByLibrary.simpleMessage(
      "Отправка отчётов о сбоях при необходимости",
    ),
    "enableOverride": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение",
    ),
    "enableProfileChain": MessageLookupByLibrary.simpleMessage(
      "Включить цепной прокси для этой группы подписки",
    ),
    "enableProfileChainDesc": MessageLookupByLibrary.simpleMessage(
      "Поддерживает ретрансляцию через предпрокси и настройку финального прокси-выхода",
    ),
    "enableTraySpeed": MessageLookupByLibrary.simpleMessage("Скорость в трее"),
    "enableTraySpeedDesc": MessageLookupByLibrary.simpleMessage(
      "Отображение скорости отдачи и загрузки в строке меню",
    ),
    "enableUdpForwarding": MessageLookupByLibrary.simpleMessage(
      "Включить пересылку UDP",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "Улучшенный NAT",
    ),
    "endpointIndependentNatConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "Включение функции Endpoint-Independent NAT может незначительно снизить производительность. Рекомендуется включать её только в случае необходимости и если вы с ней знакомы.",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Оптимизация работы UDP/P2P приложений",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "exclude": MessageLookupByLibrary.simpleMessage("Скрыть из недавних"),
    "excludeChina": MessageLookupByLibrary.simpleMessage("Исключить Китай"),
    "excludeChinaDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить QUIC-трафик Китая вместо полной блокировки",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Скрыть приложение из недавних задач",
    ),
    "existsTip": m12,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "expand": MessageLookupByLibrary.simpleMessage("Максимальная"),
    "experimental": MessageLookupByLibrary.simpleMessage("Экспериментальное"),
    "experimentalDesc": MessageLookupByLibrary.simpleMessage(
      "Экспериментальные настройки, используйте с осторожностью",
    ),
    "expirationTime": MessageLookupByLibrary.simpleMessage("Срок действия"),
    "expired": MessageLookupByLibrary.simpleMessage("Истекший"),
    "export": MessageLookupByLibrary.simpleMessage("Экспорт"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Экспорт файла"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Экспорт успешен"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Экспрессивный"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешнее управление",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Управление ядром через REST API",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "externalResources": MessageLookupByLibrary.simpleMessage(
      "Внешние ресурсы",
    ),
    "fadingCircle": MessageLookupByLibrary.simpleMessage("Затухающий круг"),
    "fadingFour": MessageLookupByLibrary.simpleMessage("Затухающие точки"),
    "failover": MessageLookupByLibrary.simpleMessage("Аварийное переключение"),
    "failoverEnableFirst": MessageLookupByLibrary.simpleMessage(
      "Сначала включите цепочку прокси",
    ),
    "failoverFailed": m13,
    "failoverInProgress": MessageLookupByLibrary.simpleMessage(
      "Выполняется аварийное переключение...",
    ),
    "failoverManualHint": MessageLookupByLibrary.simpleMessage(
      "При обнаружении сбоя цепочки можно вручную переключиться на резервный узел",
    ),
    "failoverNoCandidates": MessageLookupByLibrary.simpleMessage(
      "Резервные кандидаты ещё не настроены",
    ),
    "failoverNoCandidatesAdvice": MessageLookupByLibrary.simpleMessage(
      "Добавьте резервного кандидата хотя бы для одной роли выше и повторите попытку",
    ),
    "failoverSuccess": m14,
    "failoverTrigger": MessageLookupByLibrary.simpleMessage(
      "Переключить сейчас",
    ),
    "failoverTriggerReason": MessageLookupByLibrary.simpleMessage(
      "Пользователь запустил переключение вручную",
    ),
    "fakeIpFilterMode": MessageLookupByLibrary.simpleMessage(
      "Режим фильтрации FakeIP",
    ),
    "fakeIpFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Указать режим фильтрации FakeIP",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр FakeIP"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон FakeIP"),
    "fakeipRangeV6": MessageLookupByLibrary.simpleMessage("Диапазон FakeIPv6"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Время жизни FakeIP"),
    "fallback": MessageLookupByLibrary.simpleMessage("Резервный DNS"),
    "fallbackConcurrent": MessageLookupByLibrary.simpleMessage(
      "Параллельный опрос резервного DNS",
    ),
    "fallbackConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Одновременный опрос основного и резервного DNS",
    ),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Обычно используются зарубежные DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Фильтр резервного DNS",
    ),
    "fcmOptimization": MessageLookupByLibrary.simpleMessage("Оптимизация FCM"),
    "fcmOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Повышает стабильность FCM при прямом подключении",
    ),
    "fcmTip": MessageLookupByLibrary.simpleMessage(
      "FCM зависит от устройства. Для точных результатов отключите \'Разрешить обход VPN\'",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Высокая точность"),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileDesc": MessageLookupByLibrary.simpleMessage(
      "Загрузить файл конфигурации",
    ),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл изменён. Сохранить изменения?",
    ),
    "filterAll": MessageLookupByLibrary.simpleMessage("Все"),
    "filterError": MessageLookupByLibrary.simpleMessage("Сбой/не проверено"),
    "filterHealthy": MessageLookupByLibrary.simpleMessage("Только рабочие"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Скрыть системные приложения",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Определение процессов",
    ),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "Включить определение процессов",
    ),
    "flagged": MessageLookupByLibrary.simpleMessage("Помечен"),
    "followMainSelector": MessageLookupByLibrary.simpleMessage(
      "Следовать текущей группе выбора узла (рекомендуется)",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Шрифт"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Принудительное DNS-отображение",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Принудительно отображать результаты DNS на соединение",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage(
      "Принудительный сниффинг доменов",
    ),
    "forceGCDesc": MessageLookupByLibrary.simpleMessage(
      "Выполнить сброс мусора ядра? Экспериментально, используйте с осторожностью",
    ),
    "forceGCTitle": MessageLookupByLibrary.simpleMessage("Очистка кеша ядра"),
    "formatError": MessageLookupByLibrary.simpleMessage("Проверьте формат"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("4 колонки"),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("Фруктовый микс"),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Изменить глобальные настройки",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Создать из приватного ключа",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Сгенерировать"),
    "geoData": MessageLookupByLibrary.simpleMessage("Геоданные"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Экономия памяти GEO",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать загрузчик GEO с низким потреблением памяти",
    ),
    "geodataUse": MessageLookupByLibrary.simpleMessage("Загрузка GEO"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код GeoIP"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage(
      "Получить исходные правила",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Глобально"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Перейти к загрузке"),
    "groupName": MessageLookupByLibrary.simpleMessage("Название группы"),
    "harmonyFont": MessageLookupByLibrary.simpleMessage("Исправление шрифта"),
    "harmonyFontDesc": MessageLookupByLibrary.simpleMessage(
      "Встроенный шрифт для исправления отображения",
    ),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Кэшировать изменения?",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Проверка доступности"),
    "healthCheckAll": MessageLookupByLibrary.simpleMessage("Полная проверка"),
    "healthCheckTimeout": MessageLookupByLibrary.simpleMessage(
      "Таймаут проверки",
    ),
    "healthCheckTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Таймаут проверки работоспособности узлов",
    ),
    "healthError": MessageLookupByLibrary.simpleMessage("Сбой и недоступен"),
    "healthHealthy": MessageLookupByLibrary.simpleMessage("Работает"),
    "healthReport": MessageLookupByLibrary.simpleMessage(
      "Отчёт о подключении резидентного IP",
    ),
    "healthUntested": MessageLookupByLibrary.simpleMessage("Не проверено"),
    "healthWarning": MessageLookupByLibrary.simpleMessage("Частично ограничен"),
    "heapObjects": MessageLookupByLibrary.simpleMessage("Objects"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Скрыть узлы с тайм-аутом",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Не показывать узлы, у которых последняя проверка задержки завершилась тайм-аутом",
    ),
    "highPriority": MessageLookupByLibrary.simpleMessage("Высокий приоритет"),
    "highPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "Повысить приоритет процесса приложения и ядра",
    ),
    "highRefreshRate": MessageLookupByLibrary.simpleMessage(
      "Высокая частота обновления",
    ),
    "highRefreshRateDesc": MessageLookupByLibrary.simpleMessage(
      "Включить поддержку максимальной частоты обновления устройства",
    ),
    "hop": MessageLookupByLibrary.simpleMessage("Переход"),
    "host": MessageLookupByLibrary.simpleMessage("Хост"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage(
      "Добавить hosts к текущей конфигурации",
    ),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Конфликт горячих клавиш",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Управление горячими клавишами",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Управление приложением с клавиатуры",
    ),
    "hours": m15,
    "httpPortSniffer": MessageLookupByLibrary.simpleMessage(
      "HTTP порты сниффера",
    ),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("Пересылка ICMP"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Включить поддержку ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Иконка"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage(
      "Настройка иконки",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль иконок"),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importFailed": MessageLookupByLibrary.simpleMessage("Ошибка импорта"),
    "importFile": MessageLookupByLibrary.simpleMessage("Импорт из файла"),
    "importFromCode": MessageLookupByLibrary.simpleMessage("Импорт из кода"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Импорт из URL"),
    "importShareLinks": MessageLookupByLibrary.simpleMessage(
      "Импортировать ссылки",
    ),
    "importSuccessCount": m16,
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Бессрочно"),
    "inheritDefaultDialer": MessageLookupByLibrary.simpleMessage(
      "Наследовать глобальный переход по умолчанию",
    ),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Введите корректное сочетание клавиш",
    ),
    "inputProxyTextHint": MessageLookupByLibrary.simpleMessage(
      "Вставьте данные резидентного IP, например:\n198.51.100.1:8000:username:password\nили socks5://user:pass@198.51.100.1:8000\nПоддерживается вставка нескольких строк сразу",
    ),
    "installTime": MessageLookupByLibrary.simpleMessage("Время установки"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("Умный выбор"),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetAndGateway": MessageLookupByLibrary.simpleMessage(
      "Интранет и шлюз",
    ),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Локальный IP"),
    "invalidIpFormat": MessageLookupByLibrary.simpleMessage(
      "Неверный формат IP или CIDR",
    ),
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP-адрес"),
    "ipClickBehavior": MessageLookupByLibrary.simpleMessage(
      "Режим отображения",
    ),
    "ipPrivacyProtection": MessageLookupByLibrary.simpleMessage("Скрыть IP"),
    "ipRiskAbuse": MessageLookupByLibrary.simpleMessage(
      "Жалобы на злоупотребления",
    ),
    "ipRiskBlocklists": MessageLookupByLibrary.simpleMessage("Чёрные списки"),
    "ipRiskBogon": MessageLookupByLibrary.simpleMessage(
      "Зарезервированный адрес",
    ),
    "ipRiskEnable": MessageLookupByLibrary.simpleMessage("Включить запрос"),
    "ipRiskFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось выполнить запрос",
    ),
    "ipRiskHosting": MessageLookupByLibrary.simpleMessage("Хостинг/ЦОД"),
    "ipRiskIntel": MessageLookupByLibrary.simpleMessage("IP-репутация"),
    "ipRiskLimits": MessageLookupByLibrary.simpleMessage(
      "Что эти данные не показывают",
    ),
    "ipRiskMobile": MessageLookupByLibrary.simpleMessage("Мобильная сеть"),
    "ipRiskNotFlagged": MessageLookupByLibrary.simpleMessage("Не обнаружено"),
    "ipRiskOpenReport": MessageLookupByLibrary.simpleMessage(
      "Открыть полный отчёт",
    ),
    "ipRiskPrivacyNote": MessageLookupByLibrary.simpleMessage(
      "Ваш IP отправляется третьей стороне (нет политики конфиденциальности)",
    ),
    "ipRiskProxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "ipRiskRelay": MessageLookupByLibrary.simpleMessage("Ретранслятор"),
    "ipRiskSearchEngineBot": MessageLookupByLibrary.simpleMessage(
      "Поисковый бот",
    ),
    "ipRiskStale": MessageLookupByLibrary.simpleMessage(
      "Устаревшие данные (не в реальном времени)",
    ),
    "ipRiskTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipRiskVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("Включить поддержку IPv6"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить входящие IPv6",
    ),
    "isp": MessageLookupByLibrary.simpleMessage("Провайдер"),
    "itemsCount": m17,
    "jcLabel": MessageLookupByLibrary.simpleMessage(
      "Jc (число мусорных пакетов)",
    ),
    "juicityPassword": MessageLookupByLibrary.simpleMessage(
      "Пароль Juicity (введите UUID выше)",
    ),
    "just": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал TCP keep-alive",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "lanShareAddress": MessageLookupByLibrary.simpleMessage("Адрес для LAN"),
    "landingProxies": MessageLookupByLibrary.simpleMessage(
      "Резидентные узлы выхода",
    ),
    "landingProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ Ввести имя узла прокси-выхода вручную...",
    ),
    "landingProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "Нет (использовать узел подписки как финальный выход)",
    ),
    "landingProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "Узел подписки выступает в роли ретранслятора предпрокси, а этот узел становится финальным выходом. Полезно для сокрытия IP аэропорта, обхода блокировок через WARP и разблокировки AI и стриминга.",
    ),
    "landingProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "2. Прокси-выход",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "lastEdit": MessageLookupByLibrary.simpleMessage(
      "Последнее редактирование",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Ширина"),
    "leftClickBehavior": MessageLookupByLibrary.simpleMessage("Действие ЛКМ"),
    "legacyBackup": MessageLookupByLibrary.simpleMessage(
      "Резервная копия старого формата",
    ),
    "light": MessageLookupByLibrary.simpleMessage("Светлая"),
    "limitedUnlock": MessageLookupByLibrary.simpleMessage("Только оригиналы"),
    "lineWrap": MessageLookupByLibrary.simpleMessage("Перенос строк"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Прослушивание"),
    "local": MessageLookupByLibrary.simpleMessage("Локальное хранилище"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование данных в файл",
    ),
    "localFile": MessageLookupByLibrary.simpleMessage("Локальный файл"),
    "localIpLabel": MessageLookupByLibrary.simpleMessage("Локальный IP"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановление из файла",
    ),
    "locate": MessageLookupByLibrary.simpleMessage("Найти"),
    "log": MessageLookupByLibrary.simpleMessage("Лог"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Сбор логов"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("Показать раздел логов"),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Просмотр логов"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест логов"),
    "loopback": MessageLookupByLibrary.simpleMessage("Разблокировка UWP"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Инструмент для разблокировки UWP loopback",
    ),
    "loopbackProtection": MessageLookupByLibrary.simpleMessage(
      "Защита от закольцовки",
    ),
    "loopbackProtectionDesc": MessageLookupByLibrary.simpleMessage(
      "Блокировать закольцованный трафик из-за ошибок сети",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Максимальная"),
    "manualAddNode": MessageLookupByLibrary.simpleMessage(
      "Добавить узел вручную",
    ),
    "manualEntry": MessageLookupByLibrary.simpleMessage("Ручной ввод"),
    "manualRefreshIp": MessageLookupByLibrary.simpleMessage("Обновить IP"),
    "maximize": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "mediaUnlock": MessageLookupByLibrary.simpleMessage("Проверка доступности"),
    "mediaUnlockColorfulIcons": MessageLookupByLibrary.simpleMessage(
      "Показывать цветные значки по умолчанию",
    ),
    "mediaUnlockDetails": MessageLookupByLibrary.simpleMessage(
      "Детали проверки доступности",
    ),
    "mediaUnlockDisplaySettings": MessageLookupByLibrary.simpleMessage(
      "Настройки отображения",
    ),
    "mediaUnlockExtraDetails": MessageLookupByLibrary.simpleMessage(
      "Показывать больше сведений об IP",
    ),
    "mediaUnlockMiscSettings": MessageLookupByLibrary.simpleMessage(
      "Прочие настройки",
    ),
    "mediaUnlockPinnedSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Можно выбрать до 4 элементов для закрепления в виджете",
    ),
    "mediaUnlockRefreshOnNodeChange": MessageLookupByLibrary.simpleMessage(
      "Автообновление при смене узла",
    ),
    "mediaUnlockSelectLimit": MessageLookupByLibrary.simpleMessage(
      "Можно выбрать максимум 4 элемента",
    ),
    "mediaUnlocked": MessageLookupByLibrary.simpleMessage("Разблокировано"),
    "memoryAndRuntime": MessageLookupByLibrary.simpleMessage(
      "Память и среда выполнения",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Память"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Текущее значение памяти — это динамическое потребление стека ядра во время выполнения, а не полная статистика памяти приложения, только для справки.",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("Тест сообщения"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "Это тестовое сообщение.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("Минимальная"),
    "minimize": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Сворачивать при выходе",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Изменить поведение при выходе",
    ),
    "minutes": m18,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "months": m19,
    "more": MessageLookupByLibrary.simpleMessage("Подробности"),
    "moreIpInfo": MessageLookupByLibrary.simpleMessage(
      "Подробная информация об IP",
    ),
    "name": MessageLookupByLibrary.simpleMessage("Имя"),
    "nameSort": MessageLookupByLibrary.simpleMessage("По имени"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Основной DNS"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("Политика DNS"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Указать политику DNS для конкретных доменов",
    ),
    "navBarHapticFeedback": MessageLookupByLibrary.simpleMessage(
      "Тактильная отдача",
    ),
    "navBarHapticFeedbackDesc": MessageLookupByLibrary.simpleMessage(
      "Вибрация при переключении нижней панели навигации",
    ),
    "navConnections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "navTools": MessageLookupByLibrary.simpleMessage("Еще"),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("Настройки сети"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("IP сети"),
    "networkDetectionUrl": MessageLookupByLibrary.simpleMessage(
      "URL определения сети",
    ),
    "networkErrorRetryLater": MessageLookupByLibrary.simpleMessage(
      "Ошибка сети, попробуйте позже",
    ),
    "networkFix": MessageLookupByLibrary.simpleMessage("Исправление сети"),
    "networkFixDesc": MessageLookupByLibrary.simpleMessage(
      "Исправляет значок сети в системе",
    ),
    "networkInterface": MessageLookupByLibrary.simpleMessage("Интерфейс"),
    "networkLabel": MessageLookupByLibrary.simpleMessage("Транспорт"),
    "networkMatch": MessageLookupByLibrary.simpleMessage("Сопоставление сети"),
    "networkMatchHint": MessageLookupByLibrary.simpleMessage(
      "Введите IP или CIDR, максимум 2, через запятую",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Скорость в уведомлениях",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Показывать скорость и подписку в панели уведомлений",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Тип сети"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Нейтральный"),
    "noAnimation": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "noBackupFileFound": MessageLookupByLibrary.simpleMessage(
      "Файл резервной копии не найден",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Нет горячих клавиш"),
    "noIcon": MessageLookupByLibrary.simpleMessage("Без иконок"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Нет информации"),
    "noInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "Сейчас недоступных узлов нет",
    ),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Нет дополнительной информации",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложения без сети"),
    "noNodesInGroup": MessageLookupByLibrary.simpleMessage(
      "В этой группе пока нет узлов",
    ),
    "noNodesInGroupHint": MessageLookupByLibrary.simpleMessage(
      "Нажмите «Добавить узел вручную» в правом нижнем углу или «Массовый импорт ссылок» в правом верхнем углу",
    ),
    "noProxy": MessageLookupByLibrary.simpleMessage("Нет прокси"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Создайте или добавьте профиль",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "noStatusAvailable": MessageLookupByLibrary.simpleMessage(
      "Статус недоступен",
    ),
    "noUsageData": MessageLookupByLibrary.simpleMessage("Нет статистики"),
    "nodeAdded": m20,
    "nodeDeleted": m21,
    "nodeExclusion": MessageLookupByLibrary.simpleMessage("Исключение узлов"),
    "nodeExclusionDesc": MessageLookupByLibrary.simpleMessage(
      "Исключить все узлы, соответствующие шаблону",
    ),
    "nodeExclusionPlaceholder": MessageLookupByLibrary.simpleMessage(
      "HK|Гонконг|🇭🇰",
    ),
    "nodeManagement": m22,
    "nodeName": MessageLookupByLibrary.simpleMessage("Имя узла"),
    "nodeNameHint": m23,
    "nodeNameLabel": MessageLookupByLibrary.simpleMessage("Имя узла"),
    "nodeProtocol": MessageLookupByLibrary.simpleMessage("Протокол узла"),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "notRecommended": MessageLookupByLibrary.simpleMessage("Не рекомендуется"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Невозможно выбрать эту группу прокси",
    ),
    "notUnlocked": MessageLookupByLibrary.simpleMessage("Заблокировано"),
    "notificationHighPriority": MessageLookupByLibrary.simpleMessage(
      "Высокий приоритет",
    ),
    "notificationHighPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "Установить высокий приоритет для панели уведомлений",
    ),
    "notificationHighPriorityTip": MessageLookupByLibrary.simpleMessage(
      "Уведомления с высоким приоритетом могут решить проблемы работы в фоне на некоторых кастомных прошивках. Если ваш VPN работает нормально, рекомендуется оставить выключенным. Включить?",
    ),
    "ntp": MessageLookupByLibrary.simpleMessage("NTP"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать службу времени NTP",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("Интервал обновления"),
    "ntpPort": MessageLookupByLibrary.simpleMessage("Порт NTP"),
    "ntpServer": MessageLookupByLibrary.simpleMessage("Сервер NTP"),
    "ntpStatus": MessageLookupByLibrary.simpleMessage("Статус NTP"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Включить службу времени NTP",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Нет профиля, добавьте его",
    ),
    "nullTip": m24,
    "numberTip": m25,
    "obfsModeLabel": MessageLookupByLibrary.simpleMessage("Режим обфускации"),
    "obfsNoneOff": MessageLookupByLibrary.simpleMessage("Нет (выкл.)"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("1 колонка"),
    "onlinePanel": MessageLookupByLibrary.simpleMessage("Онлайн-панель"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Только иконки"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage("Только сторонние"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Только прокси-трафик",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Считать только трафик через прокси",
    ),
    "openDashboard": MessageLookupByLibrary.simpleMessage("Открыть Zashboard"),
    "openGateway": MessageLookupByLibrary.simpleMessage("Открыть шлюз"),
    "openSettings": MessageLookupByLibrary.simpleMessage("Открыть настройки"),
    "operatorOrAsn": MessageLookupByLibrary.simpleMessage("Организация / ASN"),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Другие участники (в случайном порядке)",
    ),
    "otherSettings": MessageLookupByLibrary.simpleMessage(
      "Расширенные инструменты",
    ),
    "otherSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка расширенных функций",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Маршрутизация"),
    "override": MessageLookupByLibrary.simpleMessage("Переопределение"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage(
      "Переопределение конфигурации прокси",
    ),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Переопределить назначение",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать результаты сниффинга для переопределения целевого адреса",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Переопределить DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение настроек DNS в конфигурации",
    ),
    "overrideExperimental": MessageLookupByLibrary.simpleMessage(
      "Переопределить экспериментальное",
    ),
    "overrideExperimentalDesc": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение экспериментальных настроек в конфигурации",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Не действует в режиме скрипта",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Переопределить NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение настроек NTP в конфигурации",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "Переопределить исходные правила",
    ),
    "overrideSniffer": MessageLookupByLibrary.simpleMessage(
      "Переопределить сниффер",
    ),
    "overrideSnifferDesc": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение настроек сниффера в конфигурации",
    ),
    "overrideTestUrl": MessageLookupByLibrary.simpleMessage(
      "Переопределить конфигурацию",
    ),
    "overrideTunnel": MessageLookupByLibrary.simpleMessage(
      "Переопределить туннель",
    ),
    "overrideTunnelDesc": MessageLookupByLibrary.simpleMessage(
      "Включить переопределение настроек туннеля в конфигурации",
    ),
    "packageListPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Разрешение отклонено. Без доступа невозможно получить список приложений.",
    ),
    "packageListPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Эта функция требует доступа к списку установленных приложений. Предоставить разрешение?",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Палитра"),
    "parseNoValidNode": MessageLookupByLibrary.simpleMessage(
      "Действительная информация о прокси не найдена. Проверьте формат",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Сниффинг прямых IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "Разбирать соединения по чистому IP",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "passwordAuth": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage(
      "Вставить из буфера обмена",
    ),
    "peerPublicKey": MessageLookupByLibrary.simpleMessage("Открытый ключ пира"),
    "pin": MessageLookupByLibrary.simpleMessage("Закрепить"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Привяжите WebDAV",
    ),
    "pleaseCloseSystemProxyFirst": MessageLookupByLibrary.simpleMessage(
      "Сначала отключите системный прокси",
    ),
    "pleaseCloseTunFirst": MessageLookupByLibrary.simpleMessage(
      "Сначала отключите режим TUN",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Введите название скрипта",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Введите пароль администратора",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage("Загрузите файл"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Загрузите корректный QR-код",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите разные порты",
    ),
    "portFallback": MessageLookupByLibrary.simpleMessage(
      "Обход занятого порта",
    ),
    "portFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать другой порт, если заданный уже занят",
    ),
    "portLabel": MessageLookupByLibrary.simpleMessage("Порт"),
    "portTip": m26,
    "powerSwitch": MessageLookupByLibrary.simpleMessage("Запуск"),
    "preProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ Ввести имя узла предпрокси вручную...",
    ),
    "preProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "Нет (подключаться напрямую к узлу подписки)",
    ),
    "preProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "Перед тем как трафик попадёт на узел подписки, он сначала проходит туннель через узел предпрокси. Полезно для спасения заблокированных узлов.",
    ),
    "preProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "1. Предпрокси",
    ),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Приоритет HTTP/3 для DoH",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("Нажмите клавиши"),
    "preventWebRtcLeak": MessageLookupByLibrary.simpleMessage(
      "Предотвратить утечку реального IP WebRTC",
    ),
    "preventWebRtcLeakDesc": MessageLookupByLibrary.simpleMessage(
      "Блокирует запросы STUN/TURN, предотвращая раскрытие реального публичного IP и обеспечивая безопасность зарубежных аккаунтов и кросс-бордер-электронной коммерции",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "privateIp": MessageLookupByLibrary.simpleMessage(
      "Частный / локальный IP-адрес",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Приватный ключ"),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profileAndRules": MessageLookupByLibrary.simpleMessage(
      "Профиль и правила",
    ),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Введите корректный формат интервала",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите интервал автообновления"),
    "profileChainDialogTitle": m27,
    "profileChainSaved": MessageLookupByLibrary.simpleMessage(
      "Настройки предпрокси и прокси-выхода сохранены",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Конфигурация изменена. Отключить автообновление?",
    ),
    "profileImportFailed": m28,
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите имя профиля",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "Ошибка чтения профиля",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите корректный URL профиля",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите URL профиля",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортировка профилей"),
    "progress": MessageLookupByLibrary.simpleMessage("Процесс"),
    "project": MessageLookupByLibrary.simpleMessage("Проект"),
    "protocol": MessageLookupByLibrary.simpleMessage("Протокол прокси"),
    "providers": MessageLookupByLibrary.simpleMessage("Провайдеры"),
    "provinceAndCity": MessageLookupByLibrary.simpleMessage(
      "Провинция / Город",
    ),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesCount": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("Настройки прокси"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Цепочка прокси"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Группа прокси"),
    "proxyGroupsCount": MessageLookupByLibrary.simpleMessage("Группы"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("DNS для прокси"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разрешения доменов прокси",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("Порт прокси"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage(
      "Установить порт прослушивания Clash",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "proxyProvidersCount": MessageLookupByLibrary.simpleMessage(
      "Наборы прокси",
    ),
    "pskKey": MessageLookupByLibrary.simpleMessage(
      "Предварительный общий ключ PSK",
    ),
    "pulse": MessageLookupByLibrary.simpleMessage("Пульсация"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чистый чёрный"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканировать QR для получения профиля",
    ),
    "quicGoDisableEcn": MessageLookupByLibrary.simpleMessage(
      "Отключить ECN QUIC",
    ),
    "quicGoDisableEcnDesc": MessageLookupByLibrary.simpleMessage(
      "Отключить Explicit Congestion Notification для QUIC",
    ),
    "quicGoDisableGso": MessageLookupByLibrary.simpleMessage(
      "Отключить GSO QUIC",
    ),
    "quicGoDisableGsoDesc": MessageLookupByLibrary.simpleMessage(
      "Отключить Generic Segmentation Offload для QUIC",
    ),
    "quicPortSniffer": MessageLookupByLibrary.simpleMessage(
      "QUIC порты сниффера",
    ),
    "quickImport": MessageLookupByLibrary.simpleMessage("Умный быстрый импорт"),
    "quickImportDesc": MessageLookupByLibrary.simpleMessage(
      "Импорт в один клик из IP:порт:логин:пароль, ссылок и других распространённых форматов",
    ),
    "quickResponse": MessageLookupByLibrary.simpleMessage("Быстрый отклик"),
    "quickResponseDesc": MessageLookupByLibrary.simpleMessage(
      "Активно отключать соединения при изменении сети",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Радуга"),
    "realTimeSpeed": MessageLookupByLibrary.simpleMessage("Текущая скорость"),
    "realityPublicKey": MessageLookupByLibrary.simpleMessage(
      "Открытый ключ REALITY",
    ),
    "reclaimableMemory": MessageLookupByLibrary.simpleMessage("К возврату"),
    "recovery": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("Все данные"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage("Только профили"),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "Режим восстановления",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Совместимость",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Перезаписать",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage(
      "Восстановление успешно",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Порт перенаправления"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "refresh": MessageLookupByLibrary.simpleMessage("Обновить"),
    "refreshAppList": MessageLookupByLibrary.simpleMessage(
      "Обновить список приложений",
    ),
    "refreshAppListConfirm": MessageLookupByLibrary.simpleMessage(
      "Обновить список приложений?",
    ),
    "regExp": MessageLookupByLibrary.simpleMessage("Регулярное выражение"),
    "remote": MessageLookupByLibrary.simpleMessage("Удалённый сервер"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование на WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Удалённое назначение",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановление с WebDAV",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Удалить"),
    "rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "replace": MessageLookupByLibrary.simpleMessage("Заменить"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Заменить все"),
    "request": MessageLookupByLibrary.simpleMessage("Запрос"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр недавних запросов",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetTip": MessageLookupByLibrary.simpleMessage("Сбросить настройки?"),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Управление внешними ресурсами",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Следовать правилам"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-запросы следуют правилам маршрутизации",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапуск"),
    "restartApp": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "restartCoreDesc": MessageLookupByLibrary.simpleMessage(
      "Перезапустить ядро вручную?",
    ),
    "restartCoreTitle": MessageLookupByLibrary.simpleMessage("Перезапуск ядра"),
    "restartTip": MessageLookupByLibrary.simpleMessage(
      "Изменения вступят в силу после перезапуска TUN",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "retest": MessageLookupByLibrary.simpleMessage("Проверить снова"),
    "retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "rightClickBehavior": MessageLookupByLibrary.simpleMessage("Действие ПКМ"),
    "roleEntry": MessageLookupByLibrary.simpleMessage("Входной узел"),
    "roleExit": MessageLookupByLibrary.simpleMessage("Выход"),
    "roleRelay": MessageLookupByLibrary.simpleMessage("Транзитный узел"),
    "rotatingCircle": MessageLookupByLibrary.simpleMessage("Вращающийся круг"),
    "rule": MessageLookupByLibrary.simpleMessage("По правилам"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Имя правила"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдеры правил"),
    "ruleProvidersCount": MessageLookupByLibrary.simpleMessage("Наборы правил"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "rulesCount": MessageLookupByLibrary.simpleMessage("Правила"),
    "runTime": MessageLookupByLibrary.simpleMessage("Время работы"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Рантайм-конфигурация",
    ),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "saveAndApply": MessageLookupByLibrary.simpleMessage(
      "Сохранить и применить",
    ),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "saveNode": MessageLookupByLibrary.simpleMessage("Сохранить узел"),
    "saveTip": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "scriptDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка глобального скрипта переопределения",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("секунд"),
    "secretCopied": MessageLookupByLibrary.simpleMessage(
      "Пароль скопирован в буфер обмена",
    ),
    "securityLabel": MessageLookupByLibrary.simpleMessage("Безопасность/TLS"),
    "securityNonePlain": MessageLookupByLibrary.simpleMessage(
      "Нет (открытый текст)",
    ),
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать все"),
    "selectBackupVersion": MessageLookupByLibrary.simpleMessage(
      "Выберите версию резервной копии",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "selectedCountTitle": m29,
    "serverAddress": MessageLookupByLibrary.simpleMessage("Адрес сервера"),
    "serverAddressHint": MessageLookupByLibrary.simpleMessage("IP или домен"),
    "serverAddressLabel": MessageLookupByLibrary.simpleMessage("Адрес сервера"),
    "serverAddressRequired": MessageLookupByLibrary.simpleMessage(
      "Введите адрес сервера",
    ),
    "serviceReady": MessageLookupByLibrary.simpleMessage("Служба готова"),
    "serviceRunning": MessageLookupByLibrary.simpleMessage("Служба запущена"),
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "showHiddenItems": MessageLookupByLibrary.simpleMessage("Показать скрытые"),
    "showMenu": MessageLookupByLibrary.simpleMessage("Открыть меню"),
    "showPanel": MessageLookupByLibrary.simpleMessage("Показать окно"),
    "showStartSwitch": MessageLookupByLibrary.simpleMessage(
      "Тумблер запуска на главной",
    ),
    "showStartSwitchDesc": MessageLookupByLibrary.simpleMessage(
      "Отображать отдельную кнопку переключения на главной странице",
    ),
    "shrink": MessageLookupByLibrary.simpleMessage("Стандарт"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Тихий запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запуск в фоне без открытия окна",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Высота"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Пропустить проверку сертификата",
    ),
    "skipCertVerifyDesc": MessageLookupByLibrary.simpleMessage(
      "Устраняет ошибки самоподписанных сертификатов и TLS-рукопожатия",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Пропустить домены"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Пропустить IP назначения",
    ),
    "skipLocalAuth": MessageLookupByLibrary.simpleMessage(
      "Пропустить локальную аутентификацию",
    ),
    "skipLocalAuthDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить локальному устройству доступ к прокси без учетных данных",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Пропустить IP источника",
    ),
    "smartAutoStop": MessageLookupByLibrary.simpleMessage("Умная остановка"),
    "smartAutoStopDesc": MessageLookupByLibrary.simpleMessage(
      "Останавливать прокси при подключении к заданной сети",
    ),
    "smartAutoStopServiceRunning": MessageLookupByLibrary.simpleMessage(
      "Служба умной остановки работает",
    ),
    "smartDelayLaunch": MessageLookupByLibrary.simpleMessage("Умная задержка"),
    "smartDelayLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запуск после успешного подключения к сети",
    ),
    "snellVersion": MessageLookupByLibrary.simpleMessage("Версия Snell (1-4)"),
    "sniHint": MessageLookupByLibrary.simpleMessage(
      "Оставьте пустым, чтобы использовать адрес сервера",
    ),
    "sniLabel": MessageLookupByLibrary.simpleMessage(
      "SNI (ServerName / маскировочный домен)",
    ),
    "sniffer": MessageLookupByLibrary.simpleMessage("Сниффер"),
    "snifferAddressHint": MessageLookupByLibrary.simpleMessage(
      "Один адрес на строку",
    ),
    "snifferDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка сниффинга доменов",
    ),
    "snifferDomainHint": MessageLookupByLibrary.simpleMessage(
      "Один домен на строку",
    ),
    "snifferPorts": MessageLookupByLibrary.simpleMessage("Порты"),
    "snifferPortsHint": MessageLookupByLibrary.simpleMessage(
      "Например: 80, 8080-8880",
    ),
    "snifferStatus": MessageLookupByLibrary.simpleMessage("Статус сниффера"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Включить службу сниффинга",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Порт Socks"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP источника"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Специальный прокси"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Специальные правила"),
    "specificDialerProxy": MessageLookupByLibrary.simpleMessage(
      "Указать отдельный переход",
    ),
    "spinningLines": MessageLookupByLibrary.simpleMessage("Вращающиеся линии"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандарт"),
    "start": MessageLookupByLibrary.simpleMessage("Запуск"),
    "startTest": MessageLookupByLibrary.simpleMessage("Тест задержки"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN"),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать системный DNS при выключении",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Остановка"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN"),
    "storeFix": MessageLookupByLibrary.simpleMessage("Исправление Google Play"),
    "storeFixDesc": MessageLookupByLibrary.simpleMessage(
      "Исправляет проблемы загрузки Google Play",
    ),
    "strictRoute": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация",
    ),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать строгий режим маршрутизации TUN",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "subRule": MessageLookupByLibrary.simpleMessage("Подправило"),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "success": MessageLookupByLibrary.simpleMessage("Успех"),
    "switchLabel": MessageLookupByLibrary.simpleMessage("Переключатель"),
    "switchToDomesticIp": MessageLookupByLibrary.simpleMessage(
      "Получить локальный IP",
    ),
    "sync": MessageLookupByLibrary.simpleMessage("Синхронизировать"),
    "syncAll": MessageLookupByLibrary.simpleMessage("Синхронизировать всё"),
    "syncFailed": MessageLookupByLibrary.simpleMessage("Ошибка синхронизации"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системные приложения"),
    "systemDns": MessageLookupByLibrary.simpleMessage("Системный DNS"),
    "systemFont": MessageLookupByLibrary.simpleMessage("Системный шрифт"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "systemProxyActualOff": MessageLookupByLibrary.simpleMessage(
      "Системный прокси фактически выключен",
    ),
    "systemProxyActualOn": MessageLookupByLibrary.simpleMessage(
      "Системный прокси фактически включён",
    ),
    "systemProxyActualStatus": MessageLookupByLibrary.simpleMessage(
      "Фактическое состояние системы",
    ),
    "systemProxyChecking": MessageLookupByLibrary.simpleMessage(
      "Проверка фактического состояния системы…",
    ),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Настроить системный прокси",
    ),
    "systemProxyMismatchOff": MessageLookupByLibrary.simpleMessage(
      "Системный прокси всё ещё включён",
    ),
    "systemProxyMismatchOn": MessageLookupByLibrary.simpleMessage(
      "Настройка требует включения, но системный прокси фактически не включён",
    ),
    "systemProxyUnknown": MessageLookupByLibrary.simpleMessage(
      "Не удаётся определить состояние системного прокси",
    ),
    "systemProxyUnsupported": MessageLookupByLibrary.simpleMessage(
      "Эта платформа не поддерживает определение состояния системного прокси",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладки"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage(
      "Параллельные TCP-соединения",
    ),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить параллельные TCP-соединения",
    ),
    "testAll": MessageLookupByLibrary.simpleMessage("Проверить все"),
    "testCurrentProxy": MessageLookupByLibrary.simpleMessage(
      "Проверить доступность",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL теста"),
    "testing": MessageLookupByLibrary.simpleMessage("Проверка"),
    "testingHealth": MessageLookupByLibrary.simpleMessage("Проверка..."),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштаб текста"),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка темы и иконок",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "threeBounce": MessageLookupByLibrary.simpleMessage("Прыгающие точки"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("3 колонки"),
    "threeInOut": MessageLookupByLibrary.simpleMessage("Три точки"),
    "tight": MessageLookupByLibrary.simpleMessage("Минимальная"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "tip": MessageLookupByLibrary.simpleMessage("Подсказка"),
    "titleTooLong": MessageLookupByLibrary.simpleMessage(
      "Слишком длинный, максимум 20 символов",
    ),
    "tlsPortSniffer": MessageLookupByLibrary.simpleMessage(
      "TLS порты сниффера",
    ),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("Тональный акцент"),
    "tooManyRules": MessageLookupByLibrary.simpleMessage("Максимум 5 правил"),
    "tools": MessageLookupByLibrary.simpleMessage("Инструменты"),
    "topologyClient": MessageLookupByLibrary.simpleMessage("Локальный клиент"),
    "topologyHop": MessageLookupByLibrary.simpleMessage("Входной переход"),
    "topologyLanding": MessageLookupByLibrary.simpleMessage(
      "Резидентный выход",
    ),
    "topologyRelay": MessageLookupByLibrary.simpleMessage("Транзитный узел"),
    "topologyTarget": MessageLookupByLibrary.simpleMessage("Целевой сервис"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Общий трафик"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Порт Tproxy"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Трафик"),
    "trayClickBehavior": MessageLookupByLibrary.simpleMessage(
      "Действие при нажатии на значок",
    ),
    "trayEnhancement": MessageLookupByLibrary.simpleMessage("Улучшение трея"),
    "trayEnhancementDesc": MessageLookupByLibrary.simpleMessage(
      "Управление группами прокси в меню системного трея",
    ),
    "trayIconInvert": MessageLookupByLibrary.simpleMessage(
      "Инвертировать значок трея",
    ),
    "trayIconInvertDesc": MessageLookupByLibrary.simpleMessage(
      "Инвертировать цвет текущего значка в трее",
    ),
    "tryManualRefresh": MessageLookupByLibrary.simpleMessage(
      "Обновите вручную",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("Режим TUN"),
    "tunActualOff": MessageLookupByLibrary.simpleMessage(
      "Системный TUN фактически отключён",
    ),
    "tunActualOn": MessageLookupByLibrary.simpleMessage(
      "Системный TUN фактически включён",
    ),
    "tunActualStatus": MessageLookupByLibrary.simpleMessage(
      "Фактическое состояние TUN",
    ),
    "tunChecking": MessageLookupByLibrary.simpleMessage(
      "Проверка фактического состояния TUN…",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать TUN для перехвата трафика устройства",
    ),
    "tunEnableRequireAdmin": MessageLookupByLibrary.simpleMessage(
      "Для включения режима TUN требуются права администратора или ROOT.",
    ),
    "tunMismatchOff": MessageLookupByLibrary.simpleMessage(
      "TUN всё ещё включён",
    ),
    "tunMismatchOn": MessageLookupByLibrary.simpleMessage(
      "Настройка требует включения, но системный TUN фактически не включён",
    ),
    "tunUnknown": MessageLookupByLibrary.simpleMessage(
      "Не удаётся определить фактическое состояние TUN",
    ),
    "tunUnsupported": MessageLookupByLibrary.simpleMessage(
      "Эта платформа не предоставляет фактическое состояние TUN",
    ),
    "tunVirtualAddress": MessageLookupByLibrary.simpleMessage(
      "Адрес виртуального сетевого адаптера TUN",
    ),
    "tunnel": MessageLookupByLibrary.simpleMessage("Туннель"),
    "tunnelAddress": MessageLookupByLibrary.simpleMessage(
      "Адрес прослушивания",
    ),
    "tunnelAddressHint": MessageLookupByLibrary.simpleMessage(
      "Например: 127.0.0.1:6553",
    ),
    "tunnelDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать туннель перенаправления трафика",
    ),
    "tunnelList": MessageLookupByLibrary.simpleMessage(
      "Список перенаправлений",
    ),
    "tunnelNetwork": MessageLookupByLibrary.simpleMessage("Сетевой протокол"),
    "tunnelNetworkHint": MessageLookupByLibrary.simpleMessage(
      "Например: tcp, udp",
    ),
    "tunnelProxy": MessageLookupByLibrary.simpleMessage("Имя прокси"),
    "tunnelProxyHint": MessageLookupByLibrary.simpleMessage(
      "Например: proxy (опционально)",
    ),
    "tunnelTarget": MessageLookupByLibrary.simpleMessage("Целевой адрес"),
    "tunnelTargetHint": MessageLookupByLibrary.simpleMessage(
      "Например: 114.114.114.114:53",
    ),
    "twoColumns": MessageLookupByLibrary.simpleMessage("2 колонки"),
    "udpForwarding": MessageLookupByLibrary.simpleMessage("Пересылка UDP"),
    "udpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Отключите, если резидентный IP не поддерживает UDP и возникают ошибки",
    ),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Невозможно обновить текущий профиль",
    ),
    "unauthorized": MessageLookupByLibrary.simpleMessage("Не авторизован"),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage(
      "Унифицированная задержка",
    ),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Убрать задержку рукопожатия и разбора",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unlocked": MessageLookupByLibrary.simpleMessage("Завершено"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без имени"),
    "unnamedNode": MessageLookupByLibrary.simpleMessage("Узел без имени"),
    "unpin": MessageLookupByLibrary.simpleMessage("Открепить"),
    "upLabel": MessageLookupByLibrary.simpleMessage("Вверх"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateTime": MessageLookupByLibrary.simpleMessage("Время обновления"),
    "upload": MessageLookupByLibrary.simpleMessage("Отправка"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("Получить профиль по URL"),
    "urlTip": m30,
    "useGlobalScriptOverride": MessageLookupByLibrary.simpleMessage(
      "Глобальное переопределение",
    ),
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системные hosts",
    ),
    "userAuth": MessageLookupByLibrary.simpleMessage(
      "Аутентификация пользователей",
    ),
    "username": MessageLookupByLibrary.simpleMessage("Имя пользователя"),
    "usernameCannotContainColon": MessageLookupByLibrary.simpleMessage(
      "Имя пользователя не может содержать двоеточие",
    ),
    "usernameOptional": MessageLookupByLibrary.simpleMessage(
      "Имя пользователя (необязательно)",
    ),
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Яркий"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "viewDetailedIpData": MessageLookupByLibrary.simpleMessage(
      "Посмотреть подробные данные IP",
    ),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("Настройки VPN"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматическая маршрутизация всего трафика через VpnService",
    ),
    "vpnSystemProxyConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "HTTP-прокси обычно не рекомендуется на мобильных платформах. Включайте эту функцию только при необходимости и если вы осознаёте возможные последствия.",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Добавить HTTP-прокси к VPN",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Перезапустите VPN для применения изменений",
    ),
    "wakelock": MessageLookupByLibrary.simpleMessage("Блокировка сна"),
    "wakelockDescription": MessageLookupByLibrary.simpleMessage(
      "Эта функция не требует специальных разрешений, так как использует только блокировку пробуждения экрана, а не CPU. Приложение остаётся активным в фоне, экран не гаснет автоматически, что полезно в некоторых сценариях.",
    ),
    "wave": MessageLookupByLibrary.simpleMessage("Волна"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Настройки WebDAV",
    ),
    "whitelist": MessageLookupByLibrary.simpleMessage("Белый список"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("Записать в систему"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Требуются права администратора",
    ),
    "years": m31,
  };
}
