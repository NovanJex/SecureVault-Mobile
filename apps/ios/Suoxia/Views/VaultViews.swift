import SwiftUI

struct VaultListView: View {
    @ObservedObject var store: VaultStore

    @State private var showFolderManager = false
    @State private var showTrash = false
    @State private var showNewSheet = false

    private var filteredItems: [VaultItem] {
        let q = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.activeItems.filter { item in
            if store.activeFolder == VaultHelpers.defaultFolderKey {
                if VaultHelpers.normalizeFolderName(item.folder) != VaultHelpers.defaultFolderKey { return false }
            } else if store.activeFolder != VaultHelpers.allFoldersKey {
                if item.folder != store.activeFolder { return false }
            }
            switch store.activeCat {
            case .all: break
            case .fav: if !item.isFavorite { return false }
            case .login: if item.type != .login { return false }
            case .card: if item.type != .card { return false }
            case .note: if item.type != .note { return false }
            case .identity: if item.type != .identity { return false }
            }
            if q.isEmpty { return true }
            return item.title.lowercased().contains(q)
                || item.username.lowercased().contains(q)
                || item.url.lowercased().contains(q)
                || item.notes.lowercased().contains(q)
        }
    }

    var body: some View {
        SvCompatNavigationContainer {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Header + Search + Category Pills
                    VStack(spacing: 10) {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(t("保险箱"))
                                    .font(.system(size: 22, weight: .bold))
                                if store.activeFolder == VaultHelpers.allFoldersKey {
                                    Text(AppI18n.isChinese
                                         ? "共 \(store.activeItems.count) 条凭证"
                                         : "\(store.activeItems.count) credentials")
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary.opacity(0.55))
                                        .frame(minHeight: 22, alignment: .leading)
                                } else {
                                    Button {
                                        store.activeFolder = VaultHelpers.allFoldersKey
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder")
                                                .font(.system(size: 11, weight: .medium))
                                            Text(VaultHelpers.displayFolderName(store.activeFolder))
                                                .font(.system(size: 12, weight: .medium))
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .opacity(0.8)
                                        }
                                        .foregroundColor(AppTheme.brand)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.brand.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                    .frame(minHeight: 22, alignment: .leading)
                                }
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button {
                                    showFolderManager = true
                                } label: {
                                    Circle()
                                        .fill(AppTheme.cardBackground(store.isDark))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle().stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                                        )
                                        .overlay(
                                            Image(systemName: "folder")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary.opacity(0.85))
                                        )
                                }
                                .accessibilityLabel(t("文件夹管理"))

                                Button {
                                    showTrash = true
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Circle()
                                            .fill(AppTheme.cardBackground(store.isDark))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle().stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                                            )
                                            .overlay(
                                                Image(systemName: "trash")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.primary.opacity(0.85))
                                            )
                                        if !store.trashedItems.isEmpty {
                                            Text("\(store.trashedItems.count)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .frame(minWidth: 16, minHeight: 16)
                                                .background(AppTheme.danger)
                                                .clipShape(Capsule())
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                                .accessibilityLabel(t("回收站"))
                            }
                        }

                        SearchBarField(
                            placeholder: t("搜索标题、账号或网址"),
                            text: $store.searchQuery,
                            isDark: store.isDark
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(VaultCategory.allCases) { cat in
                                    let selected = store.activeCat == cat
                                    Button {
                                        store.activeCat = cat
                                    } label: {
                                        Text(cat.label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(selected ? .white : .primary.opacity(0.72))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selected ? AppTheme.brand : AppTheme.cardBackground(store.isDark))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(selected ? AppTheme.brand : AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    // List
                    ScrollView(showsIndicators: false) {
                        if store.activeItems.isEmpty {
                            VStack(spacing: 8) {
                                Text(t("保险箱当前为空"))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(t("点击右下角 + 添加第一条加密凭证，或在「首选项」中导入备份。"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.55))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 64)
                            .padding(.horizontal, 28)
                        } else if filteredItems.isEmpty {
                            Text(t("当前筛选下暂无凭证"))
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.5))
                                .padding(.top, 56)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    NavigationLink(destination: CredentialDetailView(store: store, itemId: item.id)) {
                                        VaultItemRowCard(item: item, isDark: store.isDark) {
                                            let val = item.quickCopyValue
                                            if !val.isEmpty {
                                                KeychainAndBiometrics.copySensitive(val)
                                                store.showToast(t("已复制"))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 84)
                        }
                    }
                }
                .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())

                // Floating Action Button (+)
                Button {
                    showNewSheet = true
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
                .accessibilityLabel(t("新建凭证"))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFolderManager) {
                FolderManagerSheet(store: store)
                    .svSheetPresentation(.mediumAndLarge)
            }
            .sheet(isPresented: $showTrash) {
                TrashSheet(store: store)
                    .svSheetPresentation(.mediumAndLarge)
            }
            .sheet(isPresented: $showNewSheet) {
                CredentialEditSheet(store: store, editItem: nil)
                    .svSheetPresentation(.large)
            }
        }
    }
}

private struct VaultItemRowCard: View {
    let item: VaultItem
    let isDark: Bool
    let onQuickCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ItemAvatarView(item: item)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
                    }
                    if !item.otpSecret.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .bold))
                            Text("2FA")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.emerald)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.emerald.opacity(0.12))
                        .cornerRadius(5)
                    }
                }
                Text(item.subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onQuickCopy) {
                Text(t("复制"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.brand.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(AppTheme.cardBackground(isDark))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.borderColor(isDark), lineWidth: 0.8)
        )
    }
}

// MARK: - Folder Manager Sheet

struct FolderManagerSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var newFolderName = ""
    @State private var folderToDelete: String? = nil

    private var defaultCount: Int {
        store.activeItems.filter { VaultHelpers.normalizeFolderName($0.folder) == VaultHelpers.defaultFolderKey }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("关闭"),
                onLeft: { dismiss() },
                title: t("文件夹管理"),
                isDark: store.isDark
            ) {
                Button { dismiss() } label: {
                    Text(t("完成"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.brand)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Add folder input
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            if newFolderName.isEmpty {
                                Text(t("输入新文件夹名称..."))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.45))
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $newFolderName)
                                .font(.system(size: 12))
                        }
                        Button {
                            if store.addFolder(newFolderName) {
                                newFolderName = ""
                            }
                        } label: {
                            Text(t("新建"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(AppTheme.brand)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 6)
                    .frame(height: 40)
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                    )

                    // Folder list card
                    VStack(spacing: 0) {
                        folderRow(
                            label: t("全部凭证"),
                            count: store.activeItems.count,
                            selected: store.activeFolder == VaultHelpers.allFoldersKey,
                            deletable: false,
                            onSelect: {
                                store.activeFolder = VaultHelpers.allFoldersKey
                                dismiss()
                            },
                            onDelete: nil
                        )
                        InsetDivider(isDark: store.isDark)
                        folderRow(
                            label: t("默认"),
                            count: defaultCount,
                            selected: store.activeFolder == VaultHelpers.defaultFolderKey,
                            deletable: false,
                            onSelect: {
                                store.activeFolder = VaultHelpers.defaultFolderKey
                                dismiss()
                            },
                            onDelete: nil
                        )
                        ForEach(store.folders) { folder in
                            InsetDivider(isDark: store.isDark)
                            let cnt = store.activeItems.filter { $0.folder == folder.name }.count
                            folderRow(
                                label: folder.name,
                                count: cnt,
                                selected: store.activeFolder == folder.name,
                                deletable: true,
                                onSelect: {
                                    store.activeFolder = folder.name
                                    dismiss()
                                },
                                onDelete: {
                                    folderToDelete = folder.name
                                }
                            )
                        }
                    }
                    .background(AppTheme.cardBackground(store.isDark))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                    )
                }
                .padding(16)
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .alert(
            folderToDelete.map { AppI18n.isChinese ? "删除文件夹「\($0)」？" : "Delete folder \"\($0)\"?" } ?? "",
            isPresented: Binding(
                get: { folderToDelete != nil },
                set: { if !$0 { folderToDelete = nil } }
            )
        ) {
            Button(t("取消"), role: .cancel) { folderToDelete = nil }
            Button(t("确认删除"), role: .destructive) {
                if let name = folderToDelete {
                    store.deleteFolder(name)
                }
                folderToDelete = nil
            }
        } message: {
            if let name = folderToDelete {
                let cnt = store.activeItems.filter { $0.folder == name }.count
                if cnt > 0 {
                    Text(AppI18n.isChinese
                         ? "该文件夹内的 \(cnt) 条凭证将自动移入「默认」文件夹，不会丢失数据。"
                         : "\(cnt) items in this folder will move to Default without data loss.")
                } else {
                    Text(t("删除后该文件夹将被移除。"))
                }
            }
        }
    }

    private func folderRow(
        label: String,
        count: Int,
        selected: Bool,
        deletable: Bool,
        onSelect: @escaping () -> Void,
        onDelete: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack {
                    Text(label)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .foregroundColor(selected ? AppTheme.brand : .primary)
                    Spacer()
                    Text(AppI18n.isChinese ? "\(count) 条\(selected ? " ✓" : "")" : "\(count)\(selected ? " ✓" : "")")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if deletable, let onDelete {
                Button(action: onDelete) {
                    Text(t("删除"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.danger.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Trash Sheet

struct TrashSheet: View {
    @ObservedObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirmEmpty = false
    @State private var purgeTarget: VaultItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            SheetTopHeader(
                leftTitle: t("关闭"),
                onLeft: { dismiss() },
                title: "\(t("回收站")) (\(store.trashedItems.count))",
                isDark: store.isDark
            ) {
                if !store.trashedItems.isEmpty {
                    Button {
                        confirmEmpty = true
                    } label: {
                        Text(t("清空"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.danger)
                    }
                }
            }

            ScrollView(showsIndicators: false) {
                if store.trashedItems.isEmpty {
                    Text(t("回收站为空"))
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(store.trashedItems) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(t("30 天后自动彻底清理"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary.opacity(0.55))
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Button {
                                        store.restoreFromTrash(id: item.id)
                                    } label: {
                                        Text(t("恢复"))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppTheme.emerald)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.emerald.opacity(0.14))
                                            .cornerRadius(10)
                                    }

                                    Button {
                                        purgeTarget = item
                                    } label: {
                                        Text(t("删除"))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppTheme.danger)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.danger.opacity(0.14))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(14)
                            .background(AppTheme.cardBackground(store.isDark))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.borderColor(store.isDark), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.pageBackground(store.isDark).ignoresSafeArea())
        .alert(t("清空回收站？"), isPresented: $confirmEmpty) {
            Button(t("取消"), role: .cancel) {}
            Button(t("确认清空"), role: .destructive) {
                store.emptyTrash()
            }
        } message: {
            Text(t("回收站内所有凭证将被永久销毁且无法恢复。"))
        }
        .alert(
            purgeTarget.map { AppI18n.isChinese ? "彻底删除「\($0.title)」？" : "Delete \"\($0.title)\" forever?" } ?? "",
            isPresented: Binding(
                get: { purgeTarget != nil },
                set: { if !$0 { purgeTarget = nil } }
            )
        ) {
            Button(t("取消"), role: .cancel) { purgeTarget = nil }
            Button(t("彻底删除"), role: .destructive) {
                if let target = purgeTarget {
                    store.purgeItem(id: target.id)
                }
                purgeTarget = nil
            }
        } message: {
            Text(t("删除后将无法恢复，请确认不再需要此凭证。"))
        }
    }
}
