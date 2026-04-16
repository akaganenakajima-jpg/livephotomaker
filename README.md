# Video to Live Photo (Expo + Windows 10)

動画を Live Photo へ変換し、iPhone の写真ライブラリへ保存する iOS アプリです。
保存後は iPhone 標準の「設定」App からロック画面の壁紙として選ぶ手順を**アプリ内で案内**します。

> **重要**: 本アプリは壁紙の自動設定を行いません。壁紙設定そのものは iPhone 標準機能でユーザー自身が行います。本アプリの責務は「Live Photo を作成して写真ライブラリへ保存する」ことです。

本プロジェクトは **Windows 10 を主開発環境** とし、**React Native + Expo + EAS Build/Submit** で iPhone 向けに配布します。Mac は不要です。

---

## 確定済みの識別子

以下は確定値です。リポジトリ全体でこの値に揃えます。これ以外の文字列（旧名称 / サンプル ID）が紛れ込んだら `npm run check:bundle` / `npm run check:placeholders` でエラーになります。

| 種類 | 値 |
| --- | --- |
| App Display Name | `Video to Live Photo` |
| Expo `slug` | `video-to-livephoto` |
| iOS Bundle Identifier | `com.gen.videotolivephoto` |
| 非消耗型 IAP Product ID | `com.gen.videotolivephoto.premium.hq_unlock` |

## 未差し替えプレースホルダ一覧（残り）

Bundle ID / Product ID は確定済みなので、**残っているのは以下のユーザー固有の値だけ**です。`.env` と `eas.json` を自分のアカウント情報に差し替えてから EAS Build を回してください。`npm run check:placeholders` は以下の文字列リテラルを grep しているので、漏れがあれば即検出されます。

| プレースホルダ文字列 | 含まれるファイル | 差し替え元 | 差し替えコマンド / 方法 |
| --- | --- | --- | --- |
| `EXPO_PROJECT_ID_PLACEHOLDER` | `app.config.ts` (env 経由) | Expo dashboard の project id | `npx eas init` 実行で `.env` の `EXPO_PUBLIC_EAS_PROJECT_ID` に自動で入る |
| `APPLE_TEAM_ID_PLACEHOLDER` | `eas.json` | Apple Developer ポータル「Membership」| 10 文字の Team ID を直接コピペ |
| `ASC_APP_ID_PLACEHOLDER` | `eas.json` | App Store Connect 「アプリ情報 → Apple ID」 | 数値の App ID を直接コピペ |
| `APPLE_ID_PLACEHOLDER@example.com` | `eas.json` | App Store Connect にログインしている Apple ID | 自分のメールアドレスに置換 |
| `EXPO_PUBLIC_ADMOB_IOS_APP_ID` | `.env` | AdMob コンソール（本番前） | `.env` 内で直接上書き。デフォルトは Google 公式 test ID |
| `EXPO_PUBLIC_ADMOB_IOS_REWARDED_UNIT_ID` | `.env` | AdMob コンソール（本番前） | `.env` 内で直接上書き。デフォルトは Google 公式 test unit |

> `.env.example` にはテスト用の AdMob ID が入っているので、開発中はコピーするだけで動作します。**本番 EAS build 前に必ず実 ID へ差し替え**てください。`npm run check:placeholders` はこれらの文字列が他のファイル (ソース / README 本文など) に漏れていないかも同時に検査します。

### AdMob 設定（プロファイル別の必須値）

`react-native-google-mobile-ads` v13.x は Xcode ビルドフェーズで `app.json` の `react-native-google-mobile-ads.ios_app_id` を読みます。`npm install` 時に `scripts/sync-admob-app-json.js` が環境変数から `app.json` へ自動同期します。

| EAS プロファイル | `EXPO_PUBLIC_ADMOB_IOS_APP_ID` | ガード (`npm run check:admob`) |
| --- | --- | --- |
| `dev-sim` / `development` | 未設定可（Google テスト ID がデフォルト） | PASS |
| `preview` / `production` | **実 AdMob App ID 必須** | テスト ID のままだと FAIL |

本番ビルド時は EAS ダッシュボードの Secrets に `EXPO_PUBLIC_ADMOB_IOS_APP_ID` を設定してください。

---

## 主な機能

- 写真ライブラリから動画を選択
- 必要に応じて短いクリップへトリミング
- キーフレームを 1 枚抽出して静止画を作成
- 短い MOV + 静止画を **Live Photo ペア**として生成
- 写真ライブラリへ保存
- 作成した Live Photo のプレビュー表示
- ロック画面で Live Photo 壁紙を設定するための**標準手順**を案内

## 非対応事項（明示）

- **壁紙の自動設定はサポートしません**（iOS の制約）
- Expo Go だけでは Live Photo 生成の native 部分が動作しません（**Development Build** が必須）
- 一括変換、クラウド連携、編集機能は本バージョンではスコープ外

## 収益化モデル（買い切り + 任意視聴広告）

| プラン | 書き出し画質 | 広告 |
| --- | --- | --- |
| 無料 | 標準画質 | 表示 |
| 広告視聴（任意） | 高画質 **1 回** お試し | 視聴時のみ |
| 買い切り解放 | 高画質 **恒久** 解放 | **非表示** |

- 商品ID: `com.gen.videotolivephoto.premium.hq_unlock`
- 種別: **非消耗型 IAP**（買い切り、再購入不要）
- 買い切り購入後は広告表示を完全に無効化

---

## 技術構成

| レイヤ | 採用技術 |
| --- | --- |
| UI / Navigation | React Native + **Expo Router** |
| 言語 | TypeScript (strict) |
| 状態管理 | Zustand + Context |
| Live Photo 生成 | **Custom Expo Module**（`modules/expo-live-photo-exporter`）。Swift で `AVAssetWriter` + QuickTime metadata + `PHAssetCreationRequest` を実装 |
| 動画処理（JS側） | `expo-av`, `expo-video-thumbnails` |
| 写真ライブラリ | `expo-media-library` |
| 課金 | StoreKit 2（`expo-iap` を lazy require 経由で使用。Development Build で検証） |
| 広告 | `AdsService` で抽象化、実装は `react-native-google-mobile-ads` 等を Development Build に組み込む想定 |
| ビルド/配布 | **EAS Build** / **EAS Submit**（クラウド実行、Mac 不要） |
| 開発環境 | Windows 10 + VS Code + Git Bash / PowerShell |

### Expo Go でできること / Development Build が必要なこと

| 機能 | Expo Go | Development Build |
| --- | --- | --- |
| 画面遷移・入力 UI | ✅ | ✅ |
| 動画選択（expo-image-picker） | ✅ | ✅ |
| キーフレーム抽出（expo-video-thumbnails） | ✅ | ✅ |
| **Live Photo 生成（custom native module）** | ❌ | ✅ |
| **Live Photo 保存（PHAssetCreationRequest）** | ❌ | ✅ |
| 課金（StoreKit 2 / expo-iap） | ❌ | ✅ |
| 広告 SDK | ❌ | ✅ |

日常的な UI/ロジック開発は Expo Go でも進められますが、**Live Photo の実機検証は必ず Development Build** を使ってください（詳しい理由は後述の「Expo Go では不可な理由」セクションを参照）。

---

## Windows 10 でできること / Expo/EAS クラウド側で行うこと

### Windows 10 側で完結するもの
- ソースコード編集（VS Code）
- `npm run lint` / `typecheck` / `test`
- Expo Go による UI レベルのプレビュー
- Git 操作（Git for Windows / GitHub CLI）
- EAS CLI からの build / submit コマンド送信

### Expo/EAS クラウド側で実行されるもの
- Xcode を使った iOS ネイティブビルド（EAS Build）
- TestFlight / App Store への .ipa アップロード（EAS Submit）
- Provisioning Profile / 証明書管理（`eas credentials`）

---

## ユーザー側で事前に準備するもの

以下は**あなた自身のアカウント・情報**として先に用意してください。README で後述する `check-placeholders.ps1` で未設定箇所を検出できます。

- [ ] Expo アカウント（https://expo.dev）
- [ ] Apple Developer Program の有料会員登録
- [ ] App Store Connect でのアプリ登録（Bundle ID: `com.gen.videotolivephoto`）
- [ ] 非消耗型 IAP の商品登録（Product ID: `com.gen.videotolivephoto.premium.hq_unlock`）
- [ ] Apple Team ID（Apple Developer ポータル）
- [ ] ASC App ID（App Store Connect）
- [ ] AdMob アカウントと iOS 用 App ID / Rewarded Unit ID
- [ ] プライバシーポリシーの公開 URL
- [ ] サポート URL とサポート用メールアドレス
- [ ] iPhone 実機
- [ ] iPhone に Expo Go アプリ導入
- [ ] GitHub アカウント

---

## Windows 10 ローカル開発手順

### 1. ツール導入

**Node は Node 20 LTS を必須**とします。Expo SDK 51 / React Native 0.74 系は Node 18 / 20 のみサポートしており、Node 22 / 24 では Metro / EAS CLI / jest-expo が未知の挙動を起こします（Node 24 では `npm install` 時点で peer 解決が壊れる報告あり）。

`.nvmrc` に `20.11.1` を固定しています。`engines.node` も `>=20.11.0 <21` で同期済みなので、Node 21 以降では `npm install` が `EBADENGINE` 警告を出します（恒久対策として意図的にそうしています）。

```powershell
# 推奨: winget でまとめて導入
winget install OpenJS.NodeJS.LTS     # Node 20 LTS 系が入る
winget install Git.Git
winget install Microsoft.VisualStudioCode
winget install GitHub.cli

# Node / npm の確認（v20.x が出ていることを必ず確認）
node --version
npm --version
```

すでに Node 22 / 24 が入っていて切り替えたい場合は `nvm-windows`（https://github.com/coreybutler/nvm-windows）を使うのが最短です:

```powershell
# nvm-windows を入れた後（winget install CoreyButler.NVMforWindows）
nvm install 20.11.1
nvm use 20.11.1
node --version   # v20.11.1 が出ること
```

```powershell
# Expo CLI と EAS CLI（グローバル導入不要。npx で呼ぶ推奨）
npx expo --version
npx eas --version
```

補助スクリプト `scripts/windows/setup-dev.ps1` を実行すると一括チェックできます。

### 2. リポジトリ取得と依存インストール

```powershell
git clone https://github.com/<YOUR_HANDLE>/video-to-livephoto.git
cd video-to-livephoto

npm install
Copy-Item .env.example .env
```

### 3. Expo と EAS へログイン

```powershell
npx expo login
npx eas login
```

### 4. EAS プロジェクト初期化（初回のみ）

```powershell
npx eas init
# app.config.ts の EXPO_PROJECT_ID が書き変わります
npx eas build:configure
```

### 5. 開発サーバ起動と iPhone 実機確認

```powershell
# Expo Go で UI レベル確認（Live Photo 機能は動きません）
npx expo start

# Development Build を配信するためのサーバ起動
npx expo start --dev-client
```

### 6. iOS Development Build を EAS にリクエスト（Live Photo 機能を実機で試す）

```powershell
npx eas build --profile development --platform ios
# 完了すると QR/URL が表示される → iPhone で開いてインストール
```

### 7. 本番ビルドと提出

```powershell
# Production ビルド
npx eas build --profile production --platform ios

# App Store Connect へ提出
npx eas submit --platform ios
```

---

## Mac 不要でどこまで確認できるか

本プロジェクトは **Mac / Xcode / Console.app / Instruments をいっさい使わずに実機検証を完結できる**ように設計されています。

| 確認したいこと | Windows で可能？ | 方法 |
| --- | --- | --- |
| ソースコード編集 / 型チェック / ユニットテスト | ✅ | VS Code + `npm run typecheck` / `test` |
| Expo Go での UI プレビュー | ✅ | `npx expo start` + iPhone の Expo Go |
| iOS Development Build の作成 | ✅ | `npx eas build --profile development --platform ios`（クラウド実行） |
| Development Build のインストール | ✅ | EAS 完了画面の QR を iPhone で開いて ad-hoc インストール |
| Metro 経由の JS デバッグログ | ✅ | Metro ターミナル（`npx expo start --dev-client`） |
| **native 側の localIdentifier / contentIdentifier / エラーコード確認** | ✅ | **アプリ内 Debug 画面（設定 → デバッグ情報を開く）** |
| ネイティブビルドログ確認 | ✅ | `npx eas build:view <id>` または EAS web dashboard |
| Live Photo ペア判定 | ✅ | iPhone の Photos アプリで LIVE バッジと長押し再生を目視 |
| 課金（Sandbox） | ✅ | App Store Connect で Sandbox テスター作成 → iPhone 設定で有効化 |
| 広告（Test Unit） | ✅ | `.env` の AdMob Test ID で検証 |
| TestFlight / 本番提出 | ✅ | `npx eas submit --platform ios`（クラウド実行） |

**使わないもの**: Xcode、Devices & Simulators、Console.app、`xcrun simctl`、`instruments`、macOS Preview.app などの Mac 専用ツール。代替が必要な情報は全てアプリ内 Debug 画面 / Metro / EAS ログから取得できます。

---

## Windows 10 から iPhone 実機で Live Photo を検証する手順

ネイティブ実装が変更された場合、**必ず Development Build を作り直して**実機で確認します。シミュレータでは `PHAssetCreationRequest` の Live Photo 経路がそもそも限定的なので、確定判定にはなりません。

### 最短 10 ステップ（コピペ可）

1. ローカルで `git status` がクリーンなことを確認。ネイティブ変更があれば `git add -A && git commit -m "..." && git push` で Push する
2. Windows PowerShell で `npx eas build --profile development --platform ios --clear-cache` を実行
3. EAS web dashboard でビルド進捗を確認（失敗したら `npx eas build:view <id>` でログを落として原因追跡）
4. 完了通知の QR を iPhone のカメラで開き、Ad-hoc 配信ページから「インストール」
5. iPhone の「設定 → 一般 → VPN とデバイス管理」で開発者プロファイルを信頼（初回のみ）
6. PowerShell で `npx expo start --dev-client` を起動。Windows Defender のダイアログが出たら「プライベートネットワークを許可」
7. iPhone で Development Build を起動 → 一覧に出る Metro サーバをタップ
8. アプリ内で動画選択 → トリム → Live Photo 作成 → Photos へ保存完了まで進める
9. iPhone の Photos アプリで LIVE バッジ確認 + 長押し再生できることを目視確認
10. アプリに戻り **設定 → 「デバッグ情報を開く」** で `lastSaveResult.localIdentifier` / `contentIdentifier` が入っていること、`lastError` が `null` であることを確認

この 10 ステップのどれかで失敗したら、後述の「Photos アプリで長押し再生されない場合の切り分け手順」へ進みます。`ERR_` コード一覧とそれぞれの最初に疑うべき原因は [`docs/error-codes.md`](docs/error-codes.md) にまとめてあります。Debug 画面で表示されたコードをそのまま grep してください。

### 実機テスト直前チェックリスト（10 項目）

iPhone を手に取る直前に確認します。**すべて Windows 10 だけで完結**します。

1. `npm run preflight` が緑で通る（lint / typecheck / test / marketing / iap / bundle / placeholders）
2. `.env` が作成済みで `EXPO_PUBLIC_EAS_PROJECT_ID` が入っている（`npx eas init` 直後ならOK）
3. `eas.json` の `appleId` / `ascAppId` / `appleTeamId` の `*_PLACEHOLDER` が実値に置き換わっている（本番 submit のみ必要。development build は未置換でも可）
4. `app.config.ts` の bundleIdentifier が `com.gen.videotolivephoto` のままであることを確認（誤変更検出は `check:bundle`）
5. `modules/expo-live-photo-exporter/` に差分がある場合 → **Development Build を再作成**する必要がある旨を認識している
6. `npx eas build --profile development --platform ios --clear-cache` でビルド投入済み、EAS ダッシュボードで成功
7. Ad-hoc インストール用 QR を iPhone で読み取ってインストール済み、初回は「設定 → 一般 → VPN とデバイス管理」で開発者プロファイルを信頼済み
8. Windows の Metro を `npx expo start --dev-client` で起動済み、Windows Defender のプライベートネットワーク許可が済んでいる
9. iPhone と Windows が同一 LAN（または USB tethering）で繋がっており、Metro 一覧に該当マシンが出る
10. アプリ起動後、設定画面から「デバッグ情報を開く」が見えている（`__DEV__` ガードで production では隠れるのが正常）

### Windows で使えるログ確認手段（Xcode の代替）

Xcode の Devices & Simulators は Mac 専用です。本プロジェクトでは以下の 3 つで同等以上の情報を得られます。

#### 1. Metro ログ（JS 側 / native モジュールの diagnostics）

`npx expo start --dev-client` を動かしている PowerShell ターミナルに、JS 側からの `logger.debug` / `logger.warn` が全部流れます。Live Photo 作成時に出る重要な行:

- `[debug] NativeLivePhotoBridge.saveLivePhoto -> { movUri: '...', stillUri: '...' }`
- `[debug] NativeLivePhotoBridge.saveLivePhoto <- { localIdentifier: '...', contentIdentifier: '<UUID>' }`
- 失敗時: `[warn] NativeLivePhotoBridge.saveLivePhoto rejected ERR_MOVIE_FINISH_WRITING_FAILED <message>`

Windows ターミナルがカラー表示に対応していない場合は、PowerShell を VS Code のターミナル内で起動するとカラーでハイライトされ読みやすくなります。

#### 2. EAS Build ログ（ネイティブビルド失敗の追跡）

ネイティブビルドが通らない / インストール後に即クラッシュする場合は EAS Build のログを Windows から直接取れます。

```powershell
# 直近ビルドの一覧
npx eas build:list --platform ios --limit 5

# 1 ビルド分のサマリ + ログ URL 取得
npx eas build:view <BUILD_ID>

# ブラウザで web dashboard を開く（Windows 既定ブラウザが起動）
start https://expo.dev/accounts/<YOUR_ACCOUNT>/projects/video-to-livephoto/builds
```

web dashboard では Swift のコンパイルエラー、config plugin の警告、`PBXResourcesBuildPhase` 失敗など Xcode が出すエラーがそのまま読めます。

#### 3. アプリ内 Debug 画面（実行時の native 由来データ確認）

本プロジェクトは **Mac なしで native 由来の ID とエラーコードを読むため**、アプリ内に Debug 画面を持っています。Settings 画面の **「デバッグ情報を開く」** から到達できます（`__DEV__` ガードのため production ビルドでは表示されません）。

Debug 画面に表示されるもの:

- **Last Save (success)** — 直近成功時の `localIdentifier` と `contentIdentifier`（長押しで選択 → コピー可能）
- **Last Error** — 直近失敗時の `code`（例: `ERR_MOVIE_FINISH_WRITING_FAILED`）と `message`
- **Log Buffer** — `utils/logger` の in-memory ring buffer（直近 200 行、最新順に 50 行描画）
- **Copyable Blob** — 上記全部を JSON 文字列でまとめた塊（長押しで選択 → iPhone 標準の「コピー」→ iMessage / Notes / メール経由で Windows PC に転送）

Xcode Devices & Simulators で取っていた情報はすべてこの画面に集約されるので、Mac にログインする必要はありません。

### Tips

- シミュレータで試す場合でも保存自体は成功することがありますが、**Live 判定**は実機でないと当てになりません。審査前の最終確認は必ず実機で行ってください。
- Photos への保存が 1 枚目だけ "LIVE ではない" で、2 枚目以降は成功する場合、Photos への権限ダイアログが 1 枚目の最中に出て `addOnly` の認可が間に合わなかった可能性があります。アプリを再起動して試してください。

---

## Photos アプリで長押し再生されない場合の切り分け手順

Photos で保存はされているが Live として扱われないときは、以下の順で切り分けます。ネイティブ側の Swift 実装は 4 条件（A/B/C/D）のうち**どれが欠けても同じ症状**になるため、系統立てて潰すのが早いです。

### 条件チェックリスト（iOS 側）

| 条件 | 何をしているか | 失敗時の挙動 |
| --- | --- | --- |
| (A) JPEG の MakerApple `17` に UUID 文字列 | `writeTaggedStill` 内で CGImageDestination 経由で書き込み | 写真だけ保存され、動画が Photos 側で紐付かない |
| (B) MOV の top-level `mdta/com.apple.quicktime.content.identifier` | `writer.metadata` に設定 | 写真 + 独立した動画 2 件になる |
| (C) MOV の metadata track `mdta/com.apple.quicktime.still-image-time` | `AVAssetWriterInputMetadataAdaptor` で 1 サンプルだけ追加 | Live バッジは出るが長押しで動かない |
| (D) 同一 `PHAssetCreationRequest` に `.photo` と `.pairedVideo` を add | `createLivePhotoAsset` 内で 1 リクエストに両リソース追加 | 写真 + 動画の独立 2 資産として保存される |

### 切り分け手順

1. **最新の Development Build でコードが反映されているか**
   - Swift を直したのに挙動が変わらない場合、Development Build を作り直していない可能性が最も高い
   - `git log --oneline modules/expo-live-photo-exporter/ios/` と `npx eas build:view <BUILD_ID>` の commit SHA を Windows ターミナルで直接突き合わせる（Mac / Xcode 不要）
2. **アプリ内 Debug 画面で `lastSaveResult` が返っているか**
   - `Settings → デバッグ情報を開く` で `localIdentifier` と `contentIdentifier` の両方を確認
   - 両方揃っているのに Live にならない → ネイティブ側の条件 (A)(B)(C)(D) のどれかが足りていない
   - どちらかが空 / `lastError` に `ERR_...` コードが入っている → 次のステップへ
3. **Debug 画面の `lastError.code` で工程を特定**
   - `ERR_STILL_*` → 条件 (A) の JPEG タグ付けで失敗
   - `ERR_MOVIE_READER_CREATE_FAILED` / `ERR_MOVIE_WRITER_CREATE_FAILED` → reader/writer 構築失敗（入力動画の形式が想定外）
   - `ERR_MOVIE_VIDEO_TRACK_MISSING` → 入力 MOV にビデオトラックが無い（HEVC コンテナ破損など）
   - `ERR_MOVIE_FINISH_WRITING_FAILED` → metadata track か passthrough のどこかで失敗
   - `ERR_ASSET_CREATION_FAILED` → 条件 (D) の PHAssetCreationRequest が失敗（権限または資産追加の順番）
4. **Metro ターミナルで併せて確認**
   - `NativeLivePhotoBridge.saveLivePhoto ->` / `<-` / `rejected` のログを目視で追う
   - Debug 画面の内容と一致していること（ズレていたら JS 側と store の同期が壊れている疑い）
5. **Photos アプリで長押し再生されない / Live バッジが出ない場合**
   - バッジ無し → 条件 (A) か (D) が欠けている（JPEG 側 or PHAsset 側）
   - バッジ有り / 動かない → 条件 (B) か (C) が欠けている（MOV 側のメタデータ）
6. **`iPhone 上で pair 判定を別アプリから確認**
   - 「ショートカット」App の `写真を取得 → 詳細を表示` で、動画側の情報が出るかを確認（Mac 不要）
   - `ファイル` App に保存し直して、JPEG / MOV のメタデータ詳細を表示（EXIF viewer 系のショートカットが使える）
7. **iCloud 同期による遅延を除外**
   - iCloud 写真 On のとき、保存直後は Live 再生にならず数秒待つと動き出すことがあります。**アプリ切り替え → 戻る**で再確認してください

### ありがちな失敗パターン

- **JPEG 元素材が HEIC で Photos に保存されているケース**: `writeTaggedStill` は source UTI をそのまま使うので HEIC でも理論上通るが、一部端末で MakerApple dict が剥がれることが報告されている。疑わしい場合は事前に JPEG へ変換した still を渡す。
- **トリムした MOV が短すぎ**: `still-image-time` 区間は 1/30 秒に固定。動画本体が 1 フレームしか無いとサンプル配置が成立せず Live 判定にならない。**最低でも 0.5 秒以上のクリップ**を渡すこと。
- **`shouldMoveFile = true` で失敗**: 一時ディレクトリの権限が Photos 側から読めないときに `ERR_ASSET_CREATION_FAILED` になる。Development Build では基本的に問題は出ないが、`NSTemporaryDirectory()` 以外に書き出すように改造すると再現することがある。

---

## Expo Go では不可、Development Build 必須である理由

Expo Go は「**Expo が事前ビルドした固定バイナリ**」です。ここに後から任意のネイティブコードを注入することはできません。具体的には次の 3 つが理由になります。

1. **Custom Expo Module がリンクされていない**
   - 本アプリの Live Photo 生成は `modules/expo-live-photo-exporter/ios/ExpoLivePhotoExporterModule.swift` の `AVAssetReader/Writer` + `PHAssetCreationRequest` に依存します。
   - Expo Go にはこの Swift モジュールが含まれないため、JS 側の `require('../../modules/expo-live-photo-exporter')` が最終的に `requireNativeModule('ExpoLivePhotoExporter')` で例外を投げ、`NativeLivePhotoBridge` が `nativeModuleUnavailable` を返します。
2. **StoreKit 2 の課金 API が使えない**
   - `expo-iap` は Development Build でしか動作しません。Expo Go からは Apple ID でのサンドボックス購入フローに入れません。
3. **広告 SDK (`react-native-google-mobile-ads`) も同様**
   - ネイティブ SDK をリンクするため Expo Go には含まれません。

つまり UI の配置や画面遷移は Expo Go で触れますが、**本アプリの「Live Photo 作成・保存・課金・広告」というコアバリューそのものは一切動かない**状態です。実機での最終確認は必ず Development Build で行ってください。

---

## ローカルチェック

全チェックをひとまとめに実行するには `npm run preflight` を使います。内部的に以下を順次実行し、1 つでも失敗すると終了コード非 0 で止まります:

```powershell
npm run preflight         # = check:all
# 個別にも実行可
npm run lint
npm run typecheck
npm run test
npm run check:marketing   # 禁止表現チェック (CLAUDE.md §3 の禁止語リストを grep)
npm run check:iap         # Product ID 整合性チェック
npm run check:bundle      # Bundle Identifier 整合性チェック (com.gen.videotolivephoto)
npm run check:placeholders # *_PLACEHOLDER 文字列の許可外漏れ検出
npm run check:all         # 上記すべて
```

PowerShell 版のラッパーも用意しています:

```powershell
scripts\checks\lint.ps1
scripts\checks\typecheck.ps1
scripts\checks\test.ps1
scripts\checks\check-marketing-copy.ps1
scripts\checks\check-iap-identifiers.ps1
scripts\windows\check-placeholders.ps1
```

bash 版（Git Bash / WSL）は `scripts/hooks/` 配下にあり、npm scripts はそちらを呼びます。PowerShell が使えない環境でも `npm run preflight` が通ります。

---

## 実機検証 / E2E テスト

ユニットテスト（Jest）でカバーできない「画面遷移・ネイティブ保存・Photos ライブラリ書き込み」の検証方法です。

### プラットフォーム対応

| 方法 | Windows 10 | Mac | Live Photo 最終確認 |
| --- | :---: | :---: | :---: |
| **手動実機確認**（現在の一次手段） | ✅ | ✅ | ✅ |
| Maestro Cloud（iOS シミュレータ） | ✅※ | ✅※ | ❌ |
| Maestro ローカル（Mac + USB 実機） | ❌ | ✅ | ✅ |
| Maestro ローカル（Windows + USB） | ❌ | — | — |

※ Maestro Cloud は **iOS シミュレータのみ**。`.app`（シミュレータビルド）が必要。Live Photo 書き込み確認は不可。

### 手動実機確認（一次手段・唯一の完全な検証手段）

Development Build + iPhone があれば **今すぐ**始められます。  
Live Photo の LIVE バッジ・長押し再生は自動化では確認できないため、**常に手動確認が必要**です。

→ **[docs/quick-check.md](docs/quick-check.md)** に最短手順（~2 分）をまとめています。

### テストモードについて

ホーム画面下部の **「テストモード」スイッチ**（Development Build のみ表示）を ON にすると、iOS フォトピッカーを起動せず写真ライブラリの最新動画を直接読み込みます。

```
[テストモード] 動画を選ぶ → MediaLibrary.getAssetsAsync() → /trim へ直接遷移
```

### Maestro フロー一覧（将来の自動化資産）

| ファイル | 内容 | 実機 | Cloud |
| --- | --- | :---: | :---: |
| `e2e/flows/01_launch.yaml` | アプリ起動・ホーム画面表示確認 | ✅ | ✅ |
| `e2e/flows/02_standard_export_testmode.yaml` | テストモード：標準書き出し→成功画面 | ✅ | ⚠️ |
| `e2e/flows/02_standard_export.yaml` | iOS ピッカーを使った書き出し（互換用） | ✅ | ❌ |
| `e2e/flows/03_check_debug.yaml` | Debug 画面で status=ok・各 ID を確認 | ✅ | ⚠️ |

詳細（Maestro Cloud の制約・Mac ローカル手順・LIVE バッジ不出の切り分け）→ [`docs/e2e-setup.md`](docs/e2e-setup.md)

---

## 依存関係に関する注意事項

このリポジトリは **Expo SDK 51 / React Native 0.74** を前提にしています。`npx expo install --fix` を**必ず経由**して依存の整合性を取ってください。React Native と Expo のマイナーバージョンがずれると、EAS Build 時だけ落ちる地雷を踏みます。

### 主要依存の互換性メモ

| パッケージ | 指定 | 注意点 |
| --- | --- | --- |
| `expo` | `~51.0.0` | 現行安定線。SDK 52/53 へ上げるときは必ず公式 upgrade guide に従う |
| `expo-router` | `~3.5.0` | SDK 51 の組み合わせ。typed routes 実験機能を使用中 |
| `react-native` | `0.74.0` | SDK 51 の固定値。単独 bump 禁止（`expo install` が整合を取る） |
| `expo-av` | `~14.0.0` | SDK 52 以降は `expo-video` へ段階移行予定。現時点ではまだ `expo-av` で問題なし |
| `expo-video-thumbnails` | `~8.0.0` | SDK 51 対応版 |
| `expo-media-library` | `~16.0.0` | `.addOnly` 権限のみ |
| `expo-iap` | **採用**（SDK 51 対応版） | 詳細は下記「ライブラリ採用判断」 |
| `react-native-google-mobile-ads` | **採用**（`^13.x`、config plugin 同梱） | 詳細は下記「ライブラリ採用判断」 |

### 依存 bump の手順（Windows 10）

```powershell
# SDK の推奨バージョンに全パッケージを合わせる
npx expo install --fix

# lock ファイル再生成（package-lock.json）
npm install

# 通す
npm run typecheck
npm run test
```

### `npm install` が ERESOLVE で失敗する場合

症状: `npm install` 実行時に `ERESOLVE unable to resolve dependency tree`、`react@18.2.0` と `react-test-renderer@19.x` の peer 競合が表示される。

原因: `react-test-renderer` を devDependencies に明示していないと、npm が最新 (19.x) を引いて React 18 と衝突する。本リポジトリは `react-test-renderer: 18.2.0` を pin 済みなので、**基本的にはこのエラーは出ません**。もし出る場合は以下の順で対処:

```powershell
# 1. Node が 20.x であることを確認（Node 22 / 24 では npm の peer 解決が変な動きをする）
node --version

# 2. キャッシュと lock をクリアしてから再インストール
rm -r node_modules, package-lock.json -ErrorAction SilentlyContinue
npm cache verify
npm install

# 3. それでも通らない場合のみ一時回避（恒久解ではない）
npm install --legacy-peer-deps
```

> `--legacy-peer-deps` を使った場合は、**その場で`package.json` の `react-test-renderer` が 18.2.0 に pin されたままか** を必ず確認してください。そこがズレていなければフラグなしで次回も通ります。`@testing-library/jest-native` は 12.4 以降の `@testing-library/react-native` に統合済みで本リポジトリから削除済みなので、それを手で入れ直さないこと。

### ライブラリ採用判断

SDK 51 時点での推奨。両方とも Expo Modules + config plugin 対応で、**EAS Build のみで iOS ビルド可能**。Mac も `expo prebuild` のローカル実行も不要。

#### 課金 (IAP) — `expo-iap`

| 候補 | 判定 | 根拠 |
| --- | --- | --- |
| **`expo-iap`** | **採用** | Expo Modules API ネイティブ。config plugin 同梱で EAS Build だけで iOS 組める。StoreKit 2 対応。`expo-in-app-purchases` の後継として実質のデファクト。SDK 51 対応版あり。 |
| `expo-in-app-purchases` | 却下 | Expo が公式に保守を止めた（SDK 49 以降非推奨）。StoreKit 2 API に追随しない。 |
| `react-native-iap` | 却下 | 機能的には最強だが config plugin がなく、Expo ワークフロー下では `expo prebuild` が実質必須。CLAUDE.md §4「`expo prebuild` をむやみに呼ばない」と矛盾。 |

採用コマンド:

```powershell
npx expo install expo-iap
```

統合方針: `src/services/PurchaseService.ts` 内で `expo-iap` を **lazy require** で読み込み、Expo Go / Jest 環境では例外を握り潰してモックを返す。`src/constants/products.ts` の `ProductIdentifier.PremiumHQUnlock` を必ず経由する。

#### 広告 — `react-native-google-mobile-ads`

| 候補 | 判定 | 根拠 |
| --- | --- | --- |
| **`react-native-google-mobile-ads`** (Invertase) | **採用** | 広告 SDK として事実上のデファクト。config plugin 同梱で EAS Build のみで iOS 対応。GADApplicationIdentifier / SKAdNetworkItems を Info.plist へ自動書き込み。 |
| `expo-ads-admob` | 却下 | Expo が SDK 46 で deprecate → 削除済み。現存しない。 |
| `react-native-admob-native-ads` | 却下 | メンテが鈍化。Expo Modules 非対応。 |

採用コマンド:

```powershell
npx expo install react-native-google-mobile-ads
```

統合方針:
- `src/services/AdsService.ts` に **lazy require** で閉じ込め、SDK import を他ファイルに漏らさない
- `app.config.ts` の `plugins` に config plugin を追加し、`.env` の `EXPO_PUBLIC_ADMOB_IOS_APP_ID` を `ios.googleMobileAdsAppId` として渡す
- Rewarded 広告のみ使用。進捗画面を中断しない
- Test Unit ID は `.env.example` に記載済み (Google 提供の安全なテスト ID)

#### リスクと退避路

- SDK 52 以降に上げると `expo-iap` / `react-native-google-mobile-ads` のメジャー版も併せて上げる必要がある。`npx expo install --fix` を最初に流す。
- どちらか片方が将来壊れても、それぞれ `PurchaseService.ts` / `AdsService.ts` 内で閉じているので差し替え先を 1 ファイルで切り替えられる
- 最終退避路として `react-native-iap` + prebuild がある。その場合は PR で方針逸脱を明示する

---

## GitHub 初期化（Windows Git Bash 例）

```bash
cd "/c/Users/<YOUR_NAME>/Desktop/intoLivePhoto"
git init -b main
git add .
git commit -m "chore: bootstrap expo live photo project"

# GitHub CLI で private リポジトリを作成
gh repo create video-to-livephoto --private --source=. --remote=origin --push
```

PowerShell 用の補助スクリプト: `scripts\windows\git-bootstrap.ps1`

**ブランチ戦略**:
- `main` — 常に安定
- `feature/bootstrap-expo-project`
- `feature/livephoto-native-module`
- `feature/iap-premium-unlock`
- `feature/rewarded-hq-trial`
- `feature/appstore-assets`

---

## 課金と広告の仕様概要

- 課金は `src/services/PurchaseService.ts` に抽象化。`ExportEntitlement` ストアを通じて画面側で判定
- 広告は `src/services/AdsService.ts` に抽象化。SDK 依存はこのファイル内のみ
- ユーザーが明示的にタップした場合のみ広告を表示
- 広告読み込み失敗時は標準画質導線へフォールバック
- 課金済みユーザーには広告を完全に非表示

## App Store 公開時の注意点

- **禁止表現**を README、UI、App Store 説明文、審査メモ、スクリーンショットのいずれにも使わない
- 買い切り課金であることを明確に伝える
- `docs/appstore-copy-ja.md` / `docs/appstore-copy-en.md` に審査用文言草案
- プライバシー文言は `docs/privacy-policy-ja.md`
- 実機検証の最終チェックリストは `docs/実機検証チェックリスト.md`

---

## ディレクトリ構成（主要部分）

```
app/                  Expo Router screens
src/services/         Protocol-shaped service layer
src/store/            Zustand stores
src/types/            Shared type definitions
src/i18n/             Localized strings
modules/expo-live-photo-exporter/
                      Custom native iOS module + config plugin
__tests__/            Jest unit tests
scripts/windows/      Windows-only setup helpers (PowerShell)
scripts/eas/          EAS CLI wrappers (PowerShell)
scripts/checks/       Lint/typecheck/test wrappers (PowerShell)
docs/                 App Store copy drafts, privacy policy, 実機検証チェックリスト
_legacy-swift/        Archived Swift/SwiftUI scaffold (not used)
```

## ライセンス

MIT License — 詳細は `LICENSE` を参照
