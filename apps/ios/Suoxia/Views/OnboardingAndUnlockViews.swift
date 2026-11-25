import LocalAuthentication
import SwiftUI

private enum ActiveOnboardingSheet: Identifiable {
    case createVault, webdavRestore, importFlow

    var id: Int {
        switch self {
        case .createVault: return 0
        case .webdavRestore: return 1
        case .importFlow: return 2
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var store: VaultStore
    @State private var activeSheet: ActiveOnboardingSheet? = nil
    @State private var showRestoreChoices = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Brand Hero
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brand.opacity(0.12))
                            .frame(width: 92, height: 92)
                        Circle()
                            .fill(AppTheme.brand.opacity(0.18))
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(AppTheme.brandGradient)
                            .frame(width: 56, height: 56)
                            .shadow(color: AppTheme.brand.opacity(0.32), radius: 12, y: 6)
                            .overlay(
                                Image(systemName: "shield")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    VStack(spacing: 6) {
                        Text(t("锁匣 · SecureVault"))
                            .font(.system(size: 22, weight: .bold))
                        Text(t("本地加密密码管理器 · 手机与电脑安全同步"))
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 36)

                // 3 Feature Cards
                VStack(spacing: 12) {
                    OnboardingFeatureCard(
                        icon: "lock",
                        tint: AppTheme.brand,
                        title: t("本地离线加密"),
                        desc: t("不设官方服务器，主密码仅由你本人掌握"),
                        isDark: store.isDark
                    )
                    OnboardingFeatureCard(
                        icon: "icloud",
                        tint: Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255),
                        title: t("自主多端同步"),
                        desc: t("连接个人网盘或 NAS，手机与电脑加密互通"),
                        isDark: store.isDark
                    )
                    OnboardingFeatureCard(
                        icon: "faceid",
                        tint: AppTheme.emerald,
                        title: t("灵活应用锁"),
                        desc: t("支持面容、指纹与手势密码，按需自由开启"),
                        isDark: store.isDark
                    )
                }
                .padding(.vertical, 8)

                // Bottom CTAs
                VStack(spacing: 10) {
                    Button {
                        activeSheet = .createVault
                    } label: {
                        Text(t("创建新保险箱"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppTheme.brandGradient)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.brand.opacity(0.25), radius: 10, y: 4)
                    }

                    Button {
                        showRestoreChoices = true
                    } label: {
                        Text(t("从备份恢复或导入"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppTheme.cardBackground(store.isDark))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .confirmationDialog(t("选择恢复方式"), isPresented: $showRestoreChoices, titleVisibility: .visible) {
            Button(t("从 WebDAV 云端恢复")) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    activeSheet = .webdavRestore
                }
            }
            Button(t("导入本地备份文件")) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    activeSheet = .importFlow
                }
            }
            Button(t("取消"), role: .cancel) {}
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createVault:
                CreateVaultSheet(store: store)
                    .svSheetPresentation(.large)
            case .webdavRestore:
                WebDavSheet(store: store, isOnboardingRestore: true)
                    .svSheetPresentation(.large)
            case .importFlow:
                ImportFlowSheet(store: store)
                    .svSheetPresentation(.large)
            }
        }
    }
}

private struct OnboardingFeatureCard: View {
    let icon: String
    let tint: Color
    let title: String
    let desc: String
    let isDark: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tint)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground(isDark))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.borderColor(isDark), lineWidth: 0.8)
        )
    }
}

// MARK: - Create Vault Sheet (Direction A)

struct CreateVaultSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var pwd1 = ""
    @State private var pwd2 = ""

    private var strengthLabel: (text: String, color: Color) {
        guard !pwd1.isEmpty else { return ("", .clear) }
        var score = 0
        if pwd1.count >= 8 { score += 1 }
        if pwd1.count >= 12 { score += 1 }
        var kinds = 0
        if pwd1.rangeOfCharacter(from: .lowercaseLetters) != nil { kinds += 1 }
        if pwd1.rangeOfCharacter(from: .uppercaseLetters) != nil { kinds += 1 }
        if pwd1.rangeOfCharacter(from: .decimalDigits) != nil { kinds += 1 }
        if pwd1.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { kinds += 1 }
        if kinds >= 2 { score += 1 }
        if kinds >= 3 { score += 1 }

        if pwd1.count < 8 || score <= 1 {
            return (t("强度：偏弱"), AppTheme.danger)
        } else if score <= 2 {
            return (t("强度：中等"), AppTheme.amber)
        } else {
            return (t("强度：高"), AppTheme.emerald)
        }
    }

    private var matchStatus: (text: String, color: Color, mismatch: Bool) {
        guard !pwd2.isEmpty else { return ("", .clear, false) }
        if pwd1 != pwd2 {
            return (t("两次输入不一致"), AppTheme.danger, true)
        } else {
            return (t("✓ 一致"), AppTheme.emerald, false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("取消"),
                onLeft: { dismiss() },
                title: t("创建新保险箱"),
                isDark: store.isDark
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("设置主密码"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(t("用于本地加密你的全部凭证，建议包含字母、数字与符号。"))
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    .padding(.horizontal, 4)

                    FormTextFieldBox(
                        label: t("主密码（至少 8 位）"),
                        placeholder: t("输入高强度主密码"),
                        text: $pwd1,
                        isDark: store.isDark,
                        isSecure: true,
                        showEyeToggle: true,
                        trailingLabelText: strengthLabel.text,
                        trailingLabelColor: strengthLabel.color
                    )

                    FormTextFieldBox(
                        label: t("确认主密码"),
                        placeholder: t("再次输入以确认"),
                        text: $pwd2,
                        isDark: store.isDark,
                        isSecure: true,
                        showEyeToggle: true,
                        borderHighlight: matchStatus.mismatch ? AppTheme.danger.opacity(0.75) : nil,
                        trailingLabelText: matchStatus.text,
                        trailingLabelColor: matchStatus.color
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• " + t("主密码仅由你本人掌握，无法找回或重置，请妥善牢记或手写备份。"))
                        Text("• " + t("日常打开默认直接进入，如需每次验证身份，可在「首选项」中开启应用锁。"))
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.72))
                    .lineSpacing(3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.subtleBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                    )

                    Button {
                        if pwd1.count < 8 {
                            store.showToast(t("主密码至少 8 位"), warn: true)
                            return
                        }
                        if pwd1 != pwd2 {
                            store.showToast(t("两次密码输入不一致"), warn: true)
                            return
                        }
                        Task {
                            if await store.createFreshVault(password: pwd1) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isBusy {
                                ProgressView().tint(.white)
                            }
                            Text(t("创建并进入"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.brand)
                        .cornerRadius(16)
                    }
                    .disabled(store.isBusy)
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .svToastOverlay(store: store)
    }
}

// MARK: - Unlock View

struct UnlockView: View {
    @ObservedObject var store: VaultStore
    @State private var pwd = ""
    @State private var revealed = false
    @State private var forcePasswordMode = false
    @State private var gestureFails = 0

    private var deviceBiometryType: LABiometryType {
        KeychainAndBiometrics.biometryType
    }

    private var useGesture: Bool {
        !forcePasswordMode && store.gestureOn && !store.gesturePattern.isEmpty
    }

    private var bioButtonLabel: String? {
        switch deviceBiometryType {
        case .faceID:
            return store.bioFaceOn ? t("Face ID 解锁") : nil
        case .touchID:
            return store.bioFingerOn ? t("Touch ID 解锁") : nil
        default:
            return nil
        }
    }

    private var bioIconName: String {
        deviceBiometryType == .touchID ? "touchid" : "faceid"
    }

    private var subtitleText: String {
        if useGesture {
            return bioButtonLabel != nil
                ? t("可划动九宫格，或点击下方使用面容/指纹")
                : t("请绘制手势图案以解锁")
        }
        return bioButtonLabel != nil
            ? t("输入主密码或通过生物识别快速解锁")
            : t("请输入主密码以解锁")
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.brand)
                    .frame(width: 64, height: 64)
                    .shadow(color: AppTheme.brand.opacity(0.25), radius: 10, y: 4)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    )
                Text(t("锁匣已锁定"))
                    .font(.system(size: 20, weight: .bold))
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            if useGesture {
                VStack(spacing: 20) {
                    GesturePadView { pattern in
                        if store.unlockWithGesture(pattern) {
                            gestureFails = 0
                        } else {
                            gestureFails += 1
                            if gestureFails >= 5 {
                                forcePasswordMode = true
                            }
                        }
                    }

                    HStack(spacing: 20) {
                        if let bioLabel = bioButtonLabel {
                            Button(bioLabel) {
                                store.unlockWithBiometrics()
                            }
                        }
                        Button(t("改用主密码")) {
                            forcePasswordMode = true
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.brand)
                }
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            if pwd.isEmpty {
                                Text(t("输入主密码"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.4))
                                    .allowsHitTesting(false)
                            }
                            if revealed {
                                TextField("", text: $pwd)
                                    .font(.system(size: 12))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            } else {
                                SecureField("", text: $pwd)
                                    .font(.system(size: 12))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            }
                        }
                        Button {
                            revealed.toggle()
                        } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                                .font(.system(size: 15))
                                .foregroundColor(.primary.opacity(0.5))
                                .frame(width: 28, height: 28)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                    )

                    Button {
                        let input = pwd
                        Task {
                            if await store.unlockWithPassword(input) {
                                pwd = ""
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isBusy {
                                ProgressView().tint(.white)
                            }
                            Text(t("解锁"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.brand)
                        .cornerRadius(16)
                    }
                    .disabled(store.isBusy)

                    if let bioLabel = bioButtonLabel {
                        Button {
                            store.unlockWithBiometrics()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: bioIconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.brand)
                                Text(bioLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.cardBackground(store.isDark))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                            )
                        }
                    }

                    if store.gestureOn && !store.gesturePattern.isEmpty {
                        Button(t("改用手势密码解锁")) {
                            forcePasswordMode = false
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.brand)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Text(t("本地数据已加密保护"))
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.45))
                .padding(.bottom, 16)
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
    }
}

// MARK: - Gesture Setup Sheet

struct GestureSetupSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var firstPattern = ""
    @State private var tipText = t("绘制解锁图案")

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("取消"),
                onLeft: { dismiss() },
                title: store.gestureOn ? t("修改手势密码") : t("设置手势密码"),
                isDark: store.isDark
            ) {
                if store.gestureOn {
                    Button {
                        store.gestureOn = false
                        store.gesturePattern = ""
                        store.saveMeta()
                        store.showToast(t("已关闭手势密码"))
                        dismiss()
                    } label: {
                        Text(t("关闭"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.danger)
                    }
                }
            }

            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(tipText)
                        .font(.system(size: 16, weight: .bold))
                    Text(t("至少连接 4 个圆点，连续画错 5 次将切回主密码"))
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                GesturePadView { pat in
                    if pat.count < 4 {
                        store.showToast(t("至少连接 4 个点"), warn: true)
                        return
                    }
                    if firstPattern.isEmpty {
                        firstPattern = pat
                        tipText = t("请再绘制一次以确认")
                    } else if pat != firstPattern {
                        firstPattern = ""
                        tipText = t("两次图案不一致，请重新绘制")
                        store.showToast(t("两次绘制不一致"), warn: true)
                    } else {
                        store.gesturePattern = pat
                        store.gestureOn = true
                        store.saveMeta()
                        store.showToast(t("手势密码已设置"))
                        dismiss()
                    }
                }
            }
            .padding(24)

            Spacer()
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .svToastOverlay(store: store)
    }
}

// MARK: - Verify Master Password Sheet (Before Enabling Biometrics)

struct VerifyMasterPasswordSheet: View {
    @ObservedObject var store: VaultStore
    let onVerified: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pwd = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(t("验证主密码"))
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 20)

            Text(t("开启生物识别前需先验证当前主密码"))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.6))
                .multilineTextAlignment(.center)

            FormTextFieldBox(
                label: t("当前主密码"),
                placeholder: t("输入当前主密码"),
                text: $pwd,
                isDark: store.isDark,
                isSecure: true,
                showEyeToggle: true
            )

            HStack(spacing: 10) {
                Button {
                    dismiss()
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
                .disabled(store.isBusy)

                Button {
                    if pwd.isEmpty {
                        store.showToast(t("请输入当前主密码"), warn: true)
                        return
                    }
                    let input = pwd
                    Task {
                        if await store.verifyMasterPassword(input) {
                            onVerified()
                            dismiss()
                        } else {
                            store.showToast(t("当前主密码不正确"), warn: true)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if store.isBusy {
                            ProgressView().tint(.white)
                        }
                        Text(t("确认开启"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.brand)
                    .cornerRadius(12)
                }
                .disabled(store.isBusy)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .svToastOverlay(store: store)
    }
}
