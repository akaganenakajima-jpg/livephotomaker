import type { TranslationKey } from './ja';

export const en: Record<TranslationKey, string> = {
  'home.title': 'Video to Live Photo',
  'home.subtitle': 'Create a Live Photo from a video.',
  'home.start': 'Choose Video',
  'home.settings': 'Settings',

  'onboarding.title': 'About this app',
  'onboarding.body':
    'This app creates a Live Photo from your video and saves it to your Photos library. Please set it as your lock-screen wallpaper from the iOS Settings app.',
  'onboarding.confirm': 'Get Started',

  'export.options.title': 'Choose Export Quality',
  'export.options.standard': 'Continue in Standard Quality',
  'export.options.standard.detail': 'Save for free.',
  'export.options.rewarded': 'Watch an Ad for High Quality (1 time)',
  'export.options.rewarded.detail': 'Watch a short ad to export in high quality once.',
  'export.options.premium': 'Unlock High Quality (One-time Purchase)',
  'export.options.premium.detail':
    'Unlock high-quality export permanently. Ads will also be removed.',

  'export.progress.title': 'Creating Live Photo…',
  'export.progress.hint': 'Please wait. Do not close this screen.',

  'preview.title': 'Preview',
  'preview.hint': 'Long-press to play the Live Photo.',

  'success.title': 'Saved',
  'success.body':
    'Your Live Photo has been saved to your Photos library. To use it as a Live lock-screen wallpaper, follow these steps.',
  'success.step1': '1. Open the Settings app',
  'success.step2': '2. Tap Wallpaper',
  'success.step3': '3. Tap Add New Wallpaper',
  'success.step4': '4. Select Photos > Live Photo',
  'success.done': 'Done',

  'paywall.title': 'Unlock High Quality',
  'paywall.body':
    'A one-time purchase unlocks high-quality export forever. Ads will also be removed.',
  'paywall.cta.buy': 'Buy',
  'paywall.cta.restore': 'Restore Purchase',

  'error.photo_permission': 'Photo library access is required. Please allow it in Settings.',
  'error.video_unsupported': 'This video format is not supported.',
  'error.video_too_long': 'The video is too long. Please choose a shorter clip.',
  'error.export_failed': 'Export failed. Please try again.',
  'error.ad_unavailable': 'Ad could not be loaded. You can continue in standard quality.',
  'error.purchase_failed': 'Purchase failed. Please try again later.',
  'error.native_unavailable': 'Live Photo creation is unavailable. Please use a Development Build.',
};
