// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(role) => "${role}候補を追加";

  static String m1(role) => "${role}予備候補を追加";

  static String m2(completed, total) => "チェック中 (${completed}/${total})...";

  static String m3(count) => "${count} 個のノードをインポートしました";

  static String m4(count) => "${count} 個の無効ノードを削除しました";

  static String m5(name) => "ノード「${name}」を削除してもよろしいですか？";

  static String m6(error) => "グループの作成に失敗しました: ${error}";

  static String m7(name) => "空白グループ「${name}」を作成しました。ノードを追加してください";

  static String m8(count) => "${Intl.plural(count, other: '日')}";

  static String m9(label) => "選択した ${label} を削除しますか？";

  static String m10(label) => "選択した ${label} を削除しますか？";

  static String m11(label) => "${label} は必須項目です";

  static String m12(label) => "${label} はすでに存在します";

  static String m13(reason) => "フェイルオーバーに失敗しました：${reason}";

  static String m14(node) => "フェイルオーバーに成功し、[${node}] へスムーズに切り替えました";

  static String m15(count) => "${Intl.plural(count, other: '時間')}";

  static String m16(count) => "${count} 個のランディングプロキシノードをインポートしました";

  static String m17(count) => "${count}";

  static String m18(count) => "${Intl.plural(count, other: '分')}";

  static String m19(count) => "${Intl.plural(count, other: 'ヶ月')}";

  static String m20(name) => "ノードを追加しました: ${name}";

  static String m21(name) => "ノードを削除しました: ${name}";

  static String m22(name) => "ノード管理 · ${name}";

  static String m23(proto) => "例: 香港 01 - ${proto}";

  static String m24(label) => "${label} はありません";

  static String m25(label) => "${label} は数値である必要があります";

  static String m26(label) => "${label} は1024〜49151の範囲で指定してください（0で無効）";

  static String m27(name) => "プリプロキシとランディングプロキシ · ${name}";

  static String m28(statusCode) =>
      "プロファイルのインポートに失敗しました。通信状態を確認するかURLをリセットしてください ( HTTPエラーコード: ${statusCode} )";

  static String m29(count) => "${count} 件選択中";

  static String m30(name) => "使用中: ${name}";

  static String m31(label) => "${label} は有効なURLである必要があります";

  static String m32(count) => "${Intl.plural(count, other: '年')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPN経由で通信",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アプリのブラック/ホワイトリストを設定",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリをVPN対象外に設定",
    ),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "action_mode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "action_start": MessageLookupByLibrary.simpleMessage("開始 / 停止"),
    "action_tun": MessageLookupByLibrary.simpleMessage("仮想NIC (TUN)"),
    "action_view": MessageLookupByLibrary.simpleMessage("表示 / 非表示"),
    "activeGoroutines": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addLandingProxy": MessageLookupByLibrary.simpleMessage("ランディングプロキシを追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイル追加"),
    "addRoleCandidate": m0,
    "addRoleFallbackCandidate": m1,
    "addRule": MessageLookupByLibrary.simpleMessage("ルール追加"),
    "addTunnel": MessageLookupByLibrary.simpleMessage("転送追加"),
    "addUser": MessageLookupByLibrary.simpleMessage("ユーザーを追加"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage("元のルールに追加"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "有効なWebDAVアドレスを入力してください",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage("管理者権限で自動起動"),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "管理者モードでOS起動時に自動開始",
    ),
    "advancedSettings": MessageLookupByLibrary.simpleMessage("高度な設定"),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage("Age Key 生成"),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519鍵ペアを生成しました。大切に保管してください",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage("Age 秘密鍵"),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "正しいAge秘密鍵を先に入力してください",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age 公開鍵"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効な Age 秘密鍵を入力してください (AGE-SECRET-KEY- で始まる必要があります)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage("Age 秘密鍵（任意）"),
    "ago": MessageLookupByLibrary.simpleMessage("前"),
    "agree": MessageLookupByLibrary.simpleMessage("同意する"),
    "allApps": MessageLookupByLibrary.simpleMessage("すべてのアプリ"),
    "allocatedMemory": MessageLookupByLibrary.simpleMessage("割当済"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("VPN迂回を許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage("特定アプリのVPN迂回接続を許可"),
    "allowLan": MessageLookupByLibrary.simpleMessage("LAN共有"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN経由でのプロキシ接続を許可"),
    "alreadyInWhitelist": MessageLookupByLibrary.simpleMessage(
      "すでに最適化除外リストに登録されています",
    ),
    "alwaysShowTitleBar": MessageLookupByLibrary.simpleMessage("タイトルボタン"),
    "alwaysShowTitleBarDesc": MessageLookupByLibrary.simpleMessage(
      "右上タイトルバーのボタンを常に表示",
    ),
    "amneziaObfsParams": MessageLookupByLibrary.simpleMessage(
      "AmneziaWG 2/3 難読化パラメータ (Jc / Jmin / Jmax / S1 / S2 / H1-H4)",
    ),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリのアクセス制御"),
    "appDesc": MessageLookupByLibrary.simpleMessage("アプリ設定を管理"),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("アプリ設定の変更"),
    "ascending": MessageLookupByLibrary.simpleMessage("昇順"),
    "authorized": MessageLookupByLibrary.simpleMessage("認証済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動更新確認"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "起動時にアップデートを自動確認",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続の自動切断"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード切り替え時に既存接続を自動切断",
    ),
    "autoFailover": MessageLookupByLibrary.simpleMessage("自動フェイルオーバー"),
    "autoFailoverOffDesc": MessageLookupByLibrary.simpleMessage(
      "オフ：下のボタンからのみ手動で切り替えられます",
    ),
    "autoFailoverOnDesc": MessageLookupByLibrary.simpleMessage(
      "チェーンが継続的に異常なとき、予備候補ノードへ自動で切り替えます",
    ),
    "autoInjectGroups": MessageLookupByLibrary.simpleMessage(
      "メインセレクタグループへ自動注入",
    ),
    "autoInjectGroupsDesc": MessageLookupByLibrary.simpleMessage(
      "有効なランディングプロキシを「ノード選択」などの主要ルーティンググループへ自動追加します",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("OS起動時にアプリを自動開始"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動接続"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリ起動時に自動でプロキシに接続"),
    "autoScroll": MessageLookupByLibrary.simpleMessage("自動スクロール"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを自動設定"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔（分）"),
    "back": MessageLookupByLibrary.simpleMessage("戻る"),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVまたはローカルでデータを同期",
    ),
    "backupPassword": MessageLookupByLibrary.simpleMessage("バックアップパスワード"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップ成功"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("カーネル設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("カーネル設定をグローバル変更"),
    "batchCheckingProgress": m2,
    "batchImportLinks": MessageLookupByLibrary.simpleMessage("リンクを一括インポート"),
    "batchImportParseFailed": MessageLookupByLibrary.simpleMessage(
      "有効なノードリンクを解析できませんでした。形式を確認してください。",
    ),
    "batchImportPasteHint": MessageLookupByLibrary.simpleMessage(
      "ここにノードの共有リンクまたはノード構成 (YAML/JSON) を貼り付け...",
    ),
    "batchImportShareLinks": MessageLookupByLibrary.simpleMessage(
      "共有リンクを一括インポート",
    ),
    "batchImportSuccess": m3,
    "batchImportSupportHint": MessageLookupByLibrary.simpleMessage(
      "単一/複数行のリンクまたは YAML/JSON ノード断片に対応：",
    ),
    "batteryOptimization": MessageLookupByLibrary.simpleMessage("バッテリー最適化"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "バッテリー最適化の除外権限をリクエスト",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("連携"),
    "blacklist": MessageLookupByLibrary.simpleMessage("ブラックリスト"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "blockComment": MessageLookupByLibrary.simpleMessage("コメント"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("バイパスドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("システムプロキシ有効時のみ適用"),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "プライベートネットワークをバイパス",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルIP（プライベートIP）を自動バイパス",
    ),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("キャッシュアルゴリズム"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "カメラ権限が拒否されました",
    ),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "QRスキャンにはカメラ権限が必要です。設定から許可してください。",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "システムアプリ除外を解除",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("全選択解除"),
    "categoryAi": MessageLookupByLibrary.simpleMessage("AI"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("すべて"),
    "categoryChina": MessageLookupByLibrary.simpleMessage("中国直通"),
    "categoryCrypto": MessageLookupByLibrary.simpleMessage("暗号資産"),
    "categoryDeveloper": MessageLookupByLibrary.simpleMessage("開発者"),
    "categoryGaming": MessageLookupByLibrary.simpleMessage("ゲームセンター"),
    "categorySocial": MessageLookupByLibrary.simpleMessage("コミュニティ"),
    "categoryStreaming": MessageLookupByLibrary.simpleMessage("動画配信"),
    "chainAvgLatency": MessageLookupByLibrary.simpleMessage("平均遅延"),
    "chainCreateSupportPackage": MessageLookupByLibrary.simpleMessage(
      "サポートパッケージを作成",
    ),
    "chainCreatingPackage": MessageLookupByLibrary.simpleMessage("作成中…"),
    "chainDecisionSupport": MessageLookupByLibrary.simpleMessage("意思決定サポート"),
    "chainDiagnosticPackage": MessageLookupByLibrary.simpleMessage("診断パッケージ"),
    "chainDiagnosticTitle": MessageLookupByLibrary.simpleMessage("チェーン診断"),
    "chainEventsLabel": MessageLookupByLibrary.simpleMessage("イベント"),
    "chainExportReport": MessageLookupByLibrary.simpleMessage("レポートを書き出す"),
    "chainExporting": MessageLookupByLibrary.simpleMessage("書き出し中…"),
    "chainFailuresLabel": MessageLookupByLibrary.simpleMessage("失敗"),
    "chainGeneratedOn": MessageLookupByLibrary.simpleMessage("生成日時"),
    "chainHealthLabel": MessageLookupByLibrary.simpleMessage("状態"),
    "chainHealthScore": MessageLookupByLibrary.simpleMessage("ヘルススコア"),
    "chainHopExitNode": MessageLookupByLibrary.simpleMessage("第3ホップ（出口ノード）"),
    "chainHopIncomplete": MessageLookupByLibrary.simpleMessage(
      "スリーホップチェーンが不完全です：中継ノードと出口ノードを選択してください",
    ),
    "chainHopMode": MessageLookupByLibrary.simpleMessage("チェーンホップ数"),
    "chainHopModeDesc": MessageLookupByLibrary.simpleMessage(
      "ツーホップは「前置跳板 → ランディング出口」；スリーホップは中継ノードを追加挿入します",
    ),
    "chainHopNotSelected": MessageLookupByLibrary.simpleMessage("未選択"),
    "chainHopRelayNode": MessageLookupByLibrary.simpleMessage("第2ホップ（中継ノード）"),
    "chainHopUnavailable": MessageLookupByLibrary.simpleMessage(
      "利用可能なノード一覧を読み取れなかったため、ノードの可用性を検証できませんでした",
    ),
    "chainIntelAnalytics": MessageLookupByLibrary.simpleMessage("インテリジェンス分析"),
    "chainLandingProxyNone": MessageLookupByLibrary.simpleMessage("デフォルト (なし)"),
    "chainNodeDeviceApp": MessageLookupByLibrary.simpleMessage("デバイスアプリ"),
    "chainNodeGroupNodes": MessageLookupByLibrary.simpleMessage("グループ内ノード"),
    "chainNodeLocal": MessageLookupByLibrary.simpleMessage("ローカル"),
    "chainNodePreProxy": MessageLookupByLibrary.simpleMessage("プリプロキシ"),
    "chainNodeReliability": MessageLookupByLibrary.simpleMessage("ノード信頼性"),
    "chainNodeSubscription": MessageLookupByLibrary.simpleMessage("購読ノード"),
    "chainOpenFolder": MessageLookupByLibrary.simpleMessage("フォルダーを開く"),
    "chainPackageReady": MessageLookupByLibrary.simpleMessage("パッケージ準備完了"),
    "chainPreProxyNone": MessageLookupByLibrary.simpleMessage("直接 (なし)"),
    "chainProbeNow": MessageLookupByLibrary.simpleMessage("チェーンを検査"),
    "chainProxy": MessageLookupByLibrary.simpleMessage("チェーンプロキシ"),
    "chainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "前置跳板と静的住宅IPランディングプロキシを設定します",
    ),
    "chainShareLabel": MessageLookupByLibrary.simpleMessage("共有"),
    "chainSupportTitle": MessageLookupByLibrary.simpleMessage("チェーンサポート"),
    "chainTopFailureReason": MessageLookupByLibrary.simpleMessage("主な失敗原因"),
    "chainTopologyPreview": MessageLookupByLibrary.simpleMessage(
      "チェーンルーティングトポロジのプレビュー",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("確認失敗"),
    "checkFailed": MessageLookupByLibrary.simpleMessage("Timeout"),
    "checkOrAddProfile": MessageLookupByLibrary.simpleMessage(
      "最初にプロファイルを追加してください",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新の確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("最新バージョンを使用中です"),
    "checking": MessageLookupByLibrary.simpleMessage("確認中..."),
    "cipher": MessageLookupByLibrary.simpleMessage("暗号化方式"),
    "cipherLabel": MessageLookupByLibrary.simpleMessage("暗号方式"),
    "circle": MessageLookupByLibrary.simpleMessage("サークル"),
    "clear": MessageLookupByLibrary.simpleMessage("消去"),
    "clearCacheDesc": MessageLookupByLibrary.simpleMessage(
      "FakeIPとDNSキャッシュをクリアしますか？",
    ),
    "clearCacheTitle": MessageLookupByLibrary.simpleMessage("キャッシュ削除"),
    "clearData": MessageLookupByLibrary.simpleMessage("データ消去"),
    "clearDataTipDesc": MessageLookupByLibrary.simpleMessage(
      "アプリのすべての設定がリセットされます。バックアップを確認してください。続行しますか？",
    ),
    "clearDataTipTitle": MessageLookupByLibrary.simpleMessage("危険な操作"),
    "clearInvalidProxies": MessageLookupByLibrary.simpleMessage("利用不可ノードをクリア"),
    "clearedInvalidCount": m4,
    "clipboard": MessageLookupByLibrary.simpleMessage("クリップボード"),
    "clipboardDesc": MessageLookupByLibrary.simpleMessage("クリップボードからURLを自動取得"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードへ書き出し"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードから取り込み"),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "closeAll": MessageLookupByLibrary.simpleMessage("すべて閉じる"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラーパレット"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "一部の独自機能を無効化しClash完全互換で動作",
    ),
    "concurrencyLimit": MessageLookupByLibrary.simpleMessage("並行テスト制限"),
    "concurrencyLimitDesc": MessageLookupByLibrary.simpleMessage(
      "レイテンシテストの最大並行数",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("確定"),
    "confirmClearInvalid": MessageLookupByLibrary.simpleMessage(
      "チェックで利用不可と判定された住宅IPをすべてクリアしますか？",
    ),
    "confirmDelete": MessageLookupByLibrary.simpleMessage("削除の確認"),
    "confirmDeleteNodeMsg": m5,
    "confirmImport": MessageLookupByLibrary.simpleMessage("インポートを確認"),
    "confirmPassword": MessageLookupByLibrary.simpleMessage("パスワードの確認"),
    "connection": MessageLookupByLibrary.simpleMessage("アクティブ接続"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の通信接続データを表示"),
    "connectionsSort": MessageLookupByLibrary.simpleMessage("接続並び替え"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続性："),
    "contactMe": MessageLookupByLibrary.simpleMessage("お問い合わせ"),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("コンテンツテーマ"),
    "continent": MessageLookupByLibrary.simpleMessage("大陸"),
    "controlSecret": MessageLookupByLibrary.simpleMessage("制御パスワード"),
    "controlSecretDesc": MessageLookupByLibrary.simpleMessage(
      "RESTful APIアクセスパスワード",
    ),
    "copiedPackageName": MessageLookupByLibrary.simpleMessage("パッケージ名をコピーしました"),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "クリップボードにコピーしました",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピー成功"),
    "core": MessageLookupByLibrary.simpleMessage("カーネル"),
    "coreConnected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("カーネル情報"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コア負荷詳細"),
    "coreSuspended": MessageLookupByLibrary.simpleMessage("一時停止中"),
    "country": MessageLookupByLibrary.simpleMessage("地域"),
    "countryOrRegion": MessageLookupByLibrary.simpleMessage("国 / 地域"),
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createEmptyGroup": MessageLookupByLibrary.simpleMessage("空のグループを作成"),
    "createEmptyGroupDesc": MessageLookupByLibrary.simpleMessage(
      "新しい空白構成を作成し、全プロトコルの自前ノードの手動入力と管理に対応します",
    ),
    "createEmptyGroupHint": MessageLookupByLibrary.simpleMessage(
      "空白グループを作成した後、各プロトコルのノードを手動で追加するか、共有リンクをワンクリックで一括インポートできます。",
    ),
    "createGroupFailed": m6,
    "createGroupSuccess": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("作成日時"),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "customConfigHintText": MessageLookupByLibrary.simpleMessage(
      "ここに完全なノード YAML または JSON 構成断片を入力または貼り付け：",
    ),
    "customConfigLabel": MessageLookupByLibrary.simpleMessage(
      "カスタム構成 (YAML / JSON)",
    ),
    "customConfigNode": MessageLookupByLibrary.simpleMessage("カスタム構成ノード"),
    "customDashboardTitle": MessageLookupByLibrary.simpleMessage("カスタムタイトル"),
    "customLandingProxyName": MessageLookupByLibrary.simpleMessage(
      "カスタムランディングノード名",
    ),
    "customNodesDefaultName": MessageLookupByLibrary.simpleMessage("自前ノード"),
    "customPreProxyName": MessageLookupByLibrary.simpleMessage(
      "カスタムプリプロキシノード名",
    ),
    "customScriptOptions": MessageLookupByLibrary.simpleMessage("カスタムルール"),
    "customUrl": MessageLookupByLibrary.simpleMessage("カスタムURL"),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "darkIcon": MessageLookupByLibrary.simpleMessage("ダークアイコン"),
    "darkIconDesc": MessageLookupByLibrary.simpleMessage("アプリアイコンをダーク系に切り替え"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ホーム"),
    "days": m8,
    "dedicatedGroup": MessageLookupByLibrary.simpleMessage("専用チェーンプロキシグループを作成"),
    "dedicatedGroupDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシページに「🔗 チェーンプロキシ」の独立したポリシーグループカードを生成します",
    ),
    "defaultDialerProxy": MessageLookupByLibrary.simpleMessage("既定の前置跳板"),
    "defaultDialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "ランディングプロキシが既定で使用する前置ノードまたはポリシーグループ（ノード選択グループの設定を推奨）",
    ),
    "defaultGateway": MessageLookupByLibrary.simpleMessage("デフォルトゲートウェイ"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトDNSサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNSサーバー自体の解決に使用",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("デフォルト順"),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("レイテンシ"),
    "delayAnimation": MessageLookupByLibrary.simpleMessage("テストアニメーション"),
    "delayAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "テスト中の表示アニメーションを変更",
    ),
    "delaySort": MessageLookupByLibrary.simpleMessage("レイテンシ順"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m9,
    "deleteNode": MessageLookupByLibrary.simpleMessage("ノードを削除"),
    "deleteTip": m10,
    "deleteTunnel": MessageLookupByLibrary.simpleMessage("転送削除"),
    "desc": MessageLookupByLibrary.simpleMessage(
      "Fluxoraは柔軟で強力なMihomo(Clash.Meta)カーネルを搭載した、快適性を追求したプロキシクライアントです。私たちのビジョン：Clear routes, calm control",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("降順"),
    "destination": MessageLookupByLibrary.simpleMessage("宛先アドレス"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先GeoIP"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先IP ASN"),
    "details": MessageLookupByLibrary.simpleMessage("詳細"),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "サードパーティAPIを使用しているため、参考値です",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("開発者モード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "開発者モードが有効になりました。",
    ),
    "diagnosticAdvice": MessageLookupByLibrary.simpleMessage("スマート診断の提案"),
    "dialerIp4pConvert": MessageLookupByLibrary.simpleMessage("IP4P変換有効化"),
    "dialerIp4pConvertDesc": MessageLookupByLibrary.simpleMessage(
      "ダイヤラーのIP4Pアドレス変換を有効化",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "directConnection": MessageLookupByLibrary.simpleMessage("DIRECT（跳板なしの直結）"),
    "directNameserver": MessageLookupByLibrary.simpleMessage("直連用DNS"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "ダイレクト接続のドメイン解決に使用",
    ),
    "directNameserverFollowPolicy": MessageLookupByLibrary.simpleMessage(
      "直連DNSもポリシーに従う",
    ),
    "disableQuic": MessageLookupByLibrary.simpleMessage("QUIC無効化"),
    "disableQuicDesc": MessageLookupByLibrary.simpleMessage(
      "特定の通信問題を解決するためQUICを無効化",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本アプリはオープンソースの無料ソフトウェアであり、個人的な学習・研究目的でのみ提供されています。プロキシ事業者の行為は本アプリと一切関係ありません。",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "新しいバージョンが見つかりました",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage("新バージョン検出"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS関連の設定を更新"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNSハイジャック"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "DNSクエリを内部DNSモジュールに引き込み",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("許可しますか："),
    "domain": MessageLookupByLibrary.simpleMessage("組織 / ドメイン"),
    "domainName": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "doubleBounce": MessageLookupByLibrary.simpleMessage("ダブルバウンス"),
    "downLabel": MessageLookupByLibrary.simpleMessage("下り"),
    "download": MessageLookupByLibrary.simpleMessage("受信"),
    "dozeSuspend": MessageLookupByLibrary.simpleMessage("スリープ連携"),
    "dozeSuspendDesc": MessageLookupByLibrary.simpleMessage(
      "OSのDozeスリープモードに同期",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editTunnel": MessageLookupByLibrary.simpleMessage("転送編集"),
    "emptyLandingTip": MessageLookupByLibrary.simpleMessage(
      "ランディング住宅ノードがありません。主要な住宅IPプロバイダ（IPRoyal、LunaProxy、Oxylabs など）の一般的な形式をワンクリックで貼り付けてインポートできます。",
    ),
    "emptyTip": m11,
    "enableChainProxy": MessageLookupByLibrary.simpleMessage("チェーンプロキシを有効化"),
    "enableChainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "前置ノード経由で中継してランディングプロキシに接続し、ネットワーク制限を回避しつつ実際の住宅出口を維持します",
    ),
    "enableCrashReport": MessageLookupByLibrary.simpleMessage("クラッシュ分析"),
    "enableCrashReportDesc": MessageLookupByLibrary.simpleMessage(
      "必要に応じてクラッシュログを送信",
    ),
    "enableOverride": MessageLookupByLibrary.simpleMessage("オーバーライド有効化"),
    "enableProfileChain": MessageLookupByLibrary.simpleMessage(
      "この購読グループのチェーンプロキシを有効にする",
    ),
    "enableProfileChainDesc": MessageLookupByLibrary.simpleMessage(
      "プリプロキシの踏み台リレーと最終ランディング出口の構成に対応します",
    ),
    "enableTraySpeed": MessageLookupByLibrary.simpleMessage("速度表示"),
    "enableTraySpeedDesc": MessageLookupByLibrary.simpleMessage(
      "メニューバーにアップロード/ダウンロード速度を表示",
    ),
    "enableUdpForwarding": MessageLookupByLibrary.simpleMessage("UDP 転送を有効にする"),
    "encryptBackup": MessageLookupByLibrary.simpleMessage("バックアップを暗号化"),
    "encryptBackupDesc": MessageLookupByLibrary.simpleMessage(
      "AES-256-GCMでバックアップ内容を暗号化します。パスワードは保存されないため、紛失すると復元できません",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage("NAT強化"),
    "endpointIndependentNatConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "Endpoint-Independent NATを有効にするとパフォーマンスがわずかに低下する場合があります。必要な場合のみ設定してください",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "UDP / P2Pアプリの通信体験を最適化",
    ),
    "entries": MessageLookupByLibrary.simpleMessage("件"),
    "exclude": MessageLookupByLibrary.simpleMessage("タスク一覧で非表示"),
    "excludeChina": MessageLookupByLibrary.simpleMessage("中国通信を除外"),
    "excludeChinaDesc": MessageLookupByLibrary.simpleMessage(
      "全無効化せずに中国のQUIC通信を許可",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage("最近のタスク履歴からアプリを隠す"),
    "existsTip": m12,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "expand": MessageLookupByLibrary.simpleMessage("標準"),
    "experimental": MessageLookupByLibrary.simpleMessage("実験的機能"),
    "experimentalDesc": MessageLookupByLibrary.simpleMessage(
      "実験的設定（注意してご使用ください）",
    ),
    "expirationTime": MessageLookupByLibrary.simpleMessage("有効期限"),
    "expired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "export": MessageLookupByLibrary.simpleMessage("エクスポート"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポート成功"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("エクスプレッシブ"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部制御"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "オンラインポート経由でカーネルを制御",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "externalResources": MessageLookupByLibrary.simpleMessage("外部リソース"),
    "fadingCircle": MessageLookupByLibrary.simpleMessage("フェードサークル"),
    "fadingFour": MessageLookupByLibrary.simpleMessage("フェードフォースクエア"),
    "failover": MessageLookupByLibrary.simpleMessage("フェイルオーバー"),
    "failoverEnableFirst": MessageLookupByLibrary.simpleMessage(
      "先にチェーンプロキシを有効にしてください",
    ),
    "failoverFailed": m13,
    "failoverInProgress": MessageLookupByLibrary.simpleMessage(
      "フェイルオーバー実行中...",
    ),
    "failoverManualHint": MessageLookupByLibrary.simpleMessage(
      "チェーン異常を検出したとき、手動で予備候補ノードへ切り替えられます",
    ),
    "failoverNoCandidates": MessageLookupByLibrary.simpleMessage(
      "利用可能な予備候補ノードがまだ設定されていません",
    ),
    "failoverNoCandidatesAdvice": MessageLookupByLibrary.simpleMessage(
      "上の少なくとも1つのロールに予備候補ノードを追加してから再試行してください",
    ),
    "failoverSuccess": m14,
    "failoverTrigger": MessageLookupByLibrary.simpleMessage("今すぐフェイルオーバー"),
    "failoverTriggerReason": MessageLookupByLibrary.simpleMessage(
      "ユーザーが手動でフェイルオーバーを実行",
    ),
    "fakeIpFilterMode": MessageLookupByLibrary.simpleMessage("FakeIPフィルターモード"),
    "fakeIpFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "FakeIPフィルターの動作モードを指定",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("FakeIPフィルターリスト"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("FakeIP範囲"),
    "fakeipRangeV6": MessageLookupByLibrary.simpleMessage("FakeIPv6範囲"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("FakeIP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバックDNS"),
    "fallbackConcurrent": MessageLookupByLibrary.simpleMessage("フォールバック並行検索"),
    "fallbackConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "デフォルトDNSとフォールバックDNSを同時に照会",
    ),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("主に海外ドメインの解決に使用"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fcmOptimization": MessageLookupByLibrary.simpleMessage("FCM最適化"),
    "fcmOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "FCM直連時の通信安定性を向上",
    ),
    "fcmTip": MessageLookupByLibrary.simpleMessage(
      "FCMの接続は端末環境に依存します。表示結果は参考値です。より正確なテストのため「VPNの迂回を許可」をオフにしてください",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("フィデリティ"),
    "fieldAbuse": MessageLookupByLibrary.simpleMessage("悪用報告"),
    "fieldAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "fieldBlocklists": MessageLookupByLibrary.simpleMessage("ブラックリスト"),
    "fieldMarkers": MessageLookupByLibrary.simpleMessage("リスクマーカー"),
    "fieldNativeType": MessageLookupByLibrary.simpleMessage("ネイティブ IP"),
    "fieldScenarios": MessageLookupByLibrary.simpleMessage("シナリオ別スコア"),
    "fieldScore": MessageLookupByLibrary.simpleMessage("純度スコア"),
    "fieldUnknownNotes": MessageLookupByLibrary.simpleMessage("不明項目"),
    "fieldUsageType": MessageLookupByLibrary.simpleMessage("用途タイプ"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("ローカル設定ファイルをアップロード"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されました。保存しますか？",
    ),
    "filterAll": MessageLookupByLibrary.simpleMessage("すべて"),
    "filterError": MessageLookupByLibrary.simpleMessage("異常/未測定"),
    "filterHealthy": MessageLookupByLibrary.simpleMessage("利用可能のみ"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage("システムアプリを除外"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検索"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名をマッチングして検索",
    ),
    "flagged": MessageLookupByLibrary.simpleMessage("フラグ付き"),
    "followMainSelector": MessageLookupByLibrary.simpleMessage(
      "現在のノード選択グループに追従（推奨）",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォント"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("強制DNSマッピング"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "DNSクエリ結果を接続に強制マッピング",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("対象ドメイン"),
    "forceGCDesc": MessageLookupByLibrary.simpleMessage(
      "カーネルのメモリGCを強制実行しますか？（実験的機能）",
    ),
    "forceGCTitle": MessageLookupByLibrary.simpleMessage("強制ガベージコレクション"),
    "formatError": MessageLookupByLibrary.simpleMessage("フォーマットが正しいか確認してください"),
    "fourColumns": MessageLookupByLibrary.simpleMessage("4列"),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("フルーツサラダ"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("全般設定を変更"),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage("秘密鍵から生成"),
    "generateSecret": MessageLookupByLibrary.simpleMessage("生成"),
    "geoData": MessageLookupByLibrary.simpleMessage("Geoデータ"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("GEO省メモリ"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "メモリ消費を抑えたGEOローダーを使用",
    ),
    "geodataUse": MessageLookupByLibrary.simpleMessage("GEO読込"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIPコード"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage("元のルールを取得"),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("移動"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "groupName": MessageLookupByLibrary.simpleMessage("グループ名"),
    "harmonyFont": MessageLookupByLibrary.simpleMessage("フォント修復"),
    "harmonyFontDesc": MessageLookupByLibrary.simpleMessage(
      "表示異常を改善するため内蔵フォントを使用",
    ),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("可用性チェック"),
    "healthCheckAll": MessageLookupByLibrary.simpleMessage("全項目チェック"),
    "healthCheckTimeout": MessageLookupByLibrary.simpleMessage("タイムアウト時間"),
    "healthCheckTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "ヘルスチェックのタイムアウト時間",
    ),
    "healthError": MessageLookupByLibrary.simpleMessage("異常・利用不可"),
    "healthHealthy": MessageLookupByLibrary.simpleMessage("正常・利用可能"),
    "healthReport": MessageLookupByLibrary.simpleMessage("住宅IP接続性レポート"),
    "healthUntested": MessageLookupByLibrary.simpleMessage("未チェック"),
    "healthWarning": MessageLookupByLibrary.simpleMessage("一部制限あり"),
    "heapObjects": MessageLookupByLibrary.simpleMessage("Objects"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage("タイムアウトノードを非表示"),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "前回の遅延テストがタイムアウトしたノードを表示しません",
    ),
    "highPriority": MessageLookupByLibrary.simpleMessage("高優先度"),
    "highPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "メインプロセスとカーネルプロセスの優先度を付与",
    ),
    "highRefreshRate": MessageLookupByLibrary.simpleMessage("高リフレッシュレート"),
    "highRefreshRateDesc": MessageLookupByLibrary.simpleMessage(
      "ディスプレイの最高リフレッシュレートを有効化",
    ),
    "hop": MessageLookupByLibrary.simpleMessage("跳板"),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("プロファイルのHostsを追記"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ショートカットキーの競合"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ショートカットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを操作",
    ),
    "hours": m15,
    "httpPortSniffer": MessageLookupByLibrary.simpleMessage("HTTPポート解析"),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP転送"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとICMP Pingをサポート",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("画像"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage("画像設定"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFailed": MessageLookupByLibrary.simpleMessage("インポート失敗"),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromCode": MessageLookupByLibrary.simpleMessage("コードからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "importShareLinks": MessageLookupByLibrary.simpleMessage("共有リンクをインポート"),
    "importSuccessCount": m16,
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("無期限"),
    "inheritDefaultDialer": MessageLookupByLibrary.simpleMessage(
      "グローバル既定の跳板を継承",
    ),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "正しいショートカットキーを入力してください",
    ),
    "inputProxyTextHint": MessageLookupByLibrary.simpleMessage(
      "住宅IP情報を貼り付けてください。例：\n198.51.100.1:8000:username:password\nまたは socks5://user:pass@198.51.100.1:8000\n複数行の一括貼り付けに対応",
    ),
    "installTime": MessageLookupByLibrary.simpleMessage("インストール日時"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("スマート選択"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("間隔"),
    "intranetAndGateway": MessageLookupByLibrary.simpleMessage(
      "イントラネットとゲートウェイ",
    ),
    "intranetIP": MessageLookupByLibrary.simpleMessage("ローカル IP"),
    "invalidIpFormat": MessageLookupByLibrary.simpleMessage("無効なIPまたはCIDR形式"),
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP アドレス"),
    "ipClickBehavior": MessageLookupByLibrary.simpleMessage("表示切替"),
    "ipPrivacyProtection": MessageLookupByLibrary.simpleMessage("IP表示を隠す"),
    "ipRiskAbuse": MessageLookupByLibrary.simpleMessage("不正利用報告"),
    "ipRiskBlocklists": MessageLookupByLibrary.simpleMessage("ブロックリスト"),
    "ipRiskBogon": MessageLookupByLibrary.simpleMessage("予約アドレス"),
    "ipRiskEnable": MessageLookupByLibrary.simpleMessage("照会を有効化"),
    "ipRiskFactors": MessageLookupByLibrary.simpleMessage("スコア要因"),
    "ipRiskFailed": MessageLookupByLibrary.simpleMessage("照会に失敗しました"),
    "ipRiskFieldsTitle": MessageLookupByLibrary.simpleMessage("表示項目のカスタマイズ"),
    "ipRiskHosting": MessageLookupByLibrary.simpleMessage("データセンター"),
    "ipRiskIntel": MessageLookupByLibrary.simpleMessage("IPリスク情報"),
    "ipRiskLimits": MessageLookupByLibrary.simpleMessage("このデータでは分からないこと"),
    "ipRiskMobile": MessageLookupByLibrary.simpleMessage("モバイル回線"),
    "ipRiskNativeType": MessageLookupByLibrary.simpleMessage("ネイティブ IP"),
    "ipRiskNotFlagged": MessageLookupByLibrary.simpleMessage("検出なし"),
    "ipRiskOpenReport": MessageLookupByLibrary.simpleMessage("完全なレポートを開く"),
    "ipRiskPrivacyNote": MessageLookupByLibrary.simpleMessage(
      "第三者に IP を送信します（プライバシーポリシーなし）",
    ),
    "ipRiskProxy": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "ipRiskRelay": MessageLookupByLibrary.simpleMessage("リレー"),
    "ipRiskScenarios": MessageLookupByLibrary.simpleMessage("シナリオ別スコア"),
    "ipRiskScore": MessageLookupByLibrary.simpleMessage("提供元の純度スコア"),
    "ipRiskSearchEngineBot": MessageLookupByLibrary.simpleMessage("検索エンジンボット"),
    "ipRiskStale": MessageLookupByLibrary.simpleMessage("古いデータ（リアルタイムではない）"),
    "ipRiskTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipRiskUnknownNotes": MessageLookupByLibrary.simpleMessage("検出できない項目"),
    "ipRiskVerdict": MessageLookupByLibrary.simpleMessage("提供元の評価"),
    "ipRiskVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP / サブネットマスク"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("IPv6トラフィックの受信を有効化"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6インバウンド通信を許可"),
    "isp": MessageLookupByLibrary.simpleMessage("プロバイダ"),
    "itemsCount": m17,
    "jcLabel": MessageLookupByLibrary.simpleMessage("Jc (ジャンクパケット数)"),
    "juicityPassword": MessageLookupByLibrary.simpleMessage(
      "Juicity パスワード (上に UUID を入力)",
    ),
    "just": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP Keep-Alive間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "lanShareAddress": MessageLookupByLibrary.simpleMessage("LAN 共有アドレス"),
    "landingProxies": MessageLookupByLibrary.simpleMessage("ランディング住宅ノード"),
    "landingProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ ランディングノード名を手動入力...",
    ),
    "landingProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "なし (購読ノードを最終出口とする)",
    ),
    "landingProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "購読ノードをプリプロキシの踏み台とし、最終的にこのノードを出口とします。空港 IP の隠蔽、WARP の重ね掛けによるブロック回避、AI とストリーミングの解除に利用できます。",
    ),
    "landingProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "2. ランディングプロキシ",
    ),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "lastEdit": MessageLookupByLibrary.simpleMessage("前回の編集"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "leftClickBehavior": MessageLookupByLibrary.simpleMessage("左クリック"),
    "legacyBackup": MessageLookupByLibrary.simpleMessage("旧形式のバックアップ"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "limitedUnlock": MessageLookupByLibrary.simpleMessage("自作のみ"),
    "lineWrap": MessageLookupByLibrary.simpleMessage("折り返し"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リスニング"),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage("ローカルにデータをバックアップ"),
    "localFile": MessageLookupByLibrary.simpleMessage("ローカルファイル"),
    "localIpLabel": MessageLookupByLibrary.simpleMessage("ローカル IP"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage("ファイルからデータを復元"),
    "locate": MessageLookupByLibrary.simpleMessage("位置"),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャプチャ"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("有効にするとログエントリを表示"),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("キャプチャログの確認"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWPアプリのループバック制限を解除"),
    "loopbackProtection": MessageLookupByLibrary.simpleMessage("ループバック保護"),
    "loopbackProtectionDesc": MessageLookupByLibrary.simpleMessage(
      "ネットワークエラーによるループバックを遮断",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("ルーズ"),
    "manualAddNode": MessageLookupByLibrary.simpleMessage("ノードを手動で追加"),
    "manualEntry": MessageLookupByLibrary.simpleMessage("手動入力"),
    "manualRefreshIp": MessageLookupByLibrary.simpleMessage("IPを再取得"),
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "mediaUnlock": MessageLookupByLibrary.simpleMessage("接続性テスト"),
    "mediaUnlockColorfulIcons": MessageLookupByLibrary.simpleMessage(
      "既定でカラーアイコンを表示",
    ),
    "mediaUnlockDetails": MessageLookupByLibrary.simpleMessage("接続性テスト詳細"),
    "mediaUnlockDisplaySettings": MessageLookupByLibrary.simpleMessage("表示設定"),
    "mediaUnlockExtraDetails": MessageLookupByLibrary.simpleMessage(
      "IP の詳細情報を表示",
    ),
    "mediaUnlockMiscSettings": MessageLookupByLibrary.simpleMessage("その他の設定"),
    "mediaUnlockPinnedSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "ウィジェットに常駐表示する最大4項目を選択できます",
    ),
    "mediaUnlockRefreshOnNodeChange": MessageLookupByLibrary.simpleMessage(
      "ノード変更時に自動更新",
    ),
    "mediaUnlockSelectLimit": MessageLookupByLibrary.simpleMessage(
      "最大4項目まで選択できます",
    ),
    "mediaUnlocked": MessageLookupByLibrary.simpleMessage("ロック解除済み"),
    "memoryAndRuntime": MessageLookupByLibrary.simpleMessage("メモリとランタイム"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "表示されているメモリ値はカーネル動的ヒープの占有量であり、アプリ全体のメモリ統計ではありません（参考値）。",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("テストメッセージです。"),
    "min": MessageLookupByLibrary.simpleMessage("最小"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "デフォルトのウィンドウ閉じる動作を変更",
    ),
    "minutes": m18,
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合ポート (Mixed)"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "months": m19,
    "more": MessageLookupByLibrary.simpleMessage("詳細"),
    "moreIpInfo": MessageLookupByLibrary.simpleMessage("詳細 IP 情報"),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameSort": MessageLookupByLibrary.simpleMessage("名前順"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメイン名の解決に使用"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "特定ドメイン用のDNSポリシーを指定",
    ),
    "navBarHapticFeedback": MessageLookupByLibrary.simpleMessage("触覚フィードバック"),
    "navBarHapticFeedbackDesc": MessageLookupByLibrary.simpleMessage(
      "ボトムナビゲーション切り替え時の振動フィードバック",
    ),
    "navConnections": MessageLookupByLibrary.simpleMessage("接続"),
    "navTools": MessageLookupByLibrary.simpleMessage("ツール"),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連設定を変更"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("ネットワーク検出"),
    "networkDetectionUrl": MessageLookupByLibrary.simpleMessage("ネットワーク検出URL"),
    "networkErrorRetryLater": MessageLookupByLibrary.simpleMessage(
      "ネットワークエラーが発生しました。後でもう一度お試しください",
    ),
    "networkFix": MessageLookupByLibrary.simpleMessage("ネットワーク修復"),
    "networkFixDesc": MessageLookupByLibrary.simpleMessage(
      "システムネットワーク検出アイコンの問題を修復",
    ),
    "networkInterface": MessageLookupByLibrary.simpleMessage("インターフェース"),
    "networkLabel": MessageLookupByLibrary.simpleMessage("トランスポート"),
    "networkMatch": MessageLookupByLibrary.simpleMessage("ネットワークマッチ"),
    "networkMatchHint": MessageLookupByLibrary.simpleMessage(
      "IP、CIDR または Gateway:IP/CIDR",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("通信速度"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage("速度通知"),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "通知バーに通信速度とサブスク情報を表示",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "noAnimation": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "noBackupFileFound": MessageLookupByLibrary.simpleMessage(
      "バックアップファイルが見つかりません",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("データがありません"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ショートカットキーなし"),
    "noIcon": MessageLookupByLibrary.simpleMessage("アイコンなし"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報なし"),
    "noInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "現在、利用不可の無効ノードはありません",
    ),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("これ以上の情報はありません"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークなし"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("非通信アプリ"),
    "noNodesInGroup": MessageLookupByLibrary.simpleMessage(
      "このグループにはまだノードがありません",
    ),
    "noNodesInGroupHint": MessageLookupByLibrary.simpleMessage(
      "右下の「ノードを手動で追加」または右上の「リンクを一括インポート」をタップ",
    ),
    "noProfileInEffect": MessageLookupByLibrary.simpleMessage("有効な設定はありません"),
    "noProxy": MessageLookupByLibrary.simpleMessage("プロキシなし"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage("プロファイルを作成または追加してください"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IP解決を行わない"),
    "noStatusAvailable": MessageLookupByLibrary.simpleMessage(
      "ステータスを取得できませんでした",
    ),
    "noUsageData": MessageLookupByLibrary.simpleMessage("使用量統計なし"),
    "nodeAdded": m20,
    "nodeDeleted": m21,
    "nodeExclusion": MessageLookupByLibrary.simpleMessage("ノード除外"),
    "nodeExclusionDesc": MessageLookupByLibrary.simpleMessage(
      "指定キーワードに一致するノードを除外",
    ),
    "nodeExclusionPlaceholder": MessageLookupByLibrary.simpleMessage(
      "HK|香港|🇭🇰",
    ),
    "nodeManagement": m22,
    "nodeName": MessageLookupByLibrary.simpleMessage("ノード名"),
    "nodeNameHint": m23,
    "nodeNameLabel": MessageLookupByLibrary.simpleMessage("ノード名"),
    "nodeProtocol": MessageLookupByLibrary.simpleMessage("ノードプロトコル"),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notRecommended": MessageLookupByLibrary.simpleMessage("非推奨"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("選択できないプロキシグループです"),
    "notUnlocked": MessageLookupByLibrary.simpleMessage("未解除"),
    "notificationHighPriority": MessageLookupByLibrary.simpleMessage("高優先度"),
    "notificationHighPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "現在の通知バーをフォアグラウンド高優先度に調整",
    ),
    "notificationHighPriorityTip": MessageLookupByLibrary.simpleMessage(
      "高優先度の通知は、一部のカスタムOSでバックグラウンド維持の問題を緩和できます。現在VPNが正常に動作している場合は無効のままにすることをお勧めします。有効にしますか？",
    ),
    "ntp": MessageLookupByLibrary.simpleMessage("NTP時刻同期"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("NTP時刻同期サービスを使用"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("更新間隔"),
    "ntpPort": MessageLookupByLibrary.simpleMessage("ポート"),
    "ntpServer": MessageLookupByLibrary.simpleMessage("サーバー"),
    "ntpStatus": MessageLookupByLibrary.simpleMessage("ステータス"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage("NTP時刻同期サービスを有効化"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。追加してください",
    ),
    "nullTip": m24,
    "numberTip": m25,
    "obfsModeLabel": MessageLookupByLibrary.simpleMessage("難読化モード"),
    "obfsNoneOff": MessageLookupByLibrary.simpleMessage("なし (オフ)"),
    "oneColumn": MessageLookupByLibrary.simpleMessage("1列"),
    "onlinePanel": MessageLookupByLibrary.simpleMessage("オンラインパネル"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage("サードパーティアプリのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシ通信のみ統計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシ経由の通信量のみカウント",
    ),
    "openDashboard": MessageLookupByLibrary.simpleMessage("Zashboardを開く"),
    "openGateway": MessageLookupByLibrary.simpleMessage("ゲートウェイを開く"),
    "openSettings": MessageLookupByLibrary.simpleMessage("設定を開く"),
    "operatorOrAsn": MessageLookupByLibrary.simpleMessage("組織 / ASN"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者（ランダム順）"),
    "otherSettings": MessageLookupByLibrary.simpleMessage("拡張ツール"),
    "otherSettingsDesc": MessageLookupByLibrary.simpleMessage("拡張ツールの設定を変更"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("オーバーライド"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage("プロキシ関連設定のオーバーライド"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("宛先アドレス上書き"),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "スニッフィング結果で宛先アドレスを置換",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNSオーバーライド"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル内のDNS設定を上書き",
    ),
    "overrideExperimental": MessageLookupByLibrary.simpleMessage(
      "実験的機能オーバーライド",
    ),
    "overrideExperimentalDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル内の実験的設定を上書き",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "スクリプトモードでは無効です",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("NTPオーバーライド"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル内のNTP設定を上書き",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage("元のルールを上書き"),
    "overrideSniffer": MessageLookupByLibrary.simpleMessage("スニッファーオーバーライド"),
    "overrideSnifferDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル内のスニッファー設定を上書き",
    ),
    "overrideTestUrl": MessageLookupByLibrary.simpleMessage("テストURL上書き"),
    "overrideTunnel": MessageLookupByLibrary.simpleMessage("トンネルオーバーライド"),
    "overrideTunnelDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル内のトンネル設定を上書き",
    ),
    "packageListPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "権限が拒否されました。アプリ一覧を取得できません。",
    ),
    "packageListPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "インストール済みアプリ一覧を取得する権限が必要です。許可しますか？",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "parseNoValidNode": MessageLookupByLibrary.simpleMessage(
      "有効なプロキシ情報を認識できませんでした。形式を確認してください",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("IP直接接続の解析"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage("IP直接接続を解析"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "passwordAuth": MessageLookupByLibrary.simpleMessage("パスワード"),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage("パスワードが一致しません"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("クリップボードから貼り付け"),
    "peerPublicKey": MessageLookupByLibrary.simpleMessage("ピア公開鍵"),
    "pin": MessageLookupByLibrary.simpleMessage("固定"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("WebDAVを連携してください"),
    "pleaseCloseSystemProxyFirst": MessageLookupByLibrary.simpleMessage(
      "最初にシステムプロキシをオフにしてください",
    ),
    "pleaseCloseTunFirst": MessageLookupByLibrary.simpleMessage(
      "最初にTUNモードをオフにしてください",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力してください",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "ファイルをアップロードしてください",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコード画像をアップロードしてください",
    ),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "重複しないポート番号を入力してください",
    ),
    "portFallback": MessageLookupByLibrary.simpleMessage("ポートの自動回避"),
    "portFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "設定したポートが使用中のとき、別のポートを一時的に使用します",
    ),
    "portLabel": MessageLookupByLibrary.simpleMessage("ポート"),
    "portTip": m26,
    "powerSwitch": MessageLookupByLibrary.simpleMessage("電源スイッチ"),
    "preProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ プリプロキシノード名を手動入力...",
    ),
    "preProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "なし (購読ノードに直接接続)",
    ),
    "preProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "トラフィックが購読ノードに入る前に、まずプリプロキシノードを経由して中継を貫通します。ブロックされたノードの救済に利用できます。",
    ),
    "preProxySectionTitle": MessageLookupByLibrary.simpleMessage("1. プリプロキシ"),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DoHでHTTP/3を優先使用"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーを入力してください"),
    "preventWebRtcLeak": MessageLookupByLibrary.simpleMessage(
      "WebRTC 実IP漏洩を防止",
    ),
    "preventWebRtcLeakDesc": MessageLookupByLibrary.simpleMessage(
      "STUN/TURN プローブを遮断し、実際の公開IPの露出を完全に防ぎ、海外アカウント運用と越境ECの安全を守ります",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "privateIp": MessageLookupByLibrary.simpleMessage("プライベート / LAN IP アドレス"),
    "privateKey": MessageLookupByLibrary.simpleMessage("秘密鍵"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAndRules": MessageLookupByLibrary.simpleMessage("プロファイルとルール"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な時間を指定してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("更新間隔を入力してください"),
    "profileChainDialogTitle": m27,
    "profileChainSaved": MessageLookupByLibrary.simpleMessage(
      "プリプロキシとランディングプロキシの設定を保存しました",
    ),
    "profileFallbackFailed": MessageLookupByLibrary.simpleMessage(
      "以前の設定も復元できませんでした",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されました。自動更新をオフにしますか？",
    ),
    "profileImportFailed": m28,
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "設定名を入力してください",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルの解析エラー",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "設定URLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイル並び替え"),
    "progress": MessageLookupByLibrary.simpleMessage("プロセス"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "protocol": MessageLookupByLibrary.simpleMessage("プロキシプロトコル"),
    "providers": MessageLookupByLibrary.simpleMessage("プロバイダー"),
    "provinceAndCity": MessageLookupByLibrary.simpleMessage("都道府県 / 都市"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesCount": MessageLookupByLibrary.simpleMessage("プロキシノード"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("プロキシ設定"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupsCount": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシ用DNS"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノードのドメイン解決に使用",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("プロキシポート"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage("Clashのリスニングポート設定"),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyProvidersCount": MessageLookupByLibrary.simpleMessage("プロキシセット"),
    "pskKey": MessageLookupByLibrary.simpleMessage("PSK 事前共有鍵"),
    "pulse": MessageLookupByLibrary.simpleMessage("パルス"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("ピュアブラックモード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QRコードをスキャンして設定を取得"),
    "quicGoDisableEcn": MessageLookupByLibrary.simpleMessage("QUIC ECN無効化"),
    "quicGoDisableEcnDesc": MessageLookupByLibrary.simpleMessage(
      "QUICのECN（Explicit Congestion Notification）を無効化",
    ),
    "quicGoDisableGso": MessageLookupByLibrary.simpleMessage("QUIC GSO無効化"),
    "quicGoDisableGsoDesc": MessageLookupByLibrary.simpleMessage(
      "QUICのGSO（Generic Segmentation Offload）を無効化",
    ),
    "quicPortSniffer": MessageLookupByLibrary.simpleMessage("QUICポート解析"),
    "quickImport": MessageLookupByLibrary.simpleMessage("スマート一括インポート"),
    "quickImportDesc": MessageLookupByLibrary.simpleMessage(
      "IP:ポート:ユーザー名:パスワード、リンクなどの形式をワンクリックでインポート",
    ),
    "quickResponse": MessageLookupByLibrary.simpleMessage("高速レスポンス"),
    "quickResponseDesc": MessageLookupByLibrary.simpleMessage(
      "ネットワーク変更時に接続を自動切断",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("レインボー"),
    "realTimeSpeed": MessageLookupByLibrary.simpleMessage("リアルタイム速度"),
    "realityPublicKey": MessageLookupByLibrary.simpleMessage("REALITY 公開鍵"),
    "reclaimableMemory": MessageLookupByLibrary.simpleMessage("回収可能"),
    "recovery": MessageLookupByLibrary.simpleMessage("復元"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("すべてのデータを復元"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage("プロファイルのみ復元"),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage("復元戦略"),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage("互換"),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage("上書き"),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage("復元成功"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直し"),
    "refresh": MessageLookupByLibrary.simpleMessage("更新"),
    "refreshAppList": MessageLookupByLibrary.simpleMessage("アプリ一覧を更新"),
    "refreshAppListConfirm": MessageLookupByLibrary.simpleMessage(
      "アプリ一覧を更新しますか？",
    ),
    "regExp": MessageLookupByLibrary.simpleMessage("正規表現"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVへデータをバックアップ",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVからデータを復元",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("名前変更"),
    "replace": MessageLookupByLibrary.simpleMessage("置換"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("すべて置換"),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近の通信リクエスト履歴を表示"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetIconCache": MessageLookupByLibrary.simpleMessage("アイコンキャッシュをリセット"),
    "resetIconCacheDesc": MessageLookupByLibrary.simpleMessage(
      "ローカルのアイコンキャッシュをリセットしますか？アプリがリモートリンクから自動的に再取得するため、この操作は安全です。",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("本当にリセットしますか？"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソース情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルールに従う"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS接続でRules設定を適用",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartApp": MessageLookupByLibrary.simpleMessage("アプリ再起動"),
    "restartCoreDesc": MessageLookupByLibrary.simpleMessage("カーネルを手動で再起動しますか？"),
    "restartCoreTitle": MessageLookupByLibrary.simpleMessage("カーネル再起動"),
    "restartTip": MessageLookupByLibrary.simpleMessage("TUNの再起動後に有効化されます"),
    "restore": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "retest": MessageLookupByLibrary.simpleMessage("再チェック"),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "rightClickBehavior": MessageLookupByLibrary.simpleMessage("右クリック"),
    "roleEntry": MessageLookupByLibrary.simpleMessage("入口ノード"),
    "roleExit": MessageLookupByLibrary.simpleMessage("ランディング出口"),
    "roleRelay": MessageLookupByLibrary.simpleMessage("中継ノード"),
    "rotatingCircle": MessageLookupByLibrary.simpleMessage("ローテーション"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleProviderWarningsTitle": MessageLookupByLibrary.simpleMessage(
      "一部のルールセットが読み込まれませんでした",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleProvidersCount": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルールターゲット"),
    "rulesCount": MessageLookupByLibrary.simpleMessage("ルーティング規則"),
    "runTime": MessageLookupByLibrary.simpleMessage("稼働時間"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("ランタイム設定"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveAndApply": MessageLookupByLibrary.simpleMessage("保存して適用"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "saveNode": MessageLookupByLibrary.simpleMessage("ノードを保存"),
    "saveTip": MessageLookupByLibrary.simpleMessage("保存してもよろしいですか？"),
    "scenarioAi": MessageLookupByLibrary.simpleMessage("AI サービス"),
    "scenarioEcommerce": MessageLookupByLibrary.simpleMessage("越境 EC"),
    "scenarioEmail": MessageLookupByLibrary.simpleMessage("メール送信"),
    "scenarioGaming": MessageLookupByLibrary.simpleMessage("ゲーム"),
    "scenarioSocial": MessageLookupByLibrary.simpleMessage("SNS 登録"),
    "scenarioStreaming": MessageLookupByLibrary.simpleMessage("動画配信"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptDesc": MessageLookupByLibrary.simpleMessage("グローバルオーバーライドスクリプト設定"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secretCopied": MessageLookupByLibrary.simpleMessage(
      "パスワードをクリップボードにコピーしました",
    ),
    "securityLabel": MessageLookupByLibrary.simpleMessage("セキュリティ/TLS"),
    "securityNonePlain": MessageLookupByLibrary.simpleMessage("なし (平文)"),
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectBackupVersion": MessageLookupByLibrary.simpleMessage(
      "バックアップバージョンの選択",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m29,
    "serverAddress": MessageLookupByLibrary.simpleMessage("サーバーアドレス"),
    "serverAddressHint": MessageLookupByLibrary.simpleMessage("IP またはドメイン"),
    "serverAddressLabel": MessageLookupByLibrary.simpleMessage("サーバーアドレス"),
    "serverAddressRequired": MessageLookupByLibrary.simpleMessage(
      "サーバーアドレスを入力してください",
    ),
    "serviceReady": MessageLookupByLibrary.simpleMessage("サービス準備完了"),
    "serviceRunning": MessageLookupByLibrary.simpleMessage("サービス稼働中"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "showHiddenItems": MessageLookupByLibrary.simpleMessage("非表示項目を表示"),
    "showMenu": MessageLookupByLibrary.simpleMessage("メニューを開く"),
    "showPanel": MessageLookupByLibrary.simpleMessage("ウィンドウを表示"),
    "showStartSwitch": MessageLookupByLibrary.simpleMessage("単独スイッチ表示"),
    "showStartSwitchDesc": MessageLookupByLibrary.simpleMessage(
      "ホーム画面に独立したON/OFFボタンを表示",
    ),
    "shrink": MessageLookupByLibrary.simpleMessage("コンパクト"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("サイレント起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "画面を表示せずバックグラウンドで起動",
    ),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("証明書の検証をスキップ"),
    "skipCertVerifyDesc": MessageLookupByLibrary.simpleMessage(
      "自己署名証明書や TLS ハンドシェイクのエラーを解決します",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("除外ドメイン"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("除外宛先IP"),
    "skipLocalAuth": MessageLookupByLibrary.simpleMessage("ローカル認証をスキップ"),
    "skipLocalAuthDesc": MessageLookupByLibrary.simpleMessage(
      "ローカル端末からの認証なしアクセスを許可",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("除外送信元IP"),
    "smartAutoStop": MessageLookupByLibrary.simpleMessage("スマート自動停止"),
    "smartAutoStopDesc": MessageLookupByLibrary.simpleMessage(
      "指定ネットワーク接続時にプロキシを停止",
    ),
    "smartAutoStopServiceRunning": MessageLookupByLibrary.simpleMessage(
      "スマート自動停止サービス稼働中",
    ),
    "smartDelayLaunch": MessageLookupByLibrary.simpleMessage("遅延起動"),
    "smartDelayLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "ネットワーク接続完了後に起動",
    ),
    "snellVersion": MessageLookupByLibrary.simpleMessage("Snell バージョン (1-4)"),
    "sniHint": MessageLookupByLibrary.simpleMessage("空欄の場合はサーバーアドレスと同じになります"),
    "sniLabel": MessageLookupByLibrary.simpleMessage(
      "SNI (ServerName / 偽装ドメイン)",
    ),
    "sniffer": MessageLookupByLibrary.simpleMessage("スニッファー"),
    "snifferAddressHint": MessageLookupByLibrary.simpleMessage("1行に1アドレス"),
    "snifferDesc": MessageLookupByLibrary.simpleMessage("ドメインスニッフィングの設定変更"),
    "snifferDomainHint": MessageLookupByLibrary.simpleMessage("1行に1ドメイン"),
    "snifferPorts": MessageLookupByLibrary.simpleMessage("ポート"),
    "snifferPortsHint": MessageLookupByLibrary.simpleMessage(
      "例: 80, 8080-8880",
    ),
    "snifferStatus": MessageLookupByLibrary.simpleMessage("ステータス"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "スニッフィングサービスを有効化",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socksポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並び替え"),
    "source": MessageLookupByLibrary.simpleMessage("送信元"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "specificDialerProxy": MessageLookupByLibrary.simpleMessage("専用跳板を指定"),
    "spinningLines": MessageLookupByLibrary.simpleMessage("スピンライン"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startTest": MessageLookupByLibrary.simpleMessage("レイテンシテスト"),
    "startVpn": MessageLookupByLibrary.simpleMessage("起動中..."),
    "status": MessageLookupByLibrary.simpleMessage("ステータス"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("オフにするとシステムDNSを使用します"),
    "stillUsingProfile": m30,
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("停止中..."),
    "storeFix": MessageLookupByLibrary.simpleMessage("ストア修復"),
    "storeFixDesc": MessageLookupByLibrary.simpleMessage(
      "Google Playストアのダウンロード問題を修復",
    ),
    "strictRoute": MessageLookupByLibrary.simpleMessage("厳格ルーティング"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "TUNの厳格ルーティングモードを使用",
    ),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルーール"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "success": MessageLookupByLibrary.simpleMessage("成功"),
    "switchLabel": MessageLookupByLibrary.simpleMessage("スイッチ"),
    "switchProfileFailed": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションの切り替えに失敗",
    ),
    "switchToDomesticIp": MessageLookupByLibrary.simpleMessage("国内IPを取得"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "syncAll": MessageLookupByLibrary.simpleMessage("すべて同期"),
    "syncDelayAnimation": MessageLookupByLibrary.simpleMessage(
      "アニメーションを他のページに同期",
    ),
    "syncFailed": MessageLookupByLibrary.simpleMessage("同期失敗"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemDns": MessageLookupByLibrary.simpleMessage("システム DNS"),
    "systemFont": MessageLookupByLibrary.simpleMessage("システムフォント"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyActualOff": MessageLookupByLibrary.simpleMessage(
      "システムの実際のプロキシはオフです",
    ),
    "systemProxyActualOn": MessageLookupByLibrary.simpleMessage(
      "システムの実際のプロキシはオンです",
    ),
    "systemProxyActualStatus": MessageLookupByLibrary.simpleMessage(
      "システムの実際の状態",
    ),
    "systemProxyChecking": MessageLookupByLibrary.simpleMessage(
      "システムの実際の状態を検出中…",
    ),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("システムプロキシの設定"),
    "systemProxyMismatchOff": MessageLookupByLibrary.simpleMessage(
      "システムプロキシはまだオンのままです",
    ),
    "systemProxyMismatchOn": MessageLookupByLibrary.simpleMessage(
      "設定はオンを要求していますが、システムプロキシは実際にはオンになっていません",
    ),
    "systemProxyUnknown": MessageLookupByLibrary.simpleMessage(
      "システムプロキシの状態を確認できません",
    ),
    "systemProxyUnsupported": MessageLookupByLibrary.simpleMessage(
      "このプラットフォームはシステムプロキシ状態の検出に対応していません",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP並列接続"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCPの同時並列接続を許可"),
    "testAll": MessageLookupByLibrary.simpleMessage("一括測定"),
    "testCurrentProxy": MessageLookupByLibrary.simpleMessage("可用性をテスト"),
    "testUrl": MessageLookupByLibrary.simpleMessage("テストURL"),
    "testing": MessageLookupByLibrary.simpleMessage("検出中"),
    "testingHealth": MessageLookupByLibrary.simpleMessage("検出中..."),
    "textScale": MessageLookupByLibrary.simpleMessage("テキスト倍率"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("テーマカラーとアイコンの設定"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "threeBounce": MessageLookupByLibrary.simpleMessage("トリプルバウンス"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("3列"),
    "threeInOut": MessageLookupByLibrary.simpleMessage("トリプルインアウト"),
    "tight": MessageLookupByLibrary.simpleMessage("タイト"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "titleTooLong": MessageLookupByLibrary.simpleMessage("長すぎます（最大20文字）"),
    "tlsPortSniffer": MessageLookupByLibrary.simpleMessage("TLSポート解析"),
    "toggle": MessageLookupByLibrary.simpleMessage("切替"),
    "tolerateRuleProviderErrors": MessageLookupByLibrary.simpleMessage(
      "ルールセットの読み込み失敗を無視",
    ),
    "tolerateRuleProviderErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "一部のルールセットのダウンロードが失敗しても設定を適用します。オフにすると、ルールセットの失敗で設定全体が拒否されます",
    ),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("トーナルスポット"),
    "tooManyRules": MessageLookupByLibrary.simpleMessage("ルールは最大5つまでです"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "topologyClient": MessageLookupByLibrary.simpleMessage("ローカルクライアント"),
    "topologyHop": MessageLookupByLibrary.simpleMessage("前置跳板"),
    "topologyLanding": MessageLookupByLibrary.simpleMessage("住宅ランディング"),
    "topologyRelay": MessageLookupByLibrary.simpleMessage("中継ノード"),
    "topologyTarget": MessageLookupByLibrary.simpleMessage("対象サービス"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("総通信量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxyポート"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("通信量統計"),
    "trayClickBehavior": MessageLookupByLibrary.simpleMessage("トレイクリック動作"),
    "trayEnhancement": MessageLookupByLibrary.simpleMessage("トレイ拡張"),
    "trayEnhancementDesc": MessageLookupByLibrary.simpleMessage(
      "システムトレイメニューでプロキシグループを操作",
    ),
    "trayIconInvert": MessageLookupByLibrary.simpleMessage("トレイアイコン反転"),
    "trayIconInvertDesc": MessageLookupByLibrary.simpleMessage(
      "現在のトレイアイコンの色を反転設定",
    ),
    "tryManualRefresh": MessageLookupByLibrary.simpleMessage(
      "手動で再読み込みをお試しください",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("仮想NIC (TUN)"),
    "tunActualOff": MessageLookupByLibrary.simpleMessage("システムの実際の TUN は無効です"),
    "tunActualOn": MessageLookupByLibrary.simpleMessage("システムの実際の TUN は有効です"),
    "tunActualStatus": MessageLookupByLibrary.simpleMessage("TUN の実際の状態"),
    "tunChecking": MessageLookupByLibrary.simpleMessage("TUN の実際の状態を検出中…"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("TUNモードでデバイスの全通信を管理"),
    "tunEnableRequireAdmin": MessageLookupByLibrary.simpleMessage(
      "TUN仮想NIC機能の有効化には管理者（ROOT）権限が必要です",
    ),
    "tunMismatchOff": MessageLookupByLibrary.simpleMessage("TUN はまだ有効なままです"),
    "tunMismatchOn": MessageLookupByLibrary.simpleMessage(
      "設定はオンを要求していますが、システムの TUN は実際には有効になっていません",
    ),
    "tunUnknown": MessageLookupByLibrary.simpleMessage("TUN の実際の状態を確認できません"),
    "tunUnsupported": MessageLookupByLibrary.simpleMessage(
      "このプラットフォームは TUN の実際の状態を提供していません",
    ),
    "tunVirtualAddress": MessageLookupByLibrary.simpleMessage(
      "TUN 仮想ネットワークアダプター",
    ),
    "tunnel": MessageLookupByLibrary.simpleMessage("トンネル"),
    "tunnelAddress": MessageLookupByLibrary.simpleMessage("バインドアドレス"),
    "tunnelAddressHint": MessageLookupByLibrary.simpleMessage(
      "例: 127.0.0.1:6553",
    ),
    "tunnelDesc": MessageLookupByLibrary.simpleMessage("ポートフォワーディングを使用"),
    "tunnelList": MessageLookupByLibrary.simpleMessage("転送リスト"),
    "tunnelNetwork": MessageLookupByLibrary.simpleMessage("プロトコル"),
    "tunnelNetworkHint": MessageLookupByLibrary.simpleMessage("例: tcp, udp"),
    "tunnelProxy": MessageLookupByLibrary.simpleMessage("プロキシ名"),
    "tunnelProxyHint": MessageLookupByLibrary.simpleMessage("例: proxy（任意）"),
    "tunnelTarget": MessageLookupByLibrary.simpleMessage("転送先アドレス"),
    "tunnelTargetHint": MessageLookupByLibrary.simpleMessage(
      "例: 114.114.114.114:53",
    ),
    "tvScanManualUrl": MessageLookupByLibrary.simpleMessage(
      "スマホのブラウザに直接入力も可能：",
    ),
    "tvScanNoNetwork": MessageLookupByLibrary.simpleMessage(
      "利用可能なLANが見つかりません。Wi-Fiを確認してください",
    ),
    "tvScanStep1": MessageLookupByLibrary.simpleMessage(
      "スマホとTVが同じWi-Fiネットワークにあることを確認",
    ),
    "tvScanStep2": MessageLookupByLibrary.simpleMessage(
      "対応するカメラまたはブラウザでQRコードをスキャン",
    ),
    "tvScanStep3": MessageLookupByLibrary.simpleMessage(
      "Webページで購読URLを貼り付けまたは設定をアップロードしてプッシュ",
    ),
    "tvScanSuccess": MessageLookupByLibrary.simpleMessage(
      "設定がプッシュされました。インポート中...",
    ),
    "tvScanWaiting": MessageLookupByLibrary.simpleMessage("スマホからのプッシュを待機中..."),
    "twoColumns": MessageLookupByLibrary.simpleMessage("2列"),
    "udpForwarding": MessageLookupByLibrary.simpleMessage("UDP 転送"),
    "udpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "住宅IPがUDPに対応しておらず異常が発生する場合は、この項目をオフにできます",
    ),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "現在のプロファイルを更新できません",
    ),
    "unauthorized": MessageLookupByLibrary.simpleMessage("未認証"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("レイテンシの統一"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイク等の追加レイテンシを除外",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unlocked": MessageLookupByLibrary.simpleMessage("完了"),
    "unnamed": MessageLookupByLibrary.simpleMessage("無題"),
    "unnamedNode": MessageLookupByLibrary.simpleMessage("名前のないノード"),
    "unpin": MessageLookupByLibrary.simpleMessage("固定解除"),
    "upLabel": MessageLookupByLibrary.simpleMessage("上り"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateTime": MessageLookupByLibrary.simpleMessage("更新日時"),
    "upload": MessageLookupByLibrary.simpleMessage("送信"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URLから設定を取得"),
    "urlTip": m31,
    "useGlobalScriptOverride": MessageLookupByLibrary.simpleMessage(
      "グローバルスクリプトオーバーライドを使用",
    ),
    "useHosts": MessageLookupByLibrary.simpleMessage("Hostsを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムHostsを使用"),
    "userAuth": MessageLookupByLibrary.simpleMessage("ユーザー認証"),
    "username": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "usernameCannotContainColon": MessageLookupByLibrary.simpleMessage(
      "ユーザー名にコロン（:）を含めることはできません",
    ),
    "usernameOptional": MessageLookupByLibrary.simpleMessage("ユーザー名 (任意)"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("バイブラント"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "viewDetailedIpData": MessageLookupByLibrary.simpleMessage("詳細なIPデータを見る"),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("VPN関連の設定を変更"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnServiceでシステム通信をルーティング",
    ),
    "vpnSystemProxyConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "モバイル端末ではHTTPプロキシ併用は非推奨です。必要な場合のみ設定してください",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "VpnServiceにHTTPプロキシを添付",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("VPN再起動後に有効化されます"),
    "wakelock": MessageLookupByLibrary.simpleMessage("画面常時点灯"),
    "wakelockDescription": MessageLookupByLibrary.simpleMessage(
      "画面の自動消灯を防ぐ画面ウェイクロックを有効にします（CPUウェイクは使用しません）。バックグラウンド処理を維持したい場合に便利です。",
    ),
    "wave": MessageLookupByLibrary.simpleMessage("ウェーブ"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelist": MessageLookupByLibrary.simpleMessage("ホワイトリスト"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("システムへ適用"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage("管理者権限が必要です"),
    "wrongBackupPassword": MessageLookupByLibrary.simpleMessage(
      "パスワードが違うか、バックアップが改ざんされています",
    ),
    "years": m32,
  };
}
