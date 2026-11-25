import { taskpool } from '@kit.ArkTS';
import suoxiaNapi from 'libsuoxia_napi.so';
import {
  ParsedOtpUri,
  TotpCodeResult,
  WebDavDownload,
  WebDavStat,
  WebDavStoredConfig
} from '../models/VaultModels';

interface RustEnvelope<T> {
  ok: boolean;
  data?: T;
  error?: string;
}

@Concurrent
function invokeNativeInTaskPool(cmd: string, argsJson: string): string {
  return suoxiaNapi.svInvoke(cmd, argsJson);
}

export class RustCoreBridge {
  static invoke<T>(cmd: string, args: Record<string, Object | string | number | boolean> = {}): T {
    const raw: string = suoxiaNapi.svInvoke(cmd, JSON.stringify(args));
    const parsed = JSON.parse(raw) as RustEnvelope<T>;
    if (!parsed.ok) {
      throw new Error(parsed.error ?? 'ERR_RUST_CORE');
    }
    return parsed.data as T;
  }

  static async invokeAsync<T>(
    cmd: string,
    args: Record<string, Object | string | number | boolean> = {}
  ): Promise<T> {
    const argsJson = JSON.stringify(args);
    let raw: string;
    try {
      const task = new taskpool.Task(invokeNativeInTaskPool, cmd, argsJson);
      raw = (await taskpool.execute(task)) as string;
    } catch (_) {
      raw = suoxiaNapi.svInvoke(cmd, argsJson);
    }
    const parsed = JSON.parse(raw) as RustEnvelope<T>;
    if (!parsed.ok) {
      throw new Error(parsed.error ?? 'ERR_RUST_CORE');
    }
    return parsed.data as T;
  }

  static generateSalt(): string {
    return RustCoreBridge.invoke<string>('generate_salt');
  }

  static deriveMasterKey(password: string, saltB64: string, kdf: string = 'argon2id'): string {
    return RustCoreBridge.invoke<string>('derive_master_key', {
      'password': password,
      'saltB64': saltB64,
      'kdf': kdf,
    });
  }

  static async deriveMasterKeyAsync(
    password: string,
    saltB64: string,
    kdf: string = 'argon2id'
  ): Promise<string> {
    return RustCoreBridge.invokeAsync<string>('derive_master_key', {
      'password': password,
      'saltB64': saltB64,
      'kdf': kdf,
    });
  }

  static encryptVault(plaintext: string, keyB64: string): string {
    return RustCoreBridge.invoke<string>('encrypt_vault', {
      'plaintext': plaintext,
      'keyB64': keyB64,
    });
  }

  static decryptVault(ciphertextB64: string, keyB64: string): string {
    return RustCoreBridge.invoke<string>('decrypt_vault', {
      'ciphertextB64': ciphertextB64,
      'keyB64': keyB64,
    });
  }

  static saveVaultFile(dataDir: string, ciphertextB64: string): void {
    RustCoreBridge.invoke<null>('save_vault_file', {
      'dataDir': dataDir,
      'ciphertextB64': ciphertextB64,
    });
  }

  static loadVaultFile(dataDir: string): string {
    return RustCoreBridge.invoke<string>('load_vault_file', {
      'dataDir': dataDir,
    });
  }

  static computeSha256(content: string): string {
    return RustCoreBridge.invoke<string>('compute_sha256', {
      'content': content,
    });
  }

  static writeExportFile(path: string, content: string): void {
    RustCoreBridge.invoke<null>('write_export_file', {
      'path': path,
      'content': content,
    });
  }

  static readExportFile(path: string): string {
    return RustCoreBridge.invoke<string>('read_export_file', {
      'path': path,
    });
  }

  static generateTotp(secret: string): TotpCodeResult {
    return RustCoreBridge.invoke<TotpCodeResult>('generate_totp', {
      'secret': secret,
    });
  }

  static parseOtpauthUri(uri: string): ParsedOtpUri {
    return RustCoreBridge.invoke<ParsedOtpUri>('parse_otpauth_uri', {
      'uri': uri,
    });
  }

  static generatePassword(
    length: number,
    upper: boolean,
    lower: boolean,
    numbers: boolean,
    symbols: boolean,
    excludeAmbiguous: boolean
  ): string {
    return RustCoreBridge.invoke<string>('generate_password', {
      'length': length,
      'upper': upper,
      'lower': lower,
      'numbers': numbers,
      'symbols': symbols,
      'excludeAmbiguous': excludeAmbiguous,
    });
  }

  static generateBip39(words: number, sep: string, capitalize: boolean): string {
    return RustCoreBridge.invoke<string>('generate_bip39', {
      'words': words,
      'sep': sep,
      'capitalize': capitalize,
    });
  }

  static exportKdbx(path: string, itemsJson: string, password: string): void {
    RustCoreBridge.invoke<null>('export_kdbx', {
      'path': path,
      'itemsJson': itemsJson,
      'password': password,
    });
  }

  static async exportKdbxAsync(path: string, itemsJson: string, password: string): Promise<void> {
    await RustCoreBridge.invokeAsync<null>('export_kdbx', {
      'path': path,
      'itemsJson': itemsJson,
      'password': password,
    });
  }

  static importKdbx(path: string, password: string): string {
    return RustCoreBridge.invoke<string>('import_kdbx', {
      'path': path,
      'password': password,
    });
  }

  static async importKdbxAsync(path: string, password: string): Promise<string> {
    return RustCoreBridge.invokeAsync<string>('import_kdbx', {
      'path': path,
      'password': password,
    });
  }

  static webdavTest(url: string, username: string, password: string): string {
    return RustCoreBridge.invoke<string>('webdav_test', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static async webdavTestAsync(url: string, username: string, password: string): Promise<string> {
    return RustCoreBridge.invokeAsync<string>('webdav_test', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static webdavStat(url: string, username: string, password: string): WebDavStat {
    return RustCoreBridge.invoke<WebDavStat>('webdav_stat', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static async webdavStatAsync(url: string, username: string, password: string): Promise<WebDavStat> {
    return RustCoreBridge.invokeAsync<WebDavStat>('webdav_stat', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static webdavUpload(dataDir: string, url: string, username: string, password: string): WebDavStat {
    return RustCoreBridge.invoke<WebDavStat>('webdav_upload', {
      'dataDir': dataDir,
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static async webdavUploadAsync(
    dataDir: string,
    url: string,
    username: string,
    password: string
  ): Promise<WebDavStat> {
    return RustCoreBridge.invokeAsync<WebDavStat>('webdav_upload', {
      'dataDir': dataDir,
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static webdavDownload(url: string, username: string, password: string): WebDavDownload {
    return RustCoreBridge.invoke<WebDavDownload>('webdav_download', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static async webdavDownloadAsync(
    url: string,
    username: string,
    password: string
  ): Promise<WebDavDownload> {
    return RustCoreBridge.invokeAsync<WebDavDownload>('webdav_download', {
      'url': url,
      'username': username,
      'password': password,
    });
  }

  static getWebdavConfig(dataDir: string): WebDavStoredConfig | null {
    const res = RustCoreBridge.invoke<WebDavStoredConfig | null>('get_webdav_config', {
      'dataDir': dataDir,
    });
    return res ?? null;
  }

  static saveWebdavConfig(dataDir: string, url: string, username: string, passwordEnc: string): void {
    RustCoreBridge.invoke<null>('save_webdav_config', {
      'dataDir': dataDir,
      'url': url,
      'username': username,
      'passwordEnc': passwordEnc,
    });
  }

  static clearWebdavConfig(dataDir: string): void {
    RustCoreBridge.invoke<null>('clear_webdav_config', {
      'dataDir': dataDir,
    });
  }
}
