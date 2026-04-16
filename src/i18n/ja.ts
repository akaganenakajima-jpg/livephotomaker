export const ja = {
  'home.title': 'Video to Live Photo',
  'home.subtitle': '動画からLive Photoを作成して保存します。',
  'home.start': '動画を選ぶ',
  'home.settings': '設定',

  'onboarding.title': 'このアプリについて',
  'onboarding.body':
    '動画からLive Photoを作って写真ライブラリへ保存します。壁紙の設定はiPhoneの「設定」Appから行ってください。',
  'onboarding.confirm': 'はじめる',

  'export.options.title': '書き出し方法を選ぶ',
  'export.options.standard': '標準画質で続ける',
  'export.options.standard.detail': '無料で保存できます。',
  'export.options.rewarded': '広告を見て高画質を1回試す',
  'export.options.rewarded.detail': '短い広告を見ると、高画質で1回だけ保存できます。',
  'export.options.premium': '高画質を買い切りで解放',
  'export.options.premium.detail': '一度の購入で高画質がいつでも使えます。広告も非表示になります。',

  'export.progress.title': 'Live Photoを作成中…',
  'export.progress.hint': 'しばらくお待ちください。画面を閉じないでください。',

  'preview.title': 'プレビュー',
  'preview.hint': '長押しするとLive Photoが再生されます。',

  'success.title': '保存しました',
  'success.body':
    '写真ライブラリに保存されました。ロック画面で動く壁紙として使うには、次の手順で設定してください。',
  'success.step1': '1. 設定Appを開く',
  'success.step2': '2. 「壁紙」を選ぶ',
  'success.step3': '3. 「新しい壁紙を追加」を選ぶ',
  'success.step4': '4. 「写真」→「Live Photo」から選ぶ',
  'success.done': '完了',

  'paywall.title': '高画質解放',
  'paywall.body':
    '一度の購入で高画質書き出しがいつでも使えるようになります。広告も非表示になります。',
  'paywall.cta.buy': '購入する',
  'paywall.cta.restore': '購入を復元',

  'error.photo_permission': '写真ライブラリへのアクセスが必要です。設定から許可してください。',
  'error.video_unsupported': 'この動画形式には対応していません。',
  'error.video_too_long': '動画が長すぎます。短いクリップを選んでください。',
  'error.export_failed': '書き出しに失敗しました。もう一度お試しください。',
  'error.ad_unavailable': '広告を読み込めませんでした。標準画質で続行できます。',
  'error.purchase_failed': '購入処理に失敗しました。時間をおいて再度お試しください。',
  'error.native_unavailable':
    'Live Photo作成機能が利用できません。Development Buildをお使いください。',
  'error.title': 'エラー',

  // Navigation headers
  'nav.home': 'Video to Live Photo',
  'nav.import': '動画を選ぶ',
  'nav.trim': 'トリム',
  'nav.export_options': '書き出し方法',
  'nav.export_progress': '作成中',
  'nav.preview': 'プレビュー',
  'nav.success': '保存しました',
  'nav.paywall': '高画質解放',
  'nav.settings': '設定',
  'nav.debug': 'デバッグ情報',

  // Settings screen
  'settings.plan_label': '現在のプラン',
  'settings.plan_premium': '高画質 (買い切り)',
  'settings.plan_trial': '高画質 (1回のみ)',
  'settings.plan_free': '標準画質',
  'settings.restore': '購入を復元',
  'settings.buy_premium': '高画質解放を購入',
  'settings.debug': 'デバッグ情報を開く',

  // Trim screen
  'trim.title': 'クリップの長さを確認',
  'trim.body': 'Live Photo には先頭 3 秒前後が使われます。必要に応じて後で調整できます。',
  'trim.next': '次へ',

  // Import screen
  'import.loading': '動画を選んでください…',
  'import.error': '動画を読み込めませんでした。',
  'import.back': '戻る',
  'import.test_mode_loading': 'テストモード: 最新の動画を読み込み中…',
  'import.test_mode_no_video': '写真ライブラリに動画が見つかりません。動画を追加してください。',

  // Test mode (DEV only — never shown in production)
  'debug.test_mode': 'テストモード',
  'debug.test_mode.detail': 'フォトピッカーを使わず、ライブラリの最新動画で書き出します',
} as const;

export type TranslationKey = keyof typeof ja;
