import { fileIo } from '@kit.CoreFileKit';
import { RustCoreBridge } from '../bridge/RustCoreBridge';
import { t, tf } from '../i18n/AppI18n';
import {
  ALL_FOLDER_FILTER,
  AppScreen,
  AutoLockOption,
  DEFAULT_FOLDER,
  evaluatePasswordStrength,
  formatUpdatedAt,
  HomeTab,
  ImportParseResult,
  ImportSourceKey,
  ImportStrategy,
  ItemType,
  KdfType,
  normalizeFolderName,
  PasswordHistoryEntry,
  StandaloneTotp,
  ThemeMode,
  VaultFolder,
  VaultItem,
  WebDavSnapshot,
  WebDavStat,
  WebDavStoredConfig
} from '../models/VaultModels';

interface LocalMeta {
  hasVault: boolean;
  saltB64: string;
  kdfType?: KdfType;
  requireUnlock: boolean;
  bioFaceOn: boolean;
  bioFingerOn: boolean;
  gestureOn: boolean;
  gesturePattern: string;
  autoLock: AutoLockOption;
  privacyMask: boolean;
  theme: ThemeMode;
  webdavConfigured: boolean;
  webdavAutoSync?: boolean;
  webdavLastSync?: string;
  webdavUrl?: string;
  webdavUser?: string;
  webdavLocalDirty?: boolean;
  webdavSnapshot?: WebDavSnapshot;
  cachedKeyB64: string;
}

interface DecryptAttempt {
  keyB64: string;
  plain: string;
  kdf: KdfType;
}

interface ParsedVaultFile {
  salt: string;
  cipher: string;
  isLegacy: boolean;
}

interface PendingWebDavOnboarding {
  url: string;
  username: string;
  password: string;
}

function copyRecord(src: Record<string, Object>): Record<string, Object> {
  const out: Record<string, Object> = {};
  const keys = Object.keys(src);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    out[k] = src[k];
  }
  return out;
}

function asStr(rec: Record<string, Object>, key: string): string {
  const v = rec[key];
  return typeof v === 'string' ? v : '';
}

function asOptStr(rec: Record<string, Object>, key: string): string | undefined {
  const v = rec[key];
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function asBool(rec: Record<string, Object>, key: string): boolean {
  const v = rec[key];
  return typeof v === 'boolean' ? v : false;
}

function normalizeItemType(raw: string): ItemType {
  if (raw === 'card' || raw === 'note' || raw === 'identity') {
    return raw;
  }
  return 'login';
}

export function normalizeWebDavUrlPreview(raw: string): string {
  const u = raw.trim();
  if (u.length === 0) {
    return '';
  }
  if (u.endsWith('/')) {
    return `${u}vault.enc`;
  }
  const schemeIdx = u.indexOf('://');
  const after = schemeIdx >= 0 ? u.slice(schemeIdx + 3) : u;
  const idx = after.lastIndexOf('/');
  if (idx === -1) {
    return `${u}/vault.enc`;
  }
  const last = after.slice(idx + 1);
  if (last.length === 0) {
    return `${u}vault.enc`;
  }
  return last.includes('.') ? u : `${u}/vault.enc`;
}

export function extractUrlHost(raw: string): string {
  const u = raw.trim();
  const schemeIdx = u.indexOf('://');
  if (schemeIdx < 0) {
    return '';
  }
  const rest = u.slice(schemeIdx + 3);
  const slashIdx = rest.indexOf('/');
  return slashIdx >= 0 ? rest.slice(0, slashIdx) : rest;
}

export function isValidWebDavUrl(raw: string): boolean {
  const u = raw.trim();
  return (
    u.startsWith('https://') ||
    u.startsWith('http://localhost') ||
    u.startsWith('http://127.0.0.1')
  );
}

@ObservedV2
export class VaultStore {
  @Trace screen: AppScreen = 'onboarding';
  @Trace activeTab: HomeTab = 'vault';
  @Trace items: VaultItem[] = [];
  @Trace folders: string[] = [];
  @Trace standaloneTotps: StandaloneTotp[] = [];

  @Trace activeCat: string = 'all';
  @Trace activeFolder: string = ALL_FOLDER_FILTER;
  @Trace searchQuery: string = '';
  @Trace totpSearch: string = '';

  @Trace requireUnlock: boolean = false;
  @Trace bioFaceOn: boolean = false;
  @Trace bioFingerOn: boolean = false;
  @Trace gestureOn: boolean = false;
  @Trace gesturePattern: string = '';
  @Trace autoLock: AutoLockOption = '5 分钟';
  @Trace privacyMask: boolean = true;
  @Trace theme: ThemeMode = 'light';

  // WebDAV reactive state
  @Trace webdavConfigured: boolean = false;
  @Trace webdavAutoSync: boolean = true;
  @Trace webdavLastSync: string = '';
  @Trace webdavUrl: string = '';
  @Trace webdavUser: string = '';
  @Trace webdavSyncing: boolean = false;
  @Trace showWebDavConflict: boolean = false;
  @Trace showRemotePwdPrompt: boolean = false;

  // Generator history (max 6)
  @Trace genHistory: string[] = [];

  // Toast HUD
  @Trace toastMsg: string = '';
  @Trace toastIsWarn: boolean = false;
  @Trace toastVisible: boolean = false;

  private dataDir: string = '';
  private masterKeyB64: string = '';
  private saltB64: string = '';
  private kdfType: KdfType = 'argon2id';
  private folderRecords: VaultFolder[] = [];
  private extraPayloadFields: Record<string, Object> = {};
  private webdavLocalDirty: boolean = false;
  private webdavSnapshot: WebDavSnapshot = { etag: '', lastModified: '', size: 0 };
  private syncDebounceTimer: number = -1;
  private toastTimer: number = -1;

  // Pending remote download when salt differs or onboarding restore
  private pendingRemoteContent: string = '';
  private pendingRemoteStat: WebDavStat | null = null;
  private pendingOnboardingWebDav: PendingWebDavOnboarding | null = null;

  init(filesDir: string): void {
    this.dataDir = filesDir;
    const meta = this.readMeta();
    if (!meta || !meta.hasVault) {
      this.screen = 'onboarding';
      return;
    }
    this.saltB64 = meta.saltB64;
    this.kdfType = meta.kdfType ?? 'argon2id';
    this.requireUnlock = meta.requireUnlock;
    this.bioFaceOn = meta.bioFaceOn;
    this.bioFingerOn = meta.bioFingerOn;
    this.gestureOn = meta.gestureOn;
    this.gesturePattern = meta.gesturePattern;
    this.autoLock = meta.autoLock;
    this.privacyMask = meta.privacyMask;
    this.theme = meta.theme;
    this.webdavConfigured = meta.webdavConfigured;
    this.webdavAutoSync = meta.webdavAutoSync ?? true;
    this.webdavLastSync = meta.webdavLastSync ?? '';
    this.webdavUrl = meta.webdavUrl ?? '';
    this.webdavUser = meta.webdavUser ?? '';
    this.webdavLocalDirty = meta.webdavLocalDirty ?? false;
    if (meta.webdavSnapshot) {
      this.webdavSnapshot = meta.webdavSnapshot;
    }
    this.syncWebDavMetaFromRustConfig();

    if (!this.requireUnlock && meta.cachedKeyB64.length > 0) {
      this.masterKeyB64 = meta.cachedKeyB64;
      try {
        this.loadAndDecryptVault();
        this.screen = 'home';
        this.onVaultUnlocked();
      } catch (_) {
        this.screen = 'unlock';
      }
    } else {
      this.screen = 'unlock';
    }
  }

  getDataDir(): string {
    return this.dataDir;
  }

  getTempPath(fileName: string): string {
    return `${this.dataDir}/${fileName}`;
  }

  private syncWebDavMetaFromRustConfig(): void {
    try {
      const stored = RustCoreBridge.getWebdavConfig(this.dataDir);
      if (stored && stored.url.length > 0) {
        this.webdavConfigured = true;
        this.webdavUrl = stored.url;
        this.webdavUser = stored.username;
      }
    } catch (_) {
      // Ignore if config.json does not exist yet
    }
  }

  private metaPath(): string {
    return `${this.dataDir}/suoxia_meta.json`;
  }

  private readMeta(): LocalMeta | null {
    try {
      if (!fileIo.accessSync(this.metaPath())) {
        return null;
      }
      const content = fileIo.readTextSync(this.metaPath());
      return JSON.parse(content) as LocalMeta;
    } catch (_) {
      return null;
    }
  }

  saveMeta(): void {
    if (this.dataDir.length === 0) {
      return;
    }
    const meta: LocalMeta = {
      hasVault: this.saltB64.length > 0,
      saltB64: this.saltB64,
      kdfType: this.kdfType,
      requireUnlock: this.requireUnlock,
      bioFaceOn: this.bioFaceOn,
      bioFingerOn: this.bioFingerOn,
      gestureOn: this.gestureOn,
      gesturePattern: this.gesturePattern,
      autoLock: this.autoLock,
      privacyMask: this.privacyMask,
      theme: this.theme,
      webdavConfigured: this.webdavConfigured,
      webdavAutoSync: this.webdavAutoSync,
      webdavLastSync: this.webdavLastSync,
      webdavUrl: this.webdavUrl,
      webdavUser: this.webdavUser,
      webdavLocalDirty: this.webdavLocalDirty,
      webdavSnapshot: this.webdavSnapshot,
      cachedKeyB64: this.requireUnlock ? '' : this.masterKeyB64,
    };
    const file = fileIo.openSync(
      this.metaPath(),
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    fileIo.writeSync(file.fd, JSON.stringify(meta));
    fileIo.closeSync(file);
  }

  private parseVaultFileContent(raw: string): ParsedVaultFile {
    const trimmed = raw.trim();
    const colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      return {
        salt: trimmed.slice(0, colonIdx),
        cipher: trimmed.slice(colonIdx + 1),
        isLegacy: false,
      };
    }
    return {
      salt: this.saltB64,
      cipher: trimmed,
      isLegacy: true,
    };
  }

  private tryDeriveAndDecrypt(
    password: string,
    saltB64: string,
    cipher: string,
    preferredKdf?: KdfType
  ): DecryptAttempt {
    const first: KdfType = preferredKdf ?? 'argon2id';
    const second: KdfType = first === 'argon2id' ? 'pbkdf2' : 'argon2id';
    try {
      const k1 = RustCoreBridge.deriveMasterKey(password, saltB64, first);
      const p1 = RustCoreBridge.decryptVault(cipher, k1);
      return { keyB64: k1, plain: p1, kdf: first };
    } catch (_) {
      const k2 = RustCoreBridge.deriveMasterKey(password, saltB64, second);
      const p2 = RustCoreBridge.decryptVault(cipher, k2);
      return { keyB64: k2, plain: p2, kdf: second };
    }
  }

  createFreshVault(masterPassword: string): boolean {
    if (masterPassword.length < 8) {
      this.showToast(t('主密码至少 8 位'), true);
      return false;
    }
    this.saltB64 = RustCoreBridge.generateSalt();
    this.kdfType = 'argon2id';
    this.masterKeyB64 = RustCoreBridge.deriveMasterKey(masterPassword, this.saltB64, 'argon2id');
    this.items = [];
    this.folderRecords = [];
    this.folders = [];
    this.standaloneTotps = [];
    this.extraPayloadFields = {};
    this.activeFolder = ALL_FOLDER_FILTER;
    this.persistVault(false);
    this.saveMeta();
    this.screen = 'home';
    this.activeTab = 'vault';
    this.showToast(t('已创建新保险箱'));
    return true;
  }

  verifyMasterPassword(password: string): boolean {
    if (password.length === 0 || this.saltB64.length === 0) {
      return false;
    }
    try {
      const raw = RustCoreBridge.loadVaultFile(this.dataDir);
      if (raw.trim().length === 0) {
        const k = RustCoreBridge.deriveMasterKey(password, this.saltB64, this.kdfType);
        return k === this.masterKeyB64;
      }
      const parsed = this.parseVaultFileContent(raw);
      const saltToUse = parsed.salt.length > 0 ? parsed.salt : this.saltB64;
      this.tryDeriveAndDecrypt(password, saltToUse, parsed.cipher, this.kdfType);
      return true;
    } catch (_) {
      return false;
    }
  }

  unlockWithPassword(masterPassword: string): boolean {
    try {
      const raw = RustCoreBridge.loadVaultFile(this.dataDir);
      const parsed = this.parseVaultFileContent(raw);
      const saltToUse = parsed.salt.length > 0 ? parsed.salt : this.saltB64;
      const attempt = this.tryDeriveAndDecrypt(masterPassword, saltToUse, parsed.cipher, this.kdfType);
      this.saltB64 = saltToUse;
      this.masterKeyB64 = attempt.keyB64;
      this.kdfType = attempt.kdf;
      this.applyDecryptedPayloadJson(attempt.plain);
      if (parsed.isLegacy) {
        this.persistVault(false);
      }
      this.saveMeta();
      this.screen = 'home';
      this.showToast(t('锁匣已解锁'));
      this.onVaultUnlocked();
      return true;
    } catch (_) {
      this.showToast(t('主密码不正确'), true);
      return false;
    }
  }

  unlockWithBiometricSuccess(): void {
    const meta = this.readMeta();
    if (this.masterKeyB64.length === 0 && meta && meta.cachedKeyB64.length > 0) {
      this.masterKeyB64 = meta.cachedKeyB64;
      try {
        this.loadAndDecryptVault();
      } catch (_) {
        // Keep current in-memory items if already loaded
      }
    }
    this.screen = 'home';
    this.showToast(t('锁匣已解锁'));
    this.onVaultUnlocked();
  }

  unlockWithGesture(pattern: string): boolean {
    if (pattern === this.gesturePattern && this.gesturePattern.length >= 4) {
      const meta = this.readMeta();
      if (this.masterKeyB64.length === 0 && meta && meta.cachedKeyB64.length > 0) {
        this.masterKeyB64 = meta.cachedKeyB64;
        try {
          this.loadAndDecryptVault();
        } catch (_) {
          // Keep in-memory state if already loaded
        }
      }
      this.screen = 'home';
      this.showToast(t('手势验证通过'));
      this.onVaultUnlocked();
      return true;
    }
    this.showToast(t('手势图案错误'), true);
    return false;
  }

  changeMasterPassword(oldPwd: string, newPwd: string): boolean {
    if (!this.verifyMasterPassword(oldPwd)) {
      this.showToast(t('当前主密码不正确'), true);
      return false;
    }
    if (newPwd.length < 8) {
      this.showToast(t('主密码至少 8 位'), true);
      return false;
    }
    // Decrypt saved WebDAV password before rotating masterKeyB64
    let plainWebDavPass = '';
    let storedWd: WebDavStoredConfig | null = null;
    if (this.webdavConfigured) {
      try {
        storedWd = RustCoreBridge.getWebdavConfig(this.dataDir);
        if (storedWd && storedWd.passwordEnc.length > 0) {
          plainWebDavPass = RustCoreBridge.decryptVault(storedWd.passwordEnc, this.masterKeyB64);
        }
      } catch (_) {
        plainWebDavPass = '';
      }
    }

    const newSalt = RustCoreBridge.generateSalt();
    const newKey = RustCoreBridge.deriveMasterKey(newPwd, newSalt, 'argon2id');
    this.saltB64 = newSalt;
    this.masterKeyB64 = newKey;
    this.kdfType = 'argon2id';

    if (storedWd && plainWebDavPass.length > 0) {
      try {
        const reEnc = RustCoreBridge.encryptVault(plainWebDavPass, newKey);
        RustCoreBridge.saveWebdavConfig(this.dataDir, storedWd.url, storedWd.username, reEnc);
      } catch (_) {
        // Ignore re-encryption error
      }
    }

    this.persistVault(true);
    this.saveMeta();
    this.showToast(t('主密码已更新'));
    return true;
  }

  private loadAndDecryptVault(): void {
    const raw = RustCoreBridge.loadVaultFile(this.dataDir);
    if (raw.trim().length === 0) {
      this.items = [];
      this.folderRecords = [];
      this.folders = [];
      this.standaloneTotps = [];
      return;
    }
    const parsed = this.parseVaultFileContent(raw);
    if (parsed.salt.length > 0) {
      this.saltB64 = parsed.salt;
    }
    const plain = RustCoreBridge.decryptVault(parsed.cipher, this.masterKeyB64);
    this.applyDecryptedPayloadJson(plain);
    if (parsed.isLegacy) {
      this.persistVault(false);
    }
  }

  private parseItemFromRaw(rec: Record<string, Object>, fallbackId: string): VaultItem {
    const histRaw = rec['passwordHistory'];
    const histList: PasswordHistoryEntry[] = [];
    if (Array.isArray(histRaw)) {
      const arr = histRaw as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const hRec = arr[i] as Record<string, Object>;
        const pw = asStr(hRec, 'password');
        if (pw.length > 0) {
          histList.push({
            password: pw,
            changedAt: asStr(hRec, 'changedAt'),
          });
        }
      }
    }

    const customRaw = rec['customFields'];
    let customFields: Record<string, string> | undefined = undefined;
    if (customRaw && typeof customRaw === 'object' && !Array.isArray(customRaw)) {
      const cRec = customRaw as Record<string, Object>;
      const cKeys = Object.keys(cRec);
      if (cKeys.length > 0) {
        const mapped: Record<string, string> = {};
        for (let i = 0; i < cKeys.length; i++) {
          const ck = cKeys[i];
          const cv = cRec[ck];
          if (typeof cv === 'string') {
            mapped[ck] = cv;
          }
        }
        customFields = mapped;
      }
    }

    const pwd = asOptStr(rec, 'password');
    const strengthStr = asStr(rec, 'strength');
    const strength =
      strengthStr === 'weak' || strengthStr === 'medium' || strengthStr === 'strong'
        ? strengthStr
        : pwd
          ? evaluatePasswordStrength(pwd)
          : undefined;

    return {
      id: asStr(rec, 'id') || fallbackId,
      type: normalizeItemType(asStr(rec, 'type')),
      title: asStr(rec, 'title'),
      folder: normalizeFolderName(asStr(rec, 'folder')),
      username: asOptStr(rec, 'username'),
      password: pwd,
      url: asOptStr(rec, 'url'),
      cardName: asOptStr(rec, 'cardName'),
      cardNumber: asOptStr(rec, 'cardNumber'),
      cardExpiry: asOptStr(rec, 'cardExpiry'),
      cardCvv: asOptStr(rec, 'cardCvv'),
      identityName: asOptStr(rec, 'identityName'),
      identityEmail: asOptStr(rec, 'identityEmail'),
      identityPhone: asOptStr(rec, 'identityPhone'),
      identityAddress: asOptStr(rec, 'identityAddress'),
      notes: asOptStr(rec, 'notes'),
      customFields: customFields,
      otpSecret: asOptStr(rec, 'otpSecret'),
      expiresAt: asOptStr(rec, 'expiresAt'),
      passwordHistory: histList.length > 0 ? histList : undefined,
      deletedAt: asOptStr(rec, 'deletedAt'),
      lastUsedAt: asOptStr(rec, 'lastUsedAt'),
      updatedAt: asStr(rec, 'updatedAt') || formatUpdatedAt(),
      strength: strength,
      isFavorite: asBool(rec, 'isFavorite'),
      ignoreSecurityWarning: asBool(rec, 'ignoreSecurityWarning'),
      rawJson: copyRecord(rec),
    };
  }

  private serializeItemToRecord(item: VaultItem): Record<string, Object> {
    const out: Record<string, Object> = item.rawJson ? copyRecord(item.rawJson) : {};
    out['id'] = item.id;
    out['type'] = item.type;
    out['title'] = item.title;
    out['folder'] = normalizeFolderName(item.folder);
    out['username'] = item.username ?? '';
    out['password'] = item.password ?? '';
    out['url'] = item.url ?? '';
    out['cardName'] = item.cardName ?? '';
    out['cardNumber'] = item.cardNumber ?? '';
    out['cardExpiry'] = item.cardExpiry ?? '';
    out['cardCvv'] = item.cardCvv ?? '';
    out['identityName'] = item.identityName ?? '';
    out['identityEmail'] = item.identityEmail ?? '';
    out['identityPhone'] = item.identityPhone ?? '';
    out['identityAddress'] = item.identityAddress ?? '';
    out['notes'] = item.notes ?? '';
    out['updatedAt'] = item.updatedAt || formatUpdatedAt();
    out['strength'] = item.strength ?? evaluatePasswordStrength(item.password ?? '');
    out['isFavorite'] = item.isFavorite === true;
    if (item.otpSecret && item.otpSecret.length > 0) {
      out['otpSecret'] = item.otpSecret;
    } else {
      out['otpSecret'] = '';
    }
    if (item.passwordHistory && item.passwordHistory.length > 0) {
      out['passwordHistory'] = item.passwordHistory as Object;
    }
    if (item.deletedAt && item.deletedAt.length > 0) {
      out['deletedAt'] = item.deletedAt;
    } else {
      // Remove deletedAt without using forbidden `delete` operator
      const cleaned: Record<string, Object> = {};
      const keys = Object.keys(out);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        if (k !== 'deletedAt') {
          cleaned[k] = out[k];
        }
      }
      return cleaned;
    }
    return out;
  }

  private applyDecryptedPayloadJson(plain: string): void {
    const root = JSON.parse(plain) as Record<string, Object>;
    const extras: Record<string, Object> = {};
    const rootKeys = Object.keys(root);
    for (let i = 0; i < rootKeys.length; i++) {
      const k = rootKeys[i];
      if (k !== 'items' && k !== 'folders' && k !== 'standaloneTotps') {
        extras[k] = root[k];
      }
    }
    this.extraPayloadFields = extras;

    // Parse items
    const parsedItems: VaultItem[] = [];
    const rawItems = root['items'];
    if (Array.isArray(rawItems)) {
      const arr = rawItems as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const rec = arr[i] as Record<string, Object>;
        parsedItems.push(this.parseItemFromRaw(rec, `item_${Date.now()}_${i}`));
      }
    }
    this.items = parsedItems;

    // Parse folders (supports both string and {id, name, icon})
    const fRecords: VaultFolder[] = [];
    const seenNames: Set<string> = new Set<string>();
    const rawFolders = root['folders'];
    if (Array.isArray(rawFolders)) {
      const arr = rawFolders as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const entry = arr[i];
        let fName = '';
        let fId = `folder_${i}_${Date.now()}`;
        let fIcon = 'folder';
        if (typeof entry === 'string') {
          fName = normalizeFolderName(entry);
        } else if (entry && typeof entry === 'object') {
          const fRec = entry as Record<string, Object>;
          fName = normalizeFolderName(asStr(fRec, 'name'));
          const origId = asStr(fRec, 'id');
          const origIcon = asStr(fRec, 'icon');
          if (origId.length > 0) {
            fId = origId;
          }
          if (origIcon.length > 0) {
            fIcon = origIcon;
          }
        }
        if (fName !== DEFAULT_FOLDER && !seenNames.has(fName)) {
          seenNames.add(fName);
          fRecords.push({ id: fId, name: fName, icon: fIcon });
        }
      }
    }
    // Also ensure any folder used by active items exists in folderRecords
    for (let i = 0; i < parsedItems.length; i++) {
      const fn = normalizeFolderName(parsedItems[i].folder);
      if (fn !== DEFAULT_FOLDER && !seenNames.has(fn)) {
        seenNames.add(fn);
        fRecords.push({ id: `folder_auto_${i}_${Date.now()}`, name: fn, icon: 'folder' });
      }
    }
    this.folderRecords = fRecords;
    this.folders = fRecords.map((f: VaultFolder) => f.name);

    // Parse standaloneTotps
    const parsedTotps: StandaloneTotp[] = [];
    const rawTotps = root['standaloneTotps'];
    if (Array.isArray(rawTotps)) {
      const arr = rawTotps as Array<Object>;
      for (let i = 0; i < arr.length; i++) {
        const tRec = arr[i] as Record<string, Object>;
        const sec = asStr(tRec, 'secret');
        if (sec.length > 0) {
          parsedTotps.push({
            id: asStr(tRec, 'id') || `t_${Date.now()}_${i}`,
            issuer: asStr(tRec, 'issuer') || t('动态令牌'),
            account: asStr(tRec, 'account'),
            secret: sec,
          });
        }
      }
    }
    this.standaloneTotps = parsedTotps;
  }

  private buildVaultPayloadJson(): string {
    const out: Record<string, Object> = copyRecord(this.extraPayloadFields);
    const serializedItems: Array<Record<string, Object>> = [];
    for (let i = 0; i < this.items.length; i++) {
      serializedItems.push(this.serializeItemToRecord(this.items[i]));
    }
    out['items'] = serializedItems as Object;
    out['folders'] = this.folderRecords as Object;
    out['standaloneTotps'] = this.standaloneTotps as Object;
    return JSON.stringify(out);
  }

  persistVault(scheduleSync: boolean = true): void {
    if (this.masterKeyB64.length === 0 || this.saltB64.length === 0) {
      return;
    }
    const plain = this.buildVaultPayloadJson();
    const cipher = RustCoreBridge.encryptVault(plain, this.masterKeyB64);
    const desktopFormat = `${this.saltB64}:${cipher}`;
    RustCoreBridge.saveVaultFile(this.dataDir, desktopFormat);

    if (scheduleSync && this.webdavConfigured) {
      this.webdavLocalDirty = true;
      this.saveMeta();
      if (this.webdavAutoSync) {
        this.scheduleDebouncedSync();
      }
    }
  }

  // ---- Folder CRUD ----
  addCustomFolder(rawName: string): boolean {
    const name = rawName.trim();
    if (name.length === 0) {
      this.showToast(t('请输入文件夹名称'), true);
      return false;
    }
    const norm = normalizeFolderName(name);
    if (norm === DEFAULT_FOLDER || name === ALL_FOLDER_FILTER || this.folders.includes(norm)) {
      this.showToast(t('文件夹已存在'), true);
      return false;
    }
    this.folderRecords.push({
      id: `folder_${Date.now()}`,
      name: norm,
      icon: 'folder',
    });
    this.folders = this.folderRecords.map((f: VaultFolder) => f.name);
    this.persistVault();
    this.showToast(t('已创建文件夹'));
    return true;
  }

  deleteCustomFolder(name: string): void {
    const norm = normalizeFolderName(name);
    if (norm === DEFAULT_FOLDER) {
      return;
    }
    const updatedItems: VaultItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (normalizeFolderName(it.folder) === norm) {
        it.folder = DEFAULT_FOLDER;
      }
      updatedItems.push(it);
    }
    this.items = updatedItems;
    this.folderRecords = this.folderRecords.filter((f: VaultFolder) => f.name !== norm);
    this.folders = this.folderRecords.map((f: VaultFolder) => f.name);
    if (this.activeFolder === norm) {
      this.activeFolder = ALL_FOLDER_FILTER;
    }
    this.persistVault();
    this.showToast(t('已删除文件夹，原凭证已移入默认文件夹'));
  }

  countItemsInFolder(folderName: string): number {
    let count = 0;
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (!it.deletedAt && normalizeFolderName(it.folder) === folderName) {
        count += 1;
      }
    }
    return count;
  }

  // ---- Item CRUD ----
  upsertItem(item: VaultItem, editingId: string): VaultItem {
    const nowStr = formatUpdatedAt();
    item.folder = normalizeFolderName(item.folder);
    item.updatedAt = nowStr;
    item.strength = evaluatePasswordStrength(item.password ?? '');

    if (editingId.length > 0) {
      const nextList: VaultItem[] = [];
      let saved: VaultItem = item;
      for (let i = 0; i < this.items.length; i++) {
        const prev = this.items[i];
        if (prev.id === editingId) {
          item.isFavorite = prev.isFavorite;
          item.rawJson = prev.rawJson;
          item.customFields = prev.customFields;
          item.expiresAt = prev.expiresAt;
          item.lastUsedAt = prev.lastUsedAt;
          item.ignoreSecurityWarning = prev.ignoreSecurityWarning;
          // Track password history if password changed
          const oldHist: PasswordHistoryEntry[] = prev.passwordHistory ? [...prev.passwordHistory] : [];
          if (prev.password && prev.password.length > 0 && item.password !== prev.password) {
            oldHist.unshift({ password: prev.password, changedAt: nowStr });
            item.passwordHistory = oldHist.slice(0, 5);
          } else {
            item.passwordHistory = oldHist.length > 0 ? oldHist : undefined;
          }
          saved = item;
          nextList.push(item);
        } else {
          nextList.push(prev);
        }
      }
      this.items = nextList;
      this.persistVault();
      return saved;
    } else {
      this.items = [item, ...this.items];
      this.persistVault();
      return item;
    }
  }

  toggleFavorite(itemId: string): boolean {
    let newState = false;
    const nextList: VaultItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (it.id === itemId) {
        it.isFavorite = !(it.isFavorite === true);
        newState = it.isFavorite;
      }
      nextList.push(it);
    }
    this.items = nextList;
    this.persistVault();
    this.showToast(newState ? t('已加星标') : t('已取消星标'));
    return newState;
  }

  moveToTrash(itemId: string): void {
    const nowStr = formatUpdatedAt();
    const nextList: VaultItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (it.id === itemId) {
        it.deletedAt = nowStr;
      }
      nextList.push(it);
    }
    this.items = nextList;
    this.persistVault();
    this.showToast(t('已移入回收站'));
  }

  restoreFromTrash(itemId: string): void {
    const nextList: VaultItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const it = this.items[i];
      if (it.id === itemId) {
        it.deletedAt = undefined;
      }
      nextList.push(it);
    }
    this.items = nextList;
    this.persistVault();
    this.showToast(t('已恢复'));
  }

  purgeItem(itemId: string): void {
    this.items = this.items.filter((it: VaultItem) => it.id !== itemId);
    this.persistVault();
    this.showToast(t('已彻底删除'));
  }

  emptyTrash(): void {
    this.items = this.items.filter((it: VaultItem) => !it.deletedAt);
    this.persistVault();
    this.showToast(t('已清空回收站'));
  }

  // ---- Standalone 2FA ----
  addStandaloneTotp(issuer: string, account: string, secret: string): void {
    const entry: StandaloneTotp = {
      id: `t_${Date.now()}`,
      issuer: issuer.trim(),
      account: account.trim(),
      secret: secret.trim(),
    };
    this.standaloneTotps = [entry, ...this.standaloneTotps];
    this.persistVault();
  }

  removeStandaloneTotp(id: string): void {
    this.standaloneTotps = this.standaloneTotps.filter((item: StandaloneTotp) => item.id !== id);
    this.persistVault();
    this.showToast(t('已移除动态令牌'));
  }

  // ---- Generator History ----
  pushGenHistory(pwd: string): void {
    if (pwd.length === 0) {
      return;
    }
    const filtered = this.genHistory.filter((x: string) => x !== pwd);
    this.genHistory = [pwd, ...filtered].slice(0, 6);
  }

  clearGenHistory(): void {
    this.genHistory = [];
    this.showToast(t('已清空生成记录'));
  }

  // ---- Lifecycle & Foreground Hooks ----
  private onVaultUnlocked(): void {
    if (this.webdavConfigured && this.webdavAutoSync) {
      this.syncWebDav(false).catch(() => {});
    }
  }

  handleForegroundResume(elapsedMs: number): void {
    if (this.screen !== 'home') {
      return;
    }
    if (this.requireUnlock) {
      let limitMs = 300000;
      if (this.autoLock === '切后台立即锁定') {
        limitMs = 0;
      } else if (this.autoLock === '1 分钟') {
        limitMs = 60000;
      } else if (this.autoLock === '5 分钟') {
        limitMs = 300000;
      } else if (this.autoLock === '15 分钟') {
        limitMs = 900000;
      }
      if (elapsedMs >= limitMs) {
        this.screen = 'unlock';
        return;
      }
    }
    // Vault stays unlocked on foreground → check WebDAV stat if auto-sync enabled
    if (this.webdavConfigured && this.webdavAutoSync) {
      this.syncWebDav(false).catch(() => {});
    }
  }

  // ---- Real Event-Driven Bidirectional WebDAV Sync ----
  private formatSyncClock(): string {
    const d = new Date();
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    return `${hh}:${mm}`;
  }

  private statDiffersFromSnapshot(stat: WebDavStat): boolean {
    if (!stat.exists) {
      return false;
    }
    const etag = stat.etag ?? '';
    const lastMod = stat.last_modified ?? '';
    const size = stat.size ?? 0;
    const snap = this.webdavSnapshot;
    if (snap.etag.length === 0 && snap.lastModified.length === 0 && snap.size === 0) {
      return true;
    }
    return etag !== snap.etag || lastMod !== snap.lastModified || size !== snap.size;
  }

  private updateSnapshotFromStat(stat: WebDavStat): void {
    this.webdavSnapshot = {
      etag: stat.etag ?? '',
      lastModified: stat.last_modified ?? '',
      size: stat.size ?? 0,
    };
  }

  private getDecryptedWebDavCredentials(): PendingWebDavOnboarding | null {
    try {
      const stored = RustCoreBridge.getWebdavConfig(this.dataDir);
      if (!stored || stored.url.length === 0 || stored.passwordEnc.length === 0) {
        return null;
      }
      const pass = RustCoreBridge.decryptVault(stored.passwordEnc, this.masterKeyB64);
      return {
        url: stored.url,
        username: stored.username,
        password: pass,
      };
    } catch (_) {
      return null;
    }
  }

  async testWebDavConnection(url: string, username: string, passwordInput: string): Promise<boolean> {
    const u = url.trim();
    const usr = username.trim();
    let pass = passwordInput;
    if (pass.length === 0 && this.webdavConfigured && this.masterKeyB64.length > 0) {
      const saved = this.getDecryptedWebDavCredentials();
      if (saved) {
        pass = saved.password;
      }
    }
    if (u.length === 0 || usr.length === 0 || pass.length === 0) {
      this.showToast(t('请先填写完整地址、账号与授权密码'), true);
      return false;
    }
    if (!isValidWebDavUrl(u)) {
      this.showToast(t('请使用 https:// 开头的加密地址'), true);
      return false;
    }
    try {
      await RustCoreBridge.webdavTestAsync(u, usr, pass);
      this.showToast(t('连接测试成功'));
      return true;
    } catch (e) {
      this.showToast((e as Error).message, true);
      return false;
    }
  }

  saveWebDavSettings(url: string, username: string, passwordInput: string): boolean {
    const u = url.trim();
    const usr = username.trim();
    if (u.length === 0 || usr.length === 0) {
      this.showToast(t('请先填写完整地址、账号与授权密码'), true);
      return false;
    }
    if (!isValidWebDavUrl(u)) {
      this.showToast(t('仅支持 https:// 服务器地址'), true);
      return false;
    }
    let passwordEnc = '';
    if (passwordInput.length > 0) {
      passwordEnc = RustCoreBridge.encryptVault(passwordInput, this.masterKeyB64);
    } else if (this.webdavConfigured) {
      const existing = RustCoreBridge.getWebdavConfig(this.dataDir);
      if (existing && existing.passwordEnc.length > 0) {
        passwordEnc = existing.passwordEnc;
      }
    }
    if (passwordEnc.length === 0) {
      this.showToast(t('请先填写完整地址、账号与授权密码'), true);
      return false;
    }
    try {
      const normalized = normalizeWebDavUrlPreview(u);
      RustCoreBridge.saveWebdavConfig(this.dataDir, normalized, usr, passwordEnc);
      this.webdavConfigured = true;
      this.webdavUrl = normalized;
      this.webdavUser = usr;
      this.saveMeta();
      this.showToast(t('WebDAV 配置已加密保存'));
      return true;
    } catch (e) {
      this.showToast((e as Error).message, true);
      return false;
    }
  }

  disconnectWebDav(): void {
    if (this.syncDebounceTimer >= 0) {
      clearTimeout(this.syncDebounceTimer);
      this.syncDebounceTimer = -1;
    }
    try {
      RustCoreBridge.clearWebdavConfig(this.dataDir);
    } catch (_) {
      // Ignore
    }
    this.webdavConfigured = false;
    this.webdavUrl = '';
    this.webdavUser = '';
    this.webdavLastSync = '';
    this.webdavLocalDirty = false;
    this.webdavSnapshot = { etag: '', lastModified: '', size: 0 };
    this.saveMeta();
    this.showToast(t('已断开 WebDAV 同步'));
  }

  private scheduleDebouncedSync(): void {
    if (this.syncDebounceTimer >= 0) {
      clearTimeout(this.syncDebounceTimer);
    }
    this.syncDebounceTimer = setTimeout(() => {
      this.syncDebounceTimer = -1;
      this.syncWebDav(false).catch(() => {});
    }, 2000);
  }

  async syncWebDav(isManual: boolean): Promise<void> {
    if (!this.webdavConfigured || this.masterKeyB64.length === 0) {
      if (isManual) {
        this.showToast(t('请先保存服务器配置'), true);
      }
      return;
    }
    if (this.webdavSyncing) {
      return;
    }
    const creds = this.getDecryptedWebDavCredentials();
    if (!creds) {
      if (isManual) {
        this.showToast(t('请先保存服务器配置'), true);
      }
      return;
    }

    this.webdavSyncing = true;
    try {
      const stat = await RustCoreBridge.webdavStatAsync(creds.url, creds.username, creds.password);
      const remoteChanged = this.statDiffersFromSnapshot(stat);

      if (remoteChanged && !this.webdavLocalDirty) {
        const dl = await RustCoreBridge.webdavDownloadAsync(creds.url, creds.username, creds.password);
        this.applyRemoteDownload(dl.content, dl.stat, isManual);
      } else if (remoteChanged && this.webdavLocalDirty) {
        this.showWebDavConflict = true;
      } else if (!stat.exists || this.webdavLocalDirty) {
        const upStat = await RustCoreBridge.webdavUploadAsync(
          this.dataDir,
          creds.url,
          creds.username,
          creds.password
        );
        this.updateSnapshotFromStat(upStat);
        this.webdavLocalDirty = false;
        this.webdavLastSync = this.formatSyncClock();
        this.saveMeta();
        if (isManual) {
          this.showToast(t('已同步至云端'));
        }
      } else if (isManual) {
        this.webdavLastSync = this.formatSyncClock();
        this.saveMeta();
        this.showToast(t('云端与本机已是最新'));
      }
    } catch (e) {
      this.showToast((e as Error).message, true);
    } finally {
      this.webdavSyncing = false;
    }
  }

  async resolveConflictUseLocal(): Promise<void> {
    this.showWebDavConflict = false;
    const creds = this.getDecryptedWebDavCredentials();
    if (!creds) {
      return;
    }
    this.webdavSyncing = true;
    try {
      const upStat = await RustCoreBridge.webdavUploadAsync(
        this.dataDir,
        creds.url,
        creds.username,
        creds.password
      );
      this.updateSnapshotFromStat(upStat);
      this.webdavLocalDirty = false;
      this.webdavLastSync = this.formatSyncClock();
      this.saveMeta();
      this.showToast(t('已用本机数据覆盖云端'));
    } catch (e) {
      this.showToast((e as Error).message, true);
    } finally {
      this.webdavSyncing = false;
    }
  }

  async resolveConflictUseRemote(): Promise<void> {
    this.showWebDavConflict = false;
    const creds = this.getDecryptedWebDavCredentials();
    if (!creds) {
      return;
    }
    this.webdavSyncing = true;
    try {
      const dl = await RustCoreBridge.webdavDownloadAsync(creds.url, creds.username, creds.password);
      this.applyRemoteDownload(dl.content, dl.stat, true);
    } catch (e) {
      this.showToast((e as Error).message, true);
    } finally {
      this.webdavSyncing = false;
    }
  }

  private applyRemoteDownload(content: string, stat: WebDavStat, notify: boolean): void {
    const parsed = this.parseVaultFileContent(content);
    if (parsed.salt.length > 0 && parsed.salt === this.saltB64 && this.masterKeyB64.length > 0) {
      try {
        const plain = RustCoreBridge.decryptVault(parsed.cipher, this.masterKeyB64);
        this.applyDecryptedPayloadJson(plain);
        RustCoreBridge.saveVaultFile(this.dataDir, `${parsed.salt}:${parsed.cipher}`);
        this.updateSnapshotFromStat(stat);
        this.webdavLocalDirty = false;
        this.webdavLastSync = this.formatSyncClock();
        this.saveMeta();
        if (notify) {
          this.showToast(t('已从云端更新'));
        }
        return;
      } catch (_) {
        // Fall through to password prompt
      }
    }
    this.pendingRemoteContent = content;
    this.pendingRemoteStat = stat;
    this.showRemotePwdPrompt = true;
  }

  async restoreFromWebDavOnboarding(url: string, username: string, password: string): Promise<boolean> {
    const u = url.trim();
    const usr = username.trim();
    if (u.length === 0 || usr.length === 0 || password.length === 0) {
      this.showToast(t('请先填写完整地址、账号与授权密码'), true);
      return false;
    }
    if (!isValidWebDavUrl(u)) {
      this.showToast(t('仅支持 https:// 服务器地址'), true);
      return false;
    }
    this.webdavSyncing = true;
    try {
      const dl = await RustCoreBridge.webdavDownloadAsync(u, usr, password);
      this.pendingRemoteContent = dl.content;
      this.pendingRemoteStat = dl.stat;
      this.pendingOnboardingWebDav = {
        url: normalizeWebDavUrlPreview(u),
        username: usr,
        password: password,
      };
      this.showRemotePwdPrompt = true;
      return true;
    } catch (e) {
      this.showToast((e as Error).message, true);
      return false;
    } finally {
      this.webdavSyncing = false;
    }
  }

  submitRemoteMasterPassword(password: string): boolean {
    if (password.length === 0) {
      this.showToast(t('请输入当前主密码'), true);
      return false;
    }
    try {
      const parsed = this.parseVaultFileContent(this.pendingRemoteContent);
      const saltToUse = parsed.salt.length > 0 ? parsed.salt : this.saltB64;
      const attempt = this.tryDeriveAndDecrypt(password, saltToUse, parsed.cipher, 'argon2id');
      this.saltB64 = saltToUse;
      this.masterKeyB64 = attempt.keyB64;
      this.kdfType = attempt.kdf;
      this.applyDecryptedPayloadJson(attempt.plain);
      RustCoreBridge.saveVaultFile(this.dataDir, `${saltToUse}:${parsed.cipher}`);
      if (this.pendingRemoteStat) {
        this.updateSnapshotFromStat(this.pendingRemoteStat);
      }
      if (this.pendingOnboardingWebDav) {
        const ob = this.pendingOnboardingWebDav;
        const encPass = RustCoreBridge.encryptVault(ob.password, this.masterKeyB64);
        RustCoreBridge.saveWebdavConfig(this.dataDir, ob.url, ob.username, encPass);
        this.webdavConfigured = true;
        this.webdavUrl = ob.url;
        this.webdavUser = ob.username;
        this.pendingOnboardingWebDav = null;
      }
      this.webdavLocalDirty = false;
      this.webdavLastSync = this.formatSyncClock();
      this.pendingRemoteContent = '';
      this.pendingRemoteStat = null;
      this.showRemotePwdPrompt = false;
      this.saveMeta();
      if (this.screen !== 'home') {
        this.screen = 'home';
        this.activeTab = 'vault';
      }
      this.showToast(t('已下载云端版本并更新本机'));
      return true;
    } catch (_) {
      this.showToast(t('主密码不正确'), true);
      return false;
    }
  }

  cancelRemoteMasterPassword(): void {
    this.pendingRemoteContent = '';
    this.pendingRemoteStat = null;
    this.pendingOnboardingWebDav = null;
    this.showRemotePwdPrompt = false;
  }

  // ---- Import & Export ----
  parseImportFile(
    source: ImportSourceKey,
    tempPath: string,
    password: string
  ): ImportParseResult {
    if (source === 'kdbx') {
      if (password.length === 0) {
        return {
          needsPassword: true,
          items: [],
          folders: [],
          totpCount: 0,
          badge: 'KeePass (.kdbx)',
        };
      }
      const rawJson = RustCoreBridge.importKdbx(tempPath, password);
      const parsed = JSON.parse(rawJson) as Record<string, Object>;
      const rawItems = parsed['items'] as Array<Object>;
      const items: VaultItem[] = [];
      const folderSet: Set<string> = new Set<string>();
      let totpCount = 0;
      if (Array.isArray(rawItems)) {
        for (let i = 0; i < rawItems.length; i++) {
          const r = rawItems[i] as Record<string, Object>;
          const folder = normalizeFolderName(asStr(r, 'folder'));
          if (folder !== DEFAULT_FOLDER) {
            folderSet.add(folder);
          }
          let otpSec = '';
          const custom = r['custom'];
          if (custom && typeof custom === 'object') {
            const cRec = custom as Record<string, Object>;
            const otpVal = asStr(cRec, 'otp');
            if (otpVal.startsWith('otpauth://')) {
              try {
                const parsedOtp = RustCoreBridge.parseOtpauthUri(otpVal);
                otpSec = parsedOtp.secret;
              } catch (_) {
                otpSec = '';
              }
            } else if (otpVal.length > 0) {
              otpSec = otpVal;
            }
          }
          if (otpSec.length > 0) {
            totpCount += 1;
          }
          const pwd = asStr(r, 'password');
          items.push({
            id: `imp_kdbx_${Date.now()}_${i}`,
            type: 'login',
            title: asStr(r, 'title') || 'Untitled',
            folder: folder,
            username: asStr(r, 'username'),
            password: pwd,
            url: asStr(r, 'url'),
            notes: asStr(r, 'notes'),
            otpSecret: otpSec.length > 0 ? otpSec : undefined,
            isFavorite: asBool(r, 'favorite'),
            expiresAt: asOptStr(r, 'expiresAt'),
            updatedAt: formatUpdatedAt(),
            strength: evaluatePasswordStrength(pwd),
          });
        }
      }
      return {
        needsPassword: false,
        items: items,
        folders: Array.from(folderSet),
        totpCount: totpCount,
        badge: 'KeePass (.kdbx)',
      };
    }

    const content = RustCoreBridge.readExportFile(tempPath);
    const trimmed = content.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      const obj = JSON.parse(trimmed) as Record<string, Object>;
      if (asBool(obj, 'isEncrypted')) {
        if (password.length === 0) {
          return {
            needsPassword: true,
            items: [],
            folders: [],
            totpCount: 0,
            badge: t('锁匣加密备份 (.json)'),
          };
        }
        const salt = asStr(obj, 'salt');
        const encPayload = asStr(obj, 'encryptedPayload');
        const kdfHint = asStr(obj, 'kdf') === 'pbkdf2' ? 'pbkdf2' : 'argon2id';
        const attempt = this.tryDeriveAndDecrypt(password, salt, encPayload, kdfHint);
        const expectedSum = asStr(obj, 'checksum');
        if (expectedSum.length > 0) {
          const actualSum = RustCoreBridge.computeSha256(attempt.plain);
          if (actualSum !== expectedSum) {
            throw new Error('ERR_CHECKSUM_MISMATCH');
          }
        }
        const plainObj = JSON.parse(attempt.plain) as Record<string, Object>;
        return this.extractItemsFromPlainJson(plainObj, t('锁匣加密备份 (.json)'));
      }
      return this.extractItemsFromPlainJson(obj, 'JSON');
    }

    // Parse CSV (Chrome / Edge / Safari / Firefox / Bitwarden)
    return this.parseCsvImport(trimmed);
  }

  private extractItemsFromPlainJson(
    obj: Record<string, Object>,
    badge: string
  ): ImportParseResult {
    const rawList = (obj['vaultItems'] ?? obj['items']) as Array<Object>;
    const items: VaultItem[] = [];
    const folderSet: Set<string> = new Set<string>();
    let totpCount = 0;

    if (Array.isArray(rawList)) {
      for (let i = 0; i < rawList.length; i++) {
        const r = rawList[i] as Record<string, Object>;
        // Handle Bitwarden export shape if `login` nested object exists
        const loginObj = r['login'];
        if (loginObj && typeof loginObj === 'object' && !Array.isArray(loginObj)) {
          const lRec = loginObj as Record<string, Object>;
          const pwd = asStr(lRec, 'password');
          const totp = asStr(lRec, 'totp');
          if (totp.length > 0) {
            totpCount += 1;
          }
          items.push({
            id: `imp_bw_${Date.now()}_${i}`,
            type: 'login',
            title: asStr(r, 'name') || 'Untitled',
            folder: DEFAULT_FOLDER,
            username: asStr(lRec, 'username'),
            password: pwd,
            notes: asStr(r, 'notes'),
            otpSecret: totp.length > 0 ? totp : undefined,
            updatedAt: formatUpdatedAt(),
            strength: evaluatePasswordStrength(pwd),
          });
        } else {
          const parsed = this.parseItemFromRaw(r, `imp_json_${Date.now()}_${i}`);
          if (parsed.folder !== DEFAULT_FOLDER) {
            folderSet.add(parsed.folder);
          }
          if (parsed.otpSecret && parsed.otpSecret.length > 0) {
            totpCount += 1;
          }
          items.push(parsed);
        }
      }
    }

    return {
      needsPassword: false,
      items: items,
      folders: Array.from(folderSet),
      totpCount: totpCount,
      badge: badge,
    };
  }

  private parseCsvLine(line: string): string[] {
    const cols: string[] = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line.charAt(i);
      if (inQuotes) {
        if (ch === '"') {
          if (i + 1 < line.length && line.charAt(i + 1) === '"') {
            cur += '"';
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          cur += ch;
        }
      } else {
        if (ch === '"') {
          inQuotes = true;
        } else if (ch === ',') {
          cols.push(cur);
          cur = '';
        } else {
          cur += ch;
        }
      }
    }
    cols.push(cur);
    return cols;
  }

  private parseCsvImport(csvText: string): ImportParseResult {
    const lines = csvText.split(/\r?\n/).filter((l: string) => l.trim().length > 0);
    if (lines.length < 2) {
      return { needsPassword: false, items: [], folders: [], totpCount: 0, badge: 'CSV' };
    }
    const headers = this.parseCsvLine(lines[0]).map((h: string) => h.trim().toLowerCase());
    const idxTitle = headers.findIndex((h: string) => h === 'name' || h === 'title');
    const idxUrl = headers.findIndex((h: string) => h === 'url' || h === 'login_uri' || h === 'website');
    const idxUser = headers.findIndex((h: string) => h === 'username' || h === 'login_username' || h === 'user');
    const idxPass = headers.findIndex((h: string) => h === 'password' || h === 'login_password');
    const idxNote = headers.findIndex((h: string) => h === 'note' || h === 'notes' || h === 'extra');
    const idxFolder = headers.findIndex((h: string) => h === 'folder' || h === 'grouping');

    const items: VaultItem[] = [];
    const folderSet: Set<string> = new Set<string>();
    for (let i = 1; i < lines.length; i++) {
      const cols = this.parseCsvLine(lines[i]);
      const getCol = (idx: number): string => (idx >= 0 && idx < cols.length ? cols[idx].trim() : '');
      const title = getCol(idxTitle) || getCol(idxUrl) || `Item ${i}`;
      const user = getCol(idxUser);
      const pass = getCol(idxPass);
      const url = getCol(idxUrl);
      const notes = getCol(idxNote);
      const folder = normalizeFolderName(getCol(idxFolder));
      if (folder !== DEFAULT_FOLDER) {
        folderSet.add(folder);
      }
      if (title.length === 0 && user.length === 0 && pass.length === 0) {
        continue;
      }
      items.push({
        id: `imp_csv_${Date.now()}_${i}`,
        type: 'login',
        title: title,
        folder: folder,
        username: user,
        password: pass,
        url: url,
        notes: notes,
        updatedAt: formatUpdatedAt(),
        strength: evaluatePasswordStrength(pass),
      });
    }
    return {
      needsPassword: false,
      items: items,
      folders: Array.from(folderSet),
      totpCount: 0,
      badge: 'CSV',
    };
  }

  executeImport(
    incoming: VaultItem[],
    strategy: ImportStrategy,
    onboardingMasterPwd?: string
  ): number {
    // If importing during onboarding, create vault first if needed
    if (this.masterKeyB64.length === 0) {
      const pwd = onboardingMasterPwd && onboardingMasterPwd.length >= 8
        ? onboardingMasterPwd
        : 'SecureVault#2026';
      this.saltB64 = RustCoreBridge.generateSalt();
      this.kdfType = 'argon2id';
      this.masterKeyB64 = RustCoreBridge.deriveMasterKey(pwd, this.saltB64, 'argon2id');
    }

    const active = this.items.filter((i: VaultItem) => !i.deletedAt);
    const existingKeys: Set<string> = new Set<string>();
    for (let i = 0; i < active.length; i++) {
      const a = active[i];
      existingKeys.add(`${a.title}|${a.username ?? a.cardNumber ?? ''}`);
    }

    const nowStr = formatUpdatedAt();
    const prepared: VaultItem[] = [];
    for (let i = 0; i < incoming.length; i++) {
      const r = incoming[i];
      r.id = `imp_${Date.now()}_${i}`;
      r.folder = normalizeFolderName(r.folder);
      r.updatedAt = nowStr;
      r.strength = evaluatePasswordStrength(r.password ?? '');
      prepared.push(r);
    }

    let addedCount = 0;
    if (strategy === 'overwrite') {
      this.items = prepared;
      this.folderRecords = [];
      addedCount = prepared.length;
    } else if (strategy === 'skip') {
      const unique: VaultItem[] = [];
      for (let i = 0; i < prepared.length; i++) {
        const r = prepared[i];
        const key = `${r.title}|${r.username ?? r.cardNumber ?? ''}`;
        if (!existingKeys.has(key)) {
          unique.push(r);
        }
      }
      this.items = [...unique, ...this.items];
      addedCount = unique.length;
    } else {
      this.items = [...prepared, ...this.items];
      addedCount = prepared.length;
    }

    // Sync folderRecords with imported folders
    const existingFolders: Set<string> = new Set<string>(this.folderRecords.map((f: VaultFolder) => f.name));
    for (let i = 0; i < this.items.length; i++) {
      const fn = normalizeFolderName(this.items[i].folder);
      if (fn !== DEFAULT_FOLDER && !existingFolders.has(fn)) {
        existingFolders.add(fn);
        this.folderRecords.push({ id: `folder_imp_${Date.now()}_${i}`, name: fn, icon: 'folder' });
      }
    }
    this.folders = this.folderRecords.map((f: VaultFolder) => f.name);

    this.persistVault();
    this.saveMeta();
    if (this.screen !== 'home') {
      this.screen = 'home';
      this.activeTab = 'vault';
    }
    const msg =
      strategy === 'overwrite'
        ? tf('已覆盖导入 {n} 条凭证', 'Overwritten with {n} credentials', { 'n': addedCount })
        : tf('已成功导入 {n} 条凭证', 'Imported {n} credentials', { 'n': addedCount });
    this.showToast(msg);
    return addedCount;
  }

  exportEncryptedJsonToTemp(tempPath: string): void {
    const serializedItems: Array<Record<string, Object>> = [];
    for (let i = 0; i < this.items.length; i++) {
      serializedItems.push(this.serializeItemToRecord(this.items[i]));
    }
    const plainPayload: Record<string, Object> = {
      'version': '1.0.0',
      'exportedAt': new Date().toISOString(),
      'folders': this.folderRecords as Object,
      'vaultItems': serializedItems as Object,
    };
    const plainStr = JSON.stringify(plainPayload);
    const checksum = RustCoreBridge.computeSha256(plainStr);
    const encPayload = RustCoreBridge.encryptVault(plainStr, this.masterKeyB64);

    const envelope: Record<string, Object> = {
      'isEncrypted': true,
      'version': '1.0.0',
      'kdf': this.kdfType,
      'salt': this.saltB64,
      'checksum': checksum,
      'encryptedPayload': encPayload,
      'hint': 'SecureVault Encrypted Backup',
    };
    RustCoreBridge.writeExportFile(tempPath, JSON.stringify(envelope, null, 2));
  }

  exportKdbxToTemp(tempPath: string, password: string): void {
    const serializedItems: Array<Record<string, Object>> = [];
    for (let i = 0; i < this.items.length; i++) {
      serializedItems.push(this.serializeItemToRecord(this.items[i]));
    }
    const itemsJson = JSON.stringify({ 'items': serializedItems });
    RustCoreBridge.exportKdbx(tempPath, itemsJson, password);
  }

  // ---- Toast ----
  showToast(msg: string, isWarn: boolean = false): void {
    this.toastMsg = msg;
    this.toastIsWarn = isWarn;
    this.toastVisible = true;
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false;
    }, 2400);
  }
}

export const vaultStore = new VaultStore();
