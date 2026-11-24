export type ItemType = 'login' | 'card' | 'note' | 'identity';
export type PasswordStrength = 'weak' | 'medium' | 'strong';
export type KdfType = 'argon2id' | 'pbkdf2';

export const DEFAULT_FOLDER: string = '默认';
export const ALL_FOLDER_FILTER: string = '全部';

export interface PasswordHistoryEntry {
  password: string;
  changedAt: string;
}

export interface VaultFolder {
  id: string;
  name: string;
  icon: string;
}

export interface VaultItem {
  id: string;
  type: ItemType;
  title: string;
  folder: string;
  username?: string;
  password?: string;
  url?: string;
  cardName?: string;
  cardNumber?: string;
  cardExpiry?: string;
  cardCvv?: string;
  identityName?: string;
  identityEmail?: string;
  identityPhone?: string;
  identityAddress?: string;
  notes?: string;
  customFields?: Record<string, string>;
  otpSecret?: string;
  expiresAt?: string;
  passwordHistory?: PasswordHistoryEntry[];
  deletedAt?: string;
  lastUsedAt?: string;
  updatedAt: string;
  strength?: PasswordStrength;
  isFavorite?: boolean;
  ignoreSecurityWarning?: boolean;
  // Original parsed desktop JSON object for lossless round-trip serialization
  rawJson?: Record<string, Object>;
}

export interface StandaloneTotp {
  id: string;
  issuer: string;
  account: string;
  secret: string;
}

export interface WebDavStat {
  exists: boolean;
  size: number;
  last_modified?: string | null;
  etag?: string | null;
}

export interface WebDavDownload {
  content: string;
  stat: WebDavStat;
}

export interface WebDavStoredConfig {
  url: string;
  username: string;
  passwordEnc: string;
}

export interface WebDavSnapshot {
  etag: string;
  lastModified: string;
  size: number;
}

export type WebDavPresetKey = 'generic' | 'nextcloud' | 'nas' | 'jianguoyun';

export interface WebDavPreset {
  key: WebDavPresetKey;
  label: string;
  placeholder: string;
  tip: string;
}

export interface TotpCodeResult {
  code: string;
  remaining: number;
}

export interface LiveTotpDisplay {
  fmt: string;
  raw: string;
  rem: number;
}

export interface ParsedOtpUri {
  issuer: string;
  account: string;
  secret: string;
}

export type ImportSourceKey = 'suoxia' | 'kdbx' | 'browser';
export type ImportStrategy = 'skip' | 'merge' | 'overwrite';
export type ImportStep = 'pick' | 'decrypt' | 'preview';

export interface ImportParseResult {
  needsPassword: boolean;
  items: VaultItem[];
  folders: string[];
  totpCount: number;
  badge: string;
}

export interface PickedFileInfo {
  fileName: string;
  tempPath: string;
}

export interface ExternalLinkRequest {
  title: string;
  url: string;
}

export interface ConfirmDialogRequest {
  title: string;
  message: string;
  confirmLabel: string;
  isDanger: boolean;
  onConfirm: () => void;
}

export type AppScreen = 'onboarding' | 'unlock' | 'home';
export type HomeTab = 'vault' | 'totp' | 'generator' | 'settings';
export type AutoLockOption = '切后台立即锁定' | '1 分钟' | '5 分钟' | '15 分钟';
export type ThemeMode = 'light' | 'dark';

export function normalizeFolderName(raw?: string | null): string {
  if (!raw) {
    return DEFAULT_FOLDER;
  }
  const trimmed = raw.trim();
  if (
    trimmed.length === 0 ||
    trimmed === '未分组' ||
    trimmed === '未分类' ||
    trimmed === '默认' ||
    trimmed === 'Default'
  ) {
    return DEFAULT_FOLDER;
  }
  return trimmed;
}

export function evaluatePasswordStrength(pwd: string): PasswordStrength {
  if (!pwd || pwd.length < 10) {
    return 'weak';
  }
  let classes = 0;
  if (/[a-z]/.test(pwd)) {
    classes += 1;
  }
  if (/[A-Z]/.test(pwd)) {
    classes += 1;
  }
  if (/[0-9]/.test(pwd)) {
    classes += 1;
  }
  if (/[^a-zA-Z0-9]/.test(pwd)) {
    classes += 1;
  }
  if (pwd.length >= 14 && classes >= 3) {
    return 'strong';
  }
  return 'medium';
}

export function formatUpdatedAt(date?: Date): string {
  const d = date ?? new Date();
  const yyyy = d.getFullYear().toString();
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  const hh = d.getHours().toString().padStart(2, '0');
  const mi = d.getMinutes().toString().padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}`;
}

export function formatDateStamp(date?: Date): string {
  const d = date ?? new Date();
  const yyyy = d.getFullYear().toString();
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}
