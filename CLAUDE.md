# CLAUDE.md — Video to Live Photo (Expo) プロジェクト固有の指示

Claude Code はこのファイルを毎セッション読み込みます。以下のルールは**プロジェクト固有**で、
グローバル `~/.claude/CLAUDE.md` を上書きしません。両方を遵守してください。

---

## 1. プロジェクト目的

動画を Live Photo へ変換し、iPhone の写真ライブラリへ保存する iOS アプリです。
ユーザーはロック画面で Live Photo 壁紙として使うための**標準手順**を案内される前提です。

## 2. プラットフォーム方針

- **主開発環境は Windows 10**。Mac は所有していない前提で設計する
- **Mac を必要とする解決策を提案しない**
- React Native + Expo + TypeScript を採用
- Expo Go は UI プレビューのみ。**Live Photo/課金/広告の実機検証には Development Build を使う**
- iOS ネイティブビルド・提出は EAS Build / EAS Submit で完結させる（クラウド実行）
- iPhone 実機での確認が最終基準

## 3. 絶対に実装しないもの（審査リスク）

- 壁紙の自動設定
- Private API の使用
- 進捗画面を遮る広告表示
- 「ワンタップで壁紙」「自動で壁紙に設定」など誤解を招く表現

以下の文字列は**コード／コメント／README／App Store 説明文／審査メモのどこにも書かない**:

- `auto set wallpaper`
- `automatically set wallpaper`
- `1 tap wallpaper set`
- `wallpaper auto apply`
- 壁紙を自動設定
- ワンタップで壁紙設定
- 自動で壁紙に設定

## 4. アーキテクチャ原則

- **レイヤ**: `app/`（Expo Router screens）→ `src/services/`（protocol 風の関数モジュール）→ native module (`modules/expo-live-photo-exporter`)
- 逆方向依存禁止: services は React / Expo Router を知らない
- Native 依存は `modules/expo-live-photo-exporter/` と service 実装の中だけに閉じる
- 画面は `src/services/*` を経由してのみ native 機能にアクセスする（直接 `NativeModules.*` を叩かない）
- Expo Modules API と config plugin を優先。`expo prebuild` をむやみに呼ばない

## 5. 変更フロー（全タスクで必須）

1. **関連ファイルを先に読む**。`Grep` / `Read` で影響範囲を確認してから変更する
2. **変更を小さく区切る**。1 コミットが 1 論理変更になるように
3. 変更後に以下を実行する（Windows でも全て実行可能）:
   - `npm run lint`
   - `npm run typecheck`
   - `npm run test`
   - `npm run check:marketing`（禁止表現チェック）
   - `npm run check:iap`（Product ID 整合性チェック）
4. 大きな変更の前にコミットして戻れるようにする

## 6. コードスタイル

- TypeScript **strict** 前提
- ログとコードコメントは英語
- ユーザー向け文言は `src/i18n/ja.ts` / `en.ts` に集約（画面にハードコードしない）
- `console.log` は直書き禁止。`src/utils/logger.ts` を使う（本番ビルドでは no-op）
- `any` 使用禁止。必要な場合は `unknown` + 型ガード
- 破壊的変更時は README / `docs/` / テストも同時更新

## 7. Custom Native Module（Live Photo）

- **Live Photo 生成のコアは `modules/expo-live-photo-exporter/` の Swift 実装**
- JS 側から呼ぶときは必ず `src/services/NativeLivePhotoBridge.ts` 経由
- テストでは `NativeLivePhotoBridge` を差し替えてモック化する
- ネイティブ側を変更した場合は **Development Build の再作成が必要**。Expo Go では反映されない
- iPhone 実機での保存結果を最終検証ポイントにする（シミュレータ不可）

## 8. StoreKit 2 / IAP

- 商品 ID は `src/constants/products.ts` の定数を必ず経由する（ハードコード禁止）
- 確定 Product ID: `com.gen.videotolivephoto.premium.hq_unlock` （非消耗型・買い切り）
- 非消耗型なので `purchase()` 後に復元フローも実装する
- シミュレータは非対応。実機 + Sandbox アカウントで検証

## 9. 広告

- 広告 SDK の import は `src/services/AdsService.ts` **のみ**に閉じ込める
- ユーザーが明示的にタップした後だけ表示
- 進捗画面を強制中断しない
- 課金済みユーザーには `AdsService.isEnabled(entitlement) === false` で完全に非表示
- 読み込み失敗は `AdResult.failed` を返して標準画質へ自然フォールバック

## 10. テスト

- Jest + `jest-expo` を使用
- ViewModel 相当のロジック（`services/`、`store/`）はユニットテスト必須
- 次の分岐は**必ず**テストする:
  - `ExportEntitlement` の状態遷移（premium / trial / free）
  - 書き出し品質決定（`resolveQuality`）
  - rewarded ad 成功 → trial 付与
  - HQ 書き出し後の trial 消費
  - 広告失敗 → 標準画質フォールバック
- Native module は JS 側 bridge を差し替えてモック化する

## 11. Markdown 出力ルール

- Markdown を生成するときは**最後まで閉じた正しい構造**にする
- コードフェンス（```）、引用、箇条書き、見出しを途中で壊さない
- 長大な出力は必ず末尾まで完結させる

---

## コミット前チェックリスト

- [ ] `npm run lint` 通過
- [ ] `npm run typecheck` 通過
- [ ] `npm run test` 通過
- [ ] `npm run check:marketing` 通過（禁止表現なし）
- [ ] `npm run check:iap` 通過
- [ ] native 変更あり → Development Build を再作成したか
- [ ] README / docs の記述が実装と一致しているか
