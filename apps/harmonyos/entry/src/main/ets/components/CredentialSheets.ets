import { common } from '@kit.AbilityKit';
import { RustCoreBridge } from '../bridge/RustCoreBridge';
import { t, tf } from '../i18n/AppI18n';
import {
  ALL_FOLDER_FILTER,
  ConfirmDialogRequest,
  DEFAULT_FOLDER,
  ItemType,
  LiveTotpDisplay,
  normalizeFolderName,
  PasswordHistoryEntry,
  VaultItem
} from '../models/VaultModels';
import { SecurityService } from '../services/SecurityService';
import { vaultStore } from '../state/VaultStore';
import { ColoredCharSegment, colorizePasswordSegments, getPalette, ThemePalette } from './UiTheme';

interface ItemTypeOption {
  type: ItemType;
  label: string;
}

const TYPE_OPTIONS: ItemTypeOption[] = [
  { type: 'login', label: '登录' },
  { type: 'card', label: '卡券' },
  { type: 'note', label: '备忘' },
  { type: 'identity', label: '密保' },
];

@ComponentV2
export struct DetailView {
  @Param itemId: string = '';
  @Param tickNow: number = 0;
  @Param onBack: () => void = () => {};
  @Param onEdit: (item: VaultItem) => void = () => {};
  @Param onRequestConfirm: (req: ConfirmDialogRequest) => void = () => {};
  @Local showSecret: boolean = false;
  @Local showMoreSheet: boolean = false;
  @Local showLargeType: boolean = false;

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private currentItem(): VaultItem | null {
    for (let i = 0; i < vaultStore.items.length; i++) {
      if (vaultStore.items[i].id === this.itemId) {
        return vaultStore.items[i];
      }
    }
    return null;
  }

  private liveTotp(secret: string): LiveTotpDisplay {
    void this.tickNow;
    try {
      const res = RustCoreBridge.generateTotp(secret);
      const fmt = res.code.length === 6 ? `${res.code.slice(0, 3)} ${res.code.slice(3)}` : res.code;
      return { fmt: fmt, raw: res.code, rem: res.remaining };
    } catch (_) {
      return { fmt: '--- ---', raw: '', rem: 30 };
    }
  }

  @Builder
  MoreActionSheet(item: VaultItem) {
    Column({ space: 12 }) {
      Text(item.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.p().fgMain)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column() {
        Row() {
          Text(item.isFavorite ? t('取消星标') : t('设为星标'))
            .fontSize(14)
            .fontColor(this.p().fgMain)
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          vaultStore.toggleFavorite(item.id);
          this.showMoreSheet = false;
        })

        Divider()
          .strokeWidth(0.5)
          .color(this.p().divider)
          .margin({ left: 16 })

        Row() {
          Text(t('移入回收站'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().danger)
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showMoreSheet = false;
          this.onRequestConfirm({
            title: tf('将「{name}」移入回收站？', 'Move "{name}" to Trash?', { 'name': item.title }),
            message: t('移入后该凭证将从列表隐藏，30 天内可在回收站随时恢复。'),
            confirmLabel: t('确认移入'),
            isDanger: true,
            onConfirm: () => {
              vaultStore.moveToTrash(item.id);
              this.onBack();
            },
          });
        })
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })

      Button(t('取消'))
        .width('100%')
        .height(44)
        .borderRadius(14)
        .fontSize(14)
        .backgroundColor(this.p().bgSub)
        .fontColor(this.p().fgMain)
        .onClick(() => {
          this.showMoreSheet = false;
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  build() {
    Stack() {
      if (this.currentItem() !== null) {
        this.DetailBody(this.currentItem() as VaultItem)
      }

      if (this.showLargeType && this.currentItem() !== null) {
        Stack() {
          Column({ space: 18 }) {
            Text(t('大字查看'))
              .fontSize(13)
              .fontColor('#94A3B8')
            Text() {
              ForEach(
                colorizePasswordSegments((this.currentItem() as VaultItem).password ?? ''),
                (seg: ColoredCharSegment) => {
                  Span(seg.text)
                    .fontColor(seg.color)
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                    .fontFamily('monospace')
                }
              )
            }
            .textAlign(TextAlign.Center)
            .lineHeight(36)
            .width('100%')

            Button(t('关闭'))
              .width(120)
              .height(40)
              .borderRadius(20)
              .fontSize(13)
              .backgroundColor('#334155')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.showLargeType = false;
              })
          }
          .padding(24)
          .width('88%')
          .borderRadius(24)
          .backgroundColor('#0F172A')
          .border({ width: 1, color: '#334155' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#B3000000')
        .onClick(() => {
          this.showLargeType = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(
      PanGesture({ direction: PanDirection.Right, distance: 60 }).onActionEnd(() => {
        this.onBack();
      })
    )
  }

  @Builder
  DetailBody(item: VaultItem) {
    Column() {
      // Top Nav Bar
      Row() {
        Text(t('‹ 返回'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onBack();
          })

        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ left: 8, right: 8 })

        Row({ space: 10 }) {
          Text(t('编辑'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().brand)
            .onClick(() => {
              this.onEdit(item);
            })
          Text('···')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.p().brand)
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.showMoreSheet = true;
            })
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 12 }) {
          // Header Card
          Row({ space: 12 }) {
            Stack() {
              Text(item.title.length > 0 ? item.title.charAt(0).toUpperCase() : '?')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.p().brand)
            }
            .width(42)
            .height(42)
            .borderRadius(12)
            .backgroundColor(this.p().brandSoft)

            Column({ space: 3 }) {
              Text(item.title)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.p().fgMain)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(
                `${t(normalizeFolderName(item.folder))} · ${item.updatedAt}`
              )
                .fontSize(11)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(item.isFavorite ? '★' : '☆')
              .fontSize(22)
              .fontColor(item.isFavorite ? '#FBBF24' : this.p().fgSub)
              .onClick(() => {
                vaultStore.toggleFavorite(item.id);
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })

          // Type-specific fields
          if (item.type === 'card') {
            Column() {
              if (item.cardName && item.cardName.length > 0) {
                Row() {
                  Column({ space: 2 }) {
                    Text(t('持卡人')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                    Text(item.cardName).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(t('复制')).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.p().brand)
                    .onClick(() => {
                      SecurityService.copySensitive(item.cardName ?? '');
                      vaultStore.showToast(t('已复制'));
                    })
                }.width('100%').padding(14)
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              }

              Row() {
                Column({ space: 2 }) {
                  Text(t('卡号')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                  Text(item.cardNumber || '-')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontFamily('monospace')
                    .fontColor(this.p().fgMain)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(t('复制')).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.p().brand)
                  .onClick(() => {
                    SecurityService.copySensitive(item.cardNumber ?? '');
                    vaultStore.showToast(t('已复制'));
                  })
              }.width('100%').padding(14)

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text(t('有效期')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                  Text(item.cardExpiry || '-')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontFamily('monospace')
                    .fontColor(this.p().fgMain)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(t('安全码 CVV')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                    Text(this.showSecret ? (item.cardCvv || '-') : '•••')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontFamily('monospace')
                      .fontColor(this.p().fgMain)
                  }.alignItems(HorizontalAlign.Start)
                  Text(this.showSecret ? t('隐藏') : t('显示'))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      this.showSecret = !this.showSecret;
                    })
                }
              }.width('100%').padding(14)
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          } else if (item.type === 'note') {
            Column({ space: 10 }) {
              Row() {
                Text(t('加密备忘正文')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                Row({ space: 14 }) {
                  Text(this.showSecret ? t('隐藏') : t('查看'))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      this.showSecret = !this.showSecret;
                    })
                  Text(t('复制'))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      SecurityService.copySensitive(item.notes ?? '');
                      vaultStore.showToast(t('已复制'));
                    })
                }
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)

              Text(this.showSecret ? (item.notes || t('无内容')) : '••••••••••••••••••••')
                .fontSize(14)
                .lineHeight(22)
                .fontColor(this.p().fgMain)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          } else if (item.type === 'identity') {
            Column() {
              if (item.identityName && item.identityName.length > 0) {
                this.IdentityFieldRow(t('姓名'), item.identityName)
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              }
              if (item.identityEmail && item.identityEmail.length > 0) {
                this.IdentityFieldRow(t('邮箱'), item.identityEmail)
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              }
              if (item.identityPhone && item.identityPhone.length > 0) {
                this.IdentityFieldRow(t('手机号'), item.identityPhone)
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              }
              if (item.identityAddress && item.identityAddress.length > 0) {
                this.IdentityFieldRow(t('地址 / 证件信息'), item.identityAddress)
              }
              if (
                (!item.identityName || item.identityName.length === 0) &&
                (!item.identityEmail || item.identityEmail.length === 0) &&
                (!item.identityPhone || item.identityPhone.length === 0) &&
                (!item.identityAddress || item.identityAddress.length === 0)
              ) {
                Text(t('暂无身份详情'))
                  .fontSize(12)
                  .fontColor(this.p().fgMain)
                  .opacity(0.55)
                  .padding(16)
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          } else {
            // Login type
            Column() {
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(t('账号')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                  Text(item.username || '-')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().fgMain)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                Button(t('复制'))
                  .height(30)
                  .fontSize(12)
                  .borderRadius(8)
                  .backgroundColor(this.p().bgSub)
                  .fontColor(this.p().fgMain)
                  .border({ width: 1, color: this.p().border })
                  .onClick(() => {
                    SecurityService.copySensitive(item.username ?? '');
                    vaultStore.showToast(t('已复制账号'));
                  })
              }.width('100%').padding(14)

              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

              Column({ space: 8 }) {
                Row() {
                  Text(t('密码')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                  Row({ space: 14 }) {
                    Text(t('大字查看'))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .onClick(() => {
                        this.showLargeType = true;
                      })
                    Text(this.showSecret ? t('隐藏') : t('显示'))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .onClick(() => {
                        this.showSecret = !this.showSecret;
                      })
                    Text(t('复制'))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .onClick(() => {
                        SecurityService.copySensitive(item.password ?? '');
                        vaultStore.showToast(t('已复制密码'));
                      })
                  }
                }.width('100%').justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  if (this.showSecret) {
                    Text() {
                      ForEach(
                        colorizePasswordSegments(item.password ?? ''),
                        (seg: ColoredCharSegment) => {
                          Span(seg.text)
                            .fontColor(seg.color)
                            .fontSize(14)
                            .fontFamily('monospace')
                        }
                      )
                    }.width('100%')
                  } else {
                    Text('••••••••••••')
                      .fontSize(14)
                      .fontFamily('monospace')
                      .fontColor('#FFFFFF')
                  }
                }
                .width('100%')
                .padding(12)
                .borderRadius(12)
                .backgroundColor('#0F172A')
              }.width('100%').padding(14)

              if (item.url && item.url.length > 0) {
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(t('网址')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
                    Text(item.url)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Button(t('打开'))
                    .height(30)
                    .fontSize(12)
                    .borderRadius(8)
                    .backgroundColor(this.p().bgSub)
                    .fontColor(this.p().fgMain)
                    .border({ width: 1, color: this.p().border })
                    .onClick(() => {
                      const ctx = getContext(this) as common.UIAbilityContext;
                      const url = item.url ?? '';
                      const fullUrl = url.startsWith('http://') || url.startsWith('https://') ? url : `https://${url}`;
                      SecurityService.openExternalUrl(ctx, fullUrl);
                    })
                }.width('100%').padding(14)
              }
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          }

          // Live OTP Card
          if (item.otpSecret && item.otpSecret.length > 0) {
            this.DetailOtpCard(item.otpSecret)
          }

          // Notes Card (non-note types)
          if (item.type !== 'note' && item.notes && item.notes.length > 0) {
            Column({ space: 4 }) {
              Text(t('备注')).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
              Text(item.notes).fontSize(13).lineHeight(20).fontColor(this.p().fgMain)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .borderRadius(16)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })
          }

          // Password History
          if (item.passwordHistory && item.passwordHistory.length > 0) {
            Column() {
              Text(t('历史密码（已隐藏）'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.p().fgMain)
                .opacity(0.6)
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })

              ForEach(item.passwordHistory, (h: PasswordHistoryEntry) => {
                Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
                Row() {
                  Column({ space: 2 }) {
                    Text('••••••••••••').fontSize(13).fontFamily('monospace').fontColor(this.p().fgMain)
                    Text(h.changedAt).fontSize(11).fontColor(this.p().fgMain).opacity(0.5)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Row({ space: 12 }) {
                    Text(t('复制'))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .onClick(() => {
                        SecurityService.copySensitive(h.password);
                        vaultStore.showToast(t('已复制密码'));
                      })
                    Text(t('恢复'))
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.p().brand)
                      .onClick(() => {
                        const updated: VaultItem = {
                          id: item.id,
                          type: item.type,
                          title: item.title,
                          folder: item.folder,
                          username: item.username,
                          password: h.password,
                          url: item.url,
                          otpSecret: item.otpSecret,
                          notes: item.notes,
                          updatedAt: item.updatedAt,
                        };
                        vaultStore.upsertItem(updated, item.id);
                        vaultStore.showToast(t('已恢复该历史密码'));
                      })
                  }
                }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
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
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.p().bgPage)
    .bindSheet($$this.showMoreSheet, this.MoreActionSheet(item), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
  }

  @Builder
  IdentityFieldRow(label: string, value: string) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(label).fontSize(11).fontColor(this.p().fgMain).opacity(0.55)
        Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.p().fgMain)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button(t('复制'))
        .height(30)
        .fontSize(12)
        .borderRadius(8)
        .backgroundColor(this.p().bgSub)
        .fontColor(this.p().fgMain)
        .border({ width: 1, color: this.p().border })
        .onClick(() => {
          SecurityService.copySensitive(value);
          vaultStore.showToast(t('已复制'));
        })
    }.width('100%').padding(14)
  }

  @Builder
  DetailOtpCard(secret: string) {
    Row() {
      Column({ space: 4 }) {
        Text(t('两步动态验证码'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
        Text(this.liveTotp(secret).fmt)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontFamily('monospace')
          .fontColor(this.p().fgMain)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)

      Row({ space: 10 }) {
        Stack() {
          Circle({ width: 38, height: 38 })
            .fill(Color.Transparent)
            .stroke(this.liveTotp(secret).rem <= 5 ? this.p().danger : this.p().brand)
            .strokeWidth(2)
          Text(`${this.liveTotp(secret).rem}s`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.liveTotp(secret).rem <= 5 ? this.p().danger : this.p().brand)
        }
        Button(t('复制'))
          .height(34)
          .fontSize(12)
          .borderRadius(10)
          .backgroundColor(this.p().brand)
          .fontColor('#FFFFFF')
          .onClick(() => {
            SecurityService.copySensitive(this.liveTotp(secret).raw);
            vaultStore.showToast(t('已复制验证码'));
          })
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.p().bgCard)
    .border({ width: 1, color: this.p().border })
  }
}

@ComponentV2
export struct EditCredentialSheet {
  @Param editItem: VaultItem | null = null;
  @Param onClose: () => void = () => {};
  @Param onSaved: (saved: VaultItem) => void = () => {};

  @Local efType: ItemType = 'login';
  @Local efTitle: string = '';
  @Local efFolder: string = DEFAULT_FOLDER;
  @Local efUser: string = '';
  @Local efPass: string = '';
  @Local efShowPass: boolean = false;
  @Local efUrl: string = '';
  @Local efOtp: string = '';
  @Local efCardName: string = '';
  @Local efCardNo: string = '';
  @Local efCardExp: string = '';
  @Local efCardCvv: string = '';
  @Local efIdName: string = '';
  @Local efIdEmail: string = '';
  @Local efIdPhone: string = '';
  @Local efIdAddr: string = '';
  @Local efNotes: string = '';

  @Local showQuickGen: boolean = false;
  @Local quickGenPwd: string = '';

  aboutToAppear(): void {
    const it = this.editItem;
    this.efType = it ? it.type : 'login';
    this.efTitle = it ? it.title : '';
    this.efFolder = it
      ? normalizeFolderName(it.folder)
      : (vaultStore.activeFolder !== ALL_FOLDER_FILTER ? normalizeFolderName(vaultStore.activeFolder) : DEFAULT_FOLDER);
    this.efUser = it?.username ?? '';
    this.efPass = it?.password ?? '';
    this.efShowPass = it === null;
    this.efUrl = it?.url ?? '';
    this.efOtp = it?.otpSecret ?? '';
    this.efCardName = it?.cardName ?? '';
    this.efCardNo = it?.cardNumber ?? '';
    this.efCardExp = it?.cardExpiry ?? '';
    this.efCardCvv = it?.cardCvv ?? '';
    this.efIdName = it?.identityName ?? '';
    this.efIdEmail = it?.identityEmail ?? '';
    this.efIdPhone = it?.identityPhone ?? '';
    this.efIdAddr = it?.identityAddress ?? '';
    this.efNotes = it?.notes ?? '';
  }

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private segIndex(): number {
    for (let i = 0; i < TYPE_OPTIONS.length; i++) {
      if (TYPE_OPTIONS[i].type === this.efType) {
        return i;
      }
    }
    return 0;
  }

  private titlePlaceholder(): string {
    if (this.efType === 'card') {
      return t('例如：招商银行信用卡');
    }
    if (this.efType === 'note') {
      return t('例如：服务器恢复秘钥');
    }
    if (this.efType === 'identity') {
      return t('例如：个人常用身份');
    }
    return t('例如：GitHub、微信');
  }

  private folderChoices(): string[] {
    return [DEFAULT_FOLDER, ...vaultStore.folders];
  }

  private regenQuickPwd(): void {
    try {
      this.quickGenPwd = RustCoreBridge.generatePassword(18, true, true, true, true, true);
    } catch (_) {
      this.quickGenPwd = '';
    }
  }

  private async scanOtpForEdit(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const raw = await SecurityService.scanQrCode(ctx);
    if (!raw) {
      return;
    }
    try {
      const parsed = RustCoreBridge.parseOtpauthUri(raw);
      this.efOtp = parsed.secret;
      vaultStore.showToast(t('已识别并填入两步验证密钥'));
    } catch (e) {
      vaultStore.showToast((e as Error).message, true);
    }
  }

  private handleSave(): void {
    if (this.efTitle.trim().length === 0) {
      vaultStore.showToast(t('请填写标题'), true);
      return;
    }
    const editingId = this.editItem ? this.editItem.id : '';
    const draft: VaultItem = {
      id: editingId || `item_${Date.now()}`,
      type: this.efType,
      title: this.efTitle.trim(),
      folder: normalizeFolderName(this.efFolder),
      username: this.efUser,
      password: this.efPass,
      url: this.efUrl,
      otpSecret: this.efOtp.trim(),
      cardName: this.efCardName,
      cardNumber: this.efCardNo,
      cardExpiry: this.efCardExp,
      cardCvv: this.efCardCvv,
      identityName: this.efIdName,
      identityEmail: this.efIdEmail,
      identityPhone: this.efIdPhone,
      identityAddress: this.efIdAddr,
      notes: this.efNotes,
      updatedAt: '',
    };
    const saved = vaultStore.upsertItem(draft, editingId);
    vaultStore.showToast(t('已加密保存'));
    this.onSaved(saved);
  }

  @Builder
  QuickGenActionSheet() {
    Column({ space: 14 }) {
      Row() {
        Text(t('快速生成密码'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text(t('换一个'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.regenQuickPwd();
          })
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text() {
          ForEach(colorizePasswordSegments(this.quickGenPwd), (seg: ColoredCharSegment) => {
            Span(seg.text).fontColor(seg.color).fontSize(15).fontFamily('monospace')
          })
        }
      }
      .width('100%')
      .padding(16)
      .borderRadius(16)
      .backgroundColor('#0F172A')

      Button(t('使用此密码'))
        .width('100%')
        .height(44)
        .borderRadius(14)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.p().brand)
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.efPass = this.quickGenPwd;
          this.showQuickGen = false;
          vaultStore.showToast(t('已填入生成的随机密码'));
        })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }

  @Builder
  FormInputBox(
    label: string,
    placeholder: string,
    val: string,
    onValChange: (v: string) => void,
    isMono: boolean = false,
    isPassword: boolean = false
  ) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(11)
        .fontColor(this.p().fgMain)
        .opacity(0.6)
        .padding({ left: 4 })
        .width('100%')
      Row() {
        TextInput({ placeholder: placeholder, text: val })
          .type(isPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .fontSize(12)
          .fontFamily(isMono && val.length > 0 ? 'monospace' : '')
          .fontColor(this.p().fgMain)
          .placeholderColor(this.p().placeholder)
          .placeholderFont({ size: 12 })
          .backgroundColor(Color.Transparent)
          .width('100%')
          .height('100%')
          .onChange((v: string) => {
            onValChange(v);
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(12)
      .backgroundColor(this.p().bgCard)
      .border({ width: 1, color: this.p().border })
    }
  }

  build() {
    Column() {
      // Sheet Header
      Row() {
        Text(t('取消'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
        Text(this.editItem ? t('编辑凭证') : t('新建凭证'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text(t('保存'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.handleSave();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 12 }) {
          // Segmented Control with Animated Sliding Thumb (~180ms)
          Stack({ alignContent: Alignment.Start }) {
            // Sliding thumb (25% width)
            Row()
              .width('25%')
              .height(30)
              .borderRadius(9)
              .backgroundColor(this.p().segThumb)
              .shadow({ radius: 4, color: '#14000000', offsetY: 1 })
              .translate({ x: `${this.segIndex() * 100}%` })
              .animation({ duration: 180, curve: Curve.EaseInOut })

            Row() {
              ForEach(TYPE_OPTIONS, (opt: ItemTypeOption) => {
                Text(t(opt.label))
                  .layoutWeight(1)
                  .height(30)
                  .textAlign(TextAlign.Center)
                  .fontSize(12)
                  .fontWeight(this.efType === opt.type ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.efType === opt.type ? this.p().segThumbText : this.p().fgMain)
                  .opacity(this.efType === opt.type ? 1 : 0.65)
                  .onClick(() => {
                    this.efType = opt.type;
                  })
              })
            }
            .width('100%')
            .height(30)
          }
          .width('100%')
          .height(36)
          .padding(3)
          .borderRadius(12)
          .backgroundColor(this.p().segTrack)

          // Title
          this.FormInputBox(t('标题 *'), this.titlePlaceholder(), this.efTitle, (v: string) => {
            this.efTitle = v;
          })

          // Folder Chips
          Column({ space: 6 }) {
            Text(t('文件夹'))
              .fontSize(11)
              .fontColor(this.p().fgMain)
              .opacity(0.6)
              .padding({ left: 4 })
              .width('100%')

            Scroll() {
              Row({ space: 6 }) {
                ForEach(this.folderChoices(), (f: string) => {
                  Text(f === DEFAULT_FOLDER ? t('默认') : f)
                    .fontSize(11)
                    .fontWeight(this.efFolder === f ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.efFolder === f ? this.p().brand : this.p().fgMain)
                    .opacity(this.efFolder === f ? 1 : 0.7)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(10)
                    .backgroundColor(this.efFolder === f ? this.p().brandSoft : this.p().bgCard)
                    .border({
                      width: 1,
                      color: this.efFolder === f ? this.p().brand : this.p().border,
                    })
                    .onClick(() => {
                      this.efFolder = f;
                    })
                })
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          // Type-specific fields (stable minHeight to prevent jumpy sheet)
          Column({ space: 12 }) {
            if (this.efType === 'login') {
              this.FormInputBox(
                t('账号 / 邮箱'),
                t('输入登录账号或邮箱'),
                this.efUser,
                (v: string) => {
                  this.efUser = v;
                }
              )

              // Password with Quick Gen + Eye toggle
              Column({ space: 6 }) {
                Row() {
                  Text(t('密码')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6)
                  Text(t('生成强密码'))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      this.regenQuickPwd();
                      this.showQuickGen = true;
                    })
                }.width('100%').padding({ left: 4, right: 4 }).justifyContent(FlexAlign.SpaceBetween)

                Row({ space: 6 }) {
                  TextInput({ placeholder: t('输入登录密码'), text: this.efPass })
                    .type(this.efShowPass ? InputType.Normal : InputType.Password)
                    .showPasswordIcon(false)
                    .fontSize(12)
                    .fontFamily(this.efPass.length > 0 ? 'monospace' : '')
                    .fontColor(this.p().fgMain)
                    .placeholderColor(this.p().placeholder)
                    .placeholderFont({ size: 12 })
                    .backgroundColor(Color.Transparent)
                    .layoutWeight(1)
                    .height('100%')
                    .onChange((v: string) => {
                      this.efPass = v;
                    })
                  Text(this.efShowPass ? t('隐藏') : t('显示'))
                    .fontSize(11)
                    .fontColor(this.p().fgMain)
                    .opacity(0.55)
                    .padding({ left: 6, right: 4 })
                    .onClick(() => {
                      this.efShowPass = !this.efShowPass;
                    })
                }
                .width('100%')
                .height(40)
                .padding({ left: 12, right: 10 })
                .borderRadius(12)
                .backgroundColor(this.p().bgCard)
                .border({ width: 1, color: this.p().border })
              }

              this.FormInputBox(t('网址 / 域名（可选）'), 'https://...', this.efUrl, (v: string) => {
                this.efUrl = v;
              })

              // 2FA Secret with QR scan link
              Column({ space: 6 }) {
                Row() {
                  Text(t('两步验证密钥（可选）')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6)
                  Text(t('相机扫码'))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().brand)
                    .onClick(() => {
                      this.scanOtpForEdit();
                    })
                }.width('100%').padding({ left: 4, right: 4 }).justifyContent(FlexAlign.SpaceBetween)

                Row() {
                  TextInput({ placeholder: t('输入两步验证密钥'), text: this.efOtp })
                    .fontSize(12)
                    .fontFamily(this.efOtp.length > 0 ? 'monospace' : '')
                    .fontColor(this.p().fgMain)
                    .placeholderColor(this.p().placeholder)
                    .placeholderFont({ size: 12 })
                    .backgroundColor(Color.Transparent)
                    .width('100%')
                    .height('100%')
                    .onChange((v: string) => {
                      this.efOtp = v;
                    })
                }
                .width('100%')
                .height(40)
                .padding({ left: 12, right: 12 })
                .borderRadius(12)
                .backgroundColor(this.p().bgCard)
                .border({ width: 1, color: this.p().border })
              }

              this.NotesTextarea(t('备注（可选）'), t('补充安全提示或恢复说明...'), 68)
            } else if (this.efType === 'card') {
              this.FormInputBox(
                t('持卡人姓名'),
                t('卡片上的姓名拼音或中文'),
                this.efCardName,
                (v: string) => {
                  this.efCardName = v;
                }
              )
              this.FormInputBox(
                t('卡号 *'),
                t('输入银行卡号'),
                this.efCardNo,
                (v: string) => {
                  this.efCardNo = v;
                },
                true
              )
              Row({ space: 10 }) {
                Column({ space: 6 }) {
                  Text(t('有效期')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
                  Row() {
                    TextInput({ placeholder: 'MM/YY', text: this.efCardExp })
                      .fontSize(12)
                      .fontFamily(this.efCardExp.length > 0 ? 'monospace' : '')
                      .fontColor(this.p().fgMain)
                      .placeholderColor(this.p().placeholder)
                      .placeholderFont({ size: 12 })
                      .backgroundColor(Color.Transparent)
                      .width('100%')
                      .height('100%')
                      .onChange((v: string) => {
                        this.efCardExp = v;
                      })
                  }
                  .width('100%').height(40).padding({ left: 12, right: 12 })
                  .borderRadius(12).backgroundColor(this.p().bgCard)
                  .border({ width: 1, color: this.p().border })
                }.layoutWeight(1)

                Column({ space: 6 }) {
                  Text(t('安全码 CVV')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
                  Row() {
                    TextInput({ placeholder: t('3-4 位数字'), text: this.efCardCvv })
                      .type(InputType.Password)
                      .showPasswordIcon(false)
                      .fontSize(12)
                      .fontFamily(this.efCardCvv.length > 0 ? 'monospace' : '')
                      .fontColor(this.p().fgMain)
                      .placeholderColor(this.p().placeholder)
                      .placeholderFont({ size: 12 })
                      .backgroundColor(Color.Transparent)
                      .width('100%')
                      .height('100%')
                      .onChange((v: string) => {
                        this.efCardCvv = v;
                      })
                  }
                  .width('100%').height(40).padding({ left: 12, right: 12 })
                  .borderRadius(12).backgroundColor(this.p().bgCard)
                  .border({ width: 1, color: this.p().border })
                }.layoutWeight(1)
              }.width('100%')

              this.NotesTextarea(t('备注（可选）'), t('补充安全提示或恢复说明...'), 68)
            } else if (this.efType === 'note') {
              this.NotesTextarea(
                t('加密备忘正文 *'),
                t('输入需要加密保存的文本、助记信息或密钥片段...'),
                176
              )
            } else {
              this.FormInputBox(
                t('姓名'),
                t('真实姓名或常用昵称'),
                this.efIdName,
                (v: string) => {
                  this.efIdName = v;
                }
              )
              this.FormInputBox(t('邮箱'), 'name@example.com', this.efIdEmail, (v: string) => {
                this.efIdEmail = v;
              })
              this.FormInputBox(
                t('手机号'),
                t('手机号码'),
                this.efIdPhone,
                (v: string) => {
                  this.efIdPhone = v;
                },
                true
              )
              this.FormInputBox(
                t('地址 / 证件信息'),
                t('居住地址、身份证号或密保问题'),
                this.efIdAddr,
                (v: string) => {
                  this.efIdAddr = v;
                }
              )
              this.NotesTextarea(t('备注（可选）'), t('补充安全提示或恢复说明...'), 68)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 280 })
        }
        .padding(16)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
    .bindSheet($$this.showQuickGen, this.QuickGenActionSheet(), {
      detents: [SheetSize.FIT_CONTENT],
      dragBar: true,
    })
  }

  @Builder
  NotesTextarea(label: string, placeholder: string, boxHeight: number) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(11)
        .fontColor(this.p().fgMain)
        .opacity(0.6)
        .padding({ left: 4 })
        .width('100%')
      TextArea({ placeholder: placeholder, text: this.efNotes })
        .fontSize(12)
        .fontColor(this.p().fgMain)
        .placeholderColor(this.p().placeholder)
        .placeholderFont({ size: 12 })
        .backgroundColor(this.p().bgCard)
        .borderRadius(12)
        .border({ width: 1, color: this.p().border })
        .height(boxHeight)
        .width('100%')
        .padding(10)
        .onChange((v: string) => {
          this.efNotes = v;
        })
    }
  }
}

@ComponentV2
export struct FolderManagerSheet {
  @Param onClose: () => void = () => {};
  @Param onRequestConfirm: (req: ConfirmDialogRequest) => void = () => {};
  @Local newFolderInput: string = '';

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private totalActiveCount(): number {
    let c = 0;
    for (let i = 0; i < vaultStore.items.length; i++) {
      if (!vaultStore.items[i].deletedAt) {
        c += 1;
      }
    }
    return c;
  }

  build() {
    Column() {
      Row() {
        Text(t('关闭'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
        Text(t('文件夹管理'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text(t('完成'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 8 }) {
            Row() {
              TextInput({ placeholder: t('输入新文件夹名称...'), text: this.newFolderInput })
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.newFolderInput = v;
                })
            }
            .layoutWeight(1)
            .height(40)
            .padding({ left: 12, right: 12 })
            .borderRadius(12)
            .backgroundColor(this.p().bgCard)
            .border({ width: 1, color: this.p().border })

            Button(t('新建'))
              .height(40)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .borderRadius(12)
              .backgroundColor(this.p().brand)
              .fontColor('#FFFFFF')
              .onClick(() => {
                if (vaultStore.addCustomFolder(this.newFolderInput)) {
                  this.newFolderInput = '';
                }
              })
          }.width('100%')

          Column() {
            // All credentials row
            Row() {
              Text(t('全部凭证'))
                .fontSize(14)
                .fontWeight(vaultStore.activeFolder === ALL_FOLDER_FILTER ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(vaultStore.activeFolder === ALL_FOLDER_FILTER ? this.p().brand : this.p().fgMain)
                .layoutWeight(1)
              Text(`${this.totalActiveCount()}`)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              vaultStore.activeFolder = ALL_FOLDER_FILTER;
              this.onClose();
            })

            Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })

            // Default folder row (not deletable)
            Row() {
              Text(t('默认'))
                .fontSize(14)
                .fontWeight(vaultStore.activeFolder === DEFAULT_FOLDER ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(vaultStore.activeFolder === DEFAULT_FOLDER ? this.p().brand : this.p().fgMain)
                .layoutWeight(1)
              Text(`${vaultStore.countItemsInFolder(DEFAULT_FOLDER)}`)
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .opacity(0.55)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              vaultStore.activeFolder = DEFAULT_FOLDER;
              this.onClose();
            })

            // Custom folders
            ForEach(vaultStore.folders, (f: string) => {
              Divider().strokeWidth(0.5).color(this.p().divider).margin({ left: 16 })
              Row({ space: 10 }) {
                Text(f)
                  .fontSize(14)
                  .fontWeight(vaultStore.activeFolder === f ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(vaultStore.activeFolder === f ? this.p().brand : this.p().fgMain)
                  .layoutWeight(1)
                  .onClick(() => {
                    vaultStore.activeFolder = f;
                    this.onClose();
                  })
                Text(`${vaultStore.countItemsInFolder(f)}`)
                  .fontSize(12)
                  .fontColor(this.p().fgMain)
                  .opacity(0.55)
                Text(t('删除'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.p().danger)
                  .padding({ left: 6, top: 4, bottom: 4 })
                  .onClick(() => {
                    const cnt = vaultStore.countItemsInFolder(f);
                    this.onRequestConfirm({
                      title: t('删除文件夹？'),
                      message: tf(
                        '该文件夹内的 {n} 条凭证将自动移入「默认」文件夹，不会丢失数据。',
                        '{n} credentials in this folder will be moved to "Default". No data will be lost.',
                        { 'n': cnt }
                      ),
                      confirmLabel: t('确认删除'),
                      isDanger: true,
                      onConfirm: () => {
                        vaultStore.deleteCustomFolder(f);
                      },
                    });
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
            }, (f: string) => f)
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor(this.p().bgCard)
          .border({ width: 1, color: this.p().border })
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
export struct TrashSheet {
  @Param onClose: () => void = () => {};
  @Param onRequestConfirm: (req: ConfirmDialogRequest) => void = () => {};

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private trashedItems(): VaultItem[] {
    return vaultStore.items.filter((i: VaultItem) => !!i.deletedAt);
  }

  build() {
    Column() {
      Row() {
        Text(t('关闭'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            this.onClose();
          })
        Text(`${t('回收站')} (${this.trashedItems().length})`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        if (this.trashedItems().length > 0) {
          Text(t('清空'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.p().danger)
            .onClick(() => {
              this.onRequestConfirm({
                title: t('清空回收站？'),
                message: t('回收站内所有凭证将被永久销毁且无法恢复。'),
                confirmLabel: t('确认清空'),
                isDanger: true,
                onConfirm: () => {
                  vaultStore.emptyTrash();
                },
              });
            })
        } else {
          Text('').width(36)
        }
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 8 }) {
          if (this.trashedItems().length === 0) {
            Text(t('回收站为空'))
              .fontSize(12)
              .fontColor(this.p().fgMain)
              .opacity(0.5)
              .padding({ top: 48, bottom: 48 })
              .width('100%')
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.trashedItems(), (item: VaultItem) => {
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(item.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.p().fgMain)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(t('30 天后自动彻底清理'))
                    .fontSize(11)
                    .fontColor(this.p().fgMain)
                    .opacity(0.55)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                Button(t('恢复'))
                  .height(30)
                  .fontSize(12)
                  .borderRadius(10)
                  .backgroundColor(this.p().successSoft)
                  .fontColor(this.p().success)
                  .onClick(() => {
                    vaultStore.restoreFromTrash(item.id);
                  })
                Button(t('删除'))
                  .height(30)
                  .fontSize(12)
                  .borderRadius(10)
                  .backgroundColor(this.p().dangerSoft)
                  .fontColor(this.p().danger)
                  .onClick(() => {
                    this.onRequestConfirm({
                      title: tf('彻底删除「{name}」？', 'Permanently delete "{name}"?', { 'name': item.title }),
                      message: t('删除后将无法恢复，请确认不再需要此凭证。'),
                      confirmLabel: t('彻底删除'),
                      isDanger: true,
                      onConfirm: () => {
                        vaultStore.purgeItem(item.id);
                      },
                    });
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor(this.p().bgCard)
              .border({ width: 1, color: this.p().border })
            }, (item: VaultItem) => item.id)
          }
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
export struct AddTotpSheet {
  @Param onClose: () => void = () => {};
  @Local mtIssuer: string = '';
  @Local mtAccount: string = '';
  @Local mtSecret: string = '';

  private p(): ThemePalette {
    return getPalette(vaultStore.theme);
  }

  private async scanStandaloneQr(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const raw = await SecurityService.scanQrCode(ctx);
    if (!raw) {
      return;
    }
    try {
      const parsed = RustCoreBridge.parseOtpauthUri(raw);
      vaultStore.addStandaloneTotp(parsed.issuer, parsed.account, parsed.secret);
      vaultStore.showToast(t('已扫码添加动态令牌'));
      this.onClose();
    } catch (e) {
      vaultStore.showToast((e as Error).message, true);
    }
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
        Text(t('添加动态令牌'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.p().fgMain)
        Text(t('保存'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.p().brand)
          .onClick(() => {
            if (this.mtIssuer.trim().length === 0 || this.mtSecret.trim().length === 0) {
              vaultStore.showToast(t('请填写服务名称和密钥'), true);
              return;
            }
            vaultStore.addStandaloneTotp(this.mtIssuer, this.mtAccount, this.mtSecret);
            vaultStore.showToast(t('已添加动态令牌'));
            this.onClose();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: this.p().divider })

      Scroll() {
        Column({ space: 14 }) {
          // Gradient QR Scan Card
          Row({ space: 12 }) {
            Stack() {
              Circle({ width: 40, height: 40 }).fill('#26FFFFFF')
              Text('⊞').fontSize(18).fontColor('#FFFFFF')
            }
            Column({ space: 2 }) {
              Text(t('扫描二维码快速添加'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
              Text(t('对准服务商二维码自动识别'))
                .fontSize(12)
                .fontColor('#FFFFFF')
                .opacity(0.8)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('›').fontSize(18).fontColor('#FFFFFF').opacity(0.85)
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .linearGradient({
            angle: 90,
            colors: [['#4F46E5', 0.0], ['#7C3AED', 1.0]],
          })
          .onClick(() => {
            this.scanStandaloneQr();
          })

          // Divider "手动输入密钥"
          Row({ space: 10 }) {
            Divider().layoutWeight(1).strokeWidth(0.5).color(this.p().border)
            Text(t('手动输入密钥'))
              .fontSize(11)
              .fontColor(this.p().fgMain)
              .opacity(0.5)
            Divider().layoutWeight(1).strokeWidth(0.5).color(this.p().border)
          }.width('100%').padding({ left: 8, right: 8 })

          // 3 fields
          Column({ space: 6 }) {
            Text(t('服务 / 令牌名称 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row() {
              TextInput({ placeholder: t('例如：GitHub、Steam、Apple'), text: this.mtIssuer })
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.mtIssuer = v;
                })
            }.width('100%').height(40).padding({ left: 12, right: 12 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Column({ space: 6 }) {
            Text(t('备注账号或说明（可选）')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row() {
              TextInput({ placeholder: 'name@example.com', text: this.mtAccount })
                .fontSize(12)
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.mtAccount = v;
                })
            }.width('100%').height(40).padding({ left: 12, right: 12 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Column({ space: 6 }) {
            Text(t('动态密钥 *')).fontSize(11).fontColor(this.p().fgMain).opacity(0.6).padding({ left: 4 }).width('100%')
            Row() {
              TextInput({ placeholder: t('输入服务商提供的两步验证密钥'), text: this.mtSecret })
                .fontSize(12)
                .fontFamily(this.mtSecret.length > 0 ? 'monospace' : '')
                .fontColor(this.p().fgMain)
                .placeholderColor(this.p().placeholder)
                .placeholderFont({ size: 12 })
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height('100%')
                .onChange((v: string) => {
                  this.mtSecret = v;
                })
            }.width('100%').height(40).padding({ left: 12, right: 12 }).borderRadius(12)
              .backgroundColor(this.p().bgCard).border({ width: 1, color: this.p().border })
          }

          Text(t('适用于仅需动态验证码的场景；若需与账号密码绑定，可在「保险箱」内编辑配置。'))
            .fontSize(11)
            .lineHeight(17)
            .fontColor(this.p().fgMain)
            .opacity(0.5)
            .padding({ left: 4, right: 4 })
            .width('100%')
        }
        .padding(16)
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .backgroundColor(this.p().bgPage)
  }
}
