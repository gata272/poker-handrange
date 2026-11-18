# RangeHelper (ポーカー プリフロップ レンジ支援アプリ for LiveContainer)

LiveContainer上で動作する、ヨコサワハンドレンジ準拠のプリフロップアクション判定（RAISE / CALL / FOLD）支援iOSアプリです。
GitHub Actionsを利用してMac不要で未署名 `.ipa` を自動ビルドできます。

## 主な機能
- **即座に判定（プレイ中クイック判定画面）**:
  - ポジション（`UTG / HJ / CO / BTN / SB / BB`）、状況（`RFI(オープン) / vs Open / vs 3-Bet`）、2枚のカードランク・スートをタップするだけで、即座に `RAISE`（赤）・`CALL`（緑）・`FOLD`（グレー）を大きく表示
  - ヨコサワハンドレンジの色分けティア（赤・黄・緑・青・紫）も同時表示
- **13×13 レンジ表・カスタマイズ編集**:
  - 169通りのハンドマトリクスをポジション・状況別に一覧表示（RAISE率・CALL率の自動計算付き）
  - セルをタップするだけで自分のプレイスタイルやトーナメント/キャッシュに合わせてアクションを自由に書き換え可能
- **JSONエクスポート / インポート**:
  - 作成したマイレンジのバックアップや共有が可能

## GitHub Actionsでの `.ipa` ビルド手順
1. GitHubで新しいリポジトリを作成し、このフォルダの中身をすべてプッシュします（隠しフォルダ `.github` も含めてアップロードしてください）。
2. リポジトリの **Actions** タブを開くと、`Build Unsigned IPA for LiveContainer` ワークフローが自動実行されます。
3. ビルド完了後、**Artifacts** から `PokerRangeAssistant-IPA` をダウンロードし、解凍して `PokerRangeAssistant.ipa` を取得します。
4. iPhoneの **LiveContainer** に `PokerRangeAssistant.ipa` をインポートして起動してください。
