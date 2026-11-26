import { t } from '../i18n/AppI18n';
import { evaluatePasswordStrength } from '../models/VaultModels';
import { SecurityService } from '../services/SecurityService';
import { vaultStore } from '../state/VaultStore';
import { GesturePad } from './GesturePad';
import { getPalette, ThemePalette } from './UiTheme';

@ComponentV2
export struct OnboardingView {
  @Param onCreateVault: () => void = () => {};
  @Param onRestoreBackup: () => void = () => {};

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  @Builder
  FeatureCard(iconLabel: string, tintBg: string, tintFg: string, title: string, desc: string) {
    Row({ space: 14 }) {
      Stack() {
        Circle({ width: 40, height: 40 }).fill(tintBg)
        Text(iconLabel)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(tintFg)
      }
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)
        Text(desc)
          .fontSize(12)
          .fontColor(this.p().fgMain)
          .opacity(0.55)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.p().bgCard)
    .border({ width: 1, color: this.p().border })
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 14 }) {
          Stack() {
            Circle({ width: 92, height: 92 }).fill('#224F46E5')
            Circle({ width: 72, height: 72 }).fill('#2E4F46E5')
            Stack() {
              Text('🛡')
                .fontSize(26)
                .fontColor('#FFFFFF')
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .linearGradient({
              angle: 135,
              colors: [['#4F46E5', 0.0], ['#7C3AED', 1.0]],
            })
          }
          Column({ space: 6 }) {
            Text(t('锁匣 · SecureVault'))
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.p().fgMain)
            Text(t('本地加密密码管理器 · 手机与电脑安全同步'))
              .fontSize(12)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
          }
        }
        .margin({ top: 36 })

        Column({ space: 12 }) {
          this.FeatureCard(
            '🔒',
            '#1A4F46E5',
            '#4F46E5',
            t('本地离线加密'),
            t('不设官方服务器，主密码仅由你本人掌握')
          )
          this.FeatureCard(
            '☁',
            '#1A0284C7',
            '#0284C7',
            t('自主多端同步'),
            t('连接个人网盘或 NAS，手机与电脑加密互通')
          )
          this.FeatureCard(
            '◎',
            '#1A059669',
            '#059669',
            t('灵活应用锁'),
            t('支持面容、指纹与手势密码，按需自由开启')
          )
        }
        .padding({ left: 24, right: 24 })

        Column({ space: 10 }) {
          Button(t('创建新保险箱'))
            .width('100%')
            .height(48)
            .borderRadius(24)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(Color.Transparent)
            .linearGradient({
              angle: 90,
              colors: [['#4F46E5', 0.0], ['#7C3AED', 1.0]],
            })
            .onClick(() => {
              this.onCreateVault();
            })

          Button(t('从备份恢复或导入'))
            .width('100%')
            .height(48)
            .borderRadius(24)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().bgCard)
            .fontColor(this.p().fgMain)
            .border({ width: 1, color: this.p().border })
            .onClick(() => {
              this.onRestoreBackup();
            })
        }
        .padding({ left: 24, right: 24, bottom: 28 })
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }
}

@ComponentV2
export struct CreateVaultSheet {
  @Param onClose: () => void = () => {};
  @Local pwd1: string = '';
  @Local pwd2: string = '';
  @Local showPwd1: boolean = false;
  @Local showPwd2: boolean = false;
  @Local submitting: boolean = false;

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private strengthText(): string {
    if (this.pwd1.length === 0) {
      return '';
    }
    const s = evaluatePasswordStrength(this.pwd1);
    if (s === 'strong') {
      return t('强度：高');
    }
    if (s === 'medium') {
      return t('强度：中等');
    }
    return t('强度：偏弱');
  }

  private strengthColor(): string {
    const s = evaluatePasswordStrength(this.pwd1);
    if (s === 'strong') {
      return this.p().success;
    }
    if (s === 'medium') {
      return this.p().warn;
    }
    return this.p().danger;
  }

  private matchText(): string {
    if (this.pwd2.length === 0) {
      return '';
    }
    return this.pwd1 === this.pwd2 ? t('✓ 一致') : t('两次输入不一致');
  }

  private matchColor(): string {
    return this.pwd1 === this.pwd2 ? this.p().success : this.p().danger;
  }

  build() {
    Column() {
      // Sheet Header
      Row() {
        Text(t('取消'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)
          .opacity(0.6)
          .onClick(() => {
            this.onClose();
          })
        Text(t('创建新保险箱'))
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
        Column({ space: 14 }) {
          Column({ space: 4 }) {
            Text(t('设置主密码'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.p().fgMain)
            Text(t('用于本地加密你的全部凭证，建议包含字母、数字与符号。'))
              .fontSize(12)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 4, right: 4 })

          // Field 1: Master Password
          Column({ space: 6 }) {
            Row() {
              Text(t('主密码（至少 8 位）'))
                .fontSize(11)
                .fontColor(this.p().fgMain)
                .opacity(0.6)
              Text(this.strengthText())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.strengthColor())
            }
            .width('100%')
            .padding({ left: 4, right: 4 })
            .justifyContent(FlexAlign.SpaceBetween)

            Row({ space: 6 }) {
              TextInput({ placeholder: t('输入高强度主密码'), text: this.pwd1 })
                .type(this.showPwd1 ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.pwd1 = v;
                })
              SymbolGlyph(this.showPwd1 ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                .fontSize(17)
                .fontColor([this.p().fgMain])
                .opacity(0.5)
                .padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showPwd1 = !this.showPwd1;
                })
            }
            .width('100%')
            .height(40)
            .padding({ left: 12, right: 10 })
            .borderRadius(12)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          }

          // Field 2: Confirm Password
          Column({ space: 6 }) {
            Row() {
              Text(t('确认主密码'))
                .fontSize(11)
                .fontColor(this.p().fgMain)
                .opacity(0.6)
              Text(this.matchText())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.matchColor())
            }
            .width('100%')
            .padding({ left: 4, right: 4 })
            .justifyContent(FlexAlign.SpaceBetween)

            Row({ space: 6 }) {
              TextInput({ placeholder: t('再次输入以确认'), text: this.pwd2 })
                .type(this.showPwd2 ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.pwd2 = v;
                })
              SymbolGlyph(this.showPwd2 ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                .fontSize(17)
                .fontColor([this.p().fgMain])
                .opacity(0.5)
                .padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showPwd2 = !this.showPwd2;
                })
            }
            .width('100%')
            .height(40)
            .padding({ left: 12, right: 10 })
            .borderRadius(12)
            .backgroundColor(this.p().bgCard)
            .border({
              width: 1,
              color:
                this.pwd2.length > 0 && this.pwd1 !== this.pwd2
                  ? this.p().danger
                  : this.p().border,
            })
          }

          // Notice card
          Column({ space: 6 }) {
            Text(t('• 主密码仅由你本人掌握，无法找回或重置，请妥善牢记或手写备份。'))
              .fontSize(11)
              .lineHeight(17)
              .fontColor(this.p().fgMain)
              .opacity(0.75)
            Text(t('• 日常打开默认直接进入，如需每次验证身份，可在「首选项」中开启应用锁。'))
              .fontSize(11)
              .lineHeight(17)
              .fontColor(this.p().fgMain)
              .opacity(0.75)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(16)
          .backgroundColor(this.p().bgSub)
          .border({ width: 1, color: this.p().border })

          Button(this.submitting ? t('处理中...') : t('创建并进入'))
            .width('100%')
            .height(46)
            .borderRadius(16)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().brand)
            .fontColor('#FFFFFF')
            .enabled(!this.submitting)
            .onClick(async () => {
              if (this.pwd1.length < 8) {
                vaultStore.showToast(t('主密码至少 8 位'), true);
                return;
              }
              if (this.pwd1 !== this.pwd2) {
                vaultStore.showToast(t('两次密码输入不一致'), true);
                return;
              }
              this.submitting = true;
              try {
                const ok = await vaultStore.createFreshVault(this.pwd1);
                if (ok) {
                  this.onClose();
                }
              } catch (e) {
                vaultStore.showToast((e as Error).message || t('创建失败，请重试'), true);
              } finally {
                this.submitting = false;
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
export struct UnlockView {
  @Local unlockPwd: string = '';
  @Local showPwd: boolean = false;
  @Local forcePwdUnlock: boolean = false;
  @Local unlocking: boolean = false;

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private async runBiometric(): Promise<void> {
    const ok = await SecurityService.authenticateBiometric(
      vaultStore.bioFaceOn,
      vaultStore.bioFingerOn
    );
    if (ok) {
      await vaultStore.unlockWithBiometricSuccess();
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 10 }) {
          Stack() {
            Text('🔒').fontSize(28).fontColor('#FFFFFF')
          }
          .width(64)
          .height(64)
          .borderRadius(20)
          .backgroundColor(this.p().brand)

          Text(t('锁匣已锁定'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.p().fgMain)

          Text(
            vaultStore.gestureOn && !this.forcePwdUnlock
              ? t('绘制手势图案或验证生物特征以解锁')
              : t('请验证身份以解锁')
          )
            .fontSize(12)
            .fontColor(this.p().fgMain)
            .opacity(0.6)
        }
        .margin({ top: 48 })

        if (vaultStore.gestureOn && !this.forcePwdUnlock) {
          Column({ space: 20 }) {
            GesturePad({
              onPatternComplete: (pat: string) => {
                vaultStore.unlockWithGesture(pat);
              },
            })
            Row({ space: 20 }) {
              if (vaultStore.bioFaceOn || vaultStore.bioFingerOn) {
                Text(vaultStore.bioFaceOn ? t('面容识别解锁') : t('指纹识别解锁'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.p().brand)
                  .onClick(() => {
                    this.runBiometric();
                  })
              }
              Text(t('改用主密码'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().brand)
                .onClick(() => {
                  this.forcePwdUnlock = true;
                })
            }
          }
        } else {
          Column({ space: 12 }) {
            Row({ space: 6 }) {
              TextInput({ placeholder: t('输入主密码'), text: this.unlockPwd })
                .type(this.showPwd ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .height('100%')
                .onChange((v: string) => {
                  this.unlockPwd = v;
                })
              SymbolGlyph(this.showPwd ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                .fontSize(17)
                .fontColor([this.p().fgMain])
                .opacity(0.5)
                .padding({ left: 6, right: 4 })
                .onClick(() => {
                  this.showPwd = !this.showPwd;
                })
            }
            .width('100%')
            .height(44)
            .padding({ left: 14, right: 10 })
            .borderRadius(12)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            Button(this.unlocking ? t('处理中...') : t('解锁'))
              .width('100%')
              .height(46)
              .borderRadius(16)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.p().brand)
              .fontColor('#FFFFFF')
              .enabled(!this.unlocking)
              .onClick(async () => {
                this.unlocking = true;
                try {
                  const ok = await vaultStore.unlockWithPassword(this.unlockPwd);
                  if (ok) {
                    this.unlockPwd = '';
                  }
                } finally {
                  this.unlocking = false;
                }
              })

            if (vaultStore.bioFaceOn || vaultStore.bioFingerOn) {
              Button(vaultStore.bioFaceOn ? t('面容识别解锁') : t('指纹识别解锁'))
                .width('100%')
                .height(44)
                .borderRadius(16)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(this.p().bgCard)
                .fontColor(this.p().fgMain)
                .border({ width: 1, color: this.p().border })
                .onClick(() => {
                  this.runBiometric();
                })
            }

            if (vaultStore.gestureOn) {
              Text(t('改用手势密码解锁'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().brand)
                .margin({ top: 4 })
                .onClick(() => {
                  this.forcePwdUnlock = false;
                })
            }
          }
          .padding({ left: 24, right: 24 })
        }

        Text(t('本地数据已加密保护'))
          .fontSize(11)
          .fontColor(this.p().fgMain)
          .opacity(0.45)
          .margin({ bottom: 24 })
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }
}

@ComponentV2
export struct GestureSetupSheet {
  @Param onClose: () => void = () => {};
  @Local firstDraw: string = '';

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  build() {
    Column() {
      Row() {
        Text(t('取消'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)
          .opacity(0.6)
          .onClick(() => {
            this.onClose();
          })
        Text(t('手势密码'))
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

      Column({ space: 18 }) {
        Text(
          this.firstDraw.length > 0
            ? t('请再绘制一次以确认')
            : t('绘制解锁图案（至少 4 个点）')
        )
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().fgMain)

        GesturePad({
          onPatternComplete: (pat: string) => {
            if (pat.length < 4) {
              vaultStore.showToast(t('至少连接 4 个点'), true);
              return;
            }
            if (this.firstDraw.length === 0) {
              this.firstDraw = pat;
            } else if (pat !== this.firstDraw) {
              this.firstDraw = '';
              vaultStore.showToast(t('两次绘制不一致'), true);
            } else {
              vaultStore.gesturePattern = pat;
              vaultStore.gestureOn = true;
              vaultStore.saveMeta();
              this.firstDraw = '';
              this.onClose();
              vaultStore.showToast(t('手势密码已设置'));
            }
          },
        })

        if (vaultStore.gestureOn) {
          Button(t('关闭手势密码'))
            .width('100%')
            .height(42)
            .borderRadius(12)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.p().dangerSoft)
            .fontColor(this.p().danger)
            .onClick(() => {
              vaultStore.gestureOn = false;
              vaultStore.gesturePattern = '';
              vaultStore.saveMeta();
              this.onClose();
              vaultStore.showToast(t('已关闭手势密码'));
            })
        }
      }
      .padding(24)
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}
