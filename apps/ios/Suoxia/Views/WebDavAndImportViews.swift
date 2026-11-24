import SwiftUI
import UniformTypeIdentifiers

// MARK: - WebDAV Sync / Restore Sheet

struct WebDavSheet: View {
    @ObservedObject var store: VaultStore
    let isOnboardingRestore: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var preset: WebDavPreset = .generic
    @State private var guideOpen = false
    @State private var urlInput = ""
    @State private var userInput = ""
    @State private var passInput = ""
    @State private var masterPwdInput = ""
    @State private var confirmDisconnect = false

    private var normalizedPreview: String {
        SecureVaultCore.normalizeWebDavUrl(urlInput)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("关闭"),
                onLeft: { dismiss() },
                title: isOnboardingRestore ? t("从 WebDAV 云端恢复") : t("WebDAV 同步"),
                isDark: store.isDark
            ) {
                if !isOnboardingRestore && store.webdavConfigured {
                    Circle()
                        .fill(AppTheme.emerald)
                        .frame(width: 8, height: 8)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Collapsible Universal Guide
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                guideOpen.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(AppTheme.brand.opacity(0.15))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("?")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(AppTheme.brand)
                                    )
                                Text(t("不知道怎么填？查看通用图文指引"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.5))
                                    .rotationEffect(.degrees(guideOpen ? 180 : 0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if guideOpen {
                            InsetDivider(isDark: store.isDark, inset: 0)
                            VStack(alignment: .leading, spacing: 12) {
                                // Native Schematic Card
                                VStack(spacing: 10) {
                                    HStack(spacing: 8) {
                                        VStack(spacing: 2) {
                                            Text(AppI18n.isChinese ? "锁匣本机加密" : "Encrypted Locally")
                                                .font(.system(size: 11, weight: .bold))
                                            Text(AppI18n.isChinese ? "高强度本地加密" : "Local encryption")
                                                .font(.system(size: 9))
                                                .foregroundColor(AppTheme.brand)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppTheme.brand.opacity(0.12))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.brand.opacity(0.35), lineWidth: 0.8))

                                        VStack(spacing: 2) {
                                            Text("vault.enc")
                                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(AppTheme.brand)
                                                .clipShape(Capsule())
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(AppTheme.brand)
                                        }

                                        VStack(spacing: 2) {
                                            Text(AppI18n.isChinese ? "你的网盘 / NAS" : "Your Cloud / NAS")
                                                .font(.system(size: 11, weight: .bold))
                                            Text(AppI18n.isChinese ? "仅存加密文件" : "Ciphertext only")
                                                .font(.system(size: 9))
                                                .foregroundColor(AppTheme.emerald)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(AppTheme.emerald.opacity(0.12))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.emerald.opacity(0.35), lineWidth: 0.8))
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(AppI18n.isChinese
                                             ? "在任意网盘 / NAS 后台「WebDAV 设置」页找到这 3 项："
                                             : "Find these 3 items in your cloud drive / NAS WebDAV settings:")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.primary.opacity(0.55))
                                        guideBadgeLine("1", AppI18n.isChinese ? "服务器地址：https://.../dav/文件夹/" : "Server URL: https://.../dav/folder/")
                                        guideBadgeLine("2", AppI18n.isChinese ? "账号 + 3 应用专用密码（非网盘登录密码）" : "Username + 3 App Password (not login password)")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(10)
                                }
                                .padding(10)
                                .background(AppTheme.subtleBackground(store.isDark))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                                // 3-Step Text
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(AppI18n.isChinese
                                         ? "第 1 步 · 开启 WebDAV 并复制地址：在你的网盘或 NAS 后台开启 WebDAV（需 https://），直接填目录即可，程序会自动补全 /vault.enc。"
                                         : "Step 1 · Copy WebDAV URL: Enable HTTPS WebDAV on your cloud drive or NAS. Enter the folder URL; /vault.enc is added automatically.")
                                    Text(AppI18n.isChinese
                                         ? "第 2 步 · 生成应用专用密码：大多数网盘禁止直接用登录密码连接 WebDAV，请在网盘「安全设置 / 第三方应用」中新建一个授权密码。"
                                         : "Step 2 · Create App Password: Most providers require an app-specific password instead of your account login password.")
                                    Text(AppI18n.isChinese
                                         ? "第 3 步 · 多端保持一致：手机端与电脑端填写相同服务器地址并使用相同主密码，即可随时双向同步。"
                                         : "Step 3 · Keep Devices Aligned: Use the same server URL and master password across phone and desktop.")
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.primary.opacity(0.78))
                                .lineSpacing(3)
                            }
                            .padding(14)
                        }
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                    // Preset Chips
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("常用服务参考格式（可选）"))
                            .font(.system(size: 11))
                            .foregroundColor(.primary.opacity(0.55))
                            .padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(WebDavPreset.allCases) { p in
                                    let on = preset == p
                                    Button {
                                        preset = p
                                    } label: {
                                        Text(p.label)
                                            .font(.system(size: 11, weight: on ? .semibold : .medium))
                                            .foregroundColor(on ? AppTheme.brand : .primary.opacity(0.75))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(on ? AppTheme.brand.opacity(0.1) : AppTheme.cardBackground(store.isDark))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(on ? AppTheme.brand.opacity(0.4) : AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text(preset.tip)
                            .font(.system(size: 11))
                            .foregroundColor(.primary.opacity(0.6))
                            .padding(.horizontal, 4)
                    }

                    // Form Fields
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            FormTextFieldBox(
                                label: t("服务器地址 *"),
                                placeholder: preset.placeholder,
                                text: $urlInput,
                                isDark: store.isDark,
                                keyboardType: .URL
                            )
                            if !normalizedPreview.isEmpty {
                                Text((AppI18n.isChinese ? "实际同步文件：" : "Sync file: ") + normalizedPreview)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppTheme.brand)
                                    .padding(.horizontal, 4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        FormTextFieldBox(
                            label: t("账号 *"),
                            placeholder: t("输入网盘 / NAS 用户名或邮箱"),
                            text: $userInput,
                            isDark: store.isDark,
                            keyboardType: .emailAddress
                        )

                        FormTextFieldBox(
                            label: t("应用专用密码 / 授权码 *"),
                            placeholder: (!isOnboardingRestore && store.webdavHasSavedPass)
                                ? t("留空则沿用已保存的授权密码")
                                : t("输入 WebDAV 专用密码"),
                            text: $passInput,
                            isDark: store.isDark,
                            isSecure: true,
                            showEyeToggle: true
                        )

                        if isOnboardingRestore {
                            FormTextFieldBox(
                                label: t("主密码 *"),
                                placeholder: t("输入云端保险箱对应的主密码"),
                                text: $masterPwdInput,
                                isDark: store.isDark,
                                isSecure: true,
                                showEyeToggle: true
                            )
                        }
                    }

                    if isOnboardingRestore {
                        Button {
                            Task {
                                let ok = await store.restoreFromWebDav(
                                    url: urlInput,
                                    username: userInput,
                                    webdavPassword: passInput,
                                    masterPassword: masterPwdInput
                                )
                                if ok { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.webdavSyncing {
                                    ProgressView().tint(.white)
                                }
                                Text(t("连接并恢复"))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.brand)
                            .cornerRadius(16)
                        }
                        .disabled(store.webdavSyncing)
                    } else {
                        // Event-Driven Auto Sync Toggle
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("自动同步"))
                                    .font(.system(size: 13, weight: .semibold))
                                Text(t("启动或修改凭证后自动与云端保持一致"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary.opacity(0.55))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.webdavAutoSync },
                                set: { val in
                                    store.webdavAutoSync = val
                                    store.saveMeta()
                                    store.showToast(val ? t("已开启自动同步") : t("已关闭自动同步"))
                                }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.brand)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardBackground(store.isDark))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                        // Connected Status Row
                        if store.webdavConfigured {
                            HStack {
                                HStack(spacing: 4) {
                                    Text(AppI18n.isChinese ? "同步状态：" : "Status:")
                                        .foregroundColor(.primary.opacity(0.7))
                                    Text(t("已连接"))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.emerald)
                                }
                                Spacer()
                                Text(store.webdavLastSync.isEmpty
                                     ? (AppI18n.isChinese ? "尚未同步" : "Not synced yet")
                                     : (AppI18n.isChinese ? "上次同步：\(store.webdavLastSync)" : "Last sync: \(store.webdavLastSync)"))
                                    .foregroundColor(.primary.opacity(0.55))
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.subtleBackground(store.isDark))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }

                        // Action Buttons
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await store.testWebDav(url: urlInput, username: userInput, passwordInput: passInput)
                                }
                            } label: {
                                Text(t("测试连接"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(AppTheme.cardBackground(store.isDark))
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                            }
                            .disabled(store.webdavSyncing)

                            Button {
                                if store.saveWebDavConfig(url: urlInput, username: userInput, passwordInput: passInput) {
                                    passInput = ""
                                }
                            } label: {
                                Text(t("保存配置"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(AppTheme.brand)
                                    .cornerRadius(14)
                            }
                            .disabled(store.webdavSyncing)
                        }

                        Button {
                            Task { await store.syncWebDavNow() }
                        } label: {
                            HStack(spacing: 8) {
                                if store.webdavSyncing {
                                    ProgressView().tint(AppTheme.brand)
                                }
                                Text(t("立即同步"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(store.webdavConfigured ? AppTheme.brand : .primary.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(store.webdavConfigured ? AppTheme.brand.opacity(0.1) : AppTheme.cardBackground(store.isDark))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(store.webdavConfigured ? AppTheme.brand.opacity(0.3) : AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                            )
                        }
                        .disabled(store.webdavSyncing)

                        if store.webdavConfigured {
                            HStack {
                                Spacer()
                                Button {
                                    confirmDisconnect = true
                                } label: {
                                    Text(t("断开同步"))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.danger)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .onAppear {
            if !isOnboardingRestore {
                urlInput = store.webdavUrl
                userInput = store.webdavUser
            }
        }
        .alert(t("断开 WebDAV 同步？"), isPresented: $confirmDisconnect) {
            Button(t("取消"), role: .cancel) {}
            Button(t("确认断开"), role: .destructive) {
                store.disconnectWebDav()
                urlInput = ""
                userInput = ""
                passInput = ""
            }
        } message: {
            Text(t("将清除本机保存的服务器地址与密码，不会删除你本机或云端已有的备份数据。"))
        }
    }

    private func guideBadgeLine(_ num: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppTheme.brand)
                .frame(width: 14, height: 14)
                .overlay(
                    Text(num)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                )
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.primary.opacity(0.85))
        }
    }
}

// MARK: - Remote Vault Master Password Prompt Sheet

struct RemotePasswordPromptSheet: View {
    @ObservedObject var store: VaultStore
    @State private var pwd = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(t("输入云端保险箱主密码"))
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 20)

            Text(t("云端备份使用了不同的主密码或密钥，请输入对应主密码以解密并同步。"))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.6))
                .multilineTextAlignment(.center)

            FormTextFieldBox(
                label: t("主密码 *"),
                placeholder: t("输入云端保险箱对应的主密码"),
                text: $pwd,
                isDark: store.isDark,
                isSecure: true,
                showEyeToggle: true
            )

            HStack(spacing: 10) {
                Button {
                    store.cancelRemotePasswordPrompt()
                } label: {
                    Text(t("取消"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.subtleBackground(store.isDark))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }

                Button {
                    _ = store.unlockAndApplyRemoteVault(password: pwd)
                } label: {
                    Text(t("解密并同步"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.brand)
                        .cornerRadius(12)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
    }
}

// MARK: - 3-Step Import Flow Sheet

private enum ImportFlowStep {
    case pick, decrypt, preview
}

struct ImportFlowSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: ImportFlowStep = .pick
    @State private var selectedKind: ImportSourceKind = .suoxiaJson
    @State private var pickedFileURL: URL? = nil
    @State private var filePassword = ""
    @State private var parsedResult: ParsedImportResult? = nil
    @State private var strategy: ImportStrategy = .skip

    // For onboarding import (when no local vault exists yet)
    @State private var newMasterPwd1 = ""
    @State private var newMasterPwd2 = ""

    @State private var showFileImporter = false
    @State private var showOverwriteAlert = false

    private var allowedTypes: [UTType] {
        switch selectedKind {
        case .suoxiaJson: return [.json, .data]
        case .kdbx: return [.data, .item]
        case .browserCsvJson: return [.commaSeparatedText, .json, .plainText, .data]
        }
    }

    private var duplicateSet: Set<String> {
        Set(store.activeItems.map { "\($0.title)|\($0.username.isEmpty ? $0.cardNumber : $0.username)" })
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: step == .pick ? t("关闭") : (step == .decrypt ? t("‹ 上一步") : t("‹ 重新选择")),
                onLeft: {
                    if step == .pick {
                        dismiss()
                    } else {
                        step = .pick
                        filePassword = ""
                        parsedResult = nil
                    }
                },
                title: step == .pick ? t("导入凭证") : (step == .decrypt ? t("解密备份文件") : t("导入预览")),
                isDark: store.isDark
            )

            switch step {
            case .pick:
                pickStepView
            case .decrypt:
                decryptStepView
            case .preview:
                if let parsed = parsedResult {
                    previewStepView(parsed)
                }
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .failure(let err):
                store.showToast(err.localizedDescription, warn: true)
            case .success(let urls):
                guard let url = urls.first else { return }
                pickedFileURL = url
                filePassword = ""
                if store.checkIfFileNeedsPassword(url: url, kind: selectedKind) {
                    step = .decrypt
                } else {
                    do {
                        let parsed = try store.parseImportFile(url: url, kind: selectedKind, password: nil)
                        parsedResult = parsed
                        strategy = .skip
                        step = .preview
                    } catch {
                        store.showToast(error.localizedDescription, warn: true)
                    }
                }
            }
        }
        .alert(t("确认覆盖当前保险箱？"), isPresented: $showOverwriteAlert) {
            Button(t("取消"), role: .cancel) {}
            Button(t("确认覆盖"), role: .destructive) {
                if let parsed = parsedResult {
                    finishImport(parsed)
                }
            }
        } message: {
            if let parsed = parsedResult {
                Text(AppI18n.isChinese
                     ? "当前保险箱中所有现有凭证将被清空，并替换为导入文件中的 \(parsed.items.count) 条凭证，此操作无法撤销。"
                     : "All existing items will be replaced with \(parsed.items.count) imported items. This cannot be undone.")
            }
        }
    }

    private var pickStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("请选择要导入的文件格式"))
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.6))
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(ImportSourceKind.allCases.enumerated()), id: \.element.id) { idx, kind in
                        if idx > 0 { InsetDivider(isDark: store.isDark) }
                        Button {
                            selectedKind = kind
                            showFileImporter = true
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(kind.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(kind.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary.opacity(0.55))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary.opacity(0.35))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.cardBackground(store.isDark))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                Text(t("所有文件解析与解密均在设备本地离线完成，不会上传至任何服务器。"))
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.55))
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
            .padding(16)
        }
    }

    private var decryptStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedKind.badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.brand.opacity(0.1))
                        .cornerRadius(6)
                    Text(pickedFileURL?.lastPathComponent ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.75))
                    Text(t("该文件受密码保护，请输入备份对应的解密密码。"))
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.cardBackground(store.isDark))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                FormTextFieldBox(
                    label: t("文件解密密码 *"),
                    placeholder: t("输入备份文件密码"),
                    text: $filePassword,
                    isDark: store.isDark,
                    isSecure: true,
                    showEyeToggle: true
                )

                Button {
                    let pwd = filePassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !pwd.isEmpty else {
                        store.showToast(t("请输入备份文件解密密码"), warn: true)
                        return
                    }
                    guard let url = pickedFileURL else { return }
                    do {
                        let parsed = try store.parseImportFile(url: url, kind: selectedKind, password: pwd)
                        parsedResult = parsed
                        strategy = .skip
                        step = .preview
                        store.showToast(t("备份文件解密成功"))
                    } catch {
                        store.showToast(error.localizedDescription, warn: true)
                    }
                } label: {
                    Text(t("解密并解析文件"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.brand)
                        .cornerRadius(16)
                }
            }
            .padding(16)
        }
    }

    private func previewStepView(_ parsed: ParsedImportResult) -> some View {
        let existing = duplicateSet
        let dupFlags = parsed.items.map { existing.contains("\($0.title)|\($0.username.isEmpty ? $0.cardNumber : $0.username)") }
        let dupCount = dupFlags.filter { $0 }.count
        let newCount = parsed.items.count - dupCount
        let finalCount = strategy == .skip ? newCount : parsed.items.count
        let totpCount = parsed.items.filter { !$0.otpSecret.isEmpty }.count + parsed.standaloneTotps.count

        return VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Summary Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(parsed.badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.brand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.brand.opacity(0.1))
                            .cornerRadius(6)
                        Text(parsed.fileName)
                            .font(.system(size: 11))
                            .foregroundColor(.primary.opacity(0.75))

                        HStack(spacing: 8) {
                            statCell(value: "\(parsed.items.count)", label: t("识别条数"), color: .primary)
                            statCell(value: "\(newCount)", label: t("新增条目"), color: AppTheme.emerald)
                            statCell(value: "\(dupCount)", label: t("重复条目"), color: dupCount > 0 ? AppTheme.amber : .primary.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                    // Parsed Items Preview (first 20)
                    VStack(spacing: 0) {
                        HStack {
                            Text(AppI18n.isChinese
                                 ? "内容预览（共 \(parsed.items.count) 条 · \(parsed.folders.count) 个文件夹\(totpCount > 0 ? " · \(totpCount) 个 2FA" : "")）"
                                 : "Preview (\(parsed.items.count) items · \(parsed.folders.count) folders\(totpCount > 0 ? " · \(totpCount) 2FA" : ""))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.55))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        ForEach(Array(parsed.items.prefix(20).enumerated()), id: \.offset) { idx, r in
                            InsetDivider(isDark: store.isDark)
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Text(r.subtitleText)
                                        .font(.system(size: 11))
                                        .foregroundColor(.primary.opacity(0.55))
                                        .lineLimit(1)
                                }
                                Spacer()
                                let isDup = dupFlags[idx]
                                Text(isDup ? t("重复") : t("新增"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isDup ? AppTheme.amber : AppTheme.emerald)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background((isDup ? AppTheme.amber : AppTheme.emerald).opacity(0.12))
                                    .cornerRadius(6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                    // Onboarding Master Password Setup (if no vault exists yet)
                    if !store.hasVault {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t("创建本地保险箱主密码"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.6))
                                .padding(.horizontal, 4)
                            FormTextFieldBox(
                                label: t("主密码（至少 8 位）"),
                                placeholder: t("输入高强度主密码"),
                                text: $newMasterPwd1,
                                isDark: store.isDark,
                                isSecure: true,
                                showEyeToggle: true
                            )
                            FormTextFieldBox(
                                label: t("确认主密码"),
                                placeholder: t("再次输入以确认"),
                                text: $newMasterPwd2,
                                isDark: store.isDark,
                                isSecure: true,
                                showEyeToggle: true
                            )
                        }
                    }

                    // 3 Strategies (only shown when vault already exists)
                    if store.hasVault {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("选择导入方式"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.55))
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                strategyRow(
                                    kind: .skip,
                                    title: t("合并并跳过重复项"),
                                    tag: t("推荐"),
                                    desc: AppI18n.isChinese
                                        ? "仅新增 \(newCount) 条不重复凭证，自动跳过 \(dupCount) 条重复项"
                                        : "Add \(newCount) new items, skip \(dupCount) duplicates",
                                    danger: false
                                )
                                InsetDivider(isDark: store.isDark)
                                strategyRow(
                                    kind: .merge,
                                    title: t("全部合并（保留重复项）"),
                                    tag: nil,
                                    desc: AppI18n.isChinese
                                        ? "将全部 \(parsed.items.count) 条凭证追加至当前保险箱"
                                        : "Append all \(parsed.items.count) items to your vault",
                                    danger: false
                                )
                                InsetDivider(isDark: store.isDark)
                                strategyRow(
                                    kind: .overwrite,
                                    title: t("完全覆盖当前保险箱"),
                                    tag: t("谨慎"),
                                    desc: AppI18n.isChinese
                                        ? "清空现有 \(store.activeItems.count) 条凭证，并以导入文件完整替换"
                                        : "Replace all \(store.activeItems.count) existing items",
                                    danger: true
                                )
                            }
                            .background(AppTheme.cardBackground(store.isDark))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }
                    }
                }
                .padding(16)
            }

            // Sticky Footer CTA
            VStack(spacing: 0) {
                Rectangle().fill(AppTheme.dividerColor(store.isDark)).frame(height: 0.5)
                Button {
                    if !store.hasVault {
                        if newMasterPwd1.count < 8 {
                            store.showToast(t("主密码至少 8 位"), warn: true)
                            return
                        }
                        if newMasterPwd1 != newMasterPwd2 {
                            store.showToast(t("两次密码输入不一致"), warn: true)
                            return
                        }
                        finishImport(parsed)
                    } else if strategy == .overwrite {
                        showOverwriteAlert = true
                    } else {
                        finishImport(parsed)
                    }
                } label: {
                    Text(strategy == .overwrite
                         ? (AppI18n.isChinese ? "覆盖并导入（\(finalCount) 条）" : "Overwrite & Import (\(finalCount))")
                         : (AppI18n.isChinese ? "确认导入（\(finalCount) 条）" : "Confirm Import (\(finalCount))"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(strategy == .overwrite ? AppTheme.danger : AppTheme.brand)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.subtleBackground(store.isDark))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    private func strategyRow(kind: ImportStrategy, title: String, tag: String?, desc: String, danger: Bool) -> some View {
        let on = strategy == kind
        let accent = danger ? AppTheme.danger : AppTheme.brand
        return Button {
            strategy = kind
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(danger ? AppTheme.danger : .primary)
                        if let tag {
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.1))
                                .cornerRadius(5)
                        }
                    }
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.55))
                }
                Spacer()
                Circle()
                    .stroke(on ? accent : Color.primary.opacity(0.28), lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if on {
                            Circle()
                                .fill(accent)
                                .frame(width: 9, height: 9)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func finishImport(_ parsed: ParsedImportResult) {
        let ok = store.executeImport(
            parsed: parsed,
            strategy: store.hasVault ? strategy : .merge,
            newMasterPassword: store.hasVault ? nil : newMasterPwd1
        )
        if ok { dismiss() }
    }
}
