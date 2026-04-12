import type {
  NativeExportInput,
  NativeExportResult,
  NativeLivePhotoBridge,
} from '@/services/NativeLivePhotoBridge';
import type { AppError } from '@/types/AppError';

export interface MockBridgeOptions {
  available?: boolean;
  throwKind?: AppError['kind'];
}

export const createMockNativeLivePhotoBridge = (
  opts: MockBridgeOptions = {},
): NativeLivePhotoBridge & { calls: NativeExportInput[] } => {
  const calls: NativeExportInput[] = [];
  const available = opts.available ?? true;
  return {
    calls,
    isAvailable: () => available,
    saveLivePhoto: async (input) => {
      calls.push(input);
      if (opts.throwKind) {
        const err: AppError =
          opts.throwKind === 'exportFailed'
            ? { kind: 'exportFailed', underlying: 'mock failure' }
            : opts.throwKind === 'videoTooLong'
              ? { kind: 'videoTooLong', maxSeconds: 60 }
              : opts.throwKind === 'purchaseFailed'
                ? { kind: 'purchaseFailed', underlying: 'mock failure' }
                : { kind: opts.throwKind };
        throw err;
      }
      const result: NativeExportResult = {
        localIdentifier: 'mock-asset-id',
      };
      return result;
    },
  };
};
