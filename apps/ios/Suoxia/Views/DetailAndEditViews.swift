import SwiftUI

struct CredentialDetailView: View {
    @ObservedObject var store: VaultStore
    let itemId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showSecret = false
    @State private var showEditSheet = false
    @State private var showMoreSheet = false
    @State private var showTrashConfirm = false
    @State private var largeTypePassword: String? = nil

    private var item: VaultItem? {
        store.items.first { $0.id == itemId }
    }

    var body: some View {
        Group {
            if let it = item {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Header Card
                        HStack(spacing: 12) {
                            ItemAvatarView(item: it)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(it.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .lineLimit(1)
                                Text("\(VaultHelpers.displayFolderName(it.folder)) · \(AppI18n.isChinese ? "更新于 " : "Updated ")\(it.updatedAt)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.55))
                            }
                            Spacer()
                            Button {
                                store.toggleFavorite(id: it.id)
                            } label: {
                                Image(systemName: it.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 18))
                                    .foregroundColor(it.isFavorite ? Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255) : .primary.opacity(0.35))
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.cardBackground(store.isDark))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                        // Type-Specific Content
                        switch it.type {
                        case .login:
                            loginCard(it)
                        case .card:
                            cardDetails(it)
                        case .note:
                            noteCard(it)
                        case .identity:
                            identityCard(it)
                        }

                        // Live 2FA
                        if !it.otpSecret.isEmpty {
                            liveTotpCard(secret: it.otpSecret)
                        }

                        // Notes (for non-note types)
                        if it.type != .note && !it.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(t("备注"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.55))
                                Text(it.notes)
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(AppTheme.cardBackground(store.isDark))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }

                        // Password History
                        if !it.passwordHistory.isEmpty {
                            VStack(spacing: 0) {
                                HStack {
                                    Text(t("历史密码（已隐藏）"))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary.opacity(0.6))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                ForEach(Array(it.passwordHistory.enumerated()), id: \.offset) { _, hist in
                                    InsetDivider(isDark: store.isDark)
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("••••••••••••")
                                                .font(.system(size: 14, design: .monospaced))
                                            Text("\(hist.changedAt) \(AppI18n.isChinese ? "修改" : "changed")")
                                                .font(.system(size: 11))
                                                .foregroundColor(.primary.opacity(0.5))
                                        }
                                        Spacer()
                                        HStack(spacing: 14) {
                                            Button(t("复制")) {
                                                KeychainAndBiometrics.copySensitive(hist.password)
                                                store.showToast(t("已复制"))
                                            }
                                            Button(t("恢复")) {
                                                store.restorePasswordHistory(itemId: it.id, oldPassword: hist.password)
                                            }
                                        }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.brand)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(AppTheme.cardBackground(store.isDark))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }
                    }
                    .padding(16)
                }
                .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
                .navigationBarHidden(false)
                .navigationTitle(it.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(t("编辑")) {
                            showEditSheet = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.brand)

                        Button {
                            showMoreSheet = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.brand)
                        }
                    }
                }
                .confirmationDialog(it.title, isPresented: $showMoreSheet, titleVisibility: .visible) {
                    Button(it.isFavorite ? t("取消星标") : t("设为星标")) {
                        store.toggleFavorite(id: it.id)
                    }
                    Button(t("移入回收站"), role: .destructive) {
                        showTrashConfirm = true
                    }
                    Button(t("取消"), role: .cancel) {}
                }
                .alert(
                    AppI18n.isChinese ? "将「\(it.title)」移入回收站？" : "Move \"\(it.title)\" to Trash?",
                    isPresented: $showTrashConfirm
                ) {
                    Button(t("取消"), role: .cancel) {}
                    Button(t("确认移入"), role: .destructive) {
                        store.moveToTrash(id: it.id)
                        dismiss()
                    }
                } message: {
                    Text(t("移入后该凭证将从列表隐藏，30 天内可在回收站随时恢复。"))
                }
                .sheet(isPresented: $showEditSheet) {
                    CredentialEditSheet(store: store, editItem: it)
                        .svSheetPresentation(.large)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { largeTypePassword != nil },
                    set: { if !$0 { largeTypePassword = nil } }
                )) {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 28) {
                            Spacer()
                            if let p = largeTypePassword {
                                ColorizedPasswordText(password: p, fontSize: 28)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            Spacer()
                            Button {
                                largeTypePassword = nil
                            } label: {
                                Text(t("关闭"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                            }
                            .padding(.bottom, 32)
                        }
                    }
                }
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func loginCard(_ it: VaultItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("账号")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                    Text(it.username.isEmpty ? "-" : it.username)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                Spacer()
                Button(t("复制")) {
                    KeychainAndBiometrics.copySensitive(it.username)
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

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("密码")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                    Spacer()
                    HStack(spacing: 14) {
                        Button(t("大字查看")) {
                            largeTypePassword = it.password
                        }
                        Button(showSecret ? t("隐藏") : t("显示")) {
                            showSecret.toggle()
                        }
                        Button(t("复制")) {
                            KeychainAndBiometrics.copySensitive(it.password)
                            store.showToast(t("已复制"))
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.brand)
                }

                Group {
                    if showSecret {
                        ColorizedPasswordText(password: it.password, fontSize: 14)
                    } else {
                        Text("••••••••••••")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255))
                .cornerRadius(12)
            }
            .padding(16)

            if !it.url.isEmpty {
                InsetDivider(isDark: store.isDark)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("网址")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                        Text(it.url)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.brand)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(t("打开")) {
                        let raw = it.url.contains("://") ? it.url : "https://\(it.url)"
                        if let url = URL(string: raw) {
                            openURL(url)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.subtleBackground(store.isDark))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                }
                .padding(16)
            }
        }
        .background(AppTheme.cardBackground(store.isDark))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    @ViewBuilder
    private func cardDetails(_ it: VaultItem) -> some View {
        VStack(spacing: 0) {
            if !it.cardName.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("持卡人")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                        Text(it.cardName).font(.system(size: 14, weight: .medium))
                    }
                    Spacer()
                    Button(t("复制")) {
                        KeychainAndBiometrics.copySensitive(it.cardName)
                        store.showToast(t("已复制"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.brand)
                }
                .padding(16)
                InsetDivider(isDark: store.isDark)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("卡号")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                    Text(it.cardNumber.isEmpty ? "-" : it.cardNumber)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                Spacer()
                Button(t("复制")) {
                    KeychainAndBiometrics.copySensitive(it.cardNumber)
                    store.showToast(t("已复制"))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.brand)
            }
            .padding(16)

            InsetDivider(isDark: store.isDark)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("有效期")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                    Text(it.cardExpiry.isEmpty ? "-" : it.cardExpiry)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("安全码 CVV")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                        Text(showSecret ? (it.cardCvv.isEmpty ? "-" : it.cardCvv) : "•••")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
                    Spacer()
                    Button(showSecret ? t("隐藏") : t("显示")) {
                        showSecret.toggle()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(AppTheme.cardBackground(store.isDark))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    @ViewBuilder
    private func noteCard(_ it: VaultItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("加密备忘正文")).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                Spacer()
                HStack(spacing: 14) {
                    Button(showSecret ? t("隐藏") : t("查看")) {
                        showSecret.toggle()
                    }
                    Button(t("复制")) {
                        KeychainAndBiometrics.copySensitive(it.notes)
                        store.showToast(t("已复制"))
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.brand)
            }
            Text(showSecret ? (it.notes.isEmpty ? t("无内容") : it.notes) : "••••••••••••••••••••")
                .font(.system(size: 14))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppTheme.cardBackground(store.isDark))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    @ViewBuilder
    private func identityCard(_ it: VaultItem) -> some View {
        let rows: [(String, String)] = [
            (t("姓名"), it.identityName),
            (t("邮箱"), it.identityEmail),
            (t("手机号"), it.identityPhone),
            (t("地址 / 证件信息"), it.identityAddress)
        ].filter { !$0.1.isEmpty }

        VStack(spacing: 0) {
            if rows.isEmpty {
                Text(t("暂无身份详情"))
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.55))
                    .padding(18)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, pair in
                    if idx > 0 { InsetDivider(isDark: store.isDark) }
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.0).font(.system(size: 12)).foregroundColor(.primary.opacity(0.55))
                            Text(pair.1).font(.system(size: 14, weight: .medium))
                        }
                        Spacer()
                        Button(t("复制")) {
                            KeychainAndBiometrics.copySensitive(pair.1)
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
                }
            }
        }
        .background(AppTheme.cardBackground(store.isDark))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
    }

    private func liveTotpCard(secret: String) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let res = (try? SecureVaultCore.generateTotp(secret: secret)) ?? (code: "------", remaining: 30)
            let urgent = res.remaining <= 5
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("两步动态验证码"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                    Text(VaultHelpers.formatTotpCode(res.code))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }
                Spacer()
                HStack(spacing: 12) {
                    Circle()
                        .stroke(urgent ? AppTheme.danger : AppTheme.brand, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("\(res.remaining)s")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(urgent ? AppTheme.danger : AppTheme.brand)
                        )
                    Button(t("复制")) {
                        KeychainAndBiometrics.copySensitive(res.code)
                        store.showToast(t("已复制验证码"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.brand)
                    .cornerRadius(12)
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground(store.isDark))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
        }
    }
}

// MARK: - New / Edit Credential Sheet

private enum ActiveEditSubSheet: Identifiable {
    case quickGen, qrScanner

    var id: Int {
        switch self {
        case .quickGen: return 0
        case .qrScanner: return 1
        }
    }
}

struct CredentialEditSheet: View {
    @ObservedObject var store: VaultStore
    let editItem: VaultItem?
    @Environment(\.dismiss) private var dismiss

    @Namespace private var typeSegmentNS

    @State private var itemType: ItemType = .login
    @State private var title = ""
    @State private var folder = VaultHelpers.defaultFolderKey
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var otpSecret = ""
    @State private var cardName = ""
    @State private var cardNumber = ""
    @State private var cardExpiry = ""
    @State private var cardCvv = ""
    @State private var identityName = ""
    @State private var identityEmail = ""
    @State private var identityPhone = ""
    @State private var identityAddress = ""
    @State private var notes = ""

    @State private var activeSubSheet: ActiveEditSubSheet? = nil

    private var allFolderChoices: [String] {
        [VaultHelpers.defaultFolderKey] + store.folders.map { $0.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("取消"),
                onLeft: { dismiss() },
                title: editItem != nil ? t("编辑凭证") : t("新建凭证"),
                isDark: store.isDark
            ) {
                Button {
                    save()
                } label: {
                    Text(t("保存"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Segmented Control with sliding thumb (~180ms)
                    HStack(spacing: 0) {
                        ForEach(ItemType.allCases, id: \.self) { type in
                            let selected = itemType == type
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    itemType = type
                                }
                            } label: {
                                Text(type.label)
                                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                                    .foregroundColor(
                                        selected
                                            ? (store.isDark ? .white : AppTheme.brand)
                                            : .primary.opacity(0.6)
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 30)
                                    .background {
                                        if selected {
                                            RoundedRectangle(cornerRadius: 9)
                                                .fill(store.isDark ? Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255) : Color.white)
                                                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                                                .matchedGeometryEffect(id: "editTypeThumb", in: typeSegmentNS)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(store.isDark ? Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255).opacity(0.9) : Color.black.opacity(0.06))
                    .cornerRadius(12)

                    // Title
                    FormTextFieldBox(
                        label: t("标题 *"),
                        placeholder: itemType.titlePlaceholder,
                        text: $title,
                        isDark: store.isDark
                    )

                    // Folder Chips
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text(t("存放文件夹"))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.primary.opacity(0.6))
                        .padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(allFolderChoices, id: \.self) { f in
                                    let on = folder == f
                                    Button {
                                        folder = f
                                    } label: {
                                        Text(VaultHelpers.displayFolderName(f))
                                            .font(.system(size: 12, weight: on ? .semibold : .medium))
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
                    }

                    // Dynamic Type Fields (in-place switch, no divider lines)
                    VStack(spacing: 12) {
                        switch itemType {
                        case .login:
                            FormTextFieldBox(
                                label: t("账号 / 邮箱"),
                                placeholder: t("输入登录账号或邮箱"),
                                text: $username,
                                isDark: store.isDark,
                                keyboardType: .emailAddress
                            )
                            FormTextFieldBox(
                                label: t("密码"),
                                placeholder: t("输入登录密码"),
                                text: $password,
                                isDark: store.isDark,
                                isSecure: editItem != nil,
                                isMonospace: true,
                                showEyeToggle: true,
                                trailingLabelText: t("生成强密码"),
                                trailingAction: { activeSubSheet = .quickGen }
                            )
                            FormTextFieldBox(
                                label: t("网址 / 域名（可选）"),
                                placeholder: "https://...",
                                text: $url,
                                isDark: store.isDark,
                                keyboardType: .URL
                            )
                            FormTextFieldBox(
                                label: t("两步验证密钥（可选）"),
                                placeholder: t("输入或扫码填入动态密钥"),
                                text: $otpSecret,
                                isDark: store.isDark,
                                isMonospace: true,
                                trailingLabelText: t("相机扫码"),
                                trailingAction: { activeSubSheet = .qrScanner }
                            )
                            FormTextAreaBox(
                                label: t("备注（可选）"),
                                placeholder: t("补充安全提示或恢复说明..."),
                                text: $notes,
                                isDark: store.isDark,
                                minHeight: 68
                            )

                        case .card:
                            FormTextFieldBox(
                                label: t("持卡人姓名"),
                                placeholder: t("卡片上的姓名拼音或中文"),
                                text: $cardName,
                                isDark: store.isDark
                            )
                            FormTextFieldBox(
                                label: t("卡号 *"),
                                placeholder: t("输入银行卡号"),
                                text: $cardNumber,
                                isDark: store.isDark,
                                isMonospace: true,
                                keyboardType: .numbersAndPunctuation
                            )
                            HStack(spacing: 10) {
                                FormTextFieldBox(
                                    label: t("有效期"),
                                    placeholder: "MM/YY",
                                    text: $cardExpiry,
                                    isDark: store.isDark,
                                    isMonospace: true
                                )
                                FormTextFieldBox(
                                    label: t("安全码 CVV"),
                                    placeholder: t("3-4 位数字"),
                                    text: $cardCvv,
                                    isDark: store.isDark,
                                    isSecure: true,
                                    isMonospace: true,
                                    showEyeToggle: true,
                                    keyboardType: .numberPad
                                )
                            }
                            FormTextAreaBox(
                                label: t("备注（可选）"),
                                placeholder: t("补充安全提示或恢复说明..."),
                                text: $notes,
                                isDark: store.isDark,
                                minHeight: 68
                            )

                        case .note:
                            FormTextAreaBox(
                                label: t("加密备忘正文 *"),
                                placeholder: t("输入需要加密保存的文本、助记信息或密钥片段..."),
                                text: $notes,
                                isDark: store.isDark,
                                minHeight: 190
                            )

                        case .identity:
                            FormTextFieldBox(
                                label: t("姓名"),
                                placeholder: t("真实姓名或常用昵称"),
                                text: $identityName,
                                isDark: store.isDark
                            )
                            FormTextFieldBox(
                                label: t("邮箱"),
                                placeholder: "name@example.com",
                                text: $identityEmail,
                                isDark: store.isDark,
                                keyboardType: .emailAddress
                            )
                            FormTextFieldBox(
                                label: t("手机号"),
                                placeholder: t("手机号码"),
                                text: $identityPhone,
                                isDark: store.isDark,
                                isMonospace: true,
                                keyboardType: .phonePad
                            )
                            FormTextFieldBox(
                                label: t("地址 / 证件信息"),
                                placeholder: t("居住地址、身份证号或密保问题"),
                                text: $identityAddress,
                                isDark: store.isDark
                            )
                            FormTextAreaBox(
                                label: t("备注（可选）"),
                                placeholder: t("补充安全提示或恢复说明..."),
                                text: $notes,
                                isDark: store.isDark,
                                minHeight: 68
                            )
                        }
                    }
                    .frame(minHeight: 320, alignment: .top)
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .svToastOverlay(store: store)
        .onAppear {
            if let it = editItem {
                itemType = it.type
                title = it.title
                folder = VaultHelpers.normalizeFolderName(it.folder)
                username = it.username
                password = it.password
                url = it.url
                otpSecret = it.otpSecret
                cardName = it.cardName
                cardNumber = it.cardNumber
                cardExpiry = it.cardExpiry
                cardCvv = it.cardCvv
                identityName = it.identityName
                identityEmail = it.identityEmail
                identityPhone = it.identityPhone
                identityAddress = it.identityAddress
                notes = it.notes
            } else {
                folder = store.activeFolder != VaultHelpers.allFoldersKey
                    ? VaultHelpers.normalizeFolderName(store.activeFolder)
                    : VaultHelpers.defaultFolderKey
            }
        }
        .sheet(item: $activeSubSheet) { sub in
            switch sub {
            case .quickGen:
                QuickGenSheet(isDark: store.isDark) { generated in
                    password = generated
                    store.showToast(t("已填入生成的随机密码"))
                }
                .svSheetPresentation(.compact(250))
            case .qrScanner:
                QrScannerModal(isDark: store.isDark) { scanned in
                    if let parsed = try? SecureVaultCore.parseOtpauthUri(scanned) {
                        otpSecret = parsed.secret
                        store.showToast(t("已识别并填入验证密钥"))
                    } else {
                        store.showToast(t("二维码格式不支持"), warn: true)
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            store.showToast(t("请填写标题"), warn: true)
            return
        }
        let item = VaultItem(
            id: editItem?.id ?? UUID().uuidString,
            type: itemType,
            title: trimmedTitle,
            folder: folder,
            username: username,
            password: password,
            url: url,
            cardName: cardName,
            cardNumber: cardNumber,
            cardExpiry: cardExpiry,
            cardCvv: cardCvv,
            identityName: identityName,
            identityEmail: identityEmail,
            identityPhone: identityPhone,
            identityAddress: identityAddress,
            notes: notes,
            otpSecret: otpSecret,
            passwordHistory: editItem?.passwordHistory ?? [],
            deletedAt: editItem?.deletedAt,
            updatedAt: VaultHelpers.currentUpdatedAtString(),
            strength: VaultHelpers.computePasswordStrength(password),
            isFavorite: editItem?.isFavorite ?? false,
            rawJSON: editItem?.rawJSON ?? [:]
        )
        store.saveItem(item)
        dismiss()
    }
}

// MARK: - Quick Password Generator Sheet

struct QuickGenSheet: View {
    let isDark: Bool
    let onUse: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pwd = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(t("快速生成密码"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(t("换一个")) {
                    regenerate()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.brand)
            }
            .padding(.top, 16)

            ColorizedPasswordText(password: pwd, fontSize: 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255))
                .cornerRadius(16)

            Button {
                onUse(pwd)
                dismiss()
            } label: {
                Text(t("使用此密码"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppTheme.brand)
                    .cornerRadius(14)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(AppTheme.pageBackground(isDark).ignoresSafeArea())
        .onAppear {
            if pwd.isEmpty { regenerate() }
        }
    }

    private func regenerate() {
        pwd = (try? SecureVaultCore.generatePassword(
            length: 18, upper: true, lower: true, numbers: true, symbols: true, excludeAmbiguous: true
        )) ?? ""
    }
}

// MARK: - QR Scanner Wrapper

struct QrScannerModal: View {
    let isDark: Bool
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QrScannerView(
                onScanned: { code in
                    onResult(code)
                    dismiss()
                },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Text(t("取消"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}
