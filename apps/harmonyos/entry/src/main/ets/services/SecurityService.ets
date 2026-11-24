import { userAuth } from '@kit.UserAuthenticationKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { t } from '../i18n/AppI18n';
import { PickedFileInfo } from '../models/VaultModels';

const HUKS_KEY_ALIAS = 'suoxia_master_wrap_key';

export class SecurityService {
  private static mainWindow: window.Window | null = null;

  static attachWindow(win: window.Window): void {
    SecurityService.mainWindow = win;
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
    try {
      const docPicker = new picker.DocumentViewPicker(context);
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [suggestedFileName];
      const uris: string[] = await docPicker.save(opts);
      if (!uris || uris.length === 0) {
        return null;
      }
      const dstUri = uris[0];
      const srcFile = fileIo.openSync(tempPath, fileIo.OpenMode.READ_ONLY);
      const dstFile = fileIo.openSync(
        dstUri,
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
      const decoded = decodeURIComponent(dstUri);
      const lastSlash = decoded.lastIndexOf('/');
      return lastSlash >= 0 ? decoded.slice(lastSlash + 1) : suggestedFileName;
    } catch (_) {
      return null;
    }
  }

  /**
   * HarmonyOS NEXT biometric auth: prefer Face, fallback to Fingerprint.
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
      const ok = await SecurityService.runSingleAuth(authTypes[i]);
      if (ok) {
        return true;
      }
    }
    return false;
  }

  private static runSingleAuth(authType: userAuth.UserAuthType): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL2);
        const challenge = new Uint8Array(16);
        const authParam: userAuth.AuthParam = {
          challenge,
          authType: [authType],
          authTrustLevel: userAuth.AuthTrustLevel.ATL2,
        };
        const instance = userAuth.getUserAuthInstance(authParam, { title: t('验证身份以解锁锁匣') });
        instance.on('result', {
          onResult(result) {
            resolve(result.result === userAuth.UserAuthResultCode.SUCCESS);
          }
        });
        instance.start();
      } catch (_) {
        resolve(false);
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

  static async ensureHuksKey(): Promise<void> {
    try {
      const exists = await huks.isKeyItemExist(HUKS_KEY_ALIAS, { properties: [] });
      if (exists) {
        return;
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
    } catch (_) {
      // Fallback handled cleanly by caller
    }
  }
}
