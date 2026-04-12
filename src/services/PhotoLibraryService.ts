import * as MediaLibrary from 'expo-media-library';
import type { AppError } from '@/types/AppError';

export interface PhotoLibraryService {
  requestAddOnlyPermission(): Promise<boolean>;
}

export const createPhotoLibraryService = (): PhotoLibraryService => ({
  requestAddOnlyPermission: async () => {
    const res = await MediaLibrary.requestPermissionsAsync(/* writeOnly */ true);
    return res.status === 'granted';
  },
});

export const ensurePhotoPermission = async (service: PhotoLibraryService): Promise<void> => {
  const granted = await service.requestAddOnlyPermission();
  if (!granted) {
    const err: AppError = { kind: 'photoPermissionDenied' };
    throw err;
  }
};
