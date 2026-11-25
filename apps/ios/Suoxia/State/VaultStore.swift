import Foundation
import SwiftUI

@MainActor
final class VaultStore: ObservableObject {
    // MARK: - Navigation & Core Data
    @Published var screen: AppScreen = .onboarding
    @Published var activeTab: HomeTab = .vault
    @Published var items: [VaultItem] = []
    @Published var folders: [VaultFolderRecord] = []
    @Published var standaloneTotps: [StandaloneTotp] = []

    // MARK: - Filters & Search
    @Published var activeCat: VaultCategory = .all
    @Published var activeFolder: String = VaultHelpers.allFoldersKey
    @Published var searchQuery: String = ""
    @Published var totpSearch: String = ""

    // MARK: - Security & Preferences
    @Published var requireUnlock: Bool = false
    @Published var bioFaceOn: Bool = true
    @Published var bioFingerOn: Bool = true
    @Published var gestureOn: Bool = false
    @Published var gesturePattern: String = ""
    @Published var autoLock: AutoLockOption = .fiveMin
    @Published var privacyMask: Bool = true
    @Published var isDark: Bool = false

    // MARK: - WebDAV Sync State
    @Published var webdavConfigured: Bool = false
    @Published var webdavUrl: String = ""
    @Published var webdavUser: String = ""
    @Published var webdavHasSavedPass: Bool = false
    @Published var webdavAutoSync: Bool = true
    @Published var webdavLastSync: String = ""
    @Published var webdavSyncing: Bool = false
    @Published var isWebDavSheetOpen: Bool = false
    @Published var showWebdavConflictSheet: Bool = false
    @Published var showRemotePasswordPrompt: Bool = false

    // MARK: - Busy State (Off-Main KDF / KDBX)
    @Published var isBusy: Bool = false

    // MARK: - Generator History (max 6)
    @Published var genHistory: [String] = []

    // MARK: - Toast HUD
    @Published var toastMsg: String? = nil
    @Published var toastWarn: Bool = false

    // MARK: - Private Storage & Sync Internals
    let dataDir: String
    private var saltB64: String = ""
    private var masterKeyB64: String = ""
    private var rawPayloadExtras: [String: Any] = [:]
    private var localDirty: Bool = false
    private var syncSnapshot: WebDavSyncSnapshot? = nil
    private var debounceUploadTask: Task<Void, Never>? = nil
    private var pendingRemoteDownload: WebDavDownload? = nil
    private var pendingWebdavPassForRemote: String? = nil
    private var lastBackgroundDate: Date? = nil
    private var toastToken: UUID = UUID()

    private let keychainMasterKeyAccount = "suoxia.masterKey.v1"

    init() {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        self.dataDir = docs.path
        loadInitialState()
    }

    private var metaURL: URL {
        URL(fileURLWithPath: dataDir).appendingPathComponent("suoxia_meta.json")
    }

    var hasVault: Bool {
        !saltB64.isEmpty
    }

    var activeItems: [VaultItem] {
        items.filter { $0.deletedAt == nil }
    }

    var trashedItems: [VaultItem] {
        items.filter { $0.deletedAt != nil }
    }

    var webdavHost: String {
        guard let url = URL(string: webdavUrl), let host = url.host else { return "" }
        return host
    }

    // MARK: - Toast

    func showToast(_ msg: String, warn: Bool = false) {
        let token = UUID()
        toastToken = token
        withAnimation(.easeOut(duration: 0.2)) {
            toastMsg = msg
            toastWarn = warn
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            if self.toastToken == token {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.toastMsg = nil
                }
            }
        }
    }

    // MARK: - Initial Load & Meta

    private func loadInitialState() {
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (meta["hasVault"] as? Bool) == true else {
            screen = .onboarding
            return
        }
        saltB64 = (meta["saltB64"] as? String) ?? ""
        requireUnlock = (meta["requireUnlock"] as? Bool) ?? false
        bioFaceOn = (meta["bioFaceOn"] as? Bool) ?? true
        bioFingerOn = (meta["bioFingerOn"] as? Bool) ?? true
        gestureOn = (meta["gestureOn"] as? Bool) ?? false
        gesturePattern = (meta["gesturePattern"] as? String) ?? ""
        if let rawLock = meta["autoLock"] as? String, let opt = AutoLockOption(rawValue: rawLock) {
            autoLock = opt
        } else {
            autoLock = .fiveMin
        }
        privacyMask = (meta["privacyMask"] as? Bool) ?? true
        isDark = (meta["isDark"] as? Bool) ?? false
        webdavAutoSync = (meta["webdavAutoSync"] as? Bool) ?? true
        webdavLastSync = (meta["webdavLastSync"] as? String) ?? ""
        localDirty = (meta["localDirty"] as? Bool) ?? false

        if let snapDict = meta["syncSnapshot"] as? [String: Any] {
            syncSnapshot = WebDavSyncSnapshot(
                etag: snapDict["etag"] as? String,
                lastModified: snapDict["lastModified"] as? String,
                size: (snapDict["size"] as? UInt64) ?? (snapDict["size"] as? NSNumber)?.uint64Value ?? 0
            )
        }

        loadWebDavConfigMetadata()

        // Migrate cached key from meta to Keychain if needed
        let legacyCachedKey = (meta["cachedKeyB64"] as? String) ?? ""
        let keychainKey = KeychainAndBiometrics.loadKeychainValue(account: keychainMasterKeyAccount) ?? ""
        let availableKey = !keychainKey.isEmpty ? keychainKey : legacyCachedKey

        if !requireUnlock && !availableKey.isEmpty {
            masterKeyB64 = availableKey
            if keychainKey.isEmpty && !legacyCachedKey.isEmpty {
                KeychainAndBiometrics.saveKeychainValue(legacyCachedKey, account: keychainMasterKeyAccount)
            }
            if decryptLocalVault() {
                screen = .home
                Task { await self.syncWebDavOnActive() }
            } else {
                screen = .unlock
            }
        } else {
            screen = .unlock
        }
    }

    private func loadWebDavConfigMetadata() {
        if let cfg = try? SecureVaultCore.getWebdavConfig(dataDir: dataDir) {
            webdavUrl = cfg.url
            webdavUser = cfg.username
            webdavHasSavedPass = !cfg.passwordEnc.isEmpty
            webdavConfigured = !cfg.url.isEmpty && !cfg.username.isEmpty && !cfg.passwordEnc.isEmpty
        } else {
            webdavConfigured = false
            webdavHasSavedPass = false
        }
    }

    func saveMeta() {
        var meta: [String: Any] = [
            "hasVault": !saltB64.isEmpty,
            "saltB64": saltB64,
            "requireUnlock": requireUnlock,
            "bioFaceOn": bioFaceOn,
            "bioFingerOn": bioFingerOn,
            "gestureOn": gestureOn,
            "gesturePattern": gesturePattern,
            "autoLock": autoLock.rawValue,
            "privacyMask": privacyMask,
            "isDark": isDark,
            "webdavConfigured": webdavConfigured,
            "webdavAutoSync": webdavAutoSync,
            "webdavLastSync": webdavLastSync,
            "localDirty": localDirty
        ]
        if let snap = syncSnapshot {
            var sDict: [String: Any] = ["size": snap.size]
            if let etag = snap.etag { sDict["etag"] = etag }
            if let lm = snap.lastModified { sDict["lastModified"] = lm }
            meta["syncSnapshot"] = sDict
        }

        // Keep master key in Keychain when unlocked so Face ID / Gesture / direct open can decrypt
        if !masterKeyB64.isEmpty {
            KeychainAndBiometrics.saveKeychainValue(masterKeyB64, account: keychainMasterKeyAccount)
        }

        if let data = try? JSONSerialization.data(withJSONObject: meta) {
            try? data.write(to: metaURL, options: .atomic)
        }
    }

    // MARK: - Scene Phase & Auto-Lock

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            lastBackgroundDate = Date()
        case .active:
            if screen == .home {
                if requireUnlock, let bg = lastBackgroundDate {
                    let elapsed = Date().timeIntervalSince(bg)
                    if elapsed >= autoLock.seconds {
                        lockNow(showMessage: false)
                        lastBackgroundDate = nil
                        return
                    }
                }
                lastBackgroundDate = nil
                Task { await syncWebDavOnActive() }
            }
        default:
            break
        }
    }

    func lockNow(showMessage: Bool = true) {
        debounceUploadTask?.cancel()
        masterKeyB64 = ""
        items = []
        folders = []
        standaloneTotps = []
        rawPayloadExtras = [:]
        screen = .unlock
        if showMessage {
            showToast(t("锁匣已锁定"))
        }
    }

    // MARK: - Vault Creation & Unlock

    func createFreshVault(password: String) async -> Bool {
        guard !isBusy else { return false }
        guard password.count >= 8 else {
            showToast(t("主密码至少 8 位"), warn: true)
            return false
        }
        isBusy = true
        defer { isBusy = false }

        let result = await Task.detached(priority: .userInitiated) { () -> Result<(salt: String, key: String), Error> in
            Result {
                let salt = try SecureVaultCore.generateSalt()
                let key = try SecureVaultCore.deriveMasterKey(password: password, saltB64: salt, kdf: "argon2id")
                return (salt: salt, key: key)
            }
        }.value

        switch result {
        case .success(let derived):
            saltB64 = derived.salt
            masterKeyB64 = derived.key
            items = []
            folders = []
            standaloneTotps = []
            rawPayloadExtras = [:]
            activeFolder = VaultHelpers.allFoldersKey
            activeCat = .all
            persistVault(markDirty: false)
            saveMeta()
            screen = .home
            activeTab = .vault
            showToast(t("保险箱已创建"))
            return true
        case .failure:
            showToast(t("创建失败"), warn: true)
            return false
        }
    }

    nonisolated private static func splitVaultFileContent(_ raw: String) -> (salt: String?, cipher: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = trimmed.firstIndex(of: ":") {
            let s = String(trimmed[..<idx])
            let c = String(trimmed[trimmed.index(after: idx)...])
            if !s.isEmpty && !c.isEmpty {
                return (s, c)
            }
        }
        return (nil, trimmed)
    }

    nonisolated private static func deriveAndDecryptOffMain(password: String, salt: String, cipher: String) -> (key: String, plain: String)? {
        for kdf in ["argon2id", "pbkdf2"] {
            if let key = try? SecureVaultCore.deriveMasterKey(password: password, saltB64: salt, kdf: kdf),
               let plain = try? SecureVaultCore.decryptVault(ciphertextB64: cipher, keyB64: key) {
                return (key, plain)
            }
        }
        return nil
    }

    func unlockWithPassword(_ password: String) async -> Bool {
        guard !isBusy else { return false }
        guard !password.isEmpty else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }
        guard let rawFile = try? SecureVaultCore.loadVaultFile(dataDir: dataDir), !rawFile.isEmpty else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }
        let parsed = Self.splitVaultFileContent(rawFile)
        let effectiveSalt = parsed.salt ?? saltB64
        guard !effectiveSalt.isEmpty else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }

        isBusy = true
        let cipher = parsed.cipher
        let result = await Task.detached(priority: .userInitiated) {
            Self.deriveAndDecryptOffMain(password: password, salt: effectiveSalt, cipher: cipher)
        }.value
        isBusy = false

        guard let result else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }

        saltB64 = effectiveSalt
        masterKeyB64 = result.key
        applyDecryptedPayloadJSON(result.plain)
        // Migrate legacy bare-cipher format on unlock
        if parsed.salt == nil {
            persistVault(markDirty: false)
        }
        loadWebDavConfigMetadata()
        saveMeta()
        screen = .home
        showToast(t("锁匣已解锁"))
        Task { await syncWebDavOnActive() }
        return true
    }

    func unlockWithGesture(_ pattern: String) -> Bool {
        guard pattern == gesturePattern else {
            showToast(t("手势图案错误，请重试"), warn: true)
            return false
        }
        return unlockUsingStoredKey(toast: t("手势验证通过"))
    }

    func unlockWithBiometrics() {
        KeychainAndBiometrics.authenticate(reason: t("验证身份以解锁锁匣")) { [weak self] ok in
            guard let self else { return }
            Task { @MainActor in
                if ok {
                    _ = self.unlockUsingStoredKey(toast: t("生物识别验证通过"))
                } else {
                    self.showToast(t("生物识别验证失败"), warn: true)
                }
            }
        }
    }

    private func unlockUsingStoredKey(toast: String) -> Bool {
        if masterKeyB64.isEmpty, let kc = KeychainAndBiometrics.loadKeychainValue(account: keychainMasterKeyAccount) {
            masterKeyB64 = kc
        }
        guard !masterKeyB64.isEmpty, decryptLocalVault() else {
            showToast(t("请输入主密码以解锁"), warn: true)
            return false
        }
        loadWebDavConfigMetadata()
        screen = .home
        showToast(toast)
        Task { await syncWebDavOnActive() }
        return true
    }

    func verifyMasterPassword(_ password: String) async -> Bool {
        guard !isBusy else { return false }
        guard !password.isEmpty, !saltB64.isEmpty else { return false }
        isBusy = true
        defer { isBusy = false }

        let currentSalt = saltB64
        let currentKey = masterKeyB64
        return await Task.detached(priority: .userInitiated) {
            for kdf in ["argon2id", "pbkdf2"] {
                if let key = try? SecureVaultCore.deriveMasterKey(password: password, saltB64: currentSalt, kdf: kdf),
                   key == currentKey {
                    return true
                }
            }
            return false
        }.value
    }

    func changeMasterPassword(current: String, newPassword: String) async -> Bool {
        guard !isBusy else { return false }
        guard newPassword.count >= 8 else {
            showToast(t("主密码至少 8 位"), warn: true)
            return false
        }
        isBusy = true
        defer { isBusy = false }

        let oldSalt = saltB64
        let oldKey = masterKeyB64
        let verified = await Task.detached(priority: .userInitiated) {
            for kdf in ["argon2id", "pbkdf2"] {
                if let key = try? SecureVaultCore.deriveMasterKey(password: current, saltB64: oldSalt, kdf: kdf),
                   key == oldKey {
                    return true
                }
            }
            return false
        }.value

        guard verified else {
            showToast(t("当前主密码不正确"), warn: true)
            return false
        }

        // Preserve decrypted WebDAV password before rotating master key
        var savedWdPass: String? = nil
        if let cfg = try? SecureVaultCore.getWebdavConfig(dataDir: dataDir), !cfg.passwordEnc.isEmpty {
            savedWdPass = try? SecureVaultCore.decryptVault(ciphertextB64: cfg.passwordEnc, keyB64: masterKeyB64)
        }

        let deriveResult = await Task.detached(priority: .userInitiated) { () -> Result<(salt: String, key: String), Error> in
            Result {
                let newSalt = try SecureVaultCore.generateSalt()
                let newKey = try SecureVaultCore.deriveMasterKey(password: newPassword, saltB64: newSalt, kdf: "argon2id")
                return (salt: newSalt, key: newKey)
            }
        }.value

        switch deriveResult {
        case .success(let derived):
            saltB64 = derived.salt
            masterKeyB64 = derived.key

            // Re-encrypt saved WebDAV password under new master key
            if let wdPass = savedWdPass, !webdavUrl.isEmpty, !webdavUser.isEmpty {
                if let newPassEnc = try? SecureVaultCore.encryptVault(plaintext: wdPass, keyB64: derived.key) {
                    try? SecureVaultCore.saveWebdavConfig(dataDir: dataDir, url: webdavUrl, username: webdavUser, passwordEnc: newPassEnc)
                }
            }

            persistVault(markDirty: true)
            saveMeta()
            showToast(t("主密码已更新"))
            return true
        case .failure:
            showToast(t("创建失败"), warn: true)
            return false
        }
    }

    // MARK: - Local Vault Serialization (100% Desktop Compatible)

    @discardableResult
    private func decryptLocalVault() -> Bool {
        guard !masterKeyB64.isEmpty,
              let rawFile = try? SecureVaultCore.loadVaultFile(dataDir: dataDir),
              !rawFile.isEmpty else {
            return false
        }
        let parsed = Self.splitVaultFileContent(rawFile)
        if let s = parsed.salt {
            saltB64 = s
        }
        guard let plain = try? SecureVaultCore.decryptVault(ciphertextB64: parsed.cipher, keyB64: masterKeyB64) else {
            return false
        }
        applyDecryptedPayloadJSON(plain)
        return true
    }

    private func applyDecryptedPayloadJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Preserve all unknown top-level keys (e.g., autoLockTimeout)
        var extras = root
        extras.removeValue(forKey: "items")
        extras.removeValue(forKey: "folders")
        extras.removeValue(forKey: "standaloneTotps")
        extras.removeValue(forKey: "saltB64")
        rawPayloadExtras = extras

        // Parse items
        if let rawItems = root["items"] as? [[String: Any]] {
            items = rawItems.map { VaultItem.fromJSON($0) }
        } else {
            items = []
        }

        // Parse folders (both string and {id, name, icon} forms)
        var parsedFolders: [VaultFolderRecord] = []
        var seenNames = Set<String>()
        if let rawFolders = root["folders"] as? [Any] {
            for entry in rawFolders {
                if let str = entry as? String {
                    let norm = VaultHelpers.normalizeFolderName(str)
                    if norm != VaultHelpers.defaultFolderKey && !seenNames.contains(norm) {
                        seenNames.insert(norm)
                        parsedFolders.append(VaultFolderRecord(id: UUID().uuidString, name: norm, icon: "folder"))
                    }
                } else if let obj = entry as? [String: Any] {
                    let norm = VaultHelpers.normalizeFolderName(obj["name"] as? String)
                    if norm != VaultHelpers.defaultFolderKey && !seenNames.contains(norm) {
                        seenNames.insert(norm)
                        let fid = (obj["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
                        let icon = (obj["icon"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "folder"
                        parsedFolders.append(VaultFolderRecord(id: fid, name: norm, icon: icon))
                    }
                }
            }
        }
        // Also ensure any custom folder referenced by active items exists
        for item in items where item.deletedAt == nil {
            let norm = VaultHelpers.normalizeFolderName(item.folder)
            if norm != VaultHelpers.defaultFolderKey && !seenNames.contains(norm) {
                seenNames.insert(norm)
                parsedFolders.append(VaultFolderRecord(id: UUID().uuidString, name: norm, icon: "folder"))
            }
        }
        folders = parsedFolders

        // Parse mobile standalone 2FA tokens
        if let rawTotps = root["standaloneTotps"] as? [[String: Any]] {
            standaloneTotps = rawTotps.compactMap { d in
                let sec = (d["secret"] as? String) ?? ""
                guard !sec.isEmpty else { return nil }
                return StandaloneTotp(
                    id: (d["id"] as? String) ?? UUID().uuidString,
                    issuer: (d["issuer"] as? String) ?? "",
                    account: (d["account"] as? String) ?? "",
                    secret: sec
                )
            }
        } else {
            standaloneTotps = []
        }
    }

    private func buildPayloadJSONString() -> String? {
        var root = rawPayloadExtras
        root["items"] = items.map { $0.toJSON() }
        root["folders"] = folders.map { ["id": $0.id, "name": $0.name, "icon": $0.icon] }
        root["standaloneTotps"] = standaloneTotps.map { [
            "id": $0.id,
            "issuer": $0.issuer,
            "account": $0.account,
            "secret": $0.secret
        ] }
        guard let data = try? JSONSerialization.data(withJSONObject: root) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func persistVault(markDirty: Bool = true) {
        guard !masterKeyB64.isEmpty, !saltB64.isEmpty,
              let jsonStr = buildPayloadJSONString(),
              let cipher = try? SecureVaultCore.encryptVault(plaintext: jsonStr, keyB64: masterKeyB64) else {
            return
        }
        // Desktop-compatible salt:ciphertext format
        let fileContent = "\(saltB64):\(cipher)"
        try? SecureVaultCore.saveVaultFile(dataDir: dataDir, ciphertextB64: fileContent)

        if markDirty {
            localDirty = true
            saveMeta()
            if webdavConfigured && webdavAutoSync {
                scheduleDebouncedUpload()
            }
        }
    }

    // MARK: - CRUD Operations

    func saveItem(_ item: VaultItem) {
        var updated = item
        updated.folder = VaultHelpers.normalizeFolderName(item.folder)
        updated.updatedAt = VaultHelpers.currentUpdatedAtString()
        updated.strength = VaultHelpers.computePasswordStrength(item.password)

        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            let old = items[idx]
            // Preserve unknown desktop fields
            updated.rawJSON = old.rawJSON
            updated.isFavorite = old.isFavorite
            updated.deletedAt = old.deletedAt
            // Record password history if password changed
            if old.type == .login && !old.password.isEmpty && old.password != updated.password {
                var hist = old.passwordHistory
                hist.insert(PasswordHistoryEntry(password: old.password, changedAt: VaultHelpers.todayDateString()), at: 0)
                if hist.count > 10 { hist = Array(hist.prefix(10)) }
                updated.passwordHistory = hist
            } else {
                updated.passwordHistory = old.passwordHistory
            }
            items[idx] = updated
        } else {
            items.insert(updated, at: 0)
        }

        if updated.folder != VaultHelpers.defaultFolderKey && !folders.contains(where: { $0.name == updated.folder }) {
            folders.append(VaultFolderRecord(id: UUID().uuidString, name: updated.folder, icon: "folder"))
        }

        persistVault(markDirty: true)
        showToast(t("已加密保存"))
    }

    func toggleFavorite(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isFavorite.toggle()
        items[idx].updatedAt = VaultHelpers.currentUpdatedAtString()
        persistVault(markDirty: true)
        showToast(items[idx].isFavorite ? t("已加星标") : t("已取消星标"))
    }

    func restorePasswordHistory(itemId: String, oldPassword: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let current = items[idx].password
        if !current.isEmpty && current != oldPassword {
            items[idx].passwordHistory.insert(
                PasswordHistoryEntry(password: current, changedAt: VaultHelpers.todayDateString()),
                at: 0
            )
        }
        items[idx].password = oldPassword
        items[idx].strength = VaultHelpers.computePasswordStrength(oldPassword)
        items[idx].updatedAt = VaultHelpers.currentUpdatedAtString()
        persistVault(markDirty: true)
        showToast(t("已恢复该历史密码"))
    }

    func moveToTrash(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].deletedAt = VaultHelpers.todayDateString()
        persistVault(markDirty: true)
        showToast(t("已移入回收站"))
    }

    func restoreFromTrash(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].deletedAt = nil
        persistVault(markDirty: true)
        showToast(t("已恢复"))
    }

    func purgeItem(id: String) {
        items.removeAll { $0.id == id }
        persistVault(markDirty: true)
        showToast(t("已彻底删除"))
    }

    func emptyTrash() {
        items.removeAll { $0.deletedAt != nil }
        persistVault(markDirty: true)
        showToast(t("已清空回收站"))
    }

    // MARK: - Folders

    func addFolder(_ rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showToast(t("请输入文件夹名称"), warn: true)
            return false
        }
        if name == VaultHelpers.allFoldersKey || name == VaultHelpers.defaultFolderKey || folders.contains(where: { $0.name == name }) {
            showToast(t("文件夹已存在"), warn: true)
            return false
        }
        folders.append(VaultFolderRecord(id: UUID().uuidString, name: name, icon: "folder"))
        persistVault(markDirty: true)
        showToast(AppI18n.isChinese ? "已新建文件夹：\(name)" : "Folder created: \(name)")
        return true
    }

    func deleteFolder(_ name: String) {
        let affectedCount = activeItems.filter { $0.folder == name }.count
        for i in items.indices {
            if items[i].folder == name {
                items[i].folder = VaultHelpers.defaultFolderKey
            }
        }
        folders.removeAll { $0.name == name }
        if activeFolder == name {
            activeFolder = VaultHelpers.allFoldersKey
        }
        persistVault(markDirty: true)
        showToast(affectedCount > 0 ? t("已删除文件夹，原凭证已移入默认文件夹") : t("已删除文件夹"))
    }

    // MARK: - Standalone 2FA

    func addStandaloneTotp(issuer: String, account: String, secret: String, fromScan: Bool = false) {
        let cleaned = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !cleaned.isEmpty else {
            showToast(t("请填写服务名称和密钥"), warn: true)
            return
        }
        let token = StandaloneTotp(
            id: "t_\(Int(Date().timeIntervalSince1970 * 1000))",
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            account: account.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: cleaned
        )
        standaloneTotps.insert(token, at: 0)
        persistVault(markDirty: true)
        showToast(fromScan ? t("已扫码添加动态令牌") : t("已添加动态令牌"))
    }

    func deleteStandaloneTotp(id: String) {
        standaloneTotps.removeAll { $0.id == id }
        persistVault(markDirty: true)
        showToast(t("已移除令牌"))
    }

    // MARK: - Generator History

    func recordGeneratedPassword(_ pwd: String) {
        guard !pwd.isEmpty else { return }
        var next = genHistory.filter { $0 != pwd }
        next.insert(pwd, at: 0)
        if next.count > 6 { next = Array(next.prefix(6)) }
        genHistory = next
    }

    func clearGenHistory() {
        genHistory = []
        showToast(t("已清空生成记录"))
    }

    // MARK: - Real Bidirectional Event-Driven WebDAV Sync

    private func isValidWebDavUrl(_ url: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.hasPrefix("https://") || u.hasPrefix("http://localhost") || u.hasPrefix("http://127.0.0.1")
    }

    private func decryptSavedWebDavPassword() -> String? {
        guard !masterKeyB64.isEmpty,
              let cfg = try? SecureVaultCore.getWebdavConfig(dataDir: dataDir),
              !cfg.passwordEnc.isEmpty else { return nil }
        return try? SecureVaultCore.decryptVault(ciphertextB64: cfg.passwordEnc, keyB64: masterKeyB64)
    }

    private func hasRemoteChanged(_ stat: WebDavStat) -> Bool {
        guard stat.exists else { return false }
        guard let snap = syncSnapshot else { return true }
        if let e1 = stat.etag, let e2 = snap.etag, !e1.isEmpty, !e2.isEmpty {
            return e1 != e2
        }
        if let m1 = stat.lastModified, let m2 = snap.lastModified, !m1.isEmpty, !m2.isEmpty {
            return m1 != m2
        }
        return stat.size != snap.size
    }

    private func updateSnapshot(_ stat: WebDavStat) {
        syncSnapshot = WebDavSyncSnapshot(etag: stat.etag, lastModified: stat.lastModified, size: stat.size)
        let prefix = AppI18n.isChinese ? "今天 " : "Today "
        webdavLastSync = "\(prefix)\(VaultHelpers.currentHHMM())"
        saveMeta()
    }

    func testWebDav(url: String, username: String, passwordInput: String) async {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = passwordInput.isEmpty ? (decryptSavedWebDavPassword() ?? "") : passwordInput
        guard !u.isEmpty, !user.isEmpty, !pass.isEmpty else {
            showToast(t("请先填写完整地址、账号与授权密码"), warn: true)
            return
        }
        guard isValidWebDavUrl(u) else {
            showToast(t("请使用 https:// 开头的加密地址"), warn: true)
            return
        }
        webdavSyncing = true
        let result = await Task.detached(priority: .userInitiated) {
            Result { try SecureVaultCore.webdavTest(url: u, username: user, password: pass) }
        }.value
        webdavSyncing = false

        switch result {
        case .success(let msg):
            showToast(msg)
        case .failure(let err):
            showToast(err.localizedDescription, warn: true)
        }
    }

    func saveWebDavConfig(url: String, username: String, passwordInput: String) -> Bool {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = passwordInput.isEmpty ? (decryptSavedWebDavPassword() ?? "") : passwordInput
        guard !u.isEmpty, !user.isEmpty, !pass.isEmpty else {
            showToast(t("请先填写完整地址、账号与授权密码"), warn: true)
            return false
        }
        guard isValidWebDavUrl(u) else {
            showToast(t("仅支持 https:// 服务器地址"), warn: true)
            return false
        }
        do {
            let passEnc = try SecureVaultCore.encryptVault(plaintext: pass, keyB64: masterKeyB64)
            try SecureVaultCore.saveWebdavConfig(dataDir: dataDir, url: u, username: user, passwordEnc: passEnc)
            webdavUrl = SecureVaultCore.normalizeWebDavUrl(u)
            webdavUser = user
            webdavHasSavedPass = true
            webdavConfigured = true
            saveMeta()
            showToast(t("WebDAV 配置已加密保存"))
            return true
        } catch {
            showToast(error.localizedDescription, warn: true)
            return false
        }
    }

    func disconnectWebDav() {
        debounceUploadTask?.cancel()
        try? SecureVaultCore.clearWebdavConfig(dataDir: dataDir)
        webdavConfigured = false
        webdavUrl = ""
        webdavUser = ""
        webdavHasSavedPass = false
        webdavLastSync = ""
        syncSnapshot = nil
        localDirty = false
        saveMeta()
        showToast(t("已断开 WebDAV 同步"))
    }

    func syncWebDavOnActive() async {
        guard screen == .home, webdavConfigured, webdavAutoSync, !webdavSyncing else { return }
        await performBidirectionalSync(manual: false)
    }

    func syncWebDavNow() async {
        guard webdavConfigured else {
            showToast(t("请先保存服务器配置"), warn: true)
            return
        }
        guard !webdavSyncing else { return }
        await performBidirectionalSync(manual: true)
    }

    private func scheduleDebouncedUpload() {
        debounceUploadTask?.cancel()
        debounceUploadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.performDebouncedSaveUpload()
        }
    }

    private func performDebouncedSaveUpload() async {
        guard screen == .home, webdavConfigured, webdavAutoSync, localDirty, !webdavSyncing else { return }
        guard let pass = decryptSavedWebDavPassword() else { return }
        let url = webdavUrl
        let user = webdavUser
        let dir = dataDir

        webdavSyncing = true
        let statRes = await Task.detached(priority: .utility) {
            Result { try SecureVaultCore.webdavStat(url: url, username: user, password: pass) }
        }.value

        switch statRes {
        case .success(let stat):
            if stat.exists && hasRemoteChanged(stat) {
                webdavSyncing = false
                showWebdavConflictSheet = true
                return
            }
            let upRes = await Task.detached(priority: .utility) {
                Result { try SecureVaultCore.webdavUpload(dataDir: dir, url: url, username: user, password: pass) }
            }.value
            webdavSyncing = false
            switch upRes {
            case .success(let newStat):
                localDirty = false
                updateSnapshot(newStat)
            case .failure(let err):
                showToast(err.localizedDescription, warn: true)
            }
        case .failure(let err):
            webdavSyncing = false
            showToast(err.localizedDescription, warn: true)
        }
    }

    private func performBidirectionalSync(manual: Bool) async {
        guard let pass = decryptSavedWebDavPassword() else {
            if manual { showToast(t("请先保存服务器配置"), warn: true) }
            return
        }
        let url = webdavUrl
        let user = webdavUser
        let dir = dataDir

        webdavSyncing = true
        let statRes = await Task.detached(priority: .userInitiated) {
            Result { try SecureVaultCore.webdavStat(url: url, username: user, password: pass) }
        }.value

        switch statRes {
        case .failure(let err):
            webdavSyncing = false
            showToast(err.localizedDescription, warn: true)
        case .success(let stat):
            let remoteChanged = hasRemoteChanged(stat)
            if !stat.exists {
                // Upload initial vault
                let upRes = await Task.detached(priority: .userInitiated) {
                    Result { try SecureVaultCore.webdavUpload(dataDir: dir, url: url, username: user, password: pass) }
                }.value
                webdavSyncing = false
                switch upRes {
                case .success(let newStat):
                    localDirty = false
                    updateSnapshot(newStat)
                    if manual { showToast(t("已同步至云端")) }
                case .failure(let err):
                    showToast(err.localizedDescription, warn: true)
                }
            } else if remoteChanged && localDirty {
                webdavSyncing = false
                showWebdavConflictSheet = true
            } else if remoteChanged && !localDirty {
                let dlRes = await Task.detached(priority: .userInitiated) {
                    Result { try SecureVaultCore.webdavDownload(url: url, username: user, password: pass) }
                }.value
                webdavSyncing = false
                switch dlRes {
                case .success(let dl):
                    applyDownloadedVault(dl, webdavPass: pass, showToastOnSuccess: manual)
                case .failure(let err):
                    showToast(err.localizedDescription, warn: true)
                }
            } else if !remoteChanged && localDirty {
                let upRes = await Task.detached(priority: .userInitiated) {
                    Result { try SecureVaultCore.webdavUpload(dataDir: dir, url: url, username: user, password: pass) }
                }.value
                webdavSyncing = false
                switch upRes {
                case .success(let newStat):
                    localDirty = false
                    updateSnapshot(newStat)
                    if manual { showToast(t("已同步至云端")) }
                case .failure(let err):
                    showToast(err.localizedDescription, warn: true)
                }
            } else {
                webdavSyncing = false
                if manual { showToast(t("云端与本机已一致")) }
            }
        }
    }

    func resolveConflictKeepLocal() async {
        showWebdavConflictSheet = false
        guard let pass = decryptSavedWebDavPassword() else { return }
        let url = webdavUrl
        let user = webdavUser
        let dir = dataDir
        webdavSyncing = true
        let upRes = await Task.detached(priority: .userInitiated) {
            Result { try SecureVaultCore.webdavUpload(dataDir: dir, url: url, username: user, password: pass) }
        }.value
        webdavSyncing = false
        switch upRes {
        case .success(let newStat):
            localDirty = false
            updateSnapshot(newStat)
            showToast(t("已用本机数据覆盖云端"))
        case .failure(let err):
            showToast(err.localizedDescription, warn: true)
        }
    }

    func resolveConflictUseRemote() async {
        showWebdavConflictSheet = false
        guard let pass = decryptSavedWebDavPassword() else { return }
        let url = webdavUrl
        let user = webdavUser
        webdavSyncing = true
        let dlRes = await Task.detached(priority: .userInitiated) {
            Result { try SecureVaultCore.webdavDownload(url: url, username: user, password: pass) }
        }.value
        webdavSyncing = false
        switch dlRes {
        case .success(let dl):
            applyDownloadedVault(dl, webdavPass: pass, showToastOnSuccess: true)
        case .failure(let err):
            showToast(err.localizedDescription, warn: true)
        }
    }

    private func applyDownloadedVault(_ dl: WebDavDownload, webdavPass: String, showToastOnSuccess: Bool) {
        let parsed = Self.splitVaultFileContent(dl.content)
        let sameSalt = (parsed.salt == nil || parsed.salt == saltB64)
        if sameSalt, let plain = try? SecureVaultCore.decryptVault(ciphertextB64: parsed.cipher, keyB64: masterKeyB64) {
            applyDecryptedPayloadJSON(plain)
            try? SecureVaultCore.saveVaultFile(dataDir: dataDir, ciphertextB64: dl.content)
            localDirty = false
            updateSnapshot(dl.stat)
            if showToastOnSuccess { showToast(t("已从云端更新")) }
        } else {
            pendingRemoteDownload = dl
            pendingWebdavPassForRemote = webdavPass
            showRemotePasswordPrompt = true
        }
    }

    func unlockAndApplyRemoteVault(password: String) async -> Bool {
        guard !isBusy else { return false }
        guard let dl = pendingRemoteDownload else {
            showRemotePasswordPrompt = false
            return false
        }
        let parsed = Self.splitVaultFileContent(dl.content)
        let remoteSalt = parsed.salt ?? saltB64
        guard !remoteSalt.isEmpty else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }

        isBusy = true
        let cipher = parsed.cipher
        let result = await Task.detached(priority: .userInitiated) {
            Self.deriveAndDecryptOffMain(password: password, salt: remoteSalt, cipher: cipher)
        }.value
        isBusy = false

        guard let result else {
            showToast(t("主密码不正确"), warn: true)
            return false
        }
        saltB64 = remoteSalt
        masterKeyB64 = result.key
        applyDecryptedPayloadJSON(result.plain)
        try? SecureVaultCore.saveVaultFile(dataDir: dataDir, ciphertextB64: dl.content)

        // Re-encrypt WebDAV password under adopted key
        if let wdPass = pendingWebdavPassForRemote, !webdavUrl.isEmpty, !webdavUser.isEmpty,
           let newPassEnc = try? SecureVaultCore.encryptVault(plaintext: wdPass, keyB64: masterKeyB64) {
            try? SecureVaultCore.saveWebdavConfig(dataDir: dataDir, url: webdavUrl, username: webdavUser, passwordEnc: newPassEnc)
        }

        pendingRemoteDownload = nil
        pendingWebdavPassForRemote = nil
        showRemotePasswordPrompt = false
        localDirty = false
        updateSnapshot(dl.stat)
        showToast(t("已下载云端版本并更新本机"))
        return true
    }

    func cancelRemotePasswordPrompt() {
        pendingRemoteDownload = nil
        pendingWebdavPassForRemote = nil
        showRemotePasswordPrompt = false
    }

    func restoreFromWebDav(url: String, username: String, webdavPassword: String, masterPassword: String) async -> Bool {
        guard !isBusy, !webdavSyncing else { return false }
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty, !user.isEmpty, !webdavPassword.isEmpty, !masterPassword.isEmpty else {
            showToast(t("请先填写完整地址、账号与授权密码"), warn: true)
            return false
        }
        guard isValidWebDavUrl(u) else {
            showToast(t("仅支持 https:// 服务器地址"), warn: true)
            return false
        }

        webdavSyncing = true
        isBusy = true
        defer {
            webdavSyncing = false
            isBusy = false
        }

        let dlRes = await Task.detached(priority: .userInitiated) {
            Result { try SecureVaultCore.webdavDownload(url: u, username: user, password: webdavPassword) }
        }.value

        switch dlRes {
        case .failure(let err):
            showToast(err.localizedDescription, warn: true)
            return false
        case .success(let dl):
            let parsed = Self.splitVaultFileContent(dl.content)
            guard let remoteSalt = parsed.salt, !remoteSalt.isEmpty else {
                showToast(t("文件解析失败"), warn: true)
                return false
            }
            let cipher = parsed.cipher
            let dec = await Task.detached(priority: .userInitiated) {
                Self.deriveAndDecryptOffMain(password: masterPassword, salt: remoteSalt, cipher: cipher)
            }.value
            guard let dec else {
                showToast(t("主密码不正确"), warn: true)
                return false
            }
            saltB64 = remoteSalt
            masterKeyB64 = dec.key
            applyDecryptedPayloadJSON(dec.plain)
            try? SecureVaultCore.saveVaultFile(dataDir: dataDir, ciphertextB64: dl.content)

            if let passEnc = try? SecureVaultCore.encryptVault(plaintext: webdavPassword, keyB64: masterKeyB64) {
                try? SecureVaultCore.saveWebdavConfig(dataDir: dataDir, url: u, username: user, passwordEnc: passEnc)
            }
            webdavUrl = SecureVaultCore.normalizeWebDavUrl(u)
            webdavUser = user
            webdavHasSavedPass = true
            webdavConfigured = true
            localDirty = false
            updateSnapshot(dl.stat)
            screen = .home
            activeTab = .vault
            showToast(t("已从云端更新"))
            return true
        }
    }

    // MARK: - Export (Encrypted JSON & KDBX)

    func buildEncryptedJsonExport() throws -> Data {
        guard !masterKeyB64.isEmpty, !saltB64.isEmpty else {
            throw RustCoreError.message("Vault locked")
        }
        let iso = ISO8601DateFormatter().string(from: Date())
        let plainObj: [String: Any] = [
            "version": "1.0.0",
            "exportedAt": iso,
            "folders": folders.map { ["id": $0.id, "name": $0.name, "icon": $0.icon] },
            "vaultItems": activeItems.map { $0.toJSON() },
            "standaloneTotps": standaloneTotps.map { [
                "id": $0.id, "issuer": $0.issuer, "account": $0.account, "secret": $0.secret
            ] }
        ]
        let plainData = try JSONSerialization.data(withJSONObject: plainObj)
        let plainStr = String(data: plainData, encoding: .utf8) ?? "{}"
        let checksum = try SecureVaultCore.computeSha256(plainStr)
        let encryptedPayload = try SecureVaultCore.encryptVault(plaintext: plainStr, keyB64: masterKeyB64)

        let envelope: [String: Any] = [
            "isEncrypted": true,
            "version": "1.0.0",
            "kdf": "argon2id",
            "salt": saltB64,
            "checksum": checksum,
            "encryptedPayload": encryptedPayload,
            "hint": "SecureVault Encrypted Backup"
        ]
        return try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted])
    }

    func buildKdbxExport(password: String) async throws -> Data {
        guard !isBusy else { throw RustCoreError.message("Busy") }
        isBusy = true
        defer { isBusy = false }

        let itemsObj: [String: Any] = ["items": activeItems.map { $0.toJSON() }]
        let itemsData = try JSONSerialization.data(withJSONObject: itemsObj)
        let itemsJson = String(data: itemsData, encoding: .utf8) ?? "{\"items\":[]}"

        return try await Task.detached(priority: .userInitiated) {
            let tmpPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("sv_export_\(UUID().uuidString).kdbx").path
            defer { try? FileManager.default.removeItem(atPath: tmpPath) }
            try SecureVaultCore.exportKdbx(path: tmpPath, itemsJson: itemsJson, password: password)
            return try Data(contentsOf: URL(fileURLWithPath: tmpPath))
        }.value
    }

    // MARK: - Import (Encrypted/Plain JSON, KDBX, CSV)

    func checkIfFileNeedsPassword(url: URL, kind: ImportSourceKind) -> Bool {
        if kind == .kdbx { return true }
        let ext = url.pathExtension.lowercased()
        if ext == "kdbx" { return true }
        guard let text = readSecurityScopedText(url: url),
              let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return (obj["isEncrypted"] as? Bool) == true
    }

    private func readSecurityScopedText(url: URL) -> String? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try? SecureVaultCore.readExportFile(path: url.path)
    }

    func parseImportFile(url: URL, kind: ImportSourceKind, password: String?) async throws -> ParsedImportResult {
        guard !isBusy else { throw RustCoreError.message("Busy") }
        isBusy = true
        defer { isBusy = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let filePath = url.path
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        return try await Task.detached(priority: .userInitiated) {
            // 1. KeePass (.kdbx)
            if kind == .kdbx || ext == "kdbx" {
                let pwd = password ?? ""
                let jsonOut = try SecureVaultCore.importKdbx(path: filePath, password: pwd)
                guard let data = jsonOut.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw RustCoreError.message(t("文件解析失败"))
                }
                let rawItems = (obj["items"] as? [[String: Any]]) ?? []
                let parsedItems = rawItems.map { raw -> VaultItem in
                    var item = VaultItem.fromJSON(raw)
                    // Extract otpauth:// from custom fields if present
                    if item.otpSecret.isEmpty,
                       let custom = raw["custom"] as? [String: Any],
                       let otpUri = custom["otp"] as? String,
                       let parsedOtp = try? SecureVaultCore.parseOtpauthUri(otpUri) {
                        item.otpSecret = parsedOtp.secret
                    }
                    return item
                }
                let folderNames = (obj["folders"] as? [String]) ?? []
                let parsedFolders = folderNames.compactMap { name -> VaultFolderRecord? in
                    let norm = VaultHelpers.normalizeFolderName(name)
                    return norm == VaultHelpers.defaultFolderKey ? nil : VaultFolderRecord(id: UUID().uuidString, name: norm, icon: "folder")
                }
                return ParsedImportResult(badge: "KeePass (.kdbx)", fileName: fileName, items: parsedItems, folders: parsedFolders, standaloneTotps: [])
            }

            // 2. Read text content for JSON or CSV
            let content = try SecureVaultCore.readExportFile(path: filePath)

            // 3. Try JSON
            if let data = content.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if (root["isEncrypted"] as? Bool) == true {
                    let pwd = password ?? ""
                    let salt = (root["salt"] as? String) ?? ""
                    let encPayload = (root["encryptedPayload"] as? String) ?? ""
                    let preferredKdf = (root["kdf"] as? String) ?? "argon2id"
                    let fallbackKdf = preferredKdf == "argon2id" ? "pbkdf2" : "argon2id"

                    var plainStr: String? = nil
                    for kdf in [preferredKdf, fallbackKdf] {
                        if let key = try? SecureVaultCore.deriveMasterKey(password: pwd, saltB64: salt, kdf: kdf),
                           let dec = try? SecureVaultCore.decryptVault(ciphertextB64: encPayload, keyB64: key) {
                            plainStr = dec
                            break
                        }
                    }
                    guard let plain = plainStr else {
                        throw RustCoreError.message(t("解密失败，请检查文件密码"))
                    }
                    if let expectedChecksum = root["checksum"] as? String, !expectedChecksum.isEmpty {
                        let actual = try SecureVaultCore.computeSha256(plain)
                        if actual.lowercased() != expectedChecksum.lowercased() {
                            throw RustCoreError.message(t("解密失败，请检查文件密码"))
                        }
                    }
                    guard let pData = plain.data(using: .utf8),
                          let pRoot = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                        throw RustCoreError.message(t("文件解析失败"))
                    }
                    return Self.parsePlainJsonObject(pRoot, badge: t("锁匣加密备份"), fileName: fileName)
                } else {
                    return Self.parsePlainJsonObject(root, badge: "JSON", fileName: fileName)
                }
            }

            // 4. Parse CSV (Chrome / Edge / Safari / Firefox / Bitwarden)
            let rows = VaultHelpers.parseCSV(content)
            guard rows.count >= 2 else {
                throw RustCoreError.message(t("文件解析失败"))
            }
            let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            func idxOf(_ candidates: [String]) -> Int? {
                for c in candidates {
                    if let i = header.firstIndex(of: c) { return i }
                }
                return nil
            }
            let titleIdx = idxOf(["name", "title", "名称", "标题"])
            let urlIdx = idxOf(["url", "website", "uri", "login_uri", "网址"])
            let userIdx = idxOf(["username", "login_username", "user", "账号", "用户名"])
            let passIdx = idxOf(["password", "login_password", "密码"])
            let noteIdx = idxOf(["note", "notes", "备注"])
            let folderIdx = idxOf(["folder", "group", "分组", "文件夹"])

            var parsedItems: [VaultItem] = []
            for row in rows.dropFirst() {
                let get: (Int?) -> String = { i in
                    guard let i, i < row.count else { return "" }
                    return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let urlVal = get(urlIdx)
                let userVal = get(userIdx)
                let passVal = get(passIdx)
                var titleVal = get(titleIdx)
                if titleVal.isEmpty {
                    titleVal = URL(string: urlVal)?.host ?? (urlVal.isEmpty ? userVal : urlVal)
                }
                guard !titleVal.isEmpty || !passVal.isEmpty else { continue }
                let folderVal = VaultHelpers.normalizeFolderName(get(folderIdx))
                parsedItems.append(VaultItem(
                    id: UUID().uuidString,
                    type: .login,
                    title: titleVal.isEmpty ? "Imported" : titleVal,
                    folder: folderVal,
                    username: userVal,
                    password: passVal,
                    url: urlVal,
                    notes: get(noteIdx),
                    updatedAt: VaultHelpers.currentUpdatedAtString(),
                    strength: VaultHelpers.computePasswordStrength(passVal)
                ))
            }
            return ParsedImportResult(badge: "CSV", fileName: fileName, items: parsedItems, folders: [], standaloneTotps: [])
        }.value
    }

    nonisolated private static func parsePlainJsonObject(_ root: [String: Any], badge: String, fileName: String) -> ParsedImportResult {
        let rawList = (root["vaultItems"] as? [[String: Any]])
            ?? (root["items"] as? [[String: Any]])
            ?? []

        let parsedItems: [VaultItem] = rawList.map { obj in
            // Support Bitwarden JSON format as well as SecureVault desktop format
            if let login = obj["login"] as? [String: Any] {
                let title = (obj["name"] as? String) ?? ""
                let user = (login["username"] as? String) ?? ""
                let pass = (login["password"] as? String) ?? ""
                let uris = (login["uris"] as? [[String: Any]]) ?? []
                let url = (uris.first?["uri"] as? String) ?? ""
                let totp = (login["totp"] as? String) ?? ""
                let notes = (obj["notes"] as? String) ?? ""
                return VaultItem(
                    id: UUID().uuidString,
                    type: .login,
                    title: title,
                    folder: VaultHelpers.defaultFolderKey,
                    username: user,
                    password: pass,
                    url: url,
                    notes: notes,
                    otpSecret: totp,
                    updatedAt: VaultHelpers.currentUpdatedAtString(),
                    strength: VaultHelpers.computePasswordStrength(pass)
                )
            }
            return VaultItem.fromJSON(obj)
        }

        var parsedFolders: [VaultFolderRecord] = []
        if let rawFolders = root["folders"] as? [Any] {
            for f in rawFolders {
                if let s = f as? String {
                    let norm = VaultHelpers.normalizeFolderName(s)
                    if norm != VaultHelpers.defaultFolderKey {
                        parsedFolders.append(VaultFolderRecord(id: UUID().uuidString, name: norm, icon: "folder"))
                    }
                } else if let d = f as? [String: Any] {
                    let norm = VaultHelpers.normalizeFolderName(d["name"] as? String)
                    if norm != VaultHelpers.defaultFolderKey {
                        let fid = (d["id"] as? String) ?? UUID().uuidString
                        let icon = (d["icon"] as? String) ?? "folder"
                        parsedFolders.append(VaultFolderRecord(id: fid, name: norm, icon: icon))
                    }
                }
            }
        }

        var parsedTotps: [StandaloneTotp] = []
        if let rawTotps = root["standaloneTotps"] as? [[String: Any]] {
            parsedTotps = rawTotps.compactMap { d in
                let sec = (d["secret"] as? String) ?? ""
                guard !sec.isEmpty else { return nil }
                return StandaloneTotp(
                    id: (d["id"] as? String) ?? UUID().uuidString,
                    issuer: (d["issuer"] as? String) ?? "",
                    account: (d["account"] as? String) ?? "",
                    secret: sec
                )
            }
        }

        return ParsedImportResult(
            badge: badge,
            fileName: fileName,
            items: parsedItems,
            folders: parsedFolders,
            standaloneTotps: parsedTotps
        )
    }

    func executeImport(parsed: ParsedImportResult, strategy: ImportStrategy, newMasterPassword: String? = nil) async -> Bool {
        guard !isBusy else { return false }
        // If importing during onboarding (no local vault yet), initialize vault with newMasterPassword
        if !hasVault {
            let pwd = newMasterPassword ?? ""
            guard pwd.count >= 8 else {
                showToast(t("主密码至少 8 位"), warn: true)
                return false
            }
            isBusy = true
            let derivedResult = await Task.detached(priority: .userInitiated) { () -> Result<(salt: String, key: String), Error> in
                Result {
                    let salt = try SecureVaultCore.generateSalt()
                    let key = try SecureVaultCore.deriveMasterKey(password: pwd, saltB64: salt, kdf: "argon2id")
                    return (salt: salt, key: key)
                }
            }.value
            isBusy = false

            switch derivedResult {
            case .success(let derived):
                saltB64 = derived.salt
                masterKeyB64 = derived.key
            case .failure:
                showToast(t("创建失败"), warn: true)
                return false
            }
        }

        let existingKeys = Set(activeItems.map { "\($0.title)|\($0.username.isEmpty ? $0.cardNumber : $0.username)" })
        let incoming = parsed.items.map { item -> VaultItem in
            var copy = item
            copy.id = UUID().uuidString
            copy.folder = VaultHelpers.normalizeFolderName(item.folder)
            if copy.updatedAt.isEmpty { copy.updatedAt = VaultHelpers.currentUpdatedAtString() }
            copy.strength = VaultHelpers.computePasswordStrength(copy.password)
            return copy
        }

        var addedCount = 0
        switch strategy {
        case .overwrite:
            items = incoming
            folders = []
            standaloneTotps = parsed.standaloneTotps
            addedCount = incoming.count
        case .skip:
            let unique = incoming.filter { !existingKeys.contains("\($0.title)|\($0.username.isEmpty ? $0.cardNumber : $0.username)") }
            items.insert(contentsOf: unique, at: 0)
            addedCount = unique.count
            for tk in parsed.standaloneTotps where !standaloneTotps.contains(where: { $0.secret == tk.secret }) {
                standaloneTotps.append(tk)
            }
        case .merge:
            items.insert(contentsOf: incoming, at: 0)
            addedCount = incoming.count
            for tk in parsed.standaloneTotps where !standaloneTotps.contains(where: { $0.secret == tk.secret }) {
                standaloneTotps.append(tk)
            }
        }

        // Ensure all referenced custom folders exist
        var seenFolders = Set(folders.map { $0.name })
        for f in parsed.folders where f.name != VaultHelpers.defaultFolderKey && !seenFolders.contains(f.name) {
            seenFolders.insert(f.name)
            folders.append(f)
        }
        for item in items where item.deletedAt == nil {
            let norm = VaultHelpers.normalizeFolderName(item.folder)
            if norm != VaultHelpers.defaultFolderKey && !seenFolders.contains(norm) {
                seenFolders.insert(norm)
                folders.append(VaultFolderRecord(id: UUID().uuidString, name: norm, icon: "folder"))
            }
        }

        persistVault(markDirty: true)
        saveMeta()

        if screen == .onboarding {
            screen = .home
            activeTab = .vault
        }

        let msg: String
        if strategy == .overwrite {
            msg = AppI18n.isChinese ? "已覆盖导入 \(addedCount) 条凭证" : "Overwrote vault with \(addedCount) items"
        } else {
            msg = AppI18n.isChinese ? "已成功导入 \(addedCount) 条凭证" : "Imported \(addedCount) items"
        }
        showToast(msg)
        return true
    }
}
