<div align="center">

<img src="../assets/images/fluxora_mark.svg" alt="Fluxora" width="104" height="104">

# Fluxora 流序

**Make routing legible. — 明確なルーティング、静かなる制御。**

オープンソース・クロスプラットフォームの Mihomo ネットワークルーティングクライアント。
設定・接続・ルール・トラフィックの状態を、抑制の効いた明快で監査可能な一つの画面に。

[![License](https://img.shields.io/badge/license-GPL--3.0-29D6C7?style=flat-square)](../LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-4C8DFF?style=flat-square)](#対応プラットフォーム)
[![Stars](https://img.shields.io/github/stars/Tiam9173/fluxora?style=flat-square&color=7C75FF&label=stars)](https://github.com/Tiam9173/fluxora/stargazers)

<!-- ドキュメントの言語 / Documentation language -->

[![简体中文](https://img.shields.io/badge/简体中文-29D6C7?style=flat-square)](../README.md)
[![English](https://img.shields.io/badge/English-4C8DFF?style=flat-square)](../README_en.md)
[![日本語](https://img.shields.io/badge/日本語-現在-7C75FF?style=flat-square)](README_ja.md)
[![한국어](https://img.shields.io/badge/한국어-FF6B9D?style=flat-square)](README_ko.md)
[![Русский](https://img.shields.io/badge/Русский-FFB020?style=flat-square)](README_ru.md)
[![فارسی](https://img.shields.io/badge/فارسی-56C1FF?style=flat-square)](README_fa.md)

**[ダウンロード](#ダウンロード)** · **[問題報告](https://github.com/Tiam9173/fluxora/issues)** · **[コントリビュート](#コントリビュート)** · **[ライセンス](../LICENSE)**

📢 **[公式 Telegram チャンネル](https://t.me/Fluxora_Chanel)** · 💬 **[公式 Telegram グループ](https://t.me/Fluxora_Grup)**

</div>

---

## 公式コミュニティ

- 📢 **[公式 Telegram チャンネル](https://t.me/Fluxora_Chanel)** —— Fluxora のアップデート、リリース情報、プロジェクトの動向をお届けします
- 💬 **[公式 Telegram グループ](https://t.me/Fluxora_Grup)** —— コミュニティでの議論、不具合の報告、利用体験の共有

## なぜ Fluxora か

多くのプロキシクライアントは「接続できた」ことをゴールとし、ルール・ログ・接続状態を幾重ものサブメニューの奥に積み上げます。Fluxora は逆を行きます。**まず状態を見えるようにし、それから操作に手が届くようにする。**

Mihomo（Clash Meta）コアを採用し、Flutter で構築。デスクトップとモバイルで同一の情報設計を提供します——ダッシュボード、プロキシ、設定、ツール、ログ、リクエスト、リソース、スクリプト、接続という 9 つのページがそれぞれの役割を担い、詰め込みも隠蔽もしません。

設計は 3 つの原則に従います。**抑制**（装飾的なアニメーションやネオン表現をしない）、**明快**（状態は常に操作より目立つ）、**監査可能**（オープンソース、アカウント体系なし、宣言されていないクローズドソース依存を導入しない）。

Fluxora は独立したプロダクトであり、いかなる上流プロジェクトとも公式な関係はありません。その由来とライセンス上の義務は [NOTICE](../NOTICE) に完全に記録されています。

## 主な特長

- **モダンなインターフェース** — Material 3 の設計体系と統一されたデザイントークン（色 / 文字サイズ / 余白 / 角丸 / モーション）。上流 UI の単純な書き換えではありません。
- **マルチプラットフォームで一貫** — Windows、macOS、Linux、Android が同一の Flutter コードと情報設計を共有します。
- **充実したプロキシ制御** — ルール / グローバル / ダイレクトの 3 つのアウトバウンドモード、プロキシグループの選択、遅延テスト、チェーンプロキシと前置・ランディング中継。
- **ネットワークの引き受け** — TUN 仮想 NIC とシステムプロキシ、デスクトップの常駐トレイとグローバルホットキー。
- **テーマシステム** — ライト / ダーク / システム連動、純黒モード、7 種類のブランドプリセット配色、Android は Material You の動的配色に対応。
- **オープンソースで監査可能** — GPL-3.0。コア、スクリプトエンジン、依存関係のすべてを確認でき、クラウドアカウント体系はありません。

## 機能

### 接続
- システムプロキシ（デスクトップ）
- TUN 仮想 NIC（スタック種別とルーティングモードの選択を含む）
- アウトバウンドモード：ルール / グローバル / ダイレクト
- 接続一覧とリアルタイム通信量、接続の切断
- スマート起動/停止：指定したネットワークに接続するとプロキシサービスを自動停止

### ノード
- プロキシグループ：選択 / 自動速度テスト / フェイルオーバー / 負荷分散
- 遅延テストとノードの切り替え
- チェーンプロキシ（前置 / ランディング中継）

### 設定
- 複数プロファイルの管理（ローカルファイル / 購読リンク）
- プロファイルのインポートと更新、ルールリソース（rule providers）

### ツール
- ネットワーク検査、内部 IP、メディア解除の検出
- DNS オーバーライド、Sniffer オーバーライド、NTP オーバーライド
- IPv6 スイッチ、メモリ使用量、通信量の統計
- ログ、リクエスト記録、接続診断
- JavaScript スクリプト（ルールと設定の処理）

### カスタマイズ
- ライト / ダーク / システム連動
- 純黒モード（OLED）
- 7 種類のブランドプリセット配色 + カスタムメインカラー
- Android Material You の動的配色
- デスクトップのトレイ、グローバルホットキー、自動起動

## スクリーンショット

![Fluxora ホーム](../snapshots/fluxora-home.png)

## 対応プラットフォーム

| プラットフォーム | 状態 |
|---|---|
| Windows 10 / 11 | 対応 |
| macOS 12+ | 対応 |
| Linux | 対応 |
| Android 8.0+ | 対応 |
| iOS | 公式クライアントなし |

## ダウンロード

正式版は近日公開予定です。公開後、インストールパッケージは **[GitHub Releases](https://github.com/Tiam9173/fluxora/releases)** にまとめて置かれ、`Fluxora-<version>-<platform>` という命名規則になります。

現在このリポジトリには**正式な Release がまだありません**。そのため下に直接クリックできるインストーラのリンクはありません——公開後に Releases ページへ戻って取得してください。

## インストール

### Windows
1. Releases から Windows ポータブル版（`*-windows-amd64-portable.zip`）をダウンロードします。
2. 任意のディレクトリに展開します（インストール不要）。
3. `Fluxora.exe` を実行します。

> インストーラ（`.exe` セットアップウィザード）は準備中です。現時点ではポータブル版をご利用ください。

### Android
Releases からアーキテクチャに合った APK をダウンロードしてサイドロードするか、アプリストア版をお待ちください。

### Linux
Releases から AppImage / deb / rpm をダウンロードします（公開内容によります）。

### macOS
Releases からアーキテクチャに合った DMG をダウンロードします。

> Linux と macOS の正式なインストールパッケージはまだビルドされていません。Releases ページの実際の内容をご確認ください。

## FAQ

### Fluxora とは？
Mihomo（Clash Meta）コアを採用し、Flutter で構築されたオープンソース・クロスプラットフォームのネットワークルーティングクライアントです。

### 対応プラットフォームは？
Windows、macOS、Linux、Android です。iOS には現在公式クライアントがなく、現時点の計画にも含まれていません。

### Fluxora と上流プロジェクトの関係は？
Fluxora は**独立したプロダクト**であり、いかなる上流プロジェクトの公式リリースでもありません。Bettbox プロジェクトの独立した継続版で、その上にブランド、UI、設計体系、Windows コンポーネントを独自に開発しています。完全な由来とライセンス上の義務は [NOTICE](../NOTICE) をご覧ください。

### オープンソースですか？ライセンスは？
オープンソースで、**GPL-3.0** を採用しています。全文は [LICENSE](../LICENSE) をご覧ください。

### 設定のインポート方法は？
「設定」ページで購読リンクを追加するか、ローカルの設定ファイルをインポートし、選択すれば接続できます。`fluxora://install-config` リンクによる直接インポートにも対応しています。

### TUN とシステムプロキシの違いは？
システムプロキシはシステムプロキシ設定に従うアプリにのみ影響します。TUN は仮想 NIC を通じてより低い層でトラフィックを引き受けるため適用範囲が広く、通常は管理者権限が必要です。デスクトップでは両者を独立して切り替えられます。

### 一部のプラットフォームにインストーラがないのはなぜ？
各プラットフォームの配布パッケージにはそれぞれのビルド環境が必要です（Linux は GTK ツールチェーン、macOS は Xcode による署名と公証）。初回の正式リリースに向けて順次整備されます。

### データは収集されますか？
いいえ。Fluxora はクラウドアカウントサービスを提供せず、統計の送信も組み込んでいません。購読、ルール、ネットワークリクエストは、あなたが選んだ設定によってのみ決まります。

## 開発

**前提条件**：Flutter（Dart を含む）、Android SDK/NDK と JDK、対象プラットフォームのビルドツール（Windows は Visual Studio Build Tools、macOS は Xcode、Linux は GTK 開発ライブラリ）。プロキシコアと Helper は Go / Rust コンポーネントのため、それぞれのツールチェーンが必要です。

```bash
git clone https://github.com/Tiam9173/fluxora.git
cd fluxora
flutter pub get
dart run build_runner build -d
flutter run            # または flutter build windows --release
```

## コントリビュート

Issue の投稿、ドキュメントの改善、不具合の修正、コードの貢献を歓迎します：

- **不具合報告 / 機能提案** → [Issues](https://github.com/Tiam9173/fluxora/issues)
- **コード貢献** → [Pull Requests](https://github.com/Tiam9173/fluxora/pulls)

変更を提出する前に、宣言されていないクローズドソース依存を導入しないこと、GPL や第三者ライセンスの表示を削除しないことを確認してください。

## ライセンスとプロジェクトの系譜

Fluxora is distributed under the GNU General Public License v3.0. See [LICENSE](../LICENSE).

Fluxora includes and interoperates with open-source components, including the [Mihomo](https://github.com/MetaCubeX/mihomo) core and other Flutter, Go, Rust, and platform libraries. Their applicable copyright notices and licenses remain in their respective source directories and distribution metadata. See [NOTICE](../NOTICE) and the relevant component license files.

Fluxora is an independent continuation of the [Bettbox](https://github.com/appshubcc/Bettbox) project. Project lineage: **FlClash → Bettbox → Fluxora**. Fluxora's branding, UI, design system and Windows components were developed independently on that base, starting 2026-09-25. See [NOTICE](../NOTICE) for the full attribution record.

Fluxora is an independent product identity. This repository does not present itself as an official product of any upstream project.
