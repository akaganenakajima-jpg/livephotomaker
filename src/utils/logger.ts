/**
 * Thin logger wrapper. In production the log functions are no-ops so we never
 * leak verbose information to end users. Use this instead of `console.log`.
 *
 * In addition to `console.*`, every call is pushed into an in-memory ring
 * buffer so the in-app Debug screen can render them. This is the Windows-only
 * equivalent of "Xcode Devices & Simulators" — we do not rely on any Mac-side
 * tool to see what the native module / services are reporting.
 */
const isDev = typeof __DEV__ !== 'undefined' ? __DEV__ : process.env.NODE_ENV !== 'production';

type LogArgs = readonly unknown[];
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogLine {
  readonly at: number;
  readonly level: LogLevel;
  readonly message: string;
}

const MAX_LINES = 200;
const buffer: LogLine[] = [];
type Subscriber = (lines: readonly LogLine[]) => void;
const subscribers = new Set<Subscriber>();

const stringify = (args: LogArgs): string => {
  return args
    .map((a) => {
      if (a instanceof Error) return `${a.name}: ${a.message}`;
      if (typeof a === 'string') return a;
      try {
        return JSON.stringify(a);
      } catch {
        return String(a);
      }
    })
    .join(' ');
};

const push = (level: LogLevel, args: LogArgs): void => {
  const line: LogLine = {
    at: Date.now(),
    level,
    message: stringify(args),
  };
  buffer.push(line);
  if (buffer.length > MAX_LINES) buffer.shift();
  for (const sub of subscribers) sub(buffer);
};

/**
 * Reads the current ring buffer snapshot. Consumers should treat this as
 * immutable (use the `subscribe` helper below if they need change events).
 */
export const getLogLines = (): readonly LogLine[] => buffer.slice();

/**
 * Subscribes to log buffer changes. Returns an unsubscribe function.
 */
export const subscribeLogLines = (cb: Subscriber): (() => void) => {
  subscribers.add(cb);
  return () => {
    subscribers.delete(cb);
  };
};

/**
 * Clears the ring buffer. Useful from the Debug screen's "Clear" button.
 */
export const clearLogLines = (): void => {
  buffer.length = 0;
  for (const sub of subscribers) sub(buffer);
};

export const logger = {
  debug: (...args: LogArgs): void => {
    push('debug', args);
    if (isDev) {
      // eslint-disable-next-line no-console
      console.debug('[debug]', ...args);
    }
  },
  info: (...args: LogArgs): void => {
    push('info', args);
    if (isDev) {
      // eslint-disable-next-line no-console
      console.info('[info]', ...args);
    }
  },
  warn: (...args: LogArgs): void => {
    push('warn', args);
    // eslint-disable-next-line no-console
    console.warn('[warn]', ...args);
  },
  error: (...args: LogArgs): void => {
    push('error', args);
    // eslint-disable-next-line no-console
    console.error('[error]', ...args);
  },
};
