import { ThemeMode } from '../models/VaultModels';

export interface ThemePalette {
  bgPage: string;
  bgCard: string;
  bgSub: string;
  fgMain: string;
  fgSub: string;
  placeholder: string;
  border: string;
  divider: string;
  brand: string;
  brandSoft: string;
  danger: string;
  dangerSoft: string;
  success: string;
  successSoft: string;
  warn: string;
  warnSoft: string;
  segTrack: string;
  segThumb: string;
  segThumbText: string;
}

const LIGHT_PALETTE: ThemePalette = {
  bgPage: '#F2F2F7',
  bgCard: '#FFFFFF',
  bgSub: '#F8FAFC',
  fgMain: '#0F172A',
  fgSub: '#64748B',
  placeholder: '#660F172A',
  border: '#140F172A',
  divider: '#0F000000',
  brand: '#4F46E5',
  brandSoft: '#1A4F46E5',
  danger: '#E11D48',
  dangerSoft: '#1AE11D48',
  success: '#059669',
  successSoft: '#1A059669',
  warn: '#D97706',
  warnSoft: '#1AD97706',
  segTrack: '#1864748B',
  segThumb: '#FFFFFF',
  segThumbText: '#4F46E5',
};

const DARK_PALETTE: ThemePalette = {
  bgPage: '#0B0F19',
  bgCard: '#111827',
  bgSub: '#1E293B',
  fgMain: '#F8FAFC',
  fgSub: '#94A3B8',
  placeholder: '#66F8FAFC',
  border: '#1EFFFFFF',
  divider: '#12FFFFFF',
  brand: '#6366F1',
  brandSoft: '#266366F1',
  danger: '#FB7185',
  dangerSoft: '#26FB7185',
  success: '#34D399',
  successSoft: '#2634D399',
  warn: '#FBBF24',
  warnSoft: '#26FBBF24',
  segTrack: '#2694A3B8',
  segThumb: '#334155',
  segThumbText: '#FFFFFF',
};

export function getPalette(theme: ThemeMode): ThemePalette {
  return theme === 'dark' ? DARK_PALETTE : LIGHT_PALETTE;
}

export const MOBILE_REPO_URL: string = 'https://github.com/NovanJex/SecureVault-Mobile';
export const MOBILE_ISSUES_URL: string = 'https://github.com/NovanJex/SecureVault-Mobile/issues';
export const FEEDBACK_EMAIL: string = 'feedback@suoxia.app';

export interface ColoredCharSegment {
  text: string;
  color: string;
}

export function colorizePasswordSegments(pwd: string): ColoredCharSegment[] {
  const out: ColoredCharSegment[] = [];
  for (let i = 0; i < pwd.length; i++) {
    const ch = pwd.charAt(i);
    let color = '#FFFFFF';
    if (ch >= '0' && ch <= '9') {
      color = '#38BDF8';
    } else if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'))) {
      color = '#FBBF24';
    }
    if (out.length > 0 && out[out.length - 1].color === color) {
      out[out.length - 1].text += ch;
    } else {
      out.push({ text: ch, color: color });
    }
  }
  return out;
}
