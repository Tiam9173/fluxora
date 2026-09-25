<h4 align="right">
  <a href="../README.md">简体中文</a> | <a href="README_en.md">English</a> | <a href="README_ru.md">Русский</a> | <a href="README_fa.md">فارسی</a> | <strong>日本語</strong> | <a href="README_ko.md">한국어</a>
</h4>

<h1 align="center">⚡ Fluxora</h1>
<p align="center">
  <strong>Open-source cross-platform Mihomo routing client</strong>
</p>

**Fluxora は、Mihomo（Clash Meta）カーネルを搭載し、初期の FlClash をベースに再構築されたマルチプラットフォーム対応のネットワークデバッグ・分流クライアントです。**

「clear and reliable routing（より良い体験）」を追求し、オリジナルの洗練された UI を継承しつつ、細部のデザインや実用ロジックを深層最適化。コア機能と実現目標：「フロントエンドは高フレームレートで滑らか、バックグラウンドは省電力で無感」。低リソースで長期にわたり安定動作する、より優れた Mihomo クライアントの実現に尽力しています。

Fluxora：Make routing legible. - 優れた体験を、すぐに使える。

私たちのビジョン：Clear routes, calm control.

[![Latest Release](https://img.shields.io/github/v/release/Tiam9173/fluxora?style=for-the-badge&logo=github&color=238636&label=Release)](https://github.com/Tiam9173/fluxora/releases/latest) [![Core](https://img.shields.io/github/v/release/MetaCubeX/mihomo?style=for-the-badge&logo=go&logoColor=white&color=8A2BE2&label=Mihomo)](https://github.com/MetaCubeX/mihomo/releases/latest)

<p align="center">
  <img src="../assets/images/fluxora_mark.svg" alt="Fluxora" />
</p>

---
### ✈️ Telegram コミュニティ

</div>

<div align="left">

[![Telegram Group](https://img.shields.io/badge/Fluxora-Chat-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://github.com/Tiam9173/fluxora/discussions) [![Telegram Channel](https://img.shields.io/badge/Fluxora-Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://github.com/Tiam9173/fluxora/discussions)

---
## 🚀 主な特徴

* **箱から出してすぐ使える**：安定した権限処理と快適な TUN/VPN 体験。最適化プリセット済みで即座に使用可能。
* **洗練されたデザイン**：UI と操作感を隅々まで磨き上げ。高 FPS アニメーション、モバイル低消費電力、デスクトップ低フットプリント。
* **セキュリティ重視**：Mihomo メインラインを迅速に追従し、マルチプラットフォームで厳格な権限管理と検証を維持。
* **堅牢な安定性**：極端な環境下での境界処理を最適化し、二重の設定検証でエンタープライズ級の安定性を実現。
* **パフォーマンス優先**：デスクトップネイティブ ARM64 サポート、ハードウェア階層化、Flutter 最適化によりハードウェア性能を搾り出します。
* **高度な機能**：マルチプラットフォーム無感スマート起動/停止、Android スリープ対応、ワンタップ QUIC 無効化、機能強化トレイメニュー。
* **ビジュアル設定**：パラメータを画面上で視覚的に調整可能。設定ファイルを直接変更することなく即時反映。
* **ホームウィジェット**：通信速度や動作ステータスをホーム画面で一目で確認できる美しいウィジェットを内蔵。
* **カスタマイズ**：豊富なカラーテーマ、カスタムアイコン/タイトル、10 種類の動的スピードテストアニメーションを収録。
* **優れた拡張性**：すべての JS オーバーライド脚本に対応する分流 UI 設定と、使いやすいトグルスイッチを提供。
* **プロ仕様エディタ**：全プラットフォーム対応の高速再構築 code-forge エディタを内蔵し、プロレベルのエディタ体験を実現。
* **レガシー互換**：旧 OS や旧ハードウェア向けの Compatible バージョンを継続維持し、デバイスの寿命を延長。
* **プライバシーリスクゼロ**：オープンソース、広告なし。透明な CI/CD と外部監査対応で、背景でのデータ収集を遮断。
* **コミュニティ重視**：フィードバックを真摯に評価し、質の高い Issue を優先対応。ユーザーの声を大切にします。

---
</div>

## 🛠️ インストールとダウンロード

ご利用のプラットフォームおよびシステムに適した最新のインストールパッケージを **[[Releases]](https://github.com/Tiam9173/fluxora/releases)** ページからダウンロードしてください。


* **全デスクトッププラットフォーム**: 
**Windows 8.1+:** (x64/arm64)
**Linux Kernel 5.4+:** (x64/arm64)
**macOS 10.15+:** (Intel/Apple Silicon)
* **Android 8.0+ 端末**: Android (ARMv8 / ARMv7 / x86_64 / Universal)
* **Android TV**: 完全対応、ARMv7 32ビット版も選択可能
* **HarmonyOS NEXT**: [[卓易通]](https://harmonyos.cool/android-app) と組み合わせてご利用ください

**その他のインストール方法:**<br>
**ArchLinux:** <code>yay -S fluxora-bin または paru -S fluxora-bin</code> ([lyj404](https://github.com/lyj404/fluxora-aur) により維持)<br>
**AMD64=v1:** <code>yay -S fluxora-compatible-bin または paru -S fluxora-compatible-bin</code> ([VillagerTom](https://github.com/VillagerTom) により維持)

---
## ❓ よくある質問

1. **インストール・起動およびセキュリティ**：
   - Android端末：**十分なバックグラウンド権限が与えられているか、最低システム要件（Android 8.0+）を満たしているか**確認してください。
   - デスクトップ旧型端末：システムアーキテクチャに応じて**特定 CPU クラス向けの Compatible バージョンが必要か**確認してください。
   - **セキュリティ：Fluxora は完全オープンソースかつ透明で、コードは Signpath のセキュリティ監査に合格しています。**

2. **デスクトップ端末のよくある質問**：
   - Windows管理者権限：インストール時に自動処理されるため、**手動での再権限付与は不要です**。
   - TUN仮想NICを有効化できない：macOS / Linux では**正しいパスワードを入力して権限を授与したか確認してください**。
   - その他のエラー：デバッグ情報を提供し、**競合するプロキシソフトやサービスが動作していないことを確認してください**。
   - 問題が解決しない場合は、ISSUE を提出してください。

3. **macOSインストールの注意事項**：
   - ご利用の環境（Intel / Apple Silicon）に適したファイルをダウンロードし、`Fluxora-macos-xx.dmg` をダブルクリックして開きます。
   - Fluxora アイコンを「Applications」フォルダにドラッグ＆ドロップしてインストール完了。
   - **インストールまたはアップデート時の Gatekeeper 回避**（[現在 Apple デベロッパー証明書を購入していないため](https://support.apple.com/en-us/102445)）：
     - **推奨**：「Applications」フォルダ内で **Fluxora アイコンを右クリック**し、**「開く」** を選択後、確認ダイアログで再度 **「開く」** をクリックします。
     - **代替案**：ダブルクリックで開けない場合は、Mac「システム設定」 -> 「プライバシーとセキュリティ」から Fluxora を探して **「このまま開く」** をクリックします。
   - 初めて TUN モードを有効にする際、現在ログインしている Mac ユーザーのパスワードを入力してネットワーク構成を許可してください。

4. **購読リンクをインポートできない**：
   - **まずリンクをリセットして**、正常にアクセスできることを確認してからインポートしてください。
   - 問題が解決しない場合は、まずプロバイダーにお問い合わせください。アプリ側の原因である場合は ISSUE を提出してください。

---

## 💻 開発とビルド

Windows の例：

* Windows PC が必要です（OS ≥ Windows 10）
* 必要環境：Git, Visual Studio, Flutter 3.44.x, Golang, Inno Setup, Rust
```bash
* flutter pub get
* dart .\setup.dart windows --arch amd64 --out core (コアのみビルド)
* dart .\setup.dart windows --arch amd64 --out app --compatible (Compatible版オプション)
* ビルド完了後、成果物は `dist/` ディレクトリに生成されます
```

カスタムスクリプト UI 適応：

* v1.18.8 より、Fluxora は外部オーバーライドスクリプトの UI 適応をサポートしています。例えば AIsouler の **[スクリプト/設定リポジトリ](https://github.com/AIsouler/MyClash)** の場合、スクリプトの1行目に以下を追加するだけで、Fluxora 内蔵のトグルスイッチを直接使用できます：
* <code>const Compatible_With_Fluxora = { ruleOptionsEnable: true };</code>

---

### ☕ 開発のサポート（スポンサー）

**プロジェクトがお役に立ちましたら、以下の方法で開発をサポートしていただけます：**

* TRON (TRC-20):   <code>TCkTtZfF2WrciZLaJj3e1aqrh3zdTnCkDa</code>
* Bitcoin: <code>bc1qu950cl6035qvllmzk6cfw3l30j2lg3cq9n6g6h</code>
---

## 🙏 謝辞

<table>
  <tr>
    <td>
      <img alt="SignPath" src="https://signpath.org/assets/favicon-50x50.png" />
    </td>
    <td>
    Free code signing on Windows provided by <a href="https://signpath.io">SignPath.io</a>, certificate by <a href="https://signpath.org/">SignPath Foundation</a>
    </td>
  </tr>
</table>

**[FlClash GUI](https://github.com/chen08209/FlClash)** 〢 **[Mihomo Core](https://github.com/MetaCubeX/mihomo)**

すべての [コントリビューター](https://github.com/Tiam9173/fluxora/graphs/contributors) および利用・参考にしたオープンソースプロジェクトに感謝いたします：

[Zashboard](https://github.com/Zephyruso/zashboard), [CMFA](https://github.com/MetaCubeX/ClashMetaForAndroid), [Sparkle](https://github.com/xishang0128/sparkle), [SFA](https://github.com/SagerNet/sing-box-for-android), [HUSI](https://github.com/xchacha20-poly1305/husi), [V2rayN](https://github.com/2dust/v2rayN)

---

## 📄 ライセンス

GPL-3.0 ライセンス
