import React, { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useDebugInfoStore } from '@/store/debugInfoStore';
import { clearLogLines, getLogLines, subscribeLogLines, type LogLine } from '@/utils/logger';

/**
 * Windows-only diagnostics panel. Renders, in this order, so the operator
 * can see at a glance whether the last save succeeded:
 *
 *   - A big status banner (GREEN = ok / RED = failed / GRAY = not run yet)
 *     with the relative time (`3 秒前` etc) so stale data is obvious.
 *   - Last successful save (localIdentifier / contentIdentifier / absolute time)
 *   - Last failure (native error code + message + absolute time)
 *   - In-memory ring buffer of recent log lines from `utils/logger`
 *   - A single JSON "Copyable Blob" that holds all of the above for one-shot
 *     long-press copy to iMessage / Notes / email back to the Windows box.
 *
 * No Mac/Xcode involvement: every value the panel shows is produced in JS
 * and is available regardless of where the Development Build was produced.
 */
export default function DebugPanel() {
  const lastSaveResult = useDebugInfoStore((s) => s.lastSaveResult);
  const lastError = useDebugInfoStore((s) => s.lastError);
  const clearStore = useDebugInfoStore((s) => s.clear);

  // Local React state mirror of the logger ring buffer so the list re-renders
  // whenever a new log line lands. We initialise from the current snapshot
  // and subscribe so future pushes flush into the component.
  const [lines, setLines] = useState<readonly LogLine[]>(() => getLogLines());
  useEffect(() => {
    return subscribeLogLines((next) => setLines(next.slice()));
  }, []);

  // A "tick" state that advances every second purely so the relative time
  // labels ("3 秒前") refresh while the screen is mounted. Without this
  // they'd freeze at the first render value which is a confusing UX trap.
  const [, setNowTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setNowTick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, []);

  // Compute the status banner from the *most recent* event. A new success
  // clears `lastError` in the store, so `lastSaveResult` being more recent
  // always means success.
  const status: 'ok' | 'fail' | 'idle' = lastError ? 'fail' : lastSaveResult ? 'ok' : 'idle';

  // `react-native` no longer ships a Clipboard module in RN 0.74, so instead
  // of pulling in `expo-clipboard` we render every id / message with
  // `selectable` so the user can long-press → 選択 → コピー. The Debug screen
  // also dumps the full payload as a single selectable JSON blob at the
  // bottom so "all-in-one" copies are still one long-press away.
  const copyableBlob = JSON.stringify(
    {
      status,
      lastSaveResult,
      lastError,
      logs: lines.slice(-50).map((l) => ({
        at: l.at,
        level: l.level,
        message: l.message,
      })),
    },
    null,
    2,
  );

  const onClear = () => {
    clearLogLines();
    clearStore();
  };

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content} testID="debug-panel">
      <StatusBanner
        status={status}
        successAt={lastSaveResult?.at ?? null}
        failureAt={lastError?.at ?? null}
        failureCode={lastError?.code ?? null}
      />

      <Section title="Last Save (success)">
        {lastSaveResult ? (
          <>
            <KV label="localIdentifier" value={lastSaveResult.localIdentifier} />
            <KV label="contentIdentifier" value={lastSaveResult.contentIdentifier} />
            <KV label="at" value={formatTime(lastSaveResult.at)} />
            <KV label="relative" value={formatRelative(lastSaveResult.at)} />
          </>
        ) : (
          <Text style={styles.empty}>まだ成功した保存はありません。</Text>
        )}
      </Section>

      <Section title="Last Error">
        {lastError ? (
          <>
            <KV label="code" value={lastError.code} />
            <KV label="message" value={lastError.message} />
            <KV label="at" value={formatTime(lastError.at)} />
            <KV label="relative" value={formatRelative(lastError.at)} />
          </>
        ) : (
          <Text style={styles.empty}>直近のエラーはありません。</Text>
        )}
      </Section>

      <Section title={`Log Buffer (${lines.length})`}>
        {lines.length === 0 ? (
          <Text style={styles.empty}>ログはまだありません。</Text>
        ) : (
          lines
            .slice()
            .reverse()
            .slice(0, 50)
            .map((line, idx) => (
              <Text key={`${line.at}-${idx}`} style={styles.logLine} selectable>
                <Text style={levelStyle(line.level)}>[{line.level}]</Text> {formatTime(line.at)} —{' '}
                {line.message}
              </Text>
            ))
        )}
      </Section>

      <Section title="Copyable Blob (長押しで選択 → コピー)">
        <Text style={styles.blob} selectable>
          {copyableBlob}
        </Text>
      </Section>

      <View style={styles.actions}>
        <Pressable style={styles.button} onPress={onClear} testID="debug-clear">
          <Text style={styles.buttonText}>クリア</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

const StatusBanner: React.FC<{
  status: 'ok' | 'fail' | 'idle';
  successAt: number | null;
  failureAt: number | null;
  failureCode: string | null;
}> = ({ status, successAt, failureAt, failureCode }) => {
  const bgStyle =
    status === 'ok' ? styles.bannerOk : status === 'fail' ? styles.bannerFail : styles.bannerIdle;
  const title =
    status === 'ok'
      ? '直近の保存: 成功'
      : status === 'fail'
        ? '直近の保存: 失敗'
        : '保存はまだ実行されていません';
  const sub =
    status === 'ok' && successAt !== null
      ? `${formatRelative(successAt)} (${formatTime(successAt)})`
      : status === 'fail' && failureAt !== null
        ? `${failureCode ?? 'ERR_?'} — ${formatRelative(failureAt)} (${formatTime(failureAt)})`
        : 'デバッグ画面を開いたまま 動画選択 → トリム → 作成 の流れを実行してください。';
  return (
    <View style={[styles.banner, bgStyle]} testID="debug-status-banner">
      <Text style={styles.bannerTitle}>{title}</Text>
      <Text style={styles.bannerSub} selectable>
        {sub}
      </Text>
    </View>
  );
};

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => (
  <View style={styles.section}>
    <Text style={styles.sectionTitle}>{title}</Text>
    <View style={styles.sectionBody}>{children}</View>
  </View>
);

const KV: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <View style={styles.kvRow}>
    <Text style={styles.kvLabel}>{label}</Text>
    <Text style={styles.kvValue} selectable>
      {value}
    </Text>
  </View>
);

const formatTime = (ms: number): string => {
  const d = new Date(ms);
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');
  const ms3 = String(d.getMilliseconds()).padStart(3, '0');
  return `${hh}:${mm}:${ss}.${ms3}`;
};

const formatRelative = (ms: number): string => {
  const diff = Math.max(0, Date.now() - ms);
  if (diff < 1_000) return '0 秒前';
  if (diff < 60_000) return `${Math.floor(diff / 1_000)} 秒前`;
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} 分前`;
  return `${Math.floor(diff / 3_600_000)} 時間前`;
};

const levelStyle = (level: LogLine['level']) => {
  switch (level) {
    case 'error':
      return styles.levelError;
    case 'warn':
      return styles.levelWarn;
    case 'info':
      return styles.levelInfo;
    default:
      return styles.levelDebug;
  }
};

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#F2F2F7' },
  content: { padding: 16, gap: 16 },

  banner: {
    borderRadius: 14,
    padding: 16,
    gap: 4,
  },
  bannerOk: { backgroundColor: '#34C759' },
  bannerFail: { backgroundColor: '#FF3B30' },
  bannerIdle: { backgroundColor: '#8E8E93' },
  bannerTitle: { fontSize: 17, fontWeight: '700', color: '#fff' },
  bannerSub: { fontSize: 13, color: '#fff' },

  section: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 14,
  },
  sectionTitle: { fontSize: 13, fontWeight: '600', color: '#3C3C43', marginBottom: 8 },
  sectionBody: { gap: 6 },

  kvRow: { flexDirection: 'column', gap: 2 },
  kvLabel: { fontSize: 11, color: '#8E8E93' },
  kvValue: { fontSize: 14, color: '#000', fontFamily: 'Menlo' },

  empty: { fontSize: 13, color: '#8E8E93' },

  logLine: { fontSize: 11, color: '#000', fontFamily: 'Menlo' },
  blob: { fontSize: 11, color: '#000', fontFamily: 'Menlo' },
  levelDebug: { color: '#8E8E93' },
  levelInfo: { color: '#007AFF' },
  levelWarn: { color: '#FF9500' },
  levelError: { color: '#FF3B30' },

  actions: { flexDirection: 'row', gap: 12 },
  button: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 16,
    alignItems: 'center',
  },
  buttonText: { fontSize: 15, color: '#007AFF' },
});
