/**
 * Discriminated union of user-facing errors. Each kind maps to a localized
 * message key in `src/i18n/*`.
 */
export type AppError =
  | { kind: 'photoPermissionDenied' }
  | { kind: 'videoUnsupported' }
  | { kind: 'videoTooLong'; maxSeconds: number }
  | { kind: 'exportFailed'; underlying: string }
  | { kind: 'adUnavailable' }
  | { kind: 'purchaseFailed'; underlying: string }
  | { kind: 'nativeModuleUnavailable' };

export const appErrorMessageKey = (error: AppError): string => {
  switch (error.kind) {
    case 'photoPermissionDenied':
      return 'error.photo_permission';
    case 'videoUnsupported':
      return 'error.video_unsupported';
    case 'videoTooLong':
      return 'error.video_too_long';
    case 'exportFailed':
      return 'error.export_failed';
    case 'adUnavailable':
      return 'error.ad_unavailable';
    case 'purchaseFailed':
      return 'error.purchase_failed';
    case 'nativeModuleUnavailable':
      return 'error.native_unavailable';
  }
};
