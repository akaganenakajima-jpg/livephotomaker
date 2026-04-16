# E2E テスト セットアップガイド

このドキュメントは Maestro を使った iOS E2E テストの実行環境・フロー一覧・トラブルシューティングを説明します。

---

## プラットフォーム対応と制約（実測確認済み）

| 実行方法 | Windows 10 | Mac | Live Photo 書き込み確認 |
| --- | :---: | :---: | :---: |
| **手動実機確認**（推奨・一次手段） | ✅ | ✅ | ✅ |
| Maestro Cloud（iOS シミュレータ） | ✅※ | ✅※ | ❌ |
| Maestro ローカル（Mac + USB 実機） | ❌ | ✅ | ✅ |
| Maestro ローカル（Windows + USB 実機） | ❌ | — | — |

※ Maestro Cloud は **iOS シミュレータのみ**対応。`.app`（シミュレータビルド）が必要。実機 IPA は不可。

> **結論**: Live Photo 保存の最終確認（LIVE バッジ・長押し再生）は**物理 iPhone でしか確認できません**。  
> Windows ユーザーにとって **「手動実機確認」が唯一の完全な検証手段**です。

---

## 一次手段: 手動実機確認（~2 分）

→ **[docs/quick-check.md](quick-check.md)** を参照してください。

---

## Maestro Cloud の位置づけと制約

### できること（UI フローのみ）

Maestro Cloud は iOS **シミュレータ**上で Maestro フローを実行します。以下の UI フローは動作します。

| フロー | Cloud での動作 |
| --- | --- |
| `01_launch.yaml` — 起動・ホーム画面確認 | ✅ |
| `02_standard_export_testmode.yaml` — テストモード切替・ナビゲーション確認 | ⚠️ 条件付き（後述） |
| `03_check_debug.yaml` — Debug 画面アサーション | ⚠️ 条件付き（後述） |

### できないこと

| 項目 | 理由 |
| --- | --- |
| LIVE バッジの確認 | iOS シミュレータの Photos.app はマーカー認識が制限的 |
| 長押し再生の確認 | Live Photo 再生は実機 Photos フレームワークに依存 |
| Live Photos アルバム所属確認 | 上記と同じ理由 |
| `.ipa` ファイルの使用 | Maestro Cloud は `.app`（シミュレータビルド）のみ受け付ける |

### Flow 02tm の制約（テストモード）

テストモードは `MediaLibrary.getAssetsAsync` でライブラリから最新動画を取得します。  
Maestro Cloud のシミュレータは**写真ライブラリが空の状態**で起動するため、動画が見つからず `import.test_mode_no_video` エラーになります。

**回避策（将来用）**:
- テスト開始前に写真を挿入するフロー（`copyMedia` 相当）を追加する
- または Maestro Cloud の「シード機能」（メディアプリセット）を使用する（対応状況は Maestro 公式で確認）

### Maestro Cloud を使う場合の前提・手順

> **現時点では `01_launch.yaml` のみが安定して動作します。**

```bash
# 前提: maestro インストール済み・API キー取得済み
# API キー取得: https://developers.maestro.io/api/key

# シミュレータビルド (.app) の作成
# EAS Build でシミュレータプロファイルを使う場合:
npx eas build --profile dev-sim --platform ios
# ダウンロードした .app を解凍して使用

# Maestro Cloud 実行（起動確認のみ）
maestro cloud \
  --api-key <YOUR_MAESTRO_CLOUD_API_KEY> \
  --app-file path/to/App.app \
  e2e/flows/01_launch.yaml
```

---

## Maestro フロー資産

YAML フローは将来の Mac + USB ローカル実行 / Maestro Cloud 活用に向けて維持しています。

### フロー一覧

| ファイル | 内容 | 物理実機 | Cloud シミュレータ |
| --- | --- | :---: | :---: |
| `e2e/flows/01_launch.yaml` | アプリ起動・ホーム画面表示確認 | ✅ | ✅ |
| `e2e/flows/02_standard_export_testmode.yaml` | テストモード：ピッカーなし標準書き出し | ✅ | ⚠️ |
| `e2e/flows/02_standard_export.yaml` | 通常：iOS ピッカーを使った書き出し（互換用） | ✅ | ❌ |
| `e2e/flows/03_check_debug.yaml` | Debug 画面で status=ok・各 ID を確認 | ✅ | ⚠️ |

### Maestro が保証する内容（Mac + 物理実機での `02_standard_export_testmode.yaml` 完走時）

| # | アサート | 根拠 |
| --- | --- | --- |
| A | アプリが起動し、ホーム画面が表示された | `home-screen` visible |
| B | テストモードが ON になった | `home-test-mode-banner` visible |
| C | ローカル動画を取得してトリム画面へ遷移した | `trim-screen` visible |
| D | 書き出しパイプラインが開始された | `export-progress-loading` visible |
| E | Swift が `contentIdentifier` UUID を生成してタグ付けした | `success-content-identifier` が `—` 以外 |
| F | `PHAssetCreationRequest` が `localIdentifier` を返した | `success-local-identifier` が `—` 以外 |
| G | 成功画面に遷移した（エラーなし） | `success-screen` visible |

### 手動確認が必要な項目（いかなる自動化でも不可）

| 項目 | 理由 |
| --- | --- |
| LIVE バッジの目視 | Photos フレームワーク内部の認識状態は JS/Maestro から読めない |
| 長押し再生 | OS の Live Photo 再生エンジンの動作 |
| Live Photos アルバム所属 | PHAsset 認識の完全性はメタデータバイナリを要確認 |

---

## Maestro のインストール

### Java 11 以上（Maestro の依存）

```bash
# macOS (Homebrew)
brew install openjdk@21

# Windows (winget・将来用)
winget install Microsoft.OpenJDK.21
# JAVA_HOME と PATH の設定も必要
```

### Maestro インストール

```bash
# macOS / Linux
curl -Ls "https://get.maestro.mobile.dev" | bash

# Windows (PowerShell・将来用)
iex "& { $(iwr 'https://get.maestro.mobile.dev') }"

# 確認
maestro --version
```

---

## Mac ローカル実行（USB 接続）— 完全検証が可能

Mac + USB 接続 iPhone がある場合の手順です。全 Maestro フローを完走できます。

### 前提

- Development Build が iPhone にインストール済み
- Metro サーバ起動: `npm run start:dev-client`
- iPhone を USB で Mac に接続し「このコンピュータを信頼」済み
- 写真ライブラリにローカル保存済みの動画が 1 本以上ある

### フロー実行

```bash
# デバイス確認
maestro list-devices
# 例: iPhone (00008120-001234567890) — iOS 17.4 — USB

# 推奨順序（テストモード使用）
maestro test e2e/flows/01_launch.yaml
maestro test e2e/flows/02_standard_export_testmode.yaml
maestro test e2e/flows/03_check_debug.yaml

# 連続実行
maestro test \
  e2e/flows/01_launch.yaml \
  e2e/flows/02_standard_export_testmode.yaml \
  e2e/flows/03_check_debug.yaml

# デバッグ実行（詳細ログ）
maestro test e2e/flows/02_standard_export_testmode.yaml \
  --debug-output ./maestro-debug

# インタラクティブモード（フロー作成・調査用）
maestro studio   # → http://localhost:9999
```

---

## テストモードの仕組み

**テストモード**は `__DEV__ === true`（Development Build）限定の機能です。  
ホーム画面下部の **「テストモード」スイッチ** を ON にすると、iOS フォトピッカーを起動せず、`MediaLibrary.getAssetsAsync` で最新動画を直接取得してトリム画面へ遷移します。

```
[通常モード] 動画を選ぶ → iOS フォトピッカーモーダル → 手動で動画を選択
[テストモード] 動画を選ぶ → MediaLibrary.getAssetsAsync() → /trim へ直接遷移
```

### Maestro から操作する場合

```yaml
- tapOn:
    id: home-test-mode-toggle   # スイッチを ON
- assertVisible:
    id: home-test-mode-banner   # バナー確認 = ON になった証明
```

### 前提条件と制限

- Development Build でのみ動作（Production では `isTestMode` は常に `false`）
- 写真ライブラリの読み取り権限が必要
- **ローカル保存済みの動画が 1 本以上必要**（`shouldDownloadFromNetwork: false` により iCloud のみの動画はスキップ）
- 書き出し品質の選択は通常通り export-options 画面で行う

---

## LIVE バッジが出ない場合の原因候補

`localIdentifier` が取得できているのに Photos.app で LIVE バッジが出ない場合、4 条件のいずれかが欠落しています。

### Metro ログで確認する 4 行

| 条件 | ログ行 |
| --- | --- |
| A: JPEG に `still-image-time` メタデータ | `[ExpoLivePhotoExporter] tagged still written -> ...` |
| B: MOV に `contentIdentifier` メタデータ | `[ExpoLivePhotoExporter] tagged movie written -> ...` |
| C: JPEG と MOV の UUID が一致 | Debug 画面の `contentIdentifier` と `assigned contentIdentifier=<UUID>` を照合 |
| D: `PHAssetCreationRequest` に JPEG + MOV 両方 addResource | A・B の両行が `asset created` の直前に出ているか確認 |

### 優先切り分け手順

```
① Metro ログに 4 行すべて出ているか？
   → いずれか欠落 → Swift コードの該当工程を調査

② contentIdentifier が Debug 画面と Metro ログで一致しているか？
   → 不一致 → UUID の生成タイミングまたはタグ付けの実装を確認

③ 入力動画が 0.5 秒以上か？

④ iCloud 同期の遅延ではないか？（Wi-Fi オフ → Photos.app 再起動）

⑤ HEIC 入力で MakerApple 辞書が剥がれていないか？（JPEG に変換して再試行）
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| `maestro list-devices` に iOS デバイスが出ない（Windows） | XCTest Runner は macOS 専用 | Maestro Cloud（`01_launch.yaml` のみ）か Mac を使用 |
| `maestro list-devices` に iOS デバイスが出ない（Mac） | USB 信頼が未完了 | iPhone のロックを外して再接続 |
| `assertVisible` がタイムアウト | Metro に未接続 | `npm run start:dev-client` を確認し、アプリ内でサーバを選択 |
| Flow 02tm でトリム画面に進まない | iCloud 専用動画しかない | iPhone に動画を直接保存してから再実行 |
| Flow 02tm が Cloud で失敗する | シミュレータのライブラリが空 | `01_launch.yaml` のみ Cloud で実行。他は実機で手動確認 |
| `home-test-mode-toggle` が見つからない | Production Build を使用中 | Development Build でのみ動作 |
| Flow 03 で `debug-status-value` が `idle` | Flow 02/02tm を先に実行していない | 書き出しフロー → Flow 03 の順で実行 |

---

## 参照

- [Maestro ドキュメント](https://maestro.mobile.dev/docs)
- [Maestro Cloud](https://cloud.maestro.mobile.dev/) / [API Key 取得](https://developers.maestro.io/api/key)
- [`docs/quick-check.md`](quick-check.md) — 最短手動確認手順（一次手段）
- [`e2e/flows/`](../e2e/flows/) — テストフロー YAML
