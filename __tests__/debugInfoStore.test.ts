import { useDebugInfoStore } from '@/store/debugInfoStore';

describe('debugInfoStore', () => {
  beforeEach(() => {
    useDebugInfoStore.getState().clear();
  });

  it('records the most recent success and clears a prior error', () => {
    const store = useDebugInfoStore.getState();
    store.recordSaveError('ERR_STILL_LOAD_FAILED', 'boom');
    expect(useDebugInfoStore.getState().lastError?.code).toBe('ERR_STILL_LOAD_FAILED');

    store.recordSaveSuccess({
      localIdentifier: 'abc/L0/001',
      contentIdentifier: 'uuid-1234',
    });

    const s = useDebugInfoStore.getState();
    expect(s.lastSaveResult?.localIdentifier).toBe('abc/L0/001');
    expect(s.lastSaveResult?.contentIdentifier).toBe('uuid-1234');
    expect(s.lastError).toBeNull();
    expect(s.successCount).toBe(1);
  });

  it('records a failure without dropping the last success', () => {
    const store = useDebugInfoStore.getState();
    store.recordSaveSuccess({
      localIdentifier: 'abc/L0/001',
      contentIdentifier: 'uuid-1',
    });
    store.recordSaveError('ERR_MOVIE_FINISH_WRITING_FAILED', 'writer failed');

    const s = useDebugInfoStore.getState();
    // We deliberately keep the last successful save visible alongside the
    // new error, so the operator can still copy the ids from the most
    // recent good run for comparison.
    expect(s.lastSaveResult?.localIdentifier).toBe('abc/L0/001');
    expect(s.lastError?.code).toBe('ERR_MOVIE_FINISH_WRITING_FAILED');
    expect(s.errorCount).toBe(1);
  });

  it('clear() resets every field', () => {
    const store = useDebugInfoStore.getState();
    store.recordSaveSuccess({
      localIdentifier: 'x',
      contentIdentifier: 'y',
    });
    store.recordSaveError('ERR_X', 'x');
    store.clear();

    const s = useDebugInfoStore.getState();
    expect(s.lastSaveResult).toBeNull();
    expect(s.lastError).toBeNull();
    expect(s.successCount).toBe(0);
    expect(s.errorCount).toBe(0);
  });
});
