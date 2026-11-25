import { isZhLocale, t } from '../i18n/AppI18n';
import { ExternalLinkRequest } from '../models/VaultModels';
import { SecurityService } from '../services/SecurityService';
import { vaultStore } from '../state/VaultStore';
import {
  FEEDBACK_EMAIL,
  getPalette,
  MOBILE_ISSUES_URL,
  MOBILE_REPO_URL,
  ThemePalette
} from './UiTheme';

type AboutSubPage = 'main' | 'privacy' | 'security' | 'license' | 'contact';

@ComponentV2
export struct AboutSheet {
  @Param onClose: () => void = () => {};
  @Param onOpenExternalLink: (req: ExternalLinkRequest) => void = () => {};
  @Local subPage: AboutSubPage = 'main';

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private headerTitle(): string {
    if (this.subPage === 'privacy') {
      return t('隐私政策');
    }
    if (this.subPage === 'security') {
      return t('安全说明');
    }
    if (this.subPage === 'license') {
      return t('开源许可');
    }
    if (this.subPage === 'contact') {
      return t('联系我们');
    }
    return t('关于锁匣');
  }

  @Builder
  SectionCard(title: string, body: string) {
    Column({ space: 6 }) {
      if (title.length > 0) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
      }
      Text(body)
        .fontSize(13)
        .lineHeight(22)
        .fontColor(this.p().fgMain)
        .opacity(0.8)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.p().bgCard)
    .border({ width: 1, color: this.p().border })
  }

  @Builder
  LicenseDepRow(name: string, desc: string, license: string) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
        Text(desc).fontSize(12).fontColor(this.p().fgMain).opacity(0.55)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(license).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      // Header
      Row() {
        if (this.subPage === 'main') {
          Text(t('关闭'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().fgMain)
            .opacity(0.6)
            .onClick(() => {
              this.onClose();
            })
        } else {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(16)
              .fontColor([this.p().fgMain])
              .opacity(0.8)
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(this.p().bgSub)
          .border({ width: 0.8, color: this.p().border })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.subPage = 'main';
          })
        }
        Text(this.headerTitle())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text('').width(44)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        if (this.subPage === 'main') {
          this.MainAboutBody()
        } else if (this.subPage === 'privacy') {
          this.PrivacyBody()
        } else if (this.subPage === 'security') {
          this.SecurityBody()
        } else if (this.subPage === 'license') {
          this.LicenseBody()
        } else {
          this.ContactBody()
        }
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  @Builder
  MainAboutBody() {
    Column({ space: 16 }) {
      // Brand Header Card
      Column({ space: 8 }) {
        Stack() {
          Text('🛡').fontSize(26).fontColor('#FFFFFF')
        }
        .width(56)
        .height(56)
        .borderRadius(16)
        .linearGradient({
          angle: 135,
          colors: [['#4F46E5', 0.0], ['#7C3AED', 1.0]],
        })

        Text(t('锁匣 · SecureVault'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .margin({ top: 2 })

        Text(t('本地加密密码管理器 · 手机与电脑加密同步'))
          .fontSize(12)
          .fontColor(this.p().fgMain)
          .opacity(0.55)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(20)
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })

      // 5 Info & Compliance Links
      Column() {
        this.AboutRow(t('隐私政策'), '', () => {
          this.subPage = 'privacy';
        })
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.AboutRow(t('安全说明'), '', () => {
          this.subPage = 'security';
        })
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.AboutRow(t('开源许可'), '', () => {
          this.subPage = 'license';
        })
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.AboutRow(t('联系我们'), '', () => {
          this.subPage = 'contact';
        })
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.AboutRow(t('检查更新'), t('已是最新'), () => {
          vaultStore.showToast(t('当前已是最新版本 v1.0.0'));
        })
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })

      // Footer
      Row({ space: 8 }) {
        Text(t('版本 v1.0.0')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
        Text('·').fontSize(11).fontColor(this.p().fgMain).opacity(0.45)
        Text(t('开源地址'))
          .fontSize(11)
          .fontColor(this.p().fgMain)
          .opacity(0.7)
          .onClick(() => {
            this.onOpenExternalLink({
              title: t('开源仓库'),
              url: MOBILE_REPO_URL,
            });
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 6, bottom: 8 })
    }
    .padding(16)
  }

  @Builder
  AboutRow(title: string, trailing: string, onTap: () => void) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.p().fgMain)
        .layoutWeight(1)
      Row({ space: 4 }) {
        if (trailing.length > 0) {
          Text(trailing).fontSize(12).fontColor(this.p().fgMain).opacity(0.55)
        }
        Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  PrivacyBody() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text(
          isZhLocale()
            ? '「锁匣 · SecureVault」是一款离线优先的本地密码管理工具。以下内容说明本应用如何保护你的数据与使用系统权限。'
            : 'SecureVault is an offline-first local password manager. Below explains how we protect your data and use system permissions.'
        )
          .fontSize(13).lineHeight(22).fontColor(this.p().fgMain).opacity(0.8)
        Text(isZhLocale() ? '更新日期：2026 年 11 月' : 'Updated: November 2026')
          .fontSize(11).fontColor(this.p().fgMain).opacity(0.45)
      }
      .width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .borderRadius(16).backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })

      this.SectionCard(
        isZhLocale() ? '一、我们不收集你的个人数据' : '1. We Do Not Collect Personal Data',
        isZhLocale()
          ? '本应用不设账号注册与登录体系，不运营任何官方云端服务器，也不会收集、上传或共享你的任何密码、账号、卡券、备忘录、两步验证密钥或设备使用行为。应用内不包含任何广告及第三方数据追踪工具。'
          : 'This app requires no account registration, operates no official cloud servers, and never collects, uploads, or shares your passwords, cards, notes, 2FA keys, or usage analytics. There are no ads or third-party trackers.'
      )

      this.SectionCard(
        isZhLocale() ? '二、数据如何存储与保护' : '2. How Data Is Stored and Protected',
        isZhLocale()
          ? '你的全部敏感凭证仅在当前设备本地使用你的主密码完成加密，并保存在系统为应用分配的私有安全目录中。你的主密码仅由你本人掌握，应用及开发者均无法获取或重置你的主密码。'
          : 'All credentials are encrypted locally on your device using your master password and stored in the app private sandbox. Only you hold your master password; neither the app nor developers can recover or reset it.'
      )

      this.SectionCard(
        isZhLocale() ? '三、自主云同步与文件导入导出' : '3. Self-Hosted Sync & Import/Export',
        isZhLocale()
          ? '本应用默认完全离线运行。仅当你主动配置并开启 WebDAV 同步时，应用才会连接你本人指定的网盘或 NAS 服务器，且仅传输已加密的备份文件，云盘服务商无法读取其中的任何内容。本地备份的导入与导出均在设备本地完成。'
          : 'The app works completely offline by default. Only when you configure WebDAV sync does it connect to your chosen cloud or NAS, transferring only encrypted backup files. Local import and export run entirely on device.'
      )

      this.SectionCard(
        isZhLocale() ? '四、系统权限使用说明' : '4. System Permissions',
        isZhLocale()
          ? '1. 相机权限：仅在你主动点击扫描二维码添加两步验证密钥时申请，不会在后台调用或保存任何画面。\n2. 面容 / 指纹识别：仅在你开启「应用锁」时由系统完成本地身份验证，应用无法获取你的生物特征信息。\n3. 网络权限：仅用于你主动配置的 WebDAV 同步与手动检查版本更新。\n\n本应用不会申请定位、通讯录、短信、通话记录或后台常驻等无关权限。'
          : '1. Camera: Requested only when scanning QR codes for 2FA keys.\n2. Face / Fingerprint: Used only by the OS when App Lock is enabled; biometric data is never accessible to the app.\n3. Network: Used only for your configured WebDAV sync.\n\nNo location, contacts, SMS, call log, or background tracking permissions are requested.'
      )

      this.SectionCard(
        isZhLocale() ? '五、你的控制权与数据清除' : '5. Your Control & Data Deletion',
        isZhLocale()
          ? '你对自己的数据拥有完全控制权，可随时在应用内编辑、导出、彻底删除任意凭证或断开 WebDAV 同步。卸载本应用时，系统将自动清除应用私有目录内的全部本地数据，请在卸载或换机前提前做好备份。'
          : 'You have full control over your data and can edit, export, permanently delete items, or disconnect WebDAV anytime. Uninstalling the app removes all local sandbox data—please back up before switching devices.'
      )

      this.SectionCard(
        isZhLocale() ? '六、政策更新与联系我们' : '6. Updates & Contact',
        isZhLocale()
          ? '如因功能演进需要修订本隐私政策，我们会在应用内同步更新说明。如你对隐私与数据安全有任何疑问，欢迎通过「关于锁匣 → 联系我们」中的反馈邮箱或在线问题反馈与我们联系。'
          : 'Updates to this policy will be reflected in-app. For privacy or security questions, reach us via About → Contact Us.'
      )
    }.padding(16)
  }

  @Builder
  SecurityBody() {
    Column({ space: 12 }) {
      this.SectionCard(
        '',
        isZhLocale()
          ? '「锁匣 · SecureVault」以本地加密、离线可用、数据归你所有为核心原则。以下说明你的密码如何被保护及日常注意事项。'
          : 'SecureVault is built around local encryption, offline availability, and full user ownership. Below explains how your vault is protected.'
      )
      this.SectionCard(
        isZhLocale() ? '一、本地高强度加密' : '1. Strong Local Encryption',
        isZhLocale()
          ? '你存入的每一条账号、密码、银行卡、备忘和两步验证密钥，都会在当前设备本地使用你的主密码完成高强度加密后再保存。即使备份文件被他人获取，没有主密码也无法还原出任何内容。'
          : 'Every login, card, note, and 2FA key is encrypted locally on device with your master password before being saved. Even if a backup file is copied, nothing can be read without your master password.'
      )
      this.SectionCard(
        isZhLocale() ? '二、主密码无法找回' : '2. Master Password Cannot Be Recovered',
        isZhLocale()
          ? '本应用不会保存或上传你的主密码，也不存在「忘记密码」或人工重置通道。一旦遗忘主密码，本地和云端的加密数据都无法解开。请务必牢记主密码，或将其手写保存在家中安全位置。'
          : 'Your master password is never stored or uploaded, and there is no password reset. If forgotten, neither local nor cloud data can be decrypted. Memorize it or keep a written copy in a safe place.'
      )
      this.SectionCard(
        isZhLocale() ? '三、应用锁与防窥保护' : '3. App Lock & Privacy Protection',
        isZhLocale()
          ? '你可以在「首选项」中按需开启应用锁，支持系统面容、指纹与手势密码快速验证，并可设置切出后台后自动锁定。同时建议保持隐私保护开启，防止切后台或截屏时泄露敏感信息。'
          : 'Enable App Lock in Preferences for Face, Fingerprint, or Pattern unlock with automatic background locking. Keep privacy protection enabled to prevent screenshots and task-switcher leaks.'
      )
      this.SectionCard(
        isZhLocale() ? '四、多端加密同步' : '4. Encrypted Multi-Device Sync',
        isZhLocale()
          ? '开启 WebDAV 同步后，应用仅向你指定的个人网盘或 NAS 传输已加密的备份文件，且全程采用加密连接。网盘服务商无法读取其中的密码内容。手机端与电脑端连接同一地址并使用相同主密码即可双向同步。'
          : 'With WebDAV sync enabled, only encrypted vault files are transferred over HTTPS to your personal cloud or NAS. Connect phone and desktop to the same URL with the same master password for two-way sync.'
      )
      this.SectionCard(
        isZhLocale() ? '五、换机与卸载前请先备份' : '5. Back Up Before Uninstalling',
        isZhLocale()
          ? '卸载应用会导致系统清除应用私有目录内的全部本地数据。更换手机、刷机或卸载前，请先确认 WebDAV 已完成最新同步，或在「首选项 → 导出加密备份」中导出加密文件妥善留存。'
          : 'Uninstalling clears all local data. Before switching devices or uninstalling, sync via WebDAV or export an encrypted backup from Preferences.'
      )
      this.SectionCard(
        isZhLocale() ? '六、日常使用建议' : '6. Everyday Best Practices',
        isZhLocale()
          ? '1. 及时清理明文文件：从浏览器导出的 CSV 密码表属于未加密明文，导入完成后请及时从手机或电脑中彻底删除。\n2. 保护好设备环境：尽量避免在已 Root 或越狱的设备上存放高敏感金融与核心账号。\n3. 定期更新重要密码：可借助「生成器」为重要账号生成高强度随机密码，避免多平台共用同一密码。'
          : '1. Delete plaintext CSV exports immediately after importing.\n2. Avoid storing critical accounts on rooted or compromised devices.\n3. Use the Generator to create unique strong passwords for important accounts.'
      )
    }.padding(16)
  }

  @Builder
  LicenseBody() {
    Column({ space: 12 }) {
      this.SectionCard(
        '',
        isZhLocale()
          ? '「锁匣 · SecureVault」遵循开源精神发布，核心加密与数据同步代码公开透明，欢迎任何人审阅与监督。'
          : 'SecureVault is released as open-source software so anyone can audit and verify its encryption and sync code.'
      )

      Column({ space: 8 }) {
        Row() {
          Text(t('本应用许可协议')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.p().fgMain)
          Text('MIT License')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().brand)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(6)
            .backgroundColor(this.p().brandSoft)
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)

        Text(
          isZhLocale()
            ? '• 允许免费使用、复制、修改、合并、发布和分发本软件。\n• 再分发时需在副本中保留原作者的版权声明与本许可说明。\n• 本软件按「现状」提供，不附带任何明示或暗示的担保。'
            : '• Permission is granted free of charge to use, copy, modify, merge, publish, and distribute this software.\n• The copyright notice and permission notice shall be included in all copies.\n• Provided "AS IS", without warranty of any kind.'
        )
          .fontSize(13).lineHeight(22).fontColor(this.p().fgMain).opacity(0.8)

        Text('Copyright © 2026 SecureVault Contributors')
          .fontSize(11).fontColor(this.p().fgMain).opacity(0.5)
      }
      .width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .borderRadius(16).backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })

      Column() {
        Text(t('致谢 · 使用的开源组件'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)
          .opacity(0.55)
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })

        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.LicenseDepRow('RustCrypto', t('本地高强度加密与密钥派生支持'), 'MIT / Apache-2.0')
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.LicenseDepRow('keepass-rs', t('KeePass (.kdbx) 数据库读写支持'), 'MIT')
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.LicenseDepRow('reqwest & rustls', t('WebDAV 安全加密网络通信支持'), 'MIT / Apache-2.0')
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.LicenseDepRow('serde', t('本地备份文件结构解析支持'), 'MIT / Apache-2.0')
        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
        this.LicenseDepRow('HarmonyOS ArkUI', t('HarmonyOS 界面框架支持'), 'Apache-2.0')
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }.padding(16)
  }

  @Builder
  ContactBody() {
    Column({ space: 12 }) {
      this.SectionCard(
        '',
        isZhLocale()
          ? '如果你在使用「锁匣 · SecureVault」过程中遇到问题、有改进建议，或对隐私与数据安全存在疑问，欢迎通过以下方式联系我们。'
          : 'If you encounter issues, have suggestions, or have privacy/security questions about SecureVault, please reach out below.'
      )

      Column() {
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text(t('反馈邮箱')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
            Text(FEEDBACK_EMAIL).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)

          Button(t('复制'))
            .height(30)
            .fontSize(12)
            .borderRadius(8)
            .backgroundColor(this.p().bgSub)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              SecurityService.copySensitive(FEEDBACK_EMAIL);
              vaultStore.showToast(t('已复制'));
            })
        }.width('100%').padding(16)

        Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text(t('在线问题反馈')).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
            Text(t('提交使用问题、改进建议或隐私安全咨询'))
              .fontSize(11)
              .fontColor(this.p().fgMain)
              .opacity(0.55)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('›').fontSize(18).fontColor(this.p().fgMain).opacity(0.4)
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          this.onOpenExternalLink({
            title: t('在线问题反馈'),
            url: MOBILE_ISSUES_URL,
          });
        })
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })

      this.SectionCard(
        t('反馈安全提醒'),
        t('为保护你的数据安全，在发送邮件或提交反馈时，请勿附带你的主密码、账号密码、银行卡号或包含敏感信息的截图。')
      )
    }.padding(16)
  }
}
