import { common } from '@kit.AbilityKit';
import { t, tf } from '../i18n/AppI18n';
import {
  ConfirmDialogRequest,
  ImportSourceKey,
  ImportStep,
  ImportStrategy,
  VaultItem,
  WebDavPreset,
  WebDavPresetKey
} from '../models/VaultModels';
import { SecurityService } from '../services/SecurityService';
import { normalizeWebDavUrlPreview, vaultStore } from '../state/VaultStore';
import { getPalette, ThemePalette } from './UiTheme';

const WEBDAV_PRESETS: WebDavPreset[] = [
  {
    key: 'generic',
    label: '通用 WebDAV',
    placeholder: 'https://your-server.com/dav/SecureVault/',
    tip: '适用 Alist / InfiniCLOUD 等任意标准 HTTPS WebDAV 服务',
  },
  {
    key: 'nextcloud',
    label: 'Nextcloud',
    placeholder: 'https://cloud.example.com/remote.php/dav/files/username/SecureVault/',
    tip: '路径位于「文件 → 设置」，需在「安全」中创建应用密码',
  },
  {
    key: 'nas',
    label: 'NAS',
    placeholder: 'https://nas.example.com:5006/SecureVault/',
    tip: '适用群晖 / 飞牛 / 威联通等，需开启 HTTPS WebDAV 端口',
  },
  {
    key: 'jianguoyun',
    label: '坚果云',
    placeholder: 'https://dav.jianguoyun.com/dav/SecureVault/',
    tip: '需在网页版「安全选项 → 第三方应用」生成专用密码',
  },
];

@ComponentV2
export struct WebDavSheet {
  @Param isOnboardingRestore: boolean = false;
  @Param onClose: () => void = () => {};
  @Param onRequestConfirm: (req: ConfirmDialogRequest) => void = () => {};

  @Local preset: WebDavPresetKey = 'generic';
  @Local guideOpen: boolean = false;
  @Local wdUrl: string = '';
  @Local wdUser: string = '';
  @Local wdPass: string = '';
  @Local showPass: boolean = false;
  @Local testing: boolean = false;

  aboutToAppear(): void {
    this.wdUrl = vaultStore.webdavUrl;
    this.wdUser = vaultStore.webdavUser;
    this.wdPass = '';
  }

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private currentPreset(): WebDavPreset {
    for (let i = 0; i < WEBDAV_PRESETS.length; i++) {
      if (WEBDAV_PRESETS[i].key === this.preset) {
        return WEBDAV_PRESETS[i];
      }
    }
    return WEBDAV_PRESETS[0];
  }

  build() {
    Column() {
      // Header
      Row() {
        Text(t('关闭'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
        Text(this.isOnboardingRestore ? t('从 WebDAV 云端恢复') : t('WebDAV 同步'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Row() {
          if (vaultStore.webdavConfigured) {
            Circle({ width: 8, height: 8 }).fill(this.p().success)
          }
        }.width(36).justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 14 }) {
          // Collapsible Universal Guide
          Column() {
            Row({ space: 8 }) {
              Stack() {
                Circle({ width: 20, height: 20 }).fill(this.p().brandSoft)
                Text('?').fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.p().brand)
              }
              Text(t('不知道怎么填？查看通用图文指引'))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().fgMain)
                .layoutWeight(1)
              Text(this.guideOpen ? '▲' : '▼')
                .fontSize(10)
                .fontColor(this.p().fgMain)
                .opacity(0.5)
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .onClick(() => {
              this.guideOpen = !this.guideOpen;
            })

            if (this.guideOpen) {
              Divider().strokeWidth(0.5).color(this.p().divider)
              Column({ space: 10 }) {
                // Native schematic card
                Column({ space: 8 }) {
                  Row({ space: 6 }) {
                    Column({ space: 2 }) {
                      Text(t('锁匣本机加密')).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
                      Text(t('高强度本地加密')).fontSize(10).fontColor(this.p().brand)
                    }
                    .layoutWeight(1)
                    .padding(8)
                    .borderRadius(10)
                    .backgroundColor(this.p().brandSoft)

                    Column({ space: 2 }) {
                      Text('vault.enc')
                        .fontSize(9)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(8)
                        .backgroundColor(this.p().brand)
                      Text('───▶').fontSize(10).fontColor(this.p().brand)
                    }

                    Column({ space: 2 }) {
                      Text(t('你的网盘 / NAS')).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
                      Text(t('仅存加密文件')).fontSize(10).fontColor(this.p().success)
                    }
                    .layoutWeight(1)
                    .padding(8)
                    .borderRadius(10)
                    .backgroundColor(this.p().successSoft)
                  }.width('100%')

                  Column({ space: 4 }) {
                    Text(t('在任意网盘 / NAS 后台「WebDAV 设置」页找到这 3 项：'))
                      .fontSize(10)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().fgMain)
                      .opacity(0.6)
                    Text(t('1. 服务器地址：https://.../dav/文件夹/'))
                      .fontSize(10)
                      .fontColor(this.p().brand)
                    Text(t('2. 账号 + 3. 应用专用密码（非网盘登录密码）'))
                      .fontSize(10)
                      .fontColor(this.p().fgMain)
                      .opacity(0.8)
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding(8)
                  .borderRadius(10)
                  .backgroundColor(this.p().bgCard)
                }
                .width('100%')
                .padding(10)
                .borderRadius(12)
                .backgroundColor(this.p().bgSub)
                .border({ width: 1, color: this.p().border })

                // 3-step text
                Column({ space: 6 }) {
                  Text(t('第 1 步 · 开启 WebDAV 并复制地址：在你的网盘或 NAS 后台开启 WebDAV（需 https://），直接填目录即可，程序会自动补全 /vault.enc。'))
                    .fontSize(11).lineHeight(17).fontColor(this.p().fgMain).opacity(0.8)
                  Text(t('第 2 步 · 生成应用专用密码：大多数网盘禁止直接用登录密码连接 WebDAV，请在网盘「安全设置 / 第三方应用」中新建一个授权密码。'))
                    .fontSize(11).lineHeight(17).fontColor(this.p().fgMain).opacity(0.8)
                  Text(t('第 3 步 · 多端保持一致：手机端与电脑端填写相同服务器地址并使用相同主密码，即可随时双向同步。'))
                    .fontSize(11).lineHeight(17).fontColor(this.p().fgMain).opacity(0.8)
                }.width('100%').alignItems(HorizontalAlign.Start)
              }.padding(14)
            }
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })

          // Provider Presets
          Column({ space: 6 }) {
            Text(t('常用服务参考格式（可选）'))
              .fontSize(11)
              .fontColor(this.p().fgMain)
              .opacity(0.55)
              .padding({ left: 4 })
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(WEBDAV_PRESETS, (pr: WebDavPreset) => {
                Text(t(pr.label))
                  .fontSize(11)
                  .fontWeight(this.preset === pr.key ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.preset === pr.key ? this.p().brand : this.p().fgMain)
                  .opacity(this.preset === pr.key ? 1 : 0.75)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .margin({ right: 6, bottom: 6 })
                  .borderRadius(8)
                  .backgroundColor(this.preset === pr.key ? this.p().brandSoft : this.p().bgCard)
                  .border({
                    width: 1,
                    color: this.preset === pr.key ? this.p().brand : this.p().border,
                  })
                  .onClick(() => {
                    this.preset = pr.key;
                  })
              })
            }.width('100%')

            Text(t(this.currentPreset().tip))
              .fontSize(11)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
              .padding({ left: 4, right: 4 })
              .width('100%')
          }

          // Server URL
          Column({ space: 6 }) {
            Text(t('服务器地址 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row() {
              TextInput({ placeholder: this.currentPreset().placeholder, text: this.wdUrl })
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.wdUrl = v;
                })
            }.width('100%').height(40).padding({ left: 12, right: 12 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })

            if (normalizeWebDavUrlPreview(this.wdUrl).length > 0) {
              Text(
                tf('实际同步文件：{url}', 'Sync target: {url}', {
                  'url': normalizeWebDavUrlPreview(this.wdUrl),
                })
              )
                .fontSize(10)
                .fontColor(this.p().brand)
                .padding({ left: 4, right: 4 })
                .width('100%')
            }
          }

          // Username
          Column({ space: 6 }) {
            Text(t('账号 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row() {
              TextInput({ placeholder: t('输入网盘 / NAS 用户名或邮箱'), text: this.wdUser })
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.wdUser = v;
                })
            }.width('100%').height(40).padding({ left: 12, right: 12 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          // Password with eye
          Column({ space: 6 }) {
            Text(t('应用专用密码 / 授权码 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row({ space: 6 }) {
              TextInput({
                placeholder:
                  vaultStore.webdavConfigured && !this.isOnboardingRestore
                    ? t('留空则沿用已保存的授权密码')
                    : t('输入 WebDAV 专用密码'),
                text: this.wdPass,
              })
                .type(this.showPass ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.wdPass = v;
                })
              Text(this.showPass ? t('隐藏') : t('显示'))
                .fontSize(11)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
                .padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showPass = !this.showPass;
                })
            }.width('100%').height(40).padding({ left: 12, right: 10 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          if (!this.isOnboardingRestore) {
            // Auto-Sync Toggle
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(t('自动同步')).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                Text(t('启动或修改凭证后自动与云端保持一致'))
                  .fontSize(11)
                  .fontColor(this.p().fgMain)
                  .opacity(0.55)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: vaultStore.webdavAutoSync })
                .selectedColor(this.p().brand)
                .onChange((on: boolean) => {
                  vaultStore.webdavAutoSync = on;
                  vaultStore.saveMeta();
                  vaultStore.showToast(on ? t('已开启自动同步') : t('已关闭自动同步'));
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            if (vaultStore.webdavConfigured) {
              Row() {
                Row({ space: 4 }) {
                  Text(t('同步状态：')).fontSize(11).fontColor(this.p().fgMain).opacity(0.7)
                  Text(t('已连接')).fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.p().success)
                }
                Text(
                  vaultStore.webdavLastSync.length > 0
                    ? tf('上次同步：{t}', 'Last synced: {t}', { 't': vaultStore.webdavLastSync })
                    : t('尚未同步')
                )
                  .fontSize(11)
                  .fontColor(this.p().fgMain)
                  .opacity(0.55)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.p().bgSub)
              .border({ width: 1, color: this.p().border })
              .justifyContent(FlexAlign.SpaceBetween)
            }
          }

          // Action buttons
          Row({ space: 10 }) {
            Button(t('测试连接'))
              .layoutWeight(1)
              .height(44)
              .borderRadius(14)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.p().bgCard)
              .fontColor(this.p().fgMain)
              .border({ width: 1, color: this.p().border })
              .enabled(!this.testing)
              .onClick(async () => {
                this.testing = true;
                await vaultStore.testWebDavConnection(this.wdUrl, this.wdUser, this.wdPass);
                this.testing = false;
              })

            Button(this.isOnboardingRestore ? t('下载并恢复') : t('保存配置'))
              .layoutWeight(1)
              .height(44)
              .borderRadius(14)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.p().brand)
              .fontColor('#FFFFFF')
              .onClick(async () => {
                if (this.isOnboardingRestore) {
                  const ok = await vaultStore.restoreFromWebDavOnboarding(
                    this.wdUrl,
                    this.wdUser,
                    this.wdPass
                  );
                  if (ok) {
                    this.onClose();
                  }
                } else {
                  if (vaultStore.saveWebDavSettings(this.wdUrl, this.wdUser, this.wdPass)) {
                    this.wdPass = '';
                  }
                }
              })
          }.width('100%')

          if (!this.isOnboardingRestore) {
            Button(vaultStore.webdavSyncing ? t('同步中...') : t('立即同步'))
              .width('100%')
              .height(44)
              .borderRadius(14)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(vaultStore.webdavConfigured ? this.p().brandSoft : this.p().bgCard)
              .fontColor(vaultStore.webdavConfigured ? this.p().brand : this.p().fgSub)
              .border({
                width: 1,
                color: vaultStore.webdavConfigured ? this.p().brand : this.p().border,
              })
              .enabled(!vaultStore.webdavSyncing)
              .onClick(() => {
                vaultStore.syncWebDav(true);
              })

            if (vaultStore.webdavConfigured) {
              Row() {
                Text(t('断开同步'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.p().danger)
                  .padding({ top: 4, bottom: 4 })
                  .onClick(() => {
                    this.onRequestConfirm({
                      title: t('断开 WebDAV 同步？'),
                      message: t('将清除本机保存的服务器地址与密码，不会删除你本机或云端已有的备份数据。'),
                      confirmLabel: t('确认断开'),
                      isDanger: true,
                      onConfirm: () => {
                        vaultStore.disconnectWebDav();
                        this.wdUrl = '';
                        this.wdUser = '';
                        this.wdPass = '';
                      },
                    });
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.End)
              .padding({ right: 4 })
            }
          }
        }
        .padding(16)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}

@ComponentV2
export struct ImportFlowSheet {
  @Param onClose: () => void = () => {};
  @Param onRequestConfirm: (req: ConfirmDialogRequest) => void = () => {};

  @Local step: ImportStep = 'pick';
  @Local source: ImportSourceKey = 'suoxia';
  @Local strategy: ImportStrategy = 'skip';
  @Local pickedFileName: string = '';
  @Local pickedTempPath: string = '';
  @Local badge: string = '';
  @Local decryptPwd: string = '';
  @Local showDecryptPwd: boolean = false;
  @Local parsedItems: VaultItem[] = [];
  @Local parsedFoldersCount: number = 0;
  @Local parsedTotpCount: number = 0;

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private async pickSource(src: ImportSourceKey): Promise<void> {
    this.source = src;
    this.strategy = 'skip';
    this.decryptPwd = '';
    const ctx = getContext(this) as common.UIAbilityContext;
    let suffixes: string[] = ['.json'];
    if (src === 'kdbx') {
      suffixes = ['.kdbx'];
    } else if (src === 'browser') {
      suffixes = ['.csv', '.json'];
    }
    const tempPath = vaultStore.getTempPath(`import_tmp_${Date.now()}`);
    const picked = await SecurityService.pickFileToTempPath(ctx, tempPath, suffixes);
    if (!picked) {
      return;
    }
    this.pickedFileName = picked.fileName;
    this.pickedTempPath = picked.tempPath;
    try {
      const res = vaultStore.parseImportFile(src, picked.tempPath, '');
      this.badge = res.badge;
      if (res.needsPassword) {
        this.step = 'decrypt';
      } else {
        this.parsedItems = res.items;
        this.parsedFoldersCount = res.folders.length;
        this.parsedTotpCount = res.totpCount;
        this.step = 'preview';
      }
    } catch (e) {
      vaultStore.showToast((e as Error).message, true);
    }
  }

  private runDecrypt(): void {
    if (this.decryptPwd.trim().length === 0) {
      vaultStore.showToast(t('请输入备份文件解密密码'), true);
      return;
    }
    try {
      const res = vaultStore.parseImportFile(this.source, this.pickedTempPath, this.decryptPwd);
      this.badge = res.badge;
      this.parsedItems = res.items;
      this.parsedFoldersCount = res.folders.length;
      this.parsedTotpCount = res.totpCount;
      this.step = 'preview';
      vaultStore.showToast(t('备份文件解密成功'));
    } catch (_) {
      vaultStore.showToast(t('主密码不正确'), true);
    }
  }

  private isDuplicate(item: VaultItem): boolean {
    const key = `${item.title}|${item.username ?? item.cardNumber ?? ''}`;
    for (let i = 0; i < vaultStore.items.length; i++) {
      const cur = vaultStore.items[i];
      if (!cur.deletedAt && `${cur.title}|${cur.username ?? cur.cardNumber ?? ''}` === key) {
        return true;
      }
    }
    return false;
  }

  private dupCount(): number {
    let c = 0;
    for (let i = 0; i < this.parsedItems.length; i++) {
      if (this.isDuplicate(this.parsedItems[i])) {
        c += 1;
      }
    }
    return c;
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

  private finalImportCount(): number {
    if (this.strategy === 'skip') {
      return this.parsedItems.length - this.dupCount();
    }
    return this.parsedItems.length;
  }

  private confirmAndImport(): void {
    if (this.strategy === 'overwrite') {
      this.onRequestConfirm({
        title: t('确认覆盖当前保险箱？'),
        message: tf(
          '当前保险箱中所有现有凭证将被清空，并替换为导入文件中的 {n} 条凭证，此操作无法撤销。',
          'All existing credentials will be cleared and replaced with {n} imported credentials. This cannot be undone.',
          { 'n': this.parsedItems.length }
        ),
        confirmLabel: t('确认覆盖'),
        isDanger: true,
        onConfirm: () => {
          vaultStore.executeImport(this.parsedItems, 'overwrite', this.decryptPwd);
          this.onClose();
        },
      });
      return;
    }
    vaultStore.executeImport(this.parsedItems, this.strategy, this.decryptPwd);
    this.onClose();
  }

  @Builder
  StrategyRow(
    key: ImportStrategy,
    title: string,
    tag: string,
    desc: string,
    isDanger: boolean
  ) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(title)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(isDanger ? this.p().danger : this.p().fgMain)
          if (tag.length > 0) {
            Text(tag)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(isDanger ? this.p().danger : this.p().brand)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor(isDanger ? this.p().dangerSoft : this.p().brandSoft)
          }
        }
        Text(desc)
          .fontSize(11)
          .fontColor(this.p().fgMain)
          .opacity(0.55)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Stack() {
        Circle({ width: 18, height: 18 })
          .fill(Color.Transparent)
          .stroke(
            this.strategy === key
              ? (isDanger ? this.p().danger : this.p().brand)
              : this.p().fgSub
          )
          .strokeWidth(2)
        if (this.strategy === key) {
          Circle({ width: 8, height: 8 })
            .fill(isDanger ? this.p().danger : this.p().brand)
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      this.strategy = key;
    })
  }

  build() {
    Column() {
      // Header
      Row() {
        Text(
          this.step === 'pick'
            ? t('关闭')
            : (this.step === 'decrypt' ? t('‹ 上一步') : t('‹ 重新选择'))
        )
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            if (this.step === 'pick') {
              this.onClose();
            } else {
              this.step = 'pick';
            }
          })
        Text(
          this.step === 'pick'
            ? t('导入凭证')
            : (this.step === 'decrypt' ? t('解密备份文件') : t('导入预览'))
        )
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text('').width(48)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      if (this.step === 'pick') {
        Scroll() {
          Column({ space: 12 }) {
            Text(t('请选择要导入的文件格式'))
              .fontSize(12)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
              .padding({ left: 4 })
              .width('100%')

            Column() {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('锁匣加密备份 (.json)')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('从电脑端或另一台手机导出的加密备份')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
              .width('100%').padding(16)
              .onClick(() => {
                this.pickSource('suoxia');
              })

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('KeePass 数据库 (.kdbx)')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('支持文件夹分组与 2FA 动态密钥')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
              .width('100%').padding(16)
              .onClick(() => {
                this.pickSource('kdbx');
              })

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(t('浏览器 / 第三方密码 (.csv / .json)')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  Text(t('自动识别 Chrome、Edge、Safari、Firefox、Bitwarden 等')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
              }
              .width('100%').padding(16)
              .onClick(() => {
                this.pickSource('browser');
              })
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            Text(t('所有文件解析与解密均在设备本地离线完成，不会上传至任何服务器。'))
              .fontSize(11)
              .lineHeight(17)
              .fontColor(this.p().fgMain)
              .opacity(0.55)
              .padding({ left: 4, right: 4 })
              .width('100%')
          }
          .padding(16)
        }
        .scrollBar(BarState.Off)
      } else if (this.step === 'decrypt') {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 6 }) {
              Text(this.badge)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().brand)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(6)
                .backgroundColor(this.p().brandSoft)
              Text(this.pickedFileName)
                .fontSize(11)
                .fontColor(this.p().fgMain)
                .opacity(0.75)
              Text(t('该文件受密码保护，请输入备份对应的解密密码。'))
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            Column({ space: 6 }) {
              Text(t('文件解密密码 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
              Row({ space: 6 }) {
                TextInput({ placeholder: t('输入备份文件密码'), text: this.decryptPwd })
                  .type(this.showDecryptPwd ? InputType.Normal : InputType.Password)
                  .showPasswordIcon(false)
                  .fontSize(12)
                  .fontColor(this.p().fgMain)
                  .placeholderColor(this.p().placeholder)
                  .placeholderFont({ size: 12 })
                  .backgroundColor(Color.Transparent)
                  .layoutWeight(1)
                  .height('100%')
                  .onChange((v: string) => {
                    this.decryptPwd = v;
                  })
                Text(this.showDecryptPwd ? t('隐藏') : t('显示'))
                  .fontSize(11)
                  .fontColor(this.p().fgMain)
                  .opacity(0.55)
                  .padding({ left: 6, right: 4 })
                  .onClick(() => {
                    this.showDecryptPwd = !this.showDecryptPwd;
                  })
              }.width('100%').height(40).padding({ left: 12, right: 10 }).borderRadius(12)
                .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
            }

            Button(t('解密并解析文件'))
              .width('100%')
              .height(46)
              .borderRadius(16)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.p().brand)
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.runDecrypt();
              })
          }
          .padding(16)
        }
        .scrollBar(BarState.Off)
      } else {
        // Step 3: Preview + 3 Strategies
        Scroll() {
          Column({ space: 14 }) {
            // Summary Card
            Column({ space: 10 }) {
              Column({ space: 4 }) {
                Text(this.badge)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.p().brand)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(6)
                  .backgroundColor(this.p().brandSoft)
                Text(this.pickedFileName)
                  .fontSize(11)
                  .fontColor(this.p().fgMain)
                  .opacity(0.75)
              }.width('100%').alignItems(HorizontalAlign.Start)

              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(`${this.parsedItems.length}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
                  Text(t('识别条数')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).padding(10).borderRadius(12).backgroundColor(this.p().bgSub)
                  .border({ width: 1, color: this.p().border })

                Column({ space: 2 }) {
                  Text(`${this.parsedItems.length - this.dupCount()}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.p().success)
                  Text(t('新增条目')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).padding(10).borderRadius(12).backgroundColor(this.p().bgSub)
                  .border({ width: 1, color: this.p().border })

                Column({ space: 2 }) {
                  Text(`${this.dupCount()}`).fontSize(16).fontWeight(FontWeight.Bold)
                    .fontColor(this.dupCount() > 0 ? this.p().warn : this.p().fgSub)
                  Text(t('重复条目')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                }.layoutWeight(1).padding(10).borderRadius(12).backgroundColor(this.p().bgSub)
                  .border({ width: 1, color: this.p().border })
              }.width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            // Preview Items (up to 15)
            Column() {
              Text(
                tf('内容预览（共 {n} 条 · {f} 个文件夹）', 'Preview ({n} items · {f} folders)', {
                  'n': this.parsedItems.length,
                  'f': this.parsedFoldersCount,
                })
              )
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })

              ForEach(this.parsedItems.slice(0, 15), (r: VaultItem) => {
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(r.title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(r.username || r.cardNumber || r.identityEmail || t('加密备忘'))
                      .fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Text(this.isDuplicate(r) ? t('重复') : t('新增'))
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isDuplicate(r) ? this.p().warn : this.p().success)
                    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                    .borderRadius(6)
                    .backgroundColor(this.isDuplicate(r) ? this.p().warnSoft : this.p().successSoft)
                }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }, (r: VaultItem) => r.id)
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            // 3 Strategies
            Column({ space: 6 }) {
              Text(t('选择导入方式'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
                .padding({ left: 4 })
                .width('100%')

              Column() {
                this.StrategyRow(
                  'skip',
                  t('合并并跳过重复项'),
                  t('推荐'),
                  tf(
                    '仅新增 {newN} 条不重复凭证，自动跳过 {dupN} 条重复项',
                    'Add {newN} unique items, skip {dupN} duplicates',
                    { 'newN': this.parsedItems.length - this.dupCount(), 'dupN': this.dupCount() }
                  ),
                  false
                )
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                this.StrategyRow(
                  'merge',
                  t('全部合并（保留重复项）'),
                  '',
                  tf(
                    '将全部 {n} 条凭证追加至当前保险箱',
                    'Append all {n} credentials to current vault',
                    { 'n': this.parsedItems.length }
                  ),
                  false
                )
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                this.StrategyRow(
                  'overwrite',
                  t('完全覆盖当前保险箱'),
                  t('谨慎'),
                  tf(
                    '清空现有 {cur} 条凭证，并以导入文件完整替换',
                    'Clear {cur} existing credentials and replace with file',
                    { 'cur': this.activeVaultCount() }
                  ),
                  true
                )
              }
              .width('100%')
              .borderRadius(16)
              .backgroundColor(this.p().bgCard)
              .border({ width: 1, color: this.p().border })
            }
          }
          .padding(16)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        // Sticky Footer CTA
        Column() {
          Button(
            this.strategy === 'overwrite'
              ? tf('覆盖并导入（{n} 条）', 'Overwrite & Import ({n})', { 'n': this.finalImportCount() })
              : tf('确认导入（{n} 条）', 'Confirm Import ({n})', { 'n': this.finalImportCount() })
          )
            .width('100%')
            .height(46)
            .borderRadius(16)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.strategy === 'overwrite' ? this.p().danger : this.p().brand)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.confirmAndImport();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 16 })
        .border({ width: { top: 0.5 }, color: this.p().divider })
      }
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}

@ComponentV2
export struct ChangeMasterPwdSheet {
  @Param onClose: () => void = () => {};
  @Local curPwd: string = '';
  @Local newPwd: string = '';
  @Local confirmPwd: string = '';
  @Local showCur: boolean = false;
  @Local showNew: boolean = false;
  @Local showConfirm: boolean = false;

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  build() {
    Column() {
      Row() {
        Text(t('取消'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
        Text(t('修改主密码'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text('').width(40)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text(t('当前主密码')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row({ space: 6 }) {
              TextInput({ placeholder: t('输入当前主密码'), text: this.curPwd })
                .type(this.showCur ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.curPwd = v;
                })
              Text(this.showCur ? t('隐藏') : t('显示'))
                .fontSize(11).fontColor(this.p().fgMain).opacity(0.55).padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showCur = !this.showCur;
                })
            }.width('100%').height(40).padding({ left: 12, right: 10 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Column({ space: 6 }) {
            Text(t('新主密码')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row({ space: 6 }) {
              TextInput({ placeholder: t('至少 8 位'), text: this.newPwd })
                .type(this.showNew ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.newPwd = v;
                })
              Text(this.showNew ? t('隐藏') : t('显示'))
                .fontSize(11).fontColor(this.p().fgMain).opacity(0.55).padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showNew = !this.showNew;
                })
            }.width('100%').height(40).padding({ left: 12, right: 10 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Column({ space: 6 }) {
            Text(t('确认新主密码')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row({ space: 6 }) {
              TextInput({ placeholder: t('再次输入新主密码'), text: this.confirmPwd })
                .type(this.showConfirm ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.confirmPwd = v;
                })
              Text(this.showConfirm ? t('隐藏') : t('显示'))
                .fontSize(11).fontColor(this.p().fgMain).opacity(0.55).padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showConfirm = !this.showConfirm;
                })
            }.width('100%').height(40).padding({ left: 12, right: 10 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Text(t('修改后将使用新密码重新加密本地数据；同步到云端后，其他设备需使用新主密码解锁。'))
            .fontSize(11)
            .lineHeight(17)
            .fontColor(this.p().fgMain)
            .opacity(0.5)
            .padding({ left: 4, right: 4 })
            .width('100%')

          Button(t('确认修改'))
            .width('100%')
            .height(46)
            .borderRadius(16)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().brand)
            .fontColor('#FFFFFF')
            .margin({ top: 4 })
            .onClick(() => {
              if (this.newPwd.length < 8) {
                vaultStore.showToast(t('主密码至少 8 位'), true);
                return;
              }
              if (this.newPwd !== this.confirmPwd) {
                vaultStore.showToast(t('两次密码输入不一致'), true);
                return;
              }
              if (vaultStore.changeMasterPassword(this.curPwd, this.newPwd)) {
                this.onClose();
              }
            })
        }
        .padding(16)
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}

@ComponentV2
export struct VerifyPwdSheet {
  @Param onCancel: () => void = () => {};
  @Param onVerified: () => void = () => {};
  @Local pwd: string = '';

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  build() {
    Column({ space: 14 }) {
      Text(t('验证主密码'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)
      Text(t('开启生物识别前需先验证当前主密码'))
        .fontSize(12)
        .fontColor(this.p().fgMain)
        .opacity(0.6)
        .textAlign(TextAlign.Center)

      Row() {
        TextInput({ placeholder: t('输入当前主密码'), text: this.pwd })
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
            this.pwd = v;
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(12)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })

      Row({ space: 10 }) {
        Button(t('取消'))
          .layoutWeight(1)
          .height(42)
          .borderRadius(12)
          .fontSize(13)
          .backgroundColor(this.p().bgSub)
          .fontColor(this.p().fgMain)
          .border({ width: 1, color: this.p().border })
          .onClick(() => {
            this.onCancel();
          })
        Button(t('确认开启'))
          .layoutWeight(1)
          .height(42)
          .borderRadius(12)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.p().brand)
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.pwd.length === 0) {
              vaultStore.showToast(t('请输入当前主密码'), true);
              return;
            }
            if (!vaultStore.verifyMasterPassword(this.pwd)) {
              vaultStore.showToast(t('主密码不正确'), true);
              return;
            }
            this.pwd = '';
            this.onVerified();
          })
      }.width('100%')
    }
    .padding(20)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}
