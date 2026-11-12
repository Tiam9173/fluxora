<div align="center">

<img src="../assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 明確なルーティング、静かなる制御。**

オープンソース・クロスプラットフォームの Mihomo ネットワークルーティングクライアント。
設定・接続・ルール・トラフィックの状態を、抑制の効いた明快で監査可能な一つの画面に。

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](../LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#対応プラットフォーム)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- ドキュメントの言語 -->

[![简体中文](https://img.shields.io/badge/简体中文-29D6C7?style=flat-square)](../README.md)
[![English](https://img.shields.io/badge/English-4C8DFF?style=flat-square)](../README_en.md)

**[ダウンロード](#ダウンロード)** · **[問題報告](https://github.com/Tiam9173/fluxora/issues)** · **[コントリビュート](#コントリビュート)** · **[ライセンス](../LICENSE)**

📢 **[Telegram チャンネル](https://t.me/Fluxora_Channel)** · 💬 **[Telegram グループ](https://t.me/Fluxora_Group1)**

</div>

---

## 公式コミュニティ

- 📢 **[Telegram チャンネル](https://t.me/Fluxora_Channel)** — 更新・リリース・プロジェクトの動向
- 💬 **[Telegram グループ](https://t.me/Fluxora_Group1)** — 議論・質問・フィードバック

## なぜ Fluxora か

多くのプロキシクライアントは「接続できた」をゴールにし、ルール・ログ・接続状態を階層の深いサブメニューに押し込みます。Fluxora は逆を行きます。**まず状態を見えるようにし、そのうえで操作に手が届くようにする。**

Mihomo（Clash Meta）コアの上に Flutter で構築し、デスクトップとモバイルで同じ情報設計を提供します——ダッシュボード、プロキシ、設定、ツール、ログ、リクエスト、リソース、スクリプト、接続。九つのページがそれぞれの役割を持ち、詰め込まず、隠しません。

設計の三原則は **抑制**（装飾的なモーションやネオン発光をしない）、**明快**（状態は常に操作より目立つ）、**監査可能**（オープンソース、組み込みアカウントなし、宣言のないクローズドソース依存を持ち込まない）。

## 主な特長

- **現代的な UI** — Material 3 と統一されたデザイントークン（色・文字・余白・角丸・モーション）。上流 UI の単純な書き換えではありません。
- **プラットフォーム間の一貫性** — Windows・macOS・Linux・Android が同一の Flutter コードベースと情報設計を共有します。
- **完全なプロキシ制御** — ルール / グローバル / ダイレクトの出站モード、グループ選択、遅延測定、チェーンプロキシと住宅用ランディング。
- **ネットワークの引き受け** — TUN 仮想アダプタとシステムプロキシ、デスクトップでは常駐トレイとグローバルホットキー。
- **テーマとマテリアル** — ライト / ダーク / システム追従、ピュアブラック、四つのマテリアル（クラシック / すりガラス / リキッドグラス / 軽量）と「オブシディアン」テーマ。システム配色と任意のアクセントに対応。
- **オープンで監査可能** — GPL-3.0。コア・スクリプトエンジン・依存関係はすべて確認でき、クラウドアカウント体系はありません。

## 機能

### 接続

- システムプロキシ（デスクトップ）
- TUN 仮想アダプタ（スタック種別とルーティングモードを含む）
- 出站モード：ルール / グローバル / ダイレクト
- 接続一覧とリアルタイム流量、接続の切断
- スマート自動停止：指定したネットワークに接続したらプロキシを停止

### ノード

- プロキシグループ：select / url-test / fallback / load-balance
- 遅延測定とノード切り替え
- 手動切り替えは一度だけ有効で、恒久的な固定としては保存されません。url-test グループは実測の最小遅延ノードに戻ります

### チェーンプロキシ

- 入口ホップ + 静的住宅 IP の二段リレー。入口 → ランディングの順に転送
- チェーンプロキシ専用のグループカード（🔗 チェーンプロキシ）を生成し、通常グループと並べて管理
- ホップごとのノード選択と状態（入口 / ランディング）、ホップ単位の遅延測定と診断
- ルートトポロジのプレビュー：各ホップの到達性と遅延を一目で確認
- 購読ごとに有効化でき、明示的なマルチ入口チェーンにも対応

### Cloudflare WARP

- WARP 出口を内蔵し、専用の「🛡️ WARP 出口」グループを生成。任意のプロキシグループと組み合わせ可能
- Cloudflare アカウントのワンクリック登録、WARP+ ライセンスキーの紐付けに対応
- エンドポイント / ポート、クリーン IP、MTU、UDP スイッチ、リモート DNS 解決を設定可能
- ルーティングモードを選択でき、上流ダイヤラ（default dialer proxy）も指定可能

> 接続できるかどうかはノード、ネットワーク環境、Cloudflare 側の状態に依存します。

### 設定

- 複数プロファイルの管理（ローカルファイル / 購読リンク）
- プロファイルのインポートと更新、ルールプロバイダ
- 複数購読の集約
- JavaScript によるルールと設定の処理

### ツール

- ネットワーク検査、LAN IP、メディア解除判定
- DNS・Sniffer・NTP の上書き
- IPv6 スイッチ、メモリ使用量、流量統計
- ログ、リクエスト記録、接続診断
- 任意の IP リスク情報（既定はオフ）

### インターフェースと個別化

- ホームのコンポーネントは追加・並べ替え・削除が可能。接続の主操作は常に残ります
- デスクトップのサイドバーは 208px のラベル付きと 68px のアイコン表示を切り替え。モバイルはフローティングナビゲーション
- ライト / ダーク / システム追従、ピュアブラック（OLED）
- 四つのマテリアルと「オブシディアン」テーマ。レンズの強さと透過度は個別に調整可能
- 三つの配色ソース：ブランド配色、システム配色（Android Material You）、任意のアクセント
- モーションは実際の状態に連動し、システムの「アニメーションを減らす」設定を尊重
- デスクトップのトレイ、グローバルホットキー、ログイン時の自動起動

### ブランドアイコン

八つのスタイルがあり、それぞれダーク用とライト用を個別に用意：オフィシャル、クラシック、アクア、プレミアム、スピード、スカイ、サンセット、ブルーナイト。
**設定 → テーマ → アプリアイコン** から選択します。アイコンの配色とページのテーマは別々に設定できます。

![Fluxora アイコン一覧](../design/brand_icons/preview.png)

## スクリーンショット

## 対応プラットフォーム

| プラットフォーム | 状態 |
|---|---|
| Windows 10 / 11 | 対応 |
| macOS 12+ | 対応 |
| Linux | 対応 |
| Android 8.0+ | 対応 |
| iOS | 公式クライアントなし |

## ダウンロード

パッケージは **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)** で公開され、`Fluxora-<version>-<platform>` という名前で配布されます。

現在の正式版は **[v1.1.1](https://github.com/Tiam9173/fluxora/releases/tag/v1.1.1)** です。`dev` ブランチの **1.1.2-rc.2 プレビュー版は公開を保留中** で、ソース上のバージョン表記はパッケージが公開済みであることを意味しません。最新の状態とダウンロードは Releases を参照してください。

| プラットフォーム | 提供形式 | アーキテクチャ |
|---|---|---|
| Windows 10 / 11 | `setup.exe` インストーラ · `portable.zip` ポータブル版 | amd64 · amd64-compatible · arm64 |
| macOS 12+ | `.dmg` | arm64 · amd64 · amd64-compatible |
| Linux | `.AppImage` · `.deb` · `.rpm` | amd64 · amd64-compatible（三形式）· arm64（deb） |
| Android 8.0+ | `.apk` | arm64-v8a · armeabi-v7a · x86_64 · universal |
| iOS | 公式クライアントなし | — |

> `-compatible` は古い CPU やシステム（新しい命令セットを持たない端末）向けです。通常は標準版を選んでください。この表は各プラットフォームが対応する形式を示すもので、すべての候補ビルドが全形式を出力済みという意味ではありません。

## インストール

### Windows

`setup.exe` インストーラを使うか、`*-windows-amd64-portable.zip` を展開して `Fluxora.exe` を直接実行します。

### Android

Releases から端末のアーキテクチャに合う APK をダウンロードし、サイドロードでインストールします。

### Linux

ディストリビューションに合わせて `.AppImage` / `.deb` / `.rpm` を選んでください。

### macOS

アーキテクチャに合う DMG をダウンロードして開きます。

## 使い方とプライバシー

1. 「設定」で自分の購読またはローカル設定をインポートし、使用するものを選択します。
2. 「プロキシ」でノードを選び、接続を開始します。Fluxora は購読やプロキシサーバーを提供しません。
3. TUN とシステムプロキシはプラットフォームと権限に応じて動作します。システムプロキシはその設定に従うアプリにのみ影響します。

購読の更新、遅延測定、出口 IP / 解除判定、WARP 登録はそれぞれのサービスに接続します。IP リスク情報は既定でオフで、有効にして照会すると対象 IP が情報提供元へ送信されます。**「Fluxora のクラウドアカウントがない」ことを「第三者への通信がない」と読み替えないでください。** 設定・ログ・診断を共有する前に、購読 URL・鍵・個人情報を削除してください。

## FAQ

### Fluxora とは？

Mihomo（Clash Meta）コアの上に Flutter で構築された、オープンソース・クロスプラットフォームのルーティングクライアントです。

### 対応プラットフォームは？

Windows、macOS、Linux、Android です。iOS の公式クライアントはなく、当面の予定もありません。

### オープンソースですか？ライセンスは？

はい、**GPL-3.0** です。全文は [LICENSE](../LICENSE) を参照してください。

### 設定のインポート方法は？

「設定」ページで購読リンクを追加するか、ローカルファイルをインポートして選択すれば接続できます。`fluxora://install-config` リンクからの直接インポートにも対応しています。

### TUN とシステムプロキシの違いは？

システムプロキシはシステム設定に従うアプリにのみ影響します。TUN は仮想アダプタでより低い層から通信を引き受けるため適用範囲が広く、通常は管理者権限が必要です。デスクトップでは両者を独立して切り替えられます。

### iOS 版がないのはなぜ？

iOS には独立した Network Extension の実装と、開発者署名による配布が必要です。現在の計画には含まれていません。

### データを収集しますか？

いいえ。Fluxora はクラウドアカウントサービスも組み込みの統計送信も持ちません。ただし購読更新・遅延測定・IP や解除判定などは、あなたの設定に従って該当する第三者サービスへ接続します。

## 開発

**必要なもの**：Flutter（Dart を含む）、Android SDK/NDK と JDK、各プラットフォームのツールチェーン（Windows は Visual Studio Build Tools、macOS は Xcode、Linux は GTK 開発ライブラリ）。コアと Helper は Go / Rust のコンポーネントで、それぞれのツールチェーンが必要です。

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter run            # または flutter build windows --release
```

## コントリビュート

Issue、ドキュメントの改善、修正、コードのいずれも歓迎します：

- **バグ報告 / 機能要望** → [Issues](https://github.com/Tiam9173/fluxora/issues)（プラットフォーム、バージョン、再現手順、個人情報を除いたログを添えてください）
- **コード** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

提出前に、宣言のないクローズドソース依存を持ち込まないこと、GPL や第三者のライセンス表記を削除しないことを確認してください。

## ライセンスと系譜

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](../LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](../NOTICE) and the relevant component license files.

Fluxora is based on development of [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](../NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
