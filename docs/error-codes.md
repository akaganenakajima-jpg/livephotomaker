# Native エラーコード早見表 — Video to Live Photo

最終更新: 2026-04-12

`modules/expo-live-photo-exporter/ios/ExpoLivePhotoExporterModule.swift` が
`promise.reject(code, message)` で返すコードと、JS 側
(`src/services/NativeLivePhotoBridge.ts`) が `AppError` にどう落とすかの対応表です。

このドキュメントは **アプリ内 Debug 画面の `Last Error.code` を読むときの辞書**
です。Metro / アプリ内 Debug 画面にコードが出たら、このドキュメントをそのまま
grep してください。

## 凡例

- **Stage**: Swift の `performSave` パイプラインのどの工程で発生したか
- **AppError kind**: JS 側で UI に渡される `AppError` の種類
- **最初に疑うべきこと**: 実機で出たときの切り分け出発点

## 早見表

| Code | Stage | AppError kind | 最初に疑うべきこと |
| --- | --- | --- | --- |
| `ERR_NATIVE_MODULE_UNAVAILABLE` | JS only | `nativeModuleUnavailable` | Expo Go で動かしていないか / Development Build が最新の `modules/` を含んで焼かれているか |
| `ERR_PHOTO_PERMISSION_DENIED` | 前処理 | `photoPermissionDenied` | 写真 `.addOnly` 権限ダイアログを拒否していないか / 設定 App で許可を戻す |
| `ERR_INVALID_SOURCE_URI` | 前処理 | `exportFailed` | JS 側が渡した `movUri` / `stillUri` が空 or file:// 以外 |
| `ERR_STILL_LOAD_FAILED` | (A) JPEG タグ付け | `exportFailed` | 入力 JPEG/HEIC が破損、もしくは `expo-video-thumbnails` が出力したファイルが存在しない |
| `ERR_STILL_WRITE_FAILED` | (A) JPEG タグ付け | `exportFailed` | 一時ディレクトリ書き込み権限、ディスク容量 |
| `ERR_STILL_FINALIZE_FAILED` | (A) JPEG タグ付け | `exportFailed` | 稀。まずは再試行。続くなら MakerApple dict の書き込みに失敗している |
| `ERR_MOVIE_TRACK_LOAD_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | 入力 MOV が破損、`AVURLAsset.loadTracks(.video)` が throw |
| `ERR_MOVIE_VIDEO_TRACK_MISSING` | (B)(C) MOV タグ付け | `exportFailed` | 入力がオーディオのみ。動画トラック 0 本 |
| `ERR_MOVIE_READER_CREATE_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | 入力形式が想定外 (pickerを経由しない独自入力を渡した疑い) |
| `ERR_MOVIE_WRITER_CREATE_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | `AVAssetWriter` init 失敗 / metadata input 追加不可 |
| `ERR_MOVIE_START_WRITING_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | metadata spec か passthrough 設定の不整合 |
| `ERR_MOVIE_VIDEO_APPEND_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | サンプルバッファが writer から拒否。入力コーデックの想定外 |
| `ERR_MOVIE_FINISH_WRITING_FAILED` | (B)(C) MOV タグ付け | `exportFailed` | `finishWriting` 後 status が completed 以外。再試行で解消することあり |
| `ERR_ASSET_CREATION_FAILED` | (D) Photos 保存 | `exportFailed` | `PHAssetCreationRequest` が placeholder を返さない。権限か resource 追加順 |
| `ERR_LIVE_PHOTO_EXPORT_FAILED` | フォールバック | `exportFailed` | 上記以外の未知エラー。`message` を読むこと |

## Live Photo 4 条件との対応

Photos アプリで **LIVE バッジが出ない / 長押し再生しない** 症状は、Swift 実装の
4 条件 (A)(B)(C)(D) のどれかが破綻しているサインです。どの条件が壊れたかは
エラーコードからおおよそ逆引きできます。

| 条件 | 役割 | 関連する ERR_ |
| --- | --- | --- |
| (A) JPEG の `MakerApple["17"]` = contentIdentifier | 写真側のペアリング印 | `ERR_STILL_LOAD_FAILED` / `ERR_STILL_WRITE_FAILED` / `ERR_STILL_FINALIZE_FAILED` |
| (B) MOV top-level `com.apple.quicktime.content.identifier` | 動画側のペアリング印 | `ERR_MOVIE_*` 系 (特に `ERR_MOVIE_FINISH_WRITING_FAILED`) |
| (C) MOV metadata track `com.apple.quicktime.still-image-time` | 長押し再生のトリガー時刻 | `ERR_MOVIE_WRITER_CREATE_FAILED` / `ERR_MOVIE_FINISH_WRITING_FAILED` |
| (D) 同一 `PHAssetCreationRequest` に `.photo` + `.pairedVideo` | Photos が "Live" として確定する瞬間 | `ERR_ASSET_CREATION_FAILED` |

### 症状別フローチャート

- **Last Error が空 / Last Save に ids が入っている / LIVE バッジ無し**
  → (A) JPEG MakerApple dict が Photos 側で剥がれている疑い。HEIC を JPEG に変換して再試行。
- **Last Error が空 / LIVE バッジは出る / 長押しで動かない**
  → (C) still-image-time の書き込みが不完全。入力動画が極端に短い (0.5 秒未満) 可能性が高い。
- **Last Error に `ERR_MOVIE_FINISH_WRITING_FAILED`**
  → (B)(C) metadata が writer に拒否された。まず再試行 → それでも同じなら入力 MOV をピッカーから取り直す。
- **Last Error に `ERR_ASSET_CREATION_FAILED`**
  → (D) 権限ダイアログを初回で拒否した可能性、もしくは `.photo` と `.pairedVideo` が 2 回 add されている。
- **Last Error に `ERR_NATIVE_MODULE_UNAVAILABLE`**
  → Expo Go で動かしている。Development Build に切り替える。

## Windows からの読み方

1. アプリ内で `設定 → デバッグ情報を開く` を開く
2. ステータスバナー (緑 / 赤 / グレー) で全体状態を把握
3. `Last Error.code` をこのドキュメントで grep
4. 対応行を読んで原因仮説を立てる
5. Metro ターミナル (`npx expo start --dev-client`) に同じコードが流れているか確認
6. 必要なら `Copyable Blob` を長押し → 選択 → コピーで Windows 側に送り返す

Xcode Devices & Simulators は一切不要です。Mac は持たない前提の開発フローの一部として、
このドキュメントを常に最新に保ってください。
