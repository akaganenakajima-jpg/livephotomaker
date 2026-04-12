import * as VideoThumbnails from 'expo-video-thumbnails';
import * as FileSystem from 'expo-file-system';
import { Video } from 'expo-av';
import type { ExportQuality } from '@/types/ExportQuality';
import { qualityProfile } from '@/types/ExportQuality';
import type { AppError } from '@/types/AppError';
import { logger } from '@/utils/logger';

export interface PreparedVideo {
  readonly movUri: string;
  readonly stillUri: string;
  readonly durationSeconds: number;
}

export interface VideoProcessingService {
  duration(sourceUri: string): Promise<number>;
  /**
   * Produces a trimmed clip and a keyframe still for the given source video.
   * Note: actual trimming of the MOV happens in the native module because
   * Expo's JS-only surface cannot rewrite QuickTime metadata needed for a
   * Live Photo pair.
   */
  prepare(args: {
    sourceUri: string;
    quality: ExportQuality;
    startSeconds: number;
    endSeconds: number;
  }): Promise<PreparedVideo>;
}

export const MAX_ACCEPTED_DURATION_SECONDS = 60;

export const createVideoProcessingService = (): VideoProcessingService => ({
  duration: async (sourceUri) => {
    // Expo's `Video` module exposes durations via `Video.createAsync`, but to
    // keep this layer thin we use a lightweight probe via expo-av.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const probe = await (
      Video as unknown as {
        createAsync?: (source: { uri: string }) => Promise<{ durationMillis?: number }>;
      }
    ).createAsync?.({ uri: sourceUri });
    const ms = probe?.durationMillis ?? 0;
    return ms / 1000;
  },

  prepare: async ({ sourceUri, quality, startSeconds }) => {
    logger.debug('video.prepare', { sourceUri, quality });
    const profile = qualityProfile(quality);

    // Step 1: extract a keyframe still at startSeconds.
    const { uri: stillUri } = await VideoThumbnails.getThumbnailAsync(sourceUri, {
      time: Math.max(0, Math.floor(startSeconds * 1000)),
      quality: profile.jpegCompression,
    });

    // Step 2: the MOV is passed as-is to the native module, which owns the
    // trimming + metadata tagging. For the pure-JS happy path we simply copy
    // the source to a working file.
    const workingDir = `${FileSystem.cacheDirectory}livephoto-${Date.now()}/`;
    await FileSystem.makeDirectoryAsync(workingDir, { intermediates: true });
    const movUri = `${workingDir}source.mov`;
    await FileSystem.copyAsync({ from: sourceUri, to: movUri });

    // Probe duration for UI display.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const probe = await (
      Video as unknown as {
        createAsync?: (source: { uri: string }) => Promise<{ durationMillis?: number }>;
      }
    ).createAsync?.({ uri: movUri });
    const durationSeconds = (probe?.durationMillis ?? 0) / 1000;

    if (durationSeconds > MAX_ACCEPTED_DURATION_SECONDS) {
      const err: AppError = {
        kind: 'videoTooLong',
        maxSeconds: MAX_ACCEPTED_DURATION_SECONDS,
      };
      throw err;
    }

    return { movUri, stillUri, durationSeconds };
  },
});
