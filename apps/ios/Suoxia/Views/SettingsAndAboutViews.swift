import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var store: VaultStore

    @State private var showChangePwd = false
    @State private var showGestureSetup = false
    @State private var showAutoLockDialog = false
    @State private var showWebDav = false
    @State private var showImport = false
    @State private var showExportDialog = false
    @State private var showAbout = false

    // Biometric verification sheet
    @State private var pendingBioKind: String? = nil // "face" | "finger"

    // Export state
    @State private var showKdbxPwdAlert = false
    @State private var kdbxExportPassword = ""
    @State private var exportDocument: ExportFileDocument? = nil
    @State private var exportFileName: String = ""
    @State private var exportContentType: UTType = .json
    @State private var showFileExporter = false

    private var webdavSubtitle: String {
        let syncPart: String
        if !store.webdavLastSync.isEmpty {
            syncPart = AppI18n.isChinese ? "上次同步 \(store.webdavLastSync)" : "Synced \(store.webdavLastSync)"
        } else {
            syncPart = store.webdavAutoSync ? t("自动同步已开启") : t("手动同步")
        }
        let host = store.webdavHost
        return host.isEmpty ? syncPart : "\(host) · \(syncPart)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(t("首选项"))
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 4)

                // Group 1: Security & Privacy
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("安全与隐私"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.55))
                        .padding(.horizontal, 8)

                    VStack(spacing: 0) {
                        navRow(title: t("修改主密码")) {
                            showChangePwd = true
                        }

                        InsetDivider(isDark: store.isDark)

                        toggleRow(
                            title: t("应用锁"),
                            subtitle: t("开启后启动应用需验证身份"),
                            isOn: Binding(
                                get: { store.requireUnlock },
                                set: { val in
                                    store.requireUnlock = val
                                    store.saveMeta()
                                }
                            )
                        )

                        if store.requireUnlock {
                            InsetDivider(isDark: store.isDark)
                            toggleRow(
                                title: t("面容识别"),
                                subtitle: t("设备支持时优先使用面容解锁"),
                                isOn: Binding(
                                    get: { store.bioFaceOn },
                                    set: { newVal in
                                        if newVal {
                                            pendingBioKind = "face"
                                        } else {
                                            store.bioFaceOn = false
                                            store.saveMeta()
                                        }
                                    }
                                )
                            )

                            InsetDivider(isDark: store.isDark)
                            toggleRow(
                                title: t("指纹识别"),
                                subtitle: t("面容不可用或失败时快速切换指纹"),
                                isOn: Binding(
                                    get: { store.bioFingerOn },
                                    set: { newVal in
                                        if newVal {
                                            pendingBioKind = "finger"
                                        } else {
                                            store.bioFingerOn = false
                                            store.saveMeta()
                                        }
                                    }
                                )
                            )

                            InsetDivider(isDark: store.isDark)
                            Button {
                                showGestureSetup = true
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t("手势密码"))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(t("绘制九宫格图案，作为快捷或备用解锁方式"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary.opacity(0.55))
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text(store.gestureOn ? t("已开启") : t("未设置"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary.opacity(0.6))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary.opacity(0.35))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            InsetDivider(isDark: store.isDark)
                            navRow(title: t("自动锁定"), trailingText: store.autoLock.label) {
                                showAutoLockDialog = true
                            }
                        }

                        InsetDivider(isDark: store.isDark)

                        toggleRow(
                            title: t("防截屏与后台隐私保护"),
                            subtitle: t("禁止截屏录屏，切出应用时自动保护"),
                            isOn: Binding(
                                get: { store.privacyMask },
                                set: { val in
                                    store.privacyMask = val
                                    store.saveMeta()
                                }
                            )
                        )
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }

                // Group 2: Sync & Backup
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("同步与备份"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.55))
                        .padding(.horizontal, 8)

                    VStack(spacing: 0) {
                        Button {
                            showWebDav = true
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("WebDAV 同步"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    if store.webdavConfigured {
                                        Text(webdavSubtitle)
                                            .font(.system(size: 11))
                                            .foregroundColor(.primary.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    if store.webdavConfigured {
                                        Circle()
                                            .fill(AppTheme.emerald)
                                            .frame(width: 6, height: 6)
                                        Text(t("已连接"))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.emerald)
                                    } else {
                                        Text(t("未配置"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary.opacity(0.6))
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary.opacity(0.35))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        InsetDivider(isDark: store.isDark)

                        navRow(title: t("导入凭证"), trailingText: "JSON / KDBX / CSV") {
                            showImport = true
                        }

                        InsetDivider(isDark: store.isDark)

                        navRow(title: t("导出加密备份")) {
                            showExportDialog = true
                        }
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }

                // Group 3: General (NO language switcher — follows system OS locale)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("通用"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.55))
                        .padding(.horizontal, 8)

                    VStack(spacing: 0) {
                        HStack {
                            Text(t("外观模式"))
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            HStack(spacing: 2) {
                                themeChip(dark: false, label: t("浅色"))
                                themeChip(dark: true, label: t("深色"))
                            }
                            .padding(2)
                            .background(AppTheme.subtleBackground(store.isDark))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)

                        InsetDivider(isDark: store.isDark)

                        navRow(title: t("关于锁匣"), trailingText: "v1.0.0") {
                            showAbout = true
                        }
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .sheet(isPresented: $showChangePwd) {
            ChangeMasterPasswordSheet(store: store)
                .svSheetPresentation(.large)
        }
        .sheet(isPresented: $showGestureSetup) {
            GestureSetupSheet(store: store)
                .svSheetPresentation(.large)
        }
        .sheet(isPresented: Binding(
            get: { pendingBioKind != nil },
            set: { if !$0 { pendingBioKind = nil } }
        )) {
            VerifyMasterPasswordSheet(store: store) {
                if pendingBioKind == "face" {
                    store.bioFaceOn = true
                } else if pendingBioKind == "finger" {
                    store.bioFingerOn = true
                }
                store.saveMeta()
                pendingBioKind = nil
            }
            .svSheetPresentation(.compact(260))
        }
        .confirmationDialog(t("自动锁定"), isPresented: $showAutoLockDialog, titleVisibility: .visible) {
            ForEach(AutoLockOption.allCases) { opt in
                Button(opt.label) {
                    store.autoLock = opt
                    store.saveMeta()
                    store.showToast(AppI18n.isChinese ? "自动锁定已设为：\(opt.label)" : "Auto-lock: \(opt.label)")
                }
            }
            Button(t("取消"), role: .cancel) {}
        }
        .sheet(isPresented: $showWebDav) {
            WebDavSheet(store: store, isOnboardingRestore: false)
                .svSheetPresentation(.large)
        }
        .sheet(isPresented: $showImport) {
            ImportFlowSheet(store: store)
                .svSheetPresentation(.large)
        }
        .confirmationDialog(t("导出加密备份"), isPresented: $showExportDialog, titleVisibility: .visible) {
            Button(t("导出为 锁匣加密备份 (.json)")) {
                do {
                    let data = try store.buildEncryptedJsonExport()
                    exportDocument = ExportFileDocument(data: data)
                    exportFileName = "SecureVault_Backup_\(VaultHelpers.todayDateString()).json"
                    exportContentType = .json
                    showFileExporter = true
                } catch {
                    store.showToast(error.localizedDescription, warn: true)
                }
            }
            Button(t("导出为 KeePass (.kdbx)")) {
                kdbxExportPassword = ""
                showKdbxPwdAlert = true
            }
            Button(t("取消"), role: .cancel) {}
        }
        .sheet(isPresented: $showKdbxPwdAlert) {
            KdbxExportPasswordSheet(isDark: store.isDark, password: $kdbxExportPassword) { pwd in
                guard !pwd.isEmpty else {
                    store.showToast(t("请输入导出密码"), warn: true)
                    return false
                }
                do {
                    let data = try store.buildKdbxExport(password: pwd)
                    exportDocument = ExportFileDocument(data: data)
                    exportFileName = "SecureVault_\(VaultHelpers.todayDateString()).kdbx"
                    exportContentType = .data
                    showFileExporter = true
                    return true
                } catch {
                    store.showToast(error.localizedDescription, warn: true)
                    return false
                }
            }
            .svSheetPresentation(.compact(270))
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(let url):
                let name = url.lastPathComponent
                store.showToast(AppI18n.isChinese ? "已保存：\(name)" : "Saved: \(name)")
            case .failure(let err):
                store.showToast(err.localizedDescription, warn: true)
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutSheet(store: store)
                .svSheetPresentation(.large)
        }
    }

    private func navRow(title: String, trailingText: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 4) {
                    if let trailingText {
                        Text(trailingText)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.55))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func themeChip(dark: Bool, label: String) -> some View {
        let on = store.isDark == dark
        return Button {
            store.isDark = dark
            store.saveMeta()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(on ? .white : .primary.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(on ? AppTheme.brand : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Change Master Password Sheet

struct ChangeMasterPasswordSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPwd = ""
    @State private var newPwd = ""
    @State private var confirmPwd = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("取消"),
                onLeft: { dismiss() },
                title: t("修改主密码"),
                isDark: store.isDark
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    FormTextFieldBox(
                        label: t("当前主密码"),
                        placeholder: t("输入当前主密码"),
                        text: $currentPwd,
                        isDark: store.isDark,
                        isSecure: true,
                        showEyeToggle: true
                    )
                    FormTextFieldBox(
                        label: t("新主密码"),
                        placeholder: t("至少 8 位"),
                        text: $newPwd,
                        isDark: store.isDark,
                        isSecure: true,
                        showEyeToggle: true
                    )
                    FormTextFieldBox(
                        label: t("确认新主密码"),
                        placeholder: t("再次输入新主密码"),
                        text: $confirmPwd,
                        isDark: store.isDark,
                        isSecure: true,
                        showEyeToggle: true
                    )

                    Text(t("修改后将使用新密码重新加密本地数据；同步到云端后，其他设备需使用新主密码解锁。"))
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.5))
                        .lineSpacing(3)
                        .padding(.horizontal, 4)

                    Button {
                        if newPwd.count < 8 {
                            store.showToast(t("主密码至少 8 位"), warn: true)
                            return
                        }
                        if newPwd != confirmPwd {
                            store.showToast(t("两次密码输入不一致"), warn: true)
                            return
                        }
                        if store.changeMasterPassword(current: currentPwd, newPassword: newPwd) {
                            dismiss()
                        }
                    } label: {
                        Text(t("确认修改"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.brand)
                            .cornerRadius(16)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
    }
}

// MARK: - About Sheet & Subpages

private enum AboutSubpage {
    case root, privacy, security, license, contact
}

struct AboutSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var page: AboutSubpage = .root
    @State private var externalLinkTarget: (title: String, url: String)? = nil

    private let repoUrl = "https://github.com/NovanJex/SecureVault-Mobile"
    private let issuesUrl = "https://github.com/NovanJex/SecureVault-Mobile/issues"

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: page == .root ? t("关闭") : t("‹ 返回"),
                onLeft: {
                    if page == .root { dismiss() } else { page = .root }
                },
                title: pageTitle,
                isDark: store.isDark
            )

            ScrollView(showsIndicators: false) {
                switch page {
                case .root:
                    aboutRootBody
                case .privacy:
                    privacyBody
                case .security:
                    securityBody
                case .license:
                    licenseBody
                case .contact:
                    contactBody
                }
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .alert(
            externalLinkTarget.map { AppI18n.isChinese ? "将在浏览器中打开\($0.title)" : "Open \($0.title) in Browser" } ?? "",
            isPresented: Binding(
                get: { externalLinkTarget != nil },
                set: { if !$0 { externalLinkTarget = nil } }
            )
        ) {
            Button(t("取消"), role: .cancel) { externalLinkTarget = nil }
            Button(t("前往打开")) {
                if let urlStr = externalLinkTarget?.url, let url = URL(string: urlStr) {
                    openURL(url)
                    store.showToast(t("已在浏览器打开"))
                }
                externalLinkTarget = nil
            }
        } message: {
            if let urlStr = externalLinkTarget?.url {
                Text(urlStr)
            }
        }
    }

    private var pageTitle: String {
        switch page {
        case .root: return t("关于锁匣")
        case .privacy: return t("隐私政策")
        case .security: return t("安全说明")
        case .license: return t("开源许可")
        case .contact: return t("联系我们")
        }
    }

    private var aboutRootBody: some View {
        VStack(spacing: 16) {
            // Brand Header Card
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.brandGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.brand.opacity(0.25), radius: 10, y: 4)
                    .overlay(
                        Image(systemName: "shield")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    )
                Text(t("锁匣 · SecureVault"))
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 2)
                Text(t("本地加密密码管理器 · 手机与电脑加密同步"))
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

            // 5 Info Rows
            VStack(spacing: 0) {
                aboutRow(t("隐私政策")) { page = .privacy }
                InsetDivider(isDark: store.isDark)
                aboutRow(t("安全说明")) { page = .security }
                InsetDivider(isDark: store.isDark)
                aboutRow(t("开源许可")) { page = .license }
                InsetDivider(isDark: store.isDark)
                aboutRow(t("联系我们")) { page = .contact }
                InsetDivider(isDark: store.isDark)
                aboutRow(t("检查更新"), trailing: t("已是最新")) {
                    store.showToast(t("当前已是最新版本 v1.0.0"))
                }
            }
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

            // Footer
            HStack(spacing: 8) {
                Text(t("版本 v1.0.0"))
                Text("·")
                Button {
                    externalLinkTarget = (AppI18n.isChinese ? "开源仓库" : "GitHub Repository", repoUrl)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                        Text(t("开源地址"))
                    }
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 11))
            .foregroundColor(.primary.opacity(0.55))
            .padding(.top, 8)
        }
        .padding(16)
    }

    private func aboutRow(_ title: String, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 4) {
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.55))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func readingCard(_ title: String? = nil, body: String, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            Text(body)
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.82))
                .lineSpacing(5)
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.45))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.cardBackground(store.isDark))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    private var privacyBody: some View {
        VStack(spacing: 14) {
            readingCard(
                body: AppI18n.isChinese
                    ? "「锁匣 · SecureVault」是一款离线优先的本地密码管理工具。以下内容说明本应用如何保护你的数据与使用系统权限。"
                    : "SecureVault is an offline-first local password manager. Here is how we protect your data and use device permissions.",
                footer: AppI18n.isChinese ? "更新日期：2026 年 11 月" : "Updated: November 2026"
            )
            readingCard(
                AppI18n.isChinese ? "一、我们不收集你的个人数据" : "1. Zero Data Collection",
                body: AppI18n.isChinese
                    ? "本应用不设账号注册与登录体系，不运营任何官方云端服务器，也不会收集、上传或共享你的任何密码、账号、卡券、备忘录、两步验证密钥或设备使用行为。应用内不包含任何广告及第三方数据追踪工具。"
                    : "No account registration, no official cloud servers, no analytics, and no ads. We never collect, upload, or share your credentials or usage data."
            )
            readingCard(
                AppI18n.isChinese ? "二、数据如何存储与保护" : "2. Local Storage & Encryption",
                body: AppI18n.isChinese
                    ? "你的全部敏感凭证仅在当前设备本地使用你的主密码完成加密，并保存在系统为应用分配的私有安全目录中。你的主密码仅由你本人掌握，应用及开发者均无法获取或重置你的主密码。"
                    : "All credentials are encrypted locally on your device with your master password and stored in the app's private sandbox. Only you know your master password; it cannot be recovered or reset."
            )
            readingCard(
                AppI18n.isChinese ? "三、自主云同步与文件导入导出" : "3. Self-Hosted Sync & Backups",
                body: AppI18n.isChinese
                    ? "本应用默认完全离线运行。仅当你主动配置并开启 WebDAV 同步时，应用才会连接你本人指定的网盘或 NAS 服务器，且仅传输已加密的备份文件，云盘服务商无法读取其中的任何内容。本地备份的导入与导出均在设备本地完成。"
                    : "The app runs completely offline by default. When you configure WebDAV, it connects only to your chosen server and transfers encrypted vault files only."
            )
            readingCard(
                AppI18n.isChinese ? "四、系统权限使用说明" : "4. System Permissions",
                body: AppI18n.isChinese
                    ? "1. 相机权限：仅在你主动点击扫描二维码添加两步验证密钥时申请，不会在后台调用或保存任何画面。\n2. 面容 / 指纹识别：仅在你开启「应用锁」时由系统完成本地身份验证，应用无法获取你的生物特征信息。\n3. 网络权限：仅用于你主动配置的 WebDAV 同步与手动检查版本更新。"
                    : "1. Camera: Used only when scanning 2FA QR codes.\n2. Face ID / Touch ID: Local system authentication when App Lock is enabled.\n3. Network: Used only for your configured WebDAV sync.",
                footer: AppI18n.isChinese ? "本应用不会申请定位、通讯录、短信、通话记录或后台常驻等无关权限。" : "No location, contacts, or unrelated permissions are requested."
            )
            readingCard(
                AppI18n.isChinese ? "五、你的控制权与数据清除" : "5. Your Control",
                body: AppI18n.isChinese
                    ? "你对自己的数据拥有完全控制权，可随时在应用内编辑、导出、彻底删除任意凭证或断开 WebDAV 同步。卸载本应用时，系统将自动清除应用私有目录内的全部本地数据，请在卸载或换机前提前做好备份。"
                    : "You can edit, export, permanently delete items, or disconnect WebDAV anytime. Uninstalling removes local sandbox data—please back up before switching devices."
            )
            readingCard(
                AppI18n.isChinese ? "六、政策更新与联系我们" : "6. Updates & Contact",
                body: AppI18n.isChinese
                    ? "如因功能演进需要修订本隐私政策，我们会在应用内同步更新说明。如你对隐私与数据安全有任何疑问，欢迎通过「关于锁匣 → 联系我们」中的反馈邮箱或在线问题反馈与我们联系。"
                    : "Policy updates will be reflected in-app. Reach us anytime via About → Contact Us."
            )
        }
        .padding(16)
    }

    private var securityBody: some View {
        VStack(spacing: 14) {
            readingCard(
                body: AppI18n.isChinese
                    ? "「锁匣 · SecureVault」以本地加密、离线可用、数据归你所有为核心原则。以下说明你的密码如何被保护及日常注意事项。"
                    : "SecureVault is built around local encryption, offline availability, and full user ownership."
            )
            readingCard(
                AppI18n.isChinese ? "一、本地高强度加密" : "1. Strong Local Encryption",
                body: AppI18n.isChinese
                    ? "你存入的每一条账号、密码、银行卡、备忘和两步验证密钥，都会在当前设备本地使用你的主密码完成高强度加密后再保存。即使备份文件被他人获取，没有主密码也无法还原出任何内容。"
                    : "Every credential, card, note, and 2FA secret is encrypted locally using your master password before saving."
            )
            readingCard(
                AppI18n.isChinese ? "二、主密码无法找回" : "2. Master Password Cannot Be Recovered",
                body: AppI18n.isChinese
                    ? "本应用不会保存或上传你的主密码，也不存在「忘记密码」或人工重置通道。一旦遗忘主密码，本地和云端的加密数据都无法解开。请务必牢记主密码，或将其手写保存在家中安全位置。"
                    : "Your master password is never stored or uploaded. There is no password reset—keep a written backup in a safe place."
            )
            readingCard(
                AppI18n.isChinese ? "三、应用锁与防窥保护" : "3. App Lock & Privacy Shield",
                body: AppI18n.isChinese
                    ? "你可以在「首选项」中按需开启应用锁，支持系统面容、指纹与手势密码快速验证，并可设置切出后台后自动锁定。同时建议保持隐私保护开启，防止切后台或截屏时泄露敏感信息。"
                    : "Enable App Lock in Preferences with Face ID, Touch ID, or Pattern Lock, and keep Background Privacy Shield on."
            )
            readingCard(
                AppI18n.isChinese ? "四、多端加密同步" : "4. Multi-Device Encrypted Sync",
                body: AppI18n.isChinese
                    ? "开启 WebDAV 同步后，应用仅向你指定的个人网盘或 NAS 传输已加密的备份文件，且全程采用加密连接。网盘服务商无法读取其中的密码内容。手机端与电脑端连接同一地址并使用相同主密码即可双向同步。"
                    : "WebDAV syncs only your encrypted vault file over HTTPS to your own cloud drive or NAS."
            )
            readingCard(
                AppI18n.isChinese ? "五、换机与卸载前请先备份" : "5. Back Up Before Uninstalling",
                body: AppI18n.isChinese
                    ? "卸载应用会导致系统清除应用私有目录内的全部本地数据。更换手机、刷机或卸载前，请先确认 WebDAV 已完成最新同步，或在「首选项 → 导出加密备份」中导出加密文件妥善留存。"
                    : "Uninstalling removes local data. Sync via WebDAV or export an encrypted backup before changing devices."
            )
            readingCard(
                AppI18n.isChinese ? "六、日常使用建议" : "6. Best Practices",
                body: AppI18n.isChinese
                    ? "1. 及时清理明文文件：从浏览器导出的 CSV 密码表属于未加密明文，导入完成后请及时从手机或电脑中彻底删除。\n2. 保护好设备环境：尽量避免在已 Root 或越狱的设备上存放高敏感金融与核心账号。\n3. 定期更新重要密码：可借助「生成器」为重要账号生成高强度随机密码，避免多平台共用同一密码。"
                    : "1. Delete plaintext CSV exports right after importing.\n2. Avoid storing sensitive vaults on jailbroken devices.\n3. Use the Generator to create unique strong passwords."
            )
        }
        .padding(16)
    }

    private var licenseBody: some View {
        VStack(spacing: 14) {
            readingCard(
                body: AppI18n.isChinese
                    ? "「锁匣 · SecureVault」遵循开源精神发布，核心加密与数据同步代码公开透明，欢迎任何人审阅与监督。"
                    : "SecureVault is open source. Core encryption and sync code are transparent and auditable."
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppI18n.isChinese ? "本应用许可协议" : "Application License")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("MIT License")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.brand.opacity(0.1))
                        .cornerRadius(6)
                }
                Text(AppI18n.isChinese
                     ? "• 允许免费使用、复制、修改、合并、发布和分发本软件。\n• 再分发时需在副本中保留原作者的版权声明与本许可说明。\n• 本软件按「现状」提供，不附带任何明示或暗示的担保。"
                     : "• Permission is granted free of charge to use, copy, modify, merge, publish, and distribute.\n• Include the copyright and permission notice in copies.\n• Provided \"AS IS\" without warranty of any kind.")
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(4)
                Text("Copyright © 2026 SecureVault Contributors")
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.5))
                    .padding(.top, 2)
            }
            .padding(16)
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

            VStack(spacing: 0) {
                HStack {
                    Text(AppI18n.isChinese ? "致谢 · 使用的开源组件" : "Acknowledgements")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                licenseItem("RustCrypto", desc: AppI18n.isChinese ? "本地高强度加密与密钥派生支持" : "Local encryption & key derivation", license: "MIT / Apache-2.0")
                licenseItem("keepass-rs", desc: AppI18n.isChinese ? "KeePass (.kdbx) 数据库读写支持" : "KeePass (.kdbx) read/write support", license: "MIT")
                licenseItem("reqwest & rustls", desc: AppI18n.isChinese ? "WebDAV 安全加密网络通信支持" : "Secure HTTPS WebDAV networking", license: "MIT / Apache-2.0")
                licenseItem("serde", desc: AppI18n.isChinese ? "本地备份文件结构解析支持" : "Serialization & backup parsing", license: "MIT / Apache-2.0")
                licenseItem("SwiftUI", desc: AppI18n.isChinese ? "iOS 系统界面框架" : "Apple iOS UI framework", license: "Apple SDK")
            }
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
        }
        .padding(16)
    }

    private func licenseItem(_ name: String, desc: String, license: String) -> some View {
        VStack(spacing: 0) {
            InsetDivider(isDark: store.isDark)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 14, weight: .medium))
                    Text(desc).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                }
                Spacer()
                Text(license)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var contactBody: some View {
        VStack(spacing: 14) {
            readingCard(
                body: AppI18n.isChinese
                    ? "如果你在使用「锁匣 · SecureVault」过程中遇到问题、有改进建议，或对隐私与数据安全存在疑问，欢迎通过以下方式联系我们。"
                    : "Have questions, bug reports, or security feedback? Reach out to us below."
            )

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("反馈邮箱"))
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.55))
                        Text("feedback@suoxia.app")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Spacer()
                    Button(t("复制")) {
                        KeychainAndBiometrics.copySensitive("feedback@suoxia.app")
                        store.showToast(t("已复制"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.subtleBackground(store.isDark))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }
                .padding(16)

                InsetDivider(isDark: store.isDark)

                Button {
                    externalLinkTarget = (t("在线问题反馈"), issuesUrl)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("在线问题反馈"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            Text(t("提交使用问题、改进建议或隐私安全咨询"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.35))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

            readingCard(
                t("反馈安全提醒"),
                body: t("为保护你的数据安全，在发送邮件或提交反馈时，请勿附带你的主密码、账号密码、银行卡号或包含敏感信息的截图。")
            )
        }
        .padding(16)
    }
}

private struct KdbxExportPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isDark: Bool
    @Binding var password: String
    let onConfirm: (String) -> Bool

    @State private var showPwd = false

    var body: some View {
        VStack(spacing: 14) {
            Text(t("设置 KeePass 导出密码"))
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 18)

            Text(t("输入用于保护 .kdbx 文件的密码"))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            RoundedFormField(
                label: t("导出密码"),
                placeholder: t("输入用于保护 .kdbx 文件的密码"),
                text: $password,
                isDark: isDark,
                isSecure: true,
                showSecureText: $showPwd
            )
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text(t("取消"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.subBackground(isDark))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    if onConfirm(password) {
                        dismiss()
                    }
                } label: {
                    Text(t("确认导出"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.brand)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 8)
        }
        .background(AppTheme.pageBackground(isDark).ignoresSafeArea())
    }
}
