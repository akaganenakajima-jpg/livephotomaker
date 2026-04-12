export type ExportQuality = 'standard' | 'high';

export interface QualityProfile {
  readonly maxStillPixelWidth: number;
  readonly jpegCompression: number;
  readonly videoBitrate: number;
}

export const qualityProfile = (q: ExportQuality): QualityProfile => {
  if (q === 'high') {
    return { maxStillPixelWidth: 2160, jpegCompression: 0.95, videoBitrate: 8_000_000 };
  }
  return { maxStillPixelWidth: 1280, jpegCompression: 0.85, videoBitrate: 3_500_000 };
};
