import { userAuth } from '@kit.UserAuthenticationKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { t } from '../i18n/AppI18n';
import { PickedFileInfo } from '../models/VaultModels';

const HUKS_KEY_ALIAS = 'suoxia_master_wrap_key';
const HUKS_AAD_BYTES: Uint8Array = new Uint8Array([83, 85, 79, 88, 73, 65]); // "SUOXIA"
const HUKS_GCM_TAG_LEN = 16;

type SingleAuthOutcome = 'success' | 'cancelled' | 'failed';

export class SecurityService {
  private static mainWindow: window.Window | null = null;

  static attachWindow(win: window.Window): void {
    SecurityService.mainWindow = win;
  }

  static applyImmersiveSystemBars(isDark: boolean): void {
    if (!SecurityService.mainWindow) {
      return;
    }
    const fgColor = isDark ? '#F8FAFC' : '#0F172A';
    const bgColor = isDark ? '#0B0F19' : '#F2F2F7';
    try {
      SecurityService.mainWindow.setWindowBackgroundColor(bgColor);
    } catch (_) {
      // ignore on unsupported window states
    }
    SecurityService.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: fgColor,
      navigationBarContentColor: fgColor,
      isStatusBarLightIcon: isDark,
      isNavigationBarLightIcon: isDark,
    }).catch(() => {});
  }

  static setPrivacyMode(enabled: boolean): void {
    if (SecurityService.mainWindow) {
      SecurityService.mainWindow.setWindowPrivacyMode(enabled).catch(() => {});
    }
  }

  static copySensitive(text: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).catch(() => {});
  }

  static openExternalUrl(context: common.UIAbilityContext, url: string): boolean {
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url,
      };
      context.startAbility(want).catch(() => {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * Pick a local file via DocumentViewPicker and copy it into app sandbox tempPath
   * so Rust Core can read it with standard POSIX file I/O.
   */
  static async pickFileToTempPath(
    context: common.UIAbilityContext,
    tempPath: string,
    fileSuffixFilters: string[]
  ): Promise<PickedFileInfo | null> {
    try {
      const docPicker = new picker.DocumentViewPicker(context);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      if (fileSuffixFilters.length > 0) {
        opts.fileSuffixFilters = fileSuffixFilters;
      }
      const uris: string[] = await docPicker.select(opts);
      if (!uris || uris.length === 0) {
        return null;
      }
      const srcUri = uris[0];
      const decoded = decodeURIComponent(srcUri);
      const lastSlash = decoded.lastIndexOf('/');
      const fileName = lastSlash >= 0 ? decoded.slice(lastSlash + 1) : decoded;

      const srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
      const dstFile = fileIo.openSync(
        tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      try {
        const buf = new ArrayBuffer(65536);
        let readLen = fileIo.readSync(srcFile.fd, buf);
        while (readLen > 0) {
          fileIo.writeSync(dstFile.fd, buf, { length: readLen });
          readLen = fileIo.readSync(srcFile.fd, buf);
        }
      } finally {
        fileIo.closeSync(srcFile);
        fileIo.closeSync(dstFile);
      }
      return { fileName, tempPath };
    } catch (_) {
      return null;
    }
  }

  /**
   * Save a sandbox file (created by Rust Core) to a user-selected location via DocumentViewPicker.
   */
  static async saveTempFileToPicker(
    context: common.UIAbilityContext,
    tempPath: string,
    suggestedFileName: string
  ): Promise<string | null> {
    const docPicker = new picker.DocumentViewPicker(context);
    const opts = new picker.DocumentSaveOptions();
    opts.newFileNames = [suggestedFileName];
    let uris: string[];
    try {
      uris = await docPicker.save(opts);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      throw new Error(errMsg.length > 0 ? errMsg : t('导出失败'));
    }
    if (!uris || uris.length === 0) {
      return null;
    }
    const dstUri = uris[0];
    let srcFile: fileIo.File | null = null;
    let dstFile: fileIo.File | null = null;
    try {
      srcFile = fileIo.openSync(tempPath, fileIo.OpenMode.READ_ONLY);
      // HarmonyOS NEXT DocumentViewPicker URIs are pre-created; using CREATE causes EPERM 13900001
      dstFile = fileIo.openSync(
        dstUri,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
      );
      const buf = new ArrayBuffer(65536);
      let readLen = fileIo.readSync(srcFile.fd, buf);
      while (readLen > 0) {
        fileIo.writeSync(dstFile.fd, buf, { length: readLen });
        readLen = fileIo.readSync(srcFile.fd, buf);
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      throw new Error(errMsg.length > 0 ? errMsg : t('写入导出文件失败'));
    } finally {
      if (srcFile !== null) {
        try {
          fileIo.closeSync(srcFile);
        } catch (_) {
          // Ignore close error
        }
      }
      if (dstFile !== null) {
        try {
          fileIo.closeSync(dstFile);
        } catch (_) {
          // Ignore close error
        }
      }
    }
    const decoded = decodeURIComponent(dstUri);
    const lastSlash = decoded.lastIndexOf('/');
    return lastSlash >= 0 ? decoded.slice(lastSlash + 1) : suggestedFileName;
  }

  private static randomBytes(length: number): Uint8Array {
    try {
      const rand = cryptoFramework.createRandom();
      const blob = rand.generateRandomSync(length);
      if (blob && blob.data && blob.data.length === length) {
        return blob.data;
      }
    } catch (_) {
      // Fallback below
    }
    const fallback = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
      fallback[i] = Math.floor(Math.random() * 256);
    }
    return fallback;
  }

  /**
   * HarmonyOS NEXT biometric auth: prefer Face, fallback to Fingerprint only on non-cancel failure.
   */
  static async authenticateBiometric(preferFace: boolean, allowFinger: boolean): Promise<boolean> {
    const authTypes: userAuth.UserAuthType[] = [];
    if (preferFace) {
      authTypes.push(userAuth.UserAuthType.FACE);
    }
    if (allowFinger) {
      authTypes.push(userAuth.UserAuthType.FINGERPRINT);
    }
    if (authTypes.length === 0) {
      return false;
    }

    for (let i = 0; i < authTypes.length; i++) {
      const outcome = await SecurityService.runSingleAuth(authTypes[i]);
      if (outcome === 'success') {
        return true;
      }
      if (outcome === 'cancelled') {
        return false;
      }
    }
    return false;
  }

  private static runSingleAuth(authType: userAuth.UserAuthType): Promise<SingleAuthOutcome> {
    return new Promise<SingleAuthOutcome>((resolve) => {
      try {
        userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL2);
        const challenge = SecurityService.randomBytes(16);
        const authParam: userAuth.AuthParam = {
          challenge,
          authType: [authType],
          authTrustLevel: userAuth.AuthTrustLevel.ATL2,
        };
        const instance = userAuth.getUserAuthInstance(authParam, { title: t('验证身份以解锁锁匣') });
        let settled = false;
        instance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            try {
              instance.off('result');
            } catch (_) {
              // Ignore cleanup error
            }
            if (settled) {
              return;
            }
            settled = true;
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve('success');
            } else if (
              result.result === userAuth.UserAuthResultCode.CANCELED ||
              result.result === userAuth.UserAuthResultCode.CANCELED_FROM_WIDGET
            ) {
              resolve('cancelled');
            } else {
              resolve('failed');
            }
          }
        });
        instance.start();
      } catch (_) {
        resolve('failed');
      }
    });
  }

  static async scanQrCode(context: common.UIAbilityContext): Promise<string | null> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true,
      };
      const result = await scanBarcode.startScanForResult(context, options);
      return result?.originalValue ?? null;
    } catch (_) {
      return null;
    }
  }

  static async ensureHuksKey(): Promise<boolean> {
    try {
      const exists = await huks.isKeyItemExist(HUKS_KEY_ALIAS, { properties: [] });
      if (exists) {
        return true;
      }
      const props: huks.HuksParam[] = [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
        },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      ];
      await huks.generateKeyItem(HUKS_KEY_ALIAS, { properties: props });
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * Wrap master key using HUKS AES-256-GCM hardware keystore.
   * Falls back cleanly to base64 encoding if HUKS is unavailable on simulator/device.
   */
  static async wrapKeyWithHuks(plain: string): Promise<string> {
    if (plain.length === 0) {
      return '';
    }
    const encoder = new util.TextEncoder();
    const plainBytes: Uint8Array = encoder.encodeInto(plain);
    const b64Helper = new util.Base64Helper();
    try {
      const ready = await SecurityService.ensureHuksKey();
      if (!ready) {
        return `plain1:${b64Helper.encodeToStringSync(plainBytes)}`;
      }
      const nonce = SecurityService.randomBytes(12);
      const props: huks.HuksParam[] = [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
        { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: HUKS_AAD_BYTES },
      ];
      const initRes = await huks.initSession(HUKS_KEY_ALIAS, { properties: props });
      const finishRes = await huks.finishSession(initRes.handle, {
        properties: props,
        inData: plainBytes,
      });
      if (finishRes.outData && finishRes.outData.length > HUKS_GCM_TAG_LEN) {
        const nonceB64 = b64Helper.encodeToStringSync(nonce);
        const cipherB64 = b64Helper.encodeToStringSync(finishRes.outData);
        return `huks1:${nonceB64}:${cipherB64}`;
      }
    } catch (_) {
      // Safe fallback below
    }
    return `plain1:${b64Helper.encodeToStringSync(plainBytes)}`;
  }

  /**
   * Unwrap master key previously protected by wrapKeyWithHuks().
   */
  static async unwrapKeyWithHuks(wrapped: string): Promise<string> {
    if (wrapped.length === 0) {
      return '';
    }
    const b64Helper = new util.Base64Helper();
    const decoder = util.TextDecoder.create('utf-8');
    try {
      if (wrapped.startsWith('plain1:')) {
        const rawBytes = b64Helper.decodeSync(wrapped.slice(7));
        return decoder.decodeToString(rawBytes);
      }
      if (wrapped.startsWith('huks1:')) {
        const rest = wrapped.slice(6);
        const sep = rest.indexOf(':');
        if (sep <= 0) {
          return '';
        }
        const nonce = b64Helper.decodeSync(rest.slice(0, sep));
        const cipherWithTag = b64Helper.decodeSync(rest.slice(sep + 1));
        if (cipherWithTag.length <= HUKS_GCM_TAG_LEN) {
          return '';
        }
        const cipherOnly = cipherWithTag.slice(0, cipherWithTag.length - HUKS_GCM_TAG_LEN);
        const aeTag = cipherWithTag.slice(cipherWithTag.length - HUKS_GCM_TAG_LEN);
        const props: huks.HuksParam[] = [
          { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
          { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
          { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
          { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
          { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
          { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
          { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: HUKS_AAD_BYTES },
          { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: aeTag },
        ];
        const initRes = await huks.initSession(HUKS_KEY_ALIAS, { properties: props });
        const finishRes = await huks.finishSession(initRes.handle, {
          properties: props,
          inData: cipherOnly,
        });
        if (finishRes.outData && finishRes.outData.length > 0) {
          return decoder.decodeToString(finishRes.outData);
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}
