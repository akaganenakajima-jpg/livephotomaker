import { ja, type TranslationKey } from './ja';
import { en } from './en';

// The app is Japanese-first; English is available for future localization.
const DEFAULT_LANG = 'ja';

const dictionaries = { ja, en } as const;

export const t = (key: TranslationKey, lang: keyof typeof dictionaries = DEFAULT_LANG): string =>
  dictionaries[lang][key];

export type { TranslationKey };
