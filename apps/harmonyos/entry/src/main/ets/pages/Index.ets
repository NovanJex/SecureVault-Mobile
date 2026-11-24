import { common } from '@kit.AbilityKit';
import { RustCoreBridge } from '../bridge/RustCoreBridge';
import { AboutSheet } from '../components/AboutSheets';
import {
  AddTotpSheet,
  DetailView,
  EditCredentialSheet,
  FolderManagerSheet,
  TrashSheet
} from '../components/CredentialSheets';
import {
  CreateVaultSheet,
  GestureSetupSheet,
  OnboardingView,
  UnlockView
} from '../components/OnboardingAndUnlock';
import { ColoredCharSegment, colorizePasswordSegments, getPalette, ThemePalette } from '../components/UiTheme';
import {
  ChangeMasterPwdSheet,
  ImportFlowSheet,
  VerifyPwdSheet,
  WebDavSheet
} from '../components/WebDavAndImportSheets';
import { t, tf } from '../i18n/AppI18n';
import {
  ALL_FOLDER_FILTER,
  AutoLockOption,
  ConfirmDialogRequest,
  DEFAULT_FOLDER,
  ExternalLinkRequest,
  formatDateStamp,
  HomeTab,
  LiveTotpDisplay,
  normalizeFolderName,
  StandaloneTotp,
  VaultItem
} from '../models/VaultModels';
import { SecurityService } from '../services/SecurityService';
import { extractUrlHost, vaultStore } from '../state/VaultStore';

interface LabelOption {
  key: string;
  label: string;
}

const CAT_PILLS: LabelOption[] = [
  { key: 'all', label: '全部' },
  { key: 'fav', label: '收藏' },
  { key: 'login', label: '登录' },
  { key: 'card', label: '卡券' },
  { key: 'note', label: '备忘' },
  { key: 'identity', label: '密保' },
];

const AUTO_LOCK_OPTIONS: AutoLockOption[] = [
  '切后台立即锁定',
  '1 分钟',
  '5 分钟',
  '15 分钟',
];

const BIP_SEPS: LabelOption[] = [
  { key: '-', label: '连字符 -' },
  { key: '_', label: '下划线 _' },
  { key: '.', label: '点号 .' },
  { key: ' ', label: '空格' },
];

@Entry
@ComponentV2
struct Index {
  // Sheets (Tier 2)
  @Local showCreateVaultSheet: boolean = false;
  @Local showEditSheet: boolean = false;
  @Local editingItem: VaultItem | null = null;
  @Local showAddTotpSheet: boolean = false;
  @Local showFolderSheet: boolean = false;
  @Local showTrashSheet: boolean = false;
  @Local showGestureSetup: boolean = false;
  @Local showWebDavSheet: boolean = false;
  @Local webdavOnboardingMode: boolean = false;
  @Local showImportSheet: boolean = false;
  @Local showChangePwdSheet: boolean = false;
  @Local showAboutSheet: boolean = false;
  @Local showVerifyPwdSheet: boolean = false;
  @Local pendingBioTarget: 'face' | 'finger' | '' = '';
  @Local bioSyncTick: number = 0;

  // Action Sheets (Tier 3)
  @Local showRestoreActionSheet: boolean = false;
  @Local showAutoLockSheet: boolean = false;
  @Local showExportSheet: boolean = false;

  // Centered Dialogs (Tier 4)
  @Local confirmDialog: ConfirmDialogRequest | null = null;
  @Local externalLinkDialog: ExternalLinkRequest | null = null;
  @Local remotePwdInput: string = '';
  @Local showKdbxExportDialog: boolean = false;
  @Local kdbxExportPwd: string = '';

  // Detail Push Page (Tier 1)
  @Local detailItemId: string = '';

  // Live 2FA ticker
  @Local tickNow: number = Date.now();

  // Generator state
  @Local genMode: 'random' | 'bip39' = 'random';
  @Local genLen: number = 18;
  @Local genUpper: boolean = true;
  @Local genLower: boolean = true;
  @Local genNum: boolean = true;
  @Local genSym: boolean = true;
  @Local genNoAmbiguous: boolean = true;
  @Local bipWords: number = 5;
  @Local bipSep: string = '-';
  @Local bipCap: boolean = true;
  @Local generatedPwd: string = '';

  private timerId: number = -1;

  aboutToAppear(): void {
    this.regeneratePassword();
    this.timerId = setInterval(() => {
      this.tickNow = Date.now();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
  }

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private regeneratePassword(): void {
    try {
      this.generatedPwd =
        this.genMode === 'random'
          ? RustCoreBridge.generatePassword(
              this.genLen,
              this.genUpper,
              this.genLower,
              this.genNum,
              this.genSym,
              this.genNoAmbiguous
            )
          : RustCoreBridge.generateBip39(this.bipWords, this.bipSep, this.bipCap);
      vaultStore.pushGenHistory(this.generatedPwd);
    } catch (_) {
      this.generatedPwd = '';
    }
  }

  private genStrengthLabel(): string {
    if (this.genMode === 'random') {
      const score = this.genLen * 5.9;
      if (score >= 90) {
        return t('密码强度：极强');
      }
      if (score >= 65) {
        return t('密码强度：高');
      }
      return t('密码强度：中等');
    }
    return this.bipWords >= 6 ? t('密码强度：极强') : t('密码强度：高');
  }

  private liveTotpFor(secret: string): LiveTotpDisplay {
    void this.tickNow;
    try {
      const res = RustCoreBridge.generateTotp(secret);
      const fmt = res.code.length === 6 ? `${res.code.slice(0, 3)} ${res.code.slice(3)}` : res.code;
      return { fmt: fmt, raw: res.code, rem: res.remaining };
    } catch (_) {
      return { fmt: '--- ---', raw: '', rem: 30 };
    }
  }

  private filteredVaultItems(): VaultItem[] {
    const q = vaultStore.searchQuery.trim().toLowerCase();
    const out: VaultItem[] = [];
    for (let i = 0; i < vaultStore.items.length; i++) {
      const it = vaultStore.items[i];
      if (it.deletedAt) {
        continue;
      }
      if (
        vaultStore.activeFolder !== ALL_FOLDER_FILTER &&
        normalizeFolderName(it.folder) !== vaultStore.activeFolder
      ) {
        continue;
      }
      if (vaultStore.activeCat === 'fav' && !it.isFavorite) {
        continue;
      }
      if (
        vaultStore.activeCat !== 'all' &&
        vaultStore.activeCat !== 'fav' &&
        it.type !== vaultStore.activeCat
      ) {
        continue;
      }
      if (q.length > 0) {
        const hay = `${it.title} ${it.username ?? ''} ${it.url ?? ''} ${it.cardNumber ?? ''}`.toLowerCase();
        if (!hay.includes(q)) {
          continue;
        }
      }
      out.push(it);
    }
    return out;
  }

  private filteredTotps(): StandaloneTotp[] {
    const q = vaultStore.totpSearch.trim().toLowerCase();
    if (q.length === 0) {
      return vaultStore.standaloneTotps;
    }
    return vaultStore.standaloneTotps.filter((tok: StandaloneTotp) => {
      return tok.issuer.toLowerCase().includes(q) || tok.account.toLowerCase().includes(q);
    });
  }

  private activeVaultCount(): number {
    let c = 0;
    for (let i = 0; i < vaultStore.items.length; i++) {
      if (!vaultStore.items[i].deletedAt) {
        c += 1;
      }
    }
    return c;
  }

  private trashedCount(): number {
    let c = 0;
    for (let i = 0; i < vaultStore.items.length; i++) {
      if (vaultStore.items[i].deletedAt) {
        c += 1;
      }
    }
    return c;
  }

  private webdavOuterSubtitle(): string {
    if (!vaultStore.webdavConfigured) {
      return '';
    }
    const host = extractUrlHost(vaultStore.webdavUrl);
    const syncPart =
      vaultStore.webdavLastSync.length > 0
        ? tf('上次同步 {t}', 'Last synced {t}', { 't': vaultStore.webdavLastSync })
        : (vaultStore.webdavAutoSync ? t('自动同步已开启') : t('手动同步'));
    return host.length > 0 ? `${host} · ${syncPart}` : syncPart;
  }

  private async runExportJson(): Promise<void> {
    this.showExportSheet = false;
    const ctx = getContext(this) as common.UIAbilityContext;
    const fileName = `SecureVault_Backup_${formatDateStamp()}.json`;
    const tempPath = vaultStore.getTempPath(fileName);
    try {
      vaultStore.exportEncryptedJsonToTemp(tempPath);
      const savedName = await SecurityService.saveTempFileToPicker(ctx, tempPath, fileName);
      if (savedName) {
        vaultStore.showToast(tf('已保存：{f}', 'Saved: {f}', { 'f': savedName }));
      }
    } catch (e) {
      vaultStore.showToast((e as Error).message, true);
    }
  }

  private async runExportKdbx(password: string): Promise<void> {
    if (password.length < 4) {
      vaultStore.showToast(t('请为导出的 .kdbx 文件设置保护密码（至少 4 位）。'), true);
      return;
    }
    this.showKdbxExportDialog = false;
    this.kdbxExportPwd = '';
    const ctx = getContext(this) as common.UIAbilityContext;
    const fileName = `SecureVault_${formatDateStamp()}.kdbx`;
    const tempPath = vaultStore.getTempPath(fileName);
    try {
      vaultStore.exportKdbxToTemp(tempPath, password);
      const savedName = await SecurityService.saveTempFileToPicker(ctx, tempPath, fileName);
      if (savedName) {
        vaultStore.showToast(tf('已保存：{f}', 'Saved: {f}', { 'f': savedName }));
      }
    } catch (e) {
      vaultStore.showToast((e as Error).message, true);
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (vaultStore.screen === 'onboarding') {
          OnboardingView({
            onCreateVault: () => {
              this.showCreateVaultSheet = true;
            },
            onRestoreBackup: () => {
              this.showRestoreActionSheet = true;
            },
          })
        } else if (vaultStore.screen === 'unlock') {
          UnlockView()
        } else {
          this.MainShell()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.p().bgPage)

      // Tier 4 Centered Alert Dialog: Generic Binary Confirmation
      if (this.confirmDialog !== null) {
        this.CenteredConfirmOverlay(this.confirmDialog as ConfirmDialogRequest)
      }

      // Tier 4 Centered Alert Dialog: External Link Confirmation
      if (this.externalLinkDialog !== null) {
        this.ExternalLinkOverlay(this.externalLinkDialog as ExternalLinkRequest)
      }

      // Tier 4 Centered Alert Dialog: Remote Salt Master Password Prompt
      if (vaultStore.showRemotePwdPrompt) {
        this.RemoteMasterPwdOverlay()
      }

      // Tier 4 Centered Alert Dialog: KDBX Export Password
      if (this.showKdbxExportDialog) {
        this.KdbxExportPwdOverlay()
      }

      // Bottom Toast HUD
      if (vaultStore.toastVisible) {
        Row({ space: 8 }) {
          Text(vaultStore.toastIsWarn ? '!' : '✓')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(vaultStore.toastIsWarn ? '#FBBF24' : '#34D399')
          Text(vaultStore.toastMsg)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .maxLines(2)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#F20F172A')
        .borderRadius(24)
        .margin({ bottom: 84, left: 24, right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showCreateVaultSheet, this.CreateVaultSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showRestoreActionSheet, this.RestoreActionSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
    .bindSheet($$this.showEditSheet, this.EditSheetBuilder(), {
      detents: [SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showAddTotpSheet, this.AddTotpSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showFolderSheet, this.FolderSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showTrashSheet, this.TrashSheetBuilder(), {
      detents: [SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showGestureSetup, this.GestureSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
    .bindSheet($$this.showWebDavSheet, this.WebDavSheetBuilder(), {
      detents: [SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showImportSheet, this.ImportSheetBuilder(), {
      detents: [SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showChangePwdSheet, this.ChangePwdSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showAboutSheet, this.AboutSheetBuilder(), {
      detents: [SheetSize.LARGE],
      dragBar: true,
    })
    .bindSheet($$this.showVerifyPwdSheet, this.VerifyPwdSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
    .bindSheet($$this.showAutoLockSheet, this.AutoLockActionSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
    .bindSheet($$this.showExportSheet, this.ExportActionSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
    .bindSheet(vaultStore.showWebDavConflict, this.WebDavConflictActionSheetBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
      onDisappear: () => {
        vaultStore.showWebDavConflict = false;
      },
    })
  }

  // ---- Sheet Builders ----
  @Builder
  CreateVaultSheetBuilder() {
    CreateVaultSheet({
      onClose: () => {
        this.showCreateVaultSheet = false;
      },
    })
  }

  @Builder
  RestoreActionSheetBuilder() {
    Column({ space: 10 }) {
      Text(t('选择恢复方式'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)
        .padding({ bottom: 2 })

      Button(t('从 WebDAV 云端恢复'))
        .width('100%')
        .height(46)
        .borderRadius(14)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.p().bgCard)
        .fontColor(this.p().fgMain)
        .border({ width: 1, color: this.p().border })
        .onClick(() => {
          this.showRestoreActionSheet = false;
          this.webdavOnboardingMode = true;
          this.showWebDavSheet = true;
        })

      Button(t('导入本地备份文件'))
        .width('100%')
        .height(46)
        .borderRadius(14)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.p().bgCard)
        .fontColor(this.p().fgMain)
        .border({ width: 1, color: this.p().border })
        .onClick(() => {
          this.showRestoreActionSheet = false;
          this.showImportSheet = true;
        })

      Button(t('取消'))
        .width('100%')
        .height(44)
        .borderRadius(14)
        .fontSize(13)
        .backgroundColor(this.p().bgSub)
        .fontColor(this.p().fgMain)
        .onClick(() => {
          this.showRestoreActionSheet = false;
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  @Builder
  EditSheetBuilder() {
    EditCredentialSheet({
      editItem: this.editingItem,
      onClose: () => {
        this.showEditSheet = false;
      },
      onSaved: (saved: VaultItem) => {
        if (this.detailItemId.length > 0 && this.detailItemId === saved.id) {
          this.detailItemId = saved.id;
        }
        this.showEditSheet = false;
      },
    })
  }

  @Builder
  AddTotpSheetBuilder() {
    AddTotpSheet({
      onClose: () => {
        this.showAddTotpSheet = false;
      },
    })
  }

  @Builder
  FolderSheetBuilder() {
    FolderManagerSheet({
      onClose: () => {
        this.showFolderSheet = false;
      },
      onRequestConfirm: (req: ConfirmDialogRequest) => {
        this.confirmDialog = req;
      },
    })
  }

  @Builder
  TrashSheetBuilder() {
    TrashSheet({
      onClose: () => {
        this.showTrashSheet = false;
      },
      onRequestConfirm: (req: ConfirmDialogRequest) => {
        this.confirmDialog = req;
      },
    })
  }

  @Builder
  GestureSheetBuilder() {
    GestureSetupSheet({
      onClose: () => {
        this.showGestureSetup = false;
      },
    })
  }

  @Builder
  WebDavSheetBuilder() {
    WebDavSheet({
      isOnboardingRestore: this.webdavOnboardingMode,
      onClose: () => {
        this.showWebDavSheet = false;
        this.webdavOnboardingMode = false;
      },
      onRequestConfirm: (req: ConfirmDialogRequest) => {
        this.confirmDialog = req;
      },
    })
  }

  @Builder
  ImportSheetBuilder() {
    ImportFlowSheet({
      onClose: () => {
        this.showImportSheet = false;
      },
      onRequestConfirm: (req: ConfirmDialogRequest) => {
        this.confirmDialog = req;
      },
    })
  }

  @Builder
  ChangePwdSheetBuilder() {
    ChangeMasterPwdSheet({
      onClose: () => {
        this.showChangePwdSheet = false;
      },
    })
  }

  @Builder
  AboutSheetBuilder() {
    AboutSheet({
      onClose: () => {
        this.showAboutSheet = false;
      },
      onOpenExternalLink: (req: ExternalLinkRequest) => {
        this.externalLinkDialog = req;
      },
    })
  }

  @Builder
  VerifyPwdSheetBuilder() {
    VerifyPwdSheet({
      onCancel: () => {
        this.showVerifyPwdSheet = false;
        this.pendingBioTarget = '';
        this.bioSyncTick += 1;
      },
      onVerified: () => {
        if (this.pendingBioTarget === 'face') {
          vaultStore.bioFaceOn = true;
          vaultStore.showToast(`${t('面容识别')} ${t('已开启')}`);
        } else if (this.pendingBioTarget === 'finger') {
          vaultStore.bioFingerOn = true;
          vaultStore.showToast(`${t('指纹识别')} ${t('已开启')}`);
        }
        vaultStore.saveMeta();
        this.showVerifyPwdSheet = false;
        this.pendingBioTarget = '';
      },
    })
  }

  @Builder
  AutoLockActionSheetBuilder() {
    Column({ space: 12 }) {
      Text(t('自动锁定'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)

      Column() {
        ForEach(AUTO_LOCK_OPTIONS, (opt: AutoLockOption, idx: number) => {
          if (idx > 0) {
            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
          }
          Row() {
            Text(t(opt))
              .fontSize(14)
              .fontWeight(vaultStore.autoLock === opt ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(vaultStore.autoLock === opt ? this.p().brand : this.p().fgMain)
              .layoutWeight(1)
            if (vaultStore.autoLock === opt) {
              Text('✓').fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.p().brand)
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            vaultStore.autoLock = opt;
            vaultStore.saveMeta();
            this.showAutoLockSheet = false;
            vaultStore.showToast(
              tf('自动锁定已设为：{v}', 'Auto-lock set to: {v}', { 'v': t(opt) })
            );
          })
        })
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  @Builder
  ExportActionSheetBuilder() {
    Column({ space: 12 }) {
      Text(t('导出加密备份'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)

      Column() {
        Row() {
          Text(t('导出为 锁匣加密备份 (.json)'))
            .fontSize(14)
            .fontColor(this.p().fgMain)
            .layoutWeight(1)
          Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
        }
        .width('100%')
        .height(50)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.runExportJson();
        })

        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

        Row() {
          Text(t('导出为 KeePass (.kdbx)'))
            .fontSize(14)
            .fontColor(this.p().fgMain)
            .layoutWeight(1)
          Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
        }
        .width('100%')
        .height(50)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showExportSheet = false;
          this.kdbxExportPwd = '';
          this.showKdbxExportDialog = true;
        })
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  @Builder
  WebDavConflictActionSheetBuilder() {
    Column({ space: 12 }) {
      Text(t('发现同步冲突'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)
      Text(t('本机与云端的备份数据均有更新，请选择保留哪一份：'))
        .fontSize(12)
        .fontColor(this.p().fgMain)
        .opacity(0.65)
        .textAlign(TextAlign.Center)

      Button(t('用本机覆盖云端'))
        .width('100%')
        .height(44)
        .borderRadius(12)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.p().brand)
        .fontColor('#FFFFFF')
        .onClick(() => {
          vaultStore.resolveConflictUseLocal();
        })

      Button(t('用云端覆盖本机'))
        .width('100%')
        .height(44)
        .borderRadius(12)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.p().bgCard)
        .fontColor(this.p().fgMain)
        .border({ width: 1, color: this.p().border })
        .onClick(() => {
          vaultStore.resolveConflictUseRemote();
        })

      Text(t('取消'))
        .fontSize(13)
        .fontColor(this.p().fgMain)
        .opacity(0.6)
        .padding({ top: 6, bottom: 6 })
        .onClick(() => {
          vaultStore.showWebDavConflict = false;
        })
    }
    .padding(18)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  // ---- Tier 4 Centered Alert Dialog Overlays ----
  @Builder
  CenteredConfirmOverlay(req: ConfirmDialogRequest) {
    Stack() {
      Column({ space: 14 }) {
        Text(req.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .textAlign(TextAlign.Center)

        Text(req.message)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.p().fgMain)
          .opacity(0.65)
          .textAlign(TextAlign.Center)

        Row({ space: 10 }) {
          Button(t('取消'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .backgroundColor(this.p().bgSub)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.confirmDialog = null;
            })
          Button(req.confirmLabel)
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(req.isDanger ? this.p().danger : this.p().brand)
            .fontColor('#FFFFFF')
            .onClick(() => {
              const fn = req.onConfirm;
              this.confirmDialog = null;
              fn();
            })
        }.width('100%')
      }
      .width('84%')
      .constraintSize({ maxWidth: 320 })
      .padding(20)
      .borderRadius(20)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder
  ExternalLinkOverlay(req: ExternalLinkRequest) {
    Stack() {
      Column({ space: 14 }) {
        Text(tf('将在浏览器中打开{title}', 'Open {title} in Browser', { 'title': req.title }))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .textAlign(TextAlign.Center)

        Text(req.url)
          .fontSize(11)
          .fontColor(this.p().fgMain)
          .opacity(0.75)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding(10)
          .borderRadius(12)
          .backgroundColor(this.p().bgSub)
          .border({ width: 1, color: this.p().border })

        Row({ space: 10 }) {
          Button(t('取消'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .backgroundColor(this.p().bgSub)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.externalLinkDialog = null;
            })
          Button(t('前往打开'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().brand)
            .fontColor('#FFFFFF')
            .onClick(() => {
              const url = req.url;
              this.externalLinkDialog = null;
              const ctx = getContext(this) as common.UIAbilityContext;
              SecurityService.openExternalUrl(ctx, url);
              vaultStore.showToast(t('已在浏览器打开'));
            })
        }.width('100%')
      }
      .width('84%')
      .constraintSize({ maxWidth: 320 })
      .padding(20)
      .borderRadius(20)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder
  RemoteMasterPwdOverlay() {
    Stack() {
      Column({ space: 14 }) {
        Text(t('输入云端保险箱主密码'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .textAlign(TextAlign.Center)

        Text(t('云端备份使用了不同的主密码或加密盐，请输入对应的主密码以解密并同步。'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.p().fgMain)
          .opacity(0.65)
          .textAlign(TextAlign.Center)

        Row() {
          TextInput({ placeholder: t('输入主密码'), text: this.remotePwdInput })
            .type(InputType.Password)
            .showPasswordIcon(false)
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .placeholderColor(this.p().placeholder)
            .placeholderFont({ size: 12 })
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height('100%')
            .onChange((v: string) => {
              this.remotePwdInput = v;
            })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.p().bgSub)
        .border({ width: 1, color: this.p().border })

        Row({ space: 10 }) {
          Button(t('取消'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .backgroundColor(this.p().bgSub)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.remotePwdInput = '';
              vaultStore.cancelRemoteMasterPassword();
            })
          Button(t('解密并同步'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().brand)
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (vaultStore.submitRemoteMasterPassword(this.remotePwdInput)) {
                this.remotePwdInput = '';
              }
            })
        }.width('100%')
      }
      .width('84%')
      .constraintSize({ maxWidth: 320 })
      .padding(20)
      .borderRadius(20)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder
  KdbxExportPwdOverlay() {
    Stack() {
      Column({ space: 14 }) {
        Text(t('设置 KeePass 导出密码'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .textAlign(TextAlign.Center)

        Text(t('请为导出的 .kdbx 文件设置保护密码（至少 4 位）。'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.p().fgMain)
          .opacity(0.65)
          .textAlign(TextAlign.Center)

        Row() {
          TextInput({ placeholder: t('输入导出密码'), text: this.kdbxExportPwd })
            .type(InputType.Password)
            .showPasswordIcon(false)
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .placeholderColor(this.p().placeholder)
            .placeholderFont({ size: 12 })
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height('100%')
            .onChange((v: string) => {
              this.kdbxExportPwd = v;
            })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.p().bgSub)
        .border({ width: 1, color: this.p().border })

        Row({ space: 10 }) {
          Button(t('取消'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .backgroundColor(this.p().bgSub)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.showKdbxExportDialog = false;
              this.kdbxExportPwd = '';
            })
          Button(t('导出'))
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().brand)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.runExportKdbx(this.kdbxExportPwd);
            })
        }.width('100%')
      }
      .width('84%')
      .constraintSize({ maxWidth: 320 })
      .padding(20)
      .borderRadius(20)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  // ---- Main 4-Tab Shell ----
  @Builder
  MainShell() {
    Column() {
      Column() {
        if (this.detailItemId.length > 0) {
          DetailView({
            itemId: this.detailItemId,
            tickNow: this.tickNow,
            onBack: () => {
              this.detailItemId = '';
            },
            onEdit: (item: VaultItem) => {
              this.editingItem = item;
              this.showEditSheet = true;
            },
            onRequestConfirm: (req: ConfirmDialogRequest) => {
              this.confirmDialog = req;
            },
          })
        } else if (vaultStore.activeTab === 'vault') {
          this.VaultTab()
        } else if (vaultStore.activeTab === 'totp') {
          this.TotpTab()
        } else if (vaultStore.activeTab === 'generator') {
          this.GeneratorTab()
        } else {
          this.PreferencesTab()
        }
      }
      .layoutWeight(1)
      .width('100%')

      if (this.detailItemId.length === 0) {
        Row() {
          this.NavBtn('vault', '🛡', t('保险箱'))
          this.NavBtn('totp', '⏱', t('验证器'))
          this.NavBtn('generator', '✦', t('生成器'))
          this.NavBtn('settings', '⚙', t('首选项'))
        }
        .width('100%')
        .height(60)
        .backgroundColor(this.p().bgCard)
        .border({ width: { top: 0.5 }, color: this.p().divider })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  NavBtn(tab: HomeTab, icon: string, label: string) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(16)
        .fontColor(vaultStore.activeTab === tab ? this.p().brand : this.p().fgMain)
        .opacity(vaultStore.activeTab === tab ? 1 : 0.45)
      Text(label)
        .fontSize(11)
        .fontWeight(vaultStore.activeTab === tab ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(vaultStore.activeTab === tab ? this.p().brand : this.p().fgMain)
        .opacity(vaultStore.activeTab === tab ? 1 : 0.55)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      vaultStore.activeTab = tab;
    })
  }

  // ---- TAB 1: VAULT ----
  @Builder
  VaultTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 10 }) {
        // Header
        Row() {
          Column({ space: 3 }) {
            Text(t('保险箱'))
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.p().fgMain)

            if (vaultStore.activeFolder === ALL_FOLDER_FILTER) {
              Text(tf('共 {n} 条凭证', '{n} credentials', { 'n': this.activeVaultCount() }))
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
            } else {
              Row({ space: 4 }) {
                Text(
                  vaultStore.activeFolder === DEFAULT_FOLDER
                    ? t('默认')
                    : vaultStore.activeFolder
                )
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.p().brand)
                Text('✕')
                  .fontSize(10)
                  .fontColor(this.p().brand)
              }
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
              .backgroundColor(this.p().brandSoft)
              .onClick(() => {
                vaultStore.activeFolder = ALL_FOLDER_FILTER;
              })
            }
          }.alignItems(HorizontalAlign.Start)

          Row({ space: 8 }) {
            Stack() {
              Text('📁').fontSize(15)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.showFolderSheet = true;
            })

            Stack({ alignContent: Alignment.TopEnd }) {
              Stack() {
                Text('🗑').fontSize(15)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor(this.p().bgCard)
              .border({ width: 1, color: this.p().border })

              if (this.trashedCount() > 0) {
                Text(`${this.trashedCount()}`)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .padding({ left: 4, right: 4 })
                  .height(16)
                  .borderRadius(8)
                  .backgroundColor(this.p().danger)
                  .offset({ x: 3, y: -3 })
              }
            }
            .onClick(() => {
              this.showTrashSheet = true;
            })
          }
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)

        // Search Box (h=36, leading 16vp icon, 12fp text)
        Row({ space: 8 }) {
          Text('🔍').fontSize(13).opacity(0.45)
          TextInput({ placeholder: t('搜索标题、账号或网址'), text: vaultStore.searchQuery })
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .placeholderColor(this.p().placeholder)
            .placeholderFont({ size: 12 })
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .height('100%')
            .onChange((v: string) => {
              vaultStore.searchQuery = v;
            })
        }
        .width('100%')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.p().bgCard)
        .border({ width: 1, color: this.p().border })

        // Category Pills
        Scroll() {
          Row({ space: 6 }) {
            ForEach(CAT_PILLS, (opt: LabelOption) => {
              Text(t(opt.label))
                .fontSize(12)
                .fontWeight(vaultStore.activeCat === opt.key ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(vaultStore.activeCat === opt.key ? '#FFFFFF' : this.p().fgMain)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(vaultStore.activeCat === opt.key ? this.p().brand : this.p().bgCard)
                .border({
                  width: 1,
                  color: vaultStore.activeCat === opt.key ? this.p().brand : this.p().border,
                })
                .onClick(() => {
                  vaultStore.activeCat = opt.key;
                })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // List or Empty State
        if (this.filteredVaultItems().length === 0) {
          Column({ space: 6 }) {
            Text(this.activeVaultCount() === 0 ? t('暂无凭证') : t('未找到匹配的凭证'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.p().fgMain)
              .opacity(0.55)
            if (this.activeVaultCount() === 0) {
              Text(t('点击右下角 + 添加第一条凭证'))
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.45)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.filteredVaultItems(), (item: VaultItem) => {
              ListItem() {
                Row({ space: 12 }) {
                  Stack() {
                    Text(item.title.length > 0 ? item.title.charAt(0).toUpperCase() : '?')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.p().brand)
                  }
                  .width(38)
                  .height(38)
                  .borderRadius(11)
                  .backgroundColor(this.p().brandSoft)

                  Column({ space: 2 }) {
                    Row({ space: 6 }) {
                      Text(item.title)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.p().fgMain)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (item.isFavorite) {
                        Text('★').fontSize(11).fontColor('#FBBF24')
                      }
                      if (item.otpSecret && item.otpSecret.length > 0) {
                        Text('2FA')
                          .fontSize(10)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(this.p().success)
                          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                          .borderRadius(4)
                          .backgroundColor(this.p().successSoft)
                      }
                    }
                    Text(
                      item.username ||
                        item.cardNumber ||
                        item.identityName ||
                        t(normalizeFolderName(item.folder))
                    )
                      .fontSize(12)
                      .fontColor(this.p().fgMain)
                      .opacity(0.55)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Button(t('复制'))
                    .height(28)
                    .fontSize(11)
                    .borderRadius(14)
                    .backgroundColor(this.p().brandSoft)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      const val =
                        item.password || item.cardNumber || item.notes || item.identityPhone || '';
                      SecurityService.copySensitive(val);
                      vaultStore.showToast(t('已复制'));
                    })
                }
                .width('100%')
                .padding(14)
                .borderRadius(16)
                .backgroundColor(this.p().bgCard)
                .border({ width: 1, color: this.p().border })
                .onClick(() => {
                  this.detailItemId = item.id;
                })
              }
            }, (item: VaultItem) => `${item.id}_${item.updatedAt}_${item.isFavorite ? '1' : '0'}`)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ bottom: 72 })
          .scrollBar(BarState.Off)
        }
      }
      .padding({ left: 16, right: 16, top: 8 })
      .width('100%')
      .height('100%')

      // FAB (+)
      Button('+')
        .width(48)
        .height(48)
        .borderRadius(24)
        .fontSize(22)
        .backgroundColor(this.p().brand)
        .fontColor('#FFFFFF')
        .margin({ right: 16, bottom: 16 })
        .shadow({ radius: 12, color: '#404F46E5', offsetY: 4 })
        .onClick(() => {
          this.editingItem = null;
          this.showEditSheet = true;
        })
    }
    .width('100%')
    .height('100%')
  }

  // ---- TAB 2: AUTHENTICATOR (2FA) ----
  @Builder
  TotpTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 10 }) {
        Column({ space: 2 }) {
          Text(t('验证器')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
          Text(
            tf('共 {n} 个动态令牌', '{n} 2FA tokens', { 'n': vaultStore.standaloneTotps.length })
          )
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .opacity(0.55)
        }.width('100%').alignItems(HorizontalAlign.Start)

        // Search Box (h=36)
        Row({ space: 8 }) {
          Text('🔍').fontSize(13).opacity(0.45)
          TextInput({ placeholder: t('搜索令牌名称或备注账号'), text: vaultStore.totpSearch })
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .placeholderColor(this.p().placeholder)
            .placeholderFont({ size: 12 })
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .height('100%')
            .onChange((v: string) => {
              vaultStore.totpSearch = v;
            })
        }
        .width('100%')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor(this.p().bgCard)
        .border({ width: 1, color: this.p().border })

        if (this.filteredTotps().length === 0) {
          Column({ space: 6 }) {
            Text(t('暂无动态令牌'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.p().fgMain)
              .opacity(0.55)
            Text(t('点击右下角 + 扫码或手动添加'))
              .fontSize(12)
              .fontColor(this.p().fgMain)
              .opacity(0.45)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.filteredTotps(), (tok: StandaloneTotp) => {
              ListItem() {
                this.TotpTokenCard(tok)
              }
            }, (tok: StandaloneTotp) => tok.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ bottom: 72 })
          .scrollBar(BarState.Off)
        }
      }
      .padding({ left: 16, right: 16, top: 8 })
      .width('100%')
      .height('100%')

      Button('+')
        .width(48)
        .height(48)
        .borderRadius(24)
        .fontSize(22)
        .backgroundColor(this.p().brand)
        .fontColor('#FFFFFF')
        .margin({ right: 16, bottom: 16 })
        .shadow({ radius: 12, color: '#404F46E5', offsetY: 4 })
        .onClick(() => {
          this.showAddTotpSheet = true;
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TotpTokenCard(tok: StandaloneTotp) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(tok.issuer)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)
        Text(tok.account || t('动态令牌'))
          .fontSize(12)
          .fontColor(this.p().fgMain)
          .opacity(0.55)
        Text(this.liveTotpFor(tok.secret).fmt)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontFamily('monospace')
          .fontColor(this.liveTotpFor(tok.secret).rem <= 5 ? this.p().danger : this.p().brand)
          .margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Stack() {
          Circle({ width: 38, height: 38 })
            .fill(Color.Transparent)
            .stroke(this.liveTotpFor(tok.secret).rem <= 5 ? this.p().danger : this.p().brand)
            .strokeWidth(2)
          Text(`${this.liveTotpFor(tok.secret).rem}s`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.liveTotpFor(tok.secret).rem <= 5 ? this.p().danger : this.p().brand)
        }
        Text(t('删除'))
          .fontSize(11)
          .fontColor(this.p().danger)
          .opacity(0.75)
          .onClick(() => {
            this.confirmDialog = {
              title: t('移除动态令牌？'),
              message: t('移除后将不再生成该服务的动态验证码，请确认已在对应平台解绑或保留了备份密钥。'),
              confirmLabel: t('确认移除'),
              isDanger: true,
              onConfirm: () => {
                vaultStore.removeStandaloneTotp(tok.id);
              },
            };
          })
      }.alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.p().bgCard)
    .border({ width: 1, color: this.p().border })
    .onClick(() => {
      SecurityService.copySensitive(this.liveTotpFor(tok.secret).raw);
      vaultStore.showToast(t('已复制验证码'));
    })
  }

  // ---- TAB 3: GENERATOR ----
  @Builder
  GeneratorTab() {
    Scroll() {
      Column({ space: 14 }) {
        // Header + Mode Segmented Switch
        Row() {
          Text(t('生成器')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
          Row({ space: 2 }) {
            Text(t('随机密码'))
              .fontSize(12)
              .fontWeight(this.genMode === 'random' ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.genMode === 'random' ? this.p().segThumbText : this.p().fgMain)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(8)
              .backgroundColor(this.genMode === 'random' ? this.p().segThumb : Color.Transparent)
              .onClick(() => {
                this.genMode = 'random';
                this.regeneratePassword();
              })
            Text(t('助记词'))
              .fontSize(12)
              .fontWeight(this.genMode === 'bip39' ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.genMode === 'bip39' ? this.p().segThumbText : this.p().fgMain)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(8)
              .backgroundColor(this.genMode === 'bip39' ? this.p().segThumb : Color.Transparent)
              .onClick(() => {
                this.genMode = 'bip39';
                this.regeneratePassword();
              })
          }
          .padding(3)
          .borderRadius(11)
          .backgroundColor(this.p().segTrack)
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)

        // Colored Password Output Card
        Column({ space: 12 }) {
          Text() {
            ForEach(colorizePasswordSegments(this.generatedPwd), (seg: ColoredCharSegment) => {
              Span(seg.text).fontColor(seg.color).fontSize(16).fontFamily('monospace')
            })
          }
          .width('100%')
          .constraintSize({ minHeight: 46 })
          .lineHeight(24)

          Row() {
            Text(this.genStrengthLabel())
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6EE7B7')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(12)
              .backgroundColor('#2610B981')

            Row({ space: 8 }) {
              Button(t('换一个'))
                .height(30)
                .fontSize(12)
                .borderRadius(8)
                .backgroundColor('#1E293B')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.regeneratePassword();
                })
              Button(t('复制'))
                .height(30)
                .fontSize(12)
                .borderRadius(8)
                .backgroundColor(this.p().brand)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  SecurityService.copySensitive(this.generatedPwd);
                  vaultStore.showToast(t('已复制密码'));
                })
            }
          }.width('100%').justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor('#0F172A')

        // Controls Card (inset grouped)
        Column() {
          if (this.genMode === 'random') {
            Column({ space: 4 }) {
              Row() {
                Text(t('密码长度')).fontSize(14).fontColor(this.p().fgMain)
                Text(`${this.genLen}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontFamily('monospace')
                  .fontColor(this.p().brand)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)

              Slider({ value: this.genLen, min: 8, max: 48, step: 1 })
                .selectedColor(this.p().brand)
                .onChange((v: number) => {
                  const next = Math.round(v);
                  if (next !== this.genLen) {
                    this.genLen = next;
                    this.regeneratePassword();
                  }
                })
            }.width('100%').padding(16)

            this.GenToggleRow(t('大写字母 (A-Z)'), this.genUpper, (on: boolean) => {
              this.genUpper = on;
              this.regeneratePassword();
            })
            this.GenToggleRow(t('小写字母 (a-z)'), this.genLower, (on: boolean) => {
              this.genLower = on;
              this.regeneratePassword();
            })
            this.GenToggleRow(t('数字 (0-9)'), this.genNum, (on: boolean) => {
              this.genNum = on;
              this.regeneratePassword();
            })
            this.GenToggleRow(t('特殊符号 (!@#$%)'), this.genSym, (on: boolean) => {
              this.genSym = on;
              this.regeneratePassword();
            })
            this.GenToggleRow(t('排除易混淆字符 (0/O, 1/l/I)'), this.genNoAmbiguous, (on: boolean) => {
              this.genNoAmbiguous = on;
              this.regeneratePassword();
            })
          } else {
            Column({ space: 4 }) {
              Row() {
                Text(t('助记词数量')).fontSize(14).fontColor(this.p().fgMain)
                Text(`${this.bipWords}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontFamily('monospace')
                  .fontColor(this.p().brand)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)

              Slider({ value: this.bipWords, min: 3, max: 10, step: 1 })
                .selectedColor(this.p().brand)
                .onChange((v: number) => {
                  const next = Math.round(v);
                  if (next !== this.bipWords) {
                    this.bipWords = next;
                    this.regeneratePassword();
                  }
                })
            }.width('100%').padding(16)

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            Column({ space: 8 }) {
              Text(t('分隔符')).fontSize(14).fontColor(this.p().fgMain).width('100%')
              Row({ space: 4 }) {
                ForEach(BIP_SEPS, (opt: LabelOption) => {
                  Text(t(opt.label))
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.bipSep === opt.key ? '#FFFFFF' : this.p().fgMain)
                    .padding({ top: 7, bottom: 7 })
                    .borderRadius(8)
                    .backgroundColor(this.bipSep === opt.key ? this.p().brand : Color.Transparent)
                    .onClick(() => {
                      this.bipSep = opt.key;
                      this.regeneratePassword();
                    })
                })
              }
              .width('100%')
              .padding(4)
              .borderRadius(12)
              .backgroundColor(this.p().bgSub)
              .border({ width: 1, color: this.p().border })
            }.width('100%').padding(16)

            this.GenToggleRow(t('单词首字母大写'), this.bipCap, (on: boolean) => {
              this.bipCap = on;
              this.regeneratePassword();
            })
          }
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(this.p().bgCard)
        .border({ width: 1, color: this.p().border })

        // Recent History (max 6, Clear hidden when empty)
        Column({ space: 6 }) {
          Row() {
            Text(t('最近生成'))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
            if (vaultStore.genHistory.length > 0) {
              Text(t('清空'))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().danger)
                .onClick(() => {
                  this.confirmDialog = {
                    title: t('清空最近生成记录？'),
                    message: t('清空后将无法找回此前生成的临时密码，请确认重要密码已保存至保险箱。'),
                    confirmLabel: t('确认清空'),
                    isDanger: true,
                    onConfirm: () => {
                      vaultStore.clearGenHistory();
                    },
                  };
                })
            }
          }.width('100%').padding({ left: 4, right: 4 }).justifyContent(FlexAlign.SpaceBetween)

          Column() {
            if (vaultStore.genHistory.length === 0) {
              Text(t('暂无记录'))
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.45)
                .padding(16)
                .width('100%')
                .textAlign(TextAlign.Center)
            } else {
              ForEach(vaultStore.genHistory, (pwd: string, idx: number) => {
                if (idx > 0) {
                  Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                }
                Row({ space: 10 }) {
                  Text(pwd)
                    .fontSize(12)
                    .fontFamily('monospace')
                    .fontColor(this.p().fgMain)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(t('复制'))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      SecurityService.copySensitive(pwd);
                      vaultStore.showToast(t('已复制密码'));
                    })
                }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
              }, (pwd: string) => pwd)
            }
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })
        }
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  GenToggleRow(label: string, isOn: boolean, onToggle: (on: boolean) => void) {
    Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
    Row() {
      Text(label).fontSize(14).fontColor(this.p().fgMain).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.p().brand)
        .onChange((val: boolean) => {
          onToggle(val);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  // ---- TAB 4: PREFERENCES ----
  @Builder
  PreferencesTab() {
    Scroll() {
      Column({ space: 16 }) {
        Text(t('首选项'))
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .width('100%')

        // Group 1: Security & Privacy
        Column({ space: 6 }) {
          Text(t('安全与隐私'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().fgMain)
            .opacity(0.55)
            .padding({ left: 8 })
            .width('100%')

          Column() {
            Row() {
              Text(t('修改主密码')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
              Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showChangePwdSheet = true;
            })

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(t('应用锁')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                Text(t('开启后启动应用需验证身份')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: vaultStore.requireUnlock })
                .selectedColor(this.p().brand)
                .onChange((on: boolean) => {
                  vaultStore.requireUnlock = on;
                  vaultStore.saveMeta();
                })
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

            if (vaultStore.requireUnlock) {
              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('面容识别')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('设备支持时优先使用面容解锁')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: vaultStore.bioFaceOn })
                  .id(`bio_face_${this.bioSyncTick}`)
                  .selectedColor(this.p().brand)
                  .onChange((on: boolean) => {
                    if (on && !vaultStore.bioFaceOn) {
                      this.pendingBioTarget = 'face';
                      this.showVerifyPwdSheet = true;
                    } else if (!on && vaultStore.bioFaceOn) {
                      vaultStore.bioFaceOn = false;
                      vaultStore.saveMeta();
                    }
                  })
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('指纹识别')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('面容不可用或失败时快速切换指纹')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: vaultStore.bioFingerOn })
                  .id(`bio_finger_${this.bioSyncTick}`)
                  .selectedColor(this.p().brand)
                  .onChange((on: boolean) => {
                    if (on && !vaultStore.bioFingerOn) {
                      this.pendingBioTarget = 'finger';
                      this.showVerifyPwdSheet = true;
                    } else if (!on && vaultStore.bioFingerOn) {
                      vaultStore.bioFingerOn = false;
                      vaultStore.saveMeta();
                    }
                  })
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('手势密码')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('绘制九宫格图案，作为快捷或备用解锁方式')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Row({ space: 4 }) {
                  Text(vaultStore.gestureOn ? t('已开启') : t('未设置'))
                    .fontSize(12)
                    .fontColor(this.p().fgMain)
                    .opacity(0.6)
                  Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                this.showGestureSetup = true;
              })

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              Row() {
                Text(t('自动锁定')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
                Row({ space: 4 }) {
                  Text(t(vaultStore.autoLock)).fontSize(12).fontColor(this.p().fgMain).opacity(0.6)
                  Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.showAutoLockSheet = true;
              })
            }

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(t('防截屏与后台隐私保护')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                Text(t('禁止截屏录屏，切出应用时自动保护')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: vaultStore.privacyMask })
                .selectedColor(this.p().brand)
                .onChange((on: boolean) => {
                  vaultStore.privacyMask = on;
                  SecurityService.setPrivacyMode(on);
                  vaultStore.saveMeta();
                })
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })
        }

        // Group 2: Sync & Backup
        Column({ space: 6 }) {
          Text(t('同步与备份'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().fgMain)
            .opacity(0.55)
            .padding({ left: 8 })
            .width('100%')

          Column() {
            // WebDAV Row
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(t('WebDAV 同步')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                if (vaultStore.webdavConfigured) {
                  Text(this.webdavOuterSubtitle())
                    .fontSize(11)
                    .fontColor(this.p().fgMain)
                    .opacity(0.55)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              Row({ space: 6 }) {
                if (vaultStore.webdavConfigured) {
                  Circle({ width: 7, height: 7 }).fill(this.p().success)
                  Text(t('已连接')).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.p().success)
                } else {
                  Text(t('未配置')).fontSize(12).fontColor(this.p().fgMain).opacity(0.6)
                }
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 13, bottom: 13 })
            .onClick(() => {
              this.webdavOnboardingMode = false;
              this.showWebDavSheet = true;
            })

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            // Import Row
            Row() {
              Text(t('导入凭证')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
              Row({ space: 4 }) {
                Text('JSON / KDBX / CSV').fontSize(12).fontColor(this.p().fgMain).opacity(0.6)
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showImportSheet = true;
            })

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            // Export Row
            Row() {
              Text(t('导出加密备份')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
              Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showExportSheet = true;
            })
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })
        }

        // Group 3: General (NO language switcher!)
        Column({ space: 6 }) {
          Text(t('通用'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().fgMain)
            .opacity(0.55)
            .padding({ left: 8 })
            .width('100%')

          Column() {
            Row() {
              Text(t('外观模式')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
              Row({ space: 2 }) {
                Text(t('浅色'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(vaultStore.theme === 'light' ? this.p().segThumbText : this.p().fgMain)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .borderRadius(8)
                  .backgroundColor(vaultStore.theme === 'light' ? this.p().segThumb : Color.Transparent)
                  .onClick(() => {
                    vaultStore.theme = 'light';
                    vaultStore.saveMeta();
                  })
                Text(t('深色'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(vaultStore.theme === 'dark' ? this.p().segThumbText : this.p().fgMain)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .borderRadius(8)
                  .backgroundColor(vaultStore.theme === 'dark' ? this.p().segThumb : Color.Transparent)
                  .onClick(() => {
                    vaultStore.theme = 'dark';
                    vaultStore.saveMeta();
                  })
              }
              .padding(3)
              .borderRadius(10)
              .backgroundColor(this.p().segTrack)
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            Row() {
              Text(t('关于锁匣')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain).layoutWeight(1)
              Row({ space: 4 }) {
                Text('v1.0.0').fontSize(12).fontColor(this.p().fgMain).opacity(0.6)
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showAboutSheet = true;
            })
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })
        }
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
