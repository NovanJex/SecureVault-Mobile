import SwiftUI

struct TotpListView: View {
    @ObservedObject var store: VaultStore
    @State private var showAddSheet = false
    @State private var deleteTarget: StandaloneTotp? = nil

    private var filteredTokens: [StandaloneTotp] {
        let q = store.totpSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.standaloneTotps }
        return store.standaloneTotps.filter {
            $0.issuer.lowercased().contains(q) || $0.account.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("验证器"))
                            .font(.system(size: 22, weight: .bold))
                        Text(AppI18n.isChinese
                             ? "共 \(store.standaloneTotps.count) 个动态令牌"
                             : "\(store.standaloneTotps.count) tokens")
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.55))
                    }

                    SearchBarField(
                        placeholder: t("搜索令牌名称或备注账号"),
                        text: $store.totpSearch,
                        isDark: store.isDark
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    ScrollView(showsIndicators: false) {
                        if store.standaloneTotps.isEmpty {
                            VStack(spacing: 8) {
                                Text(t("暂无动态令牌"))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(t("点击右下角 + 扫描二维码或输入密钥，添加两步验证码。"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.55))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 64)
                            .padding(.horizontal, 28)
                        } else if filteredTokens.isEmpty {
                            Text(t("未找到匹配的令牌"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.5))
                                .padding(.top, 56)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredTokens) { token in
                                    let res = (try? SecureVaultCore.generateTotp(secret: token.secret)) ?? ("------", 30)
                                    let urgent = res.remaining <= 5
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(token.issuer)
                                                .font(.system(size: 14, weight: .semibold))
                                                .lineLimit(1)
                                            Text(token.account.isEmpty ? t("动态令牌") : token.account)
                                                .font(.system(size: 12))
                                                .foregroundColor(.primary.opacity(0.55))
                                                .lineLimit(1)
                                            Text(VaultHelpers.formatTotpCode(res.code))
                                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                                .foregroundColor(AppTheme.brand)
                                                .padding(.top, 2)
                                        }
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Circle()
                                                .stroke(urgent ? AppTheme.danger : AppTheme.brand, lineWidth: 2)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text("\(res.remaining)s")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(urgent ? AppTheme.danger : AppTheme.brand)
                                                )
                                            Button {
                                                deleteTarget = token
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(AppTheme.danger.opacity(0.75))
                                                    .frame(width: 32, height: 32)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(16)
                                    .background(AppTheme.cardBackground(store.isDark))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        KeychainAndBiometrics.copySensitive(res.code)
                                        store.showToast(t("已复制验证码"))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 84)
                        }
                    }
                }
            }
            .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())

            // Floating Action Button (+)
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.brand)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.brand.opacity(0.32), radius: 10, y: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            .accessibilityLabel(t("添加动态令牌"))
        }
        .sheet(isPresented: $showAddSheet) {
            AddTotpSheet(store: store)
                .svSheetPresentation(.large)
        }
        .alert(
            deleteTarget.map { AppI18n.isChinese ? "移除「\($0.issuer)」？" : "Remove \"\($0.issuer)\"?" } ?? "",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )
        ) {
            Button(t("取消"), role: .cancel) { deleteTarget = nil }
            Button(t("确认移除"), role: .destructive) {
                if let tk = deleteTarget {
                    store.deleteStandaloneTotp(id: tk.id)
                }
                deleteTarget = nil
            }
        } message: {
            Text(t("移除后将无法再通过此令牌生成两步验证码，请确认对应平台已解绑。"))
        }
    }
}

// MARK: - Add Standalone 2FA Sheet

struct AddTotpSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var issuer = ""
    @State private var account = ""
    @State private var secret = ""
    @State private var showScanner = false

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("取消"),
                onLeft: { dismiss() },
                title: t("添加动态令牌"),
                isDark: store.isDark
            ) {
                Button {
                    let iss = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sec = secret.trimmingCharacters(in: .whitespacesAndNewlines)
                    if iss.isEmpty || sec.isEmpty {
                        store.showToast(t("请填写服务名称和密钥"), warn: true)
                        return
                    }
                    store.addStandaloneTotp(issuer: iss, account: account, secret: sec)
                    dismiss()
                } label: {
                    Text(t("保存"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Gradient QR Scan Button
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("扫描二维码快速添加"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(t("对准服务商二维码自动识别"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(16)
                        .background(AppTheme.brandGradient)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.brand.opacity(0.22), radius: 8, y: 4)
                    }

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.primary.opacity(0.15)).frame(height: 0.5)
                        Text(t("手动输入密钥"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary.opacity(0.5))
                        Rectangle().fill(Color.primary.opacity(0.15)).frame(height: 0.5)
                    }
                    .padding(.horizontal, 8)

                    VStack(spacing: 12) {
                        FormTextFieldBox(
                            label: t("服务 / 令牌名称 *"),
                            placeholder: t("例如：GitHub、Steam、Apple"),
                            text: $issuer,
                            isDark: store.isDark
                        )
                        FormTextFieldBox(
                            label: t("备注账号或说明（可选）"),
                            placeholder: t("例如：name@example.com"),
                            text: $account,
                            isDark: store.isDark,
                            keyboardType: .emailAddress
                        )
                        FormTextFieldBox(
                            label: t("动态密钥 *"),
                            placeholder: t("输入服务商提供的两步验证密钥"),
                            text: $secret,
                            isDark: store.isDark,
                            isMonospace: true
                        )
                    }

                    Text(t("适用于仅需动态验证码的场景；若需与账号密码绑定，可在「保险箱」内编辑配置。"))
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.5))
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .sheet(isPresented: $showScanner) {
            QrScannerModal(isDark: store.isDark) { uri in
                if let parsed = try? SecureVaultCore.parseOtpauthUri(uri) {
                    store.addStandaloneTotp(issuer: parsed.issuer, account: parsed.account, secret: parsed.secret, fromScan: true)
                    dismiss()
                } else {
                    store.showToast(t("二维码格式不支持"), warn: true)
                }
            }
        }
    }
}

// MARK: - Password Generator View

struct GeneratorView: View {
    @ObservedObject var store: VaultStore

    @State private var mode: String = "random" // "random" | "bip39"
    @State private var length: Double = 18
    @State private var optUpper = true
    @State private var optLower = true
    @State private var optNum = true
    @State private var optSym = true
    @State private var optNoAmbiguous = true

    @State private var bipWords: Double = 5
    @State private var bipSep: String = "-"
    @State private var bipCap: Bool = true

    @State private var currentPwd: String = ""
    @State private var confirmClearHistory = false

    private var strengthBadgeText: String {
        if mode == "random" {
            let score = Int(length * 5.9)
            if score >= 90 { return t("密码强度：极强") }
            if score >= 65 { return t("密码强度：高") }
            return t("密码强度：中等")
        } else {
            return Int(bipWords) >= 6 ? t("密码强度：极强") : t("密码强度：高")
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header + Mode Segmented Switcher
                HStack {
                    Text(t("生成器"))
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    HStack(spacing: 2) {
                        modeButton(key: "random", label: t("随机密码"))
                        modeButton(key: "bip39", label: t("助记词"))
                    }
                    .padding(3)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(12)
                }

                // Output Card
                VStack(alignment: .leading, spacing: 14) {
                    ColorizedPasswordText(password: currentPwd, fontSize: 16)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)

                    HStack {
                        Text(strengthBadgeText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.emerald.opacity(0.22))
                            .clipShape(Capsule())

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                regenerate()
                            } label: {
                                Text(t("换一个"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255))
                                    .cornerRadius(8)
                            }
                            Button {
                                KeychainAndBiometrics.copySensitive(currentPwd)
                                store.showToast(t("已复制"))
                            } label: {
                                Text(t("复制"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(AppTheme.brand)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )

                // Controls Card
                VStack(spacing: 0) {
                    if mode == "random" {
                        VStack(spacing: 8) {
                            HStack {
                                Text(t("密码长度"))
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("\(Int(length))")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.brand)
                            }
                            Slider(value: $length, in: 8...48, step: 1)
                                .tint(AppTheme.brand)
                                .onChange(of: length) { _ in regenerate() }
                        }
                        .padding(16)

                        optionToggleRow(t("大写字母 (A-Z)"), isOn: $optUpper)
                        optionToggleRow(t("小写字母 (a-z)"), isOn: $optLower)
                        optionToggleRow(t("数字 (0-9)"), isOn: $optNum)
                        optionToggleRow(t("特殊符号 (!@#$%)"), isOn: $optSym)
                        optionToggleRow(t("排除易混淆字符 (0/O, 1/l/I)"), isOn: $optNoAmbiguous)
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Text(t("助记词数量"))
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(AppI18n.isChinese ? "\(Int(bipWords)) 词" : "\(Int(bipWords)) words")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.brand)
                            }
                            Slider(value: $bipWords, in: 3...10, step: 1)
                                .tint(AppTheme.brand)
                                .onChange(of: bipWords) { _ in regenerate() }
                        }
                        .padding(16)

                        InsetDivider(isDark: store.isDark)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("分隔符"))
                                .font(.system(size: 14))
                            HStack(spacing: 4) {
                                sepChip("-", t("连字符 -"))
                                sepChip("_", t("下划线 _"))
                                sepChip(".", t("点号 ."))
                                sepChip(" ", t("空格"))
                            }
                            .padding(4)
                            .background(AppTheme.subtleBackground(store.isDark))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))
                        }
                        .padding(16)

                        optionToggleRow(t("单词首字母大写"), isOn: $bipCap)
                    }
                }
                .background(AppTheme.cardBackground(store.isDark))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8))

                // Recent History (max 6)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(t("最近生成"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.6))
                        Spacer()
                        if !store.genHistory.isEmpty {
                            Button {
                                confirmClearHistory = true
                            } label: {
                                Text(t("清空"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.danger)
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        if store.genHistory.isEmpty {
                            Text(t("暂无记录"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .padding(16)
                        } else {
                            ForEach(Array(store.genHistory.enumerated()), id: \.offset) { idx, p in
                                if idx > 0 { InsetDivider(isDark: store.isDark) }
                                HStack(spacing: 10) {
                                    Text(p)
                                        .font(.system(size: 12, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(t("复制")) {
                                        KeychainAndBiometrics.copySensitive(p)
                                        store.showToast(t("已复制"))
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.brand)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
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
        .onAppear {
            if currentPwd.isEmpty { regenerate() }
        }
        .alert(t("清空最近生成记录？"), isPresented: $confirmClearHistory) {
            Button(t("取消"), role: .cancel) {}
            Button(t("确认清空"), role: .destructive) {
                store.clearGenHistory()
            }
        } message: {
            Text(t("清空后将无法找回此前生成的临时密码，请确认重要密码已保存至保险箱。"))
        }
    }

    private func modeButton(key: String, label: String) -> some View {
        let on = mode == key
        return Button {
            mode = key
            regenerate()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(on ? (store.isDark ? .white : .primary) : .primary.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? AppTheme.cardBackground(store.isDark) : Color.clear)
                .cornerRadius(9)
        }
        .buttonStyle(.plain)
    }

    private func optionToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            InsetDivider(isDark: store.isDark)
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.system(size: 14))
            }
            .tint(AppTheme.brand)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .onChange(of: isOn.wrappedValue) { _ in regenerate() }
        }
    }

    private func sepChip(_ value: String, _ label: String) -> some View {
        let on = bipSep == value
        return Button {
            bipSep = value
            regenerate()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(on ? .white : .primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(on ? AppTheme.brand : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func regenerate() {
        if mode == "random" {
            currentPwd = (try? SecureVaultCore.generatePassword(
                length: Int(length),
                upper: optUpper,
                lower: optLower,
                numbers: optNum,
                symbols: optSym,
                excludeAmbiguous: optNoAmbiguous
            )) ?? ""
        } else {
            currentPwd = (try? SecureVaultCore.generateBip39(
                words: Int(bipWords),
                sep: bipSep,
                capitalize: bipCap
            )) ?? ""
        }
        store.recordGeneratedPassword(currentPwd)
    }
}
