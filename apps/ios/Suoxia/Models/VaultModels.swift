import Foundation

enum ItemType: String, Codable, CaseIterable, Hashable {
    case login, card, note, identity

    var label: String {
        switch self {
        case .login: return t("登录")
        case .card: return t("卡券")
        case .note: return t("备忘")
        case .identity: return t("密保")
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .login: return t("例如：GitHub、微信")
        case .card: return t("例如：招商银行信用卡")
        case .note: return t("例如：服务器恢复秘钥")
        case .identity: return t("例如：个人常用身份")
        }
    }
}

struct PasswordHistoryEntry: Codable, Hashable {
    var password: String
    var changedAt: String
}

struct VaultFolderRecord: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String = "folder"
}

struct VaultItem: Identifiable, Hashable {
    var id: String
    var type: ItemType
    var title: String
    var folder: String = "默认"
    var username: String = ""
    var password: String = ""
    var url: String = ""
    var cardName: String = ""
    var cardNumber: String = ""
    var cardExpiry: String = ""
    var cardCvv: String = ""
    var identityName: String = ""
    var identityEmail: String = ""
    var identityPhone: String = ""
    var identityAddress: String = ""
    var notes: String = ""
    var otpSecret: String = ""
    var passwordHistory: [PasswordHistoryEntry] = []
    var deletedAt: String? = nil
    var updatedAt: String = ""
    var strength: String = "weak"
    var isFavorite: Bool = false

    /// Preserves unknown desktop JSON keys (customFields, expiresAt, lastUsedAt, ignoreSecurityWarning, etc.)
    var rawJSON: [String: Any] = [:]

    static func == (lhs: VaultItem, rhs: VaultItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.title == rhs.title &&
        lhs.folder == rhs.folder &&
        lhs.username == rhs.username &&
        lhs.password == rhs.password &&
        lhs.url == rhs.url &&
        lhs.cardName == rhs.cardName &&
        lhs.cardNumber == rhs.cardNumber &&
        lhs.cardExpiry == rhs.cardExpiry &&
        lhs.cardCvv == rhs.cardCvv &&
        lhs.identityName == rhs.identityName &&
        lhs.identityEmail == rhs.identityEmail &&
        lhs.identityPhone == rhs.identityPhone &&
        lhs.identityAddress == rhs.identityAddress &&
        lhs.notes == rhs.notes &&
        lhs.otpSecret == rhs.otpSecret &&
        lhs.passwordHistory == rhs.passwordHistory &&
        lhs.deletedAt == rhs.deletedAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.strength == rhs.strength &&
        lhs.isFavorite == rhs.isFavorite
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(updatedAt)
        hasher.combine(title)
        hasher.combine(isFavorite)
        hasher.combine(deletedAt)
    }

    var subtitleText: String {
        switch type {
        case .login:
            if !username.isEmpty { return username }
            if !url.isEmpty { return url }
            return VaultHelpers.displayFolderName(folder)
        case .card:
            if !cardNumber.isEmpty {
                let digits = cardNumber.filter { !$0.isWhitespace }
                if digits.count >= 4 {
                    return "•••• " + String(digits.suffix(4))
                }
                return cardNumber
            }
            return cardName.isEmpty ? VaultHelpers.displayFolderName(folder) : cardName
        case .note:
            let firstLine = notes.split(separator: "\n").first.map(String.init) ?? ""
            return firstLine.isEmpty ? t("加密备忘") : firstLine
        case .identity:
            if !identityName.isEmpty { return identityName }
            if !identityEmail.isEmpty { return identityEmail }
            if !identityPhone.isEmpty { return identityPhone }
            return VaultHelpers.displayFolderName(folder)
        }
    }

    var quickCopyValue: String {
        switch type {
        case .login: return password.isEmpty ? username : password
        case .card: return cardNumber.isEmpty ? cardName : cardNumber
        case .note: return notes
        case .identity: return !identityPhone.isEmpty ? identityPhone : (!identityEmail.isEmpty ? identityEmail : identityName)
        }
    }

    static func fromJSON(_ dict: [String: Any]) -> VaultItem {
        let str: (String) -> String = { key in
            (dict[key] as? String) ?? ""
        }
        let rawType = str("type")
        let itemType = ItemType(rawValue: rawType) ?? .login
        let id = str("id").isEmpty ? UUID().uuidString : str("id")
        let folder = VaultHelpers.normalizeFolderName(dict["folder"] as? String)
        let password = str("password")
        let strengthStr = str("strength")
        let strength = strengthStr.isEmpty ? VaultHelpers.computePasswordStrength(password) : strengthStr
        let isFav = (dict["isFavorite"] as? Bool) ?? (dict["favorite"] as? Bool) ?? false
        let delRaw = dict["deletedAt"] as? String
        let deletedAt = (delRaw?.isEmpty == false) ? delRaw : nil

        var history: [PasswordHistoryEntry] = []
        if let arr = dict["passwordHistory"] as? [[String: Any]] {
            for h in arr {
                let pw = (h["password"] as? String) ?? ""
                let ts = (h["changedAt"] as? String) ?? ""
                if !pw.isEmpty {
                    history.append(PasswordHistoryEntry(password: pw, changedAt: ts))
                }
            }
        }

        return VaultItem(
            id: id,
            type: itemType,
            title: str("title"),
            folder: folder,
            username: str("username"),
            password: password,
            url: str("url"),
            cardName: str("cardName"),
            cardNumber: str("cardNumber"),
            cardExpiry: str("cardExpiry"),
            cardCvv: str("cardCvv"),
            identityName: str("identityName"),
            identityEmail: str("identityEmail"),
            identityPhone: str("identityPhone"),
            identityAddress: str("identityAddress"),
            notes: str("notes"),
            otpSecret: str("otpSecret"),
            passwordHistory: history,
            deletedAt: deletedAt,
            updatedAt: str("updatedAt"),
            strength: strength,
            isFavorite: isFav,
            rawJSON: dict
        )
    }

    func toJSON() -> [String: Any] {
        var dict = rawJSON
        dict["id"] = id
        dict["type"] = type.rawValue
        dict["title"] = title
        dict["folder"] = VaultHelpers.normalizeFolderName(folder)
        dict["username"] = username
        dict["password"] = password
        dict["url"] = url
        dict["cardName"] = cardName
        dict["cardNumber"] = cardNumber
        dict["cardExpiry"] = cardExpiry
        dict["cardCvv"] = cardCvv
        dict["identityName"] = identityName
        dict["identityEmail"] = identityEmail
        dict["identityPhone"] = identityPhone
        dict["identityAddress"] = identityAddress
        dict["notes"] = notes
        dict["otpSecret"] = otpSecret
        dict["updatedAt"] = updatedAt.isEmpty ? VaultHelpers.currentUpdatedAtString() : updatedAt
        dict["strength"] = VaultHelpers.computePasswordStrength(password)
        dict["isFavorite"] = isFavorite

        if !passwordHistory.isEmpty {
            dict["passwordHistory"] = passwordHistory.map { ["password": $0.password, "changedAt": $0.changedAt] }
        } else {
            dict.removeValue(forKey: "passwordHistory")
        }

        if let del = deletedAt, !del.isEmpty {
            dict["deletedAt"] = del
        } else {
            dict.removeValue(forKey: "deletedAt")
        }

        return dict
    }
}

struct StandaloneTotp: Identifiable, Codable, Hashable {
    var id: String
    var issuer: String
    var account: String
    var secret: String
}

struct WebDavSyncSnapshot: Codable, Equatable {
    var etag: String?
    var lastModified: String?
    var size: UInt64
}

enum WebDavPreset: String, CaseIterable, Identifiable {
    case generic, nextcloud, nas, jianguoyun
    var id: String { rawValue }

    var label: String {
        switch self {
        case .generic: return t("通用 WebDAV")
        case .nextcloud: return "Nextcloud"
        case .nas: return "NAS"
        case .jianguoyun: return t("坚果云")
        }
    }

    var placeholder: String {
        switch self {
        case .generic: return "https://your-server.com/dav/SecureVault/"
        case .nextcloud: return "https://cloud.example.com/remote.php/dav/files/username/SecureVault/"
        case .nas: return "https://nas.example.com:5006/SecureVault/"
        case .jianguoyun: return "https://dav.jianguoyun.com/dav/SecureVault/"
        }
    }

    var tip: String {
        switch self {
        case .generic: return t("适用 Alist / InfiniCLOUD 等任意标准 HTTPS WebDAV 服务")
        case .nextcloud: return t("路径位于「文件 → 设置」，需在「安全」中创建应用密码")
        case .nas: return t("适用群晖 / 飞牛 / 威联通等，需开启 HTTPS WebDAV 端口")
        case .jianguoyun: return t("需在网页版「安全选项 → 第三方应用」生成专用密码")
        }
    }
}

enum ImportSourceKind: String, CaseIterable, Identifiable {
    case suoxiaJson
    case kdbx
    case browserCsvJson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suoxiaJson: return t("锁匣加密备份 (.json)")
        case .kdbx: return t("KeePass 数据库 (.kdbx)")
        case .browserCsvJson: return t("浏览器 / 第三方密码 (.csv / .json)")
        }
    }

    var subtitle: String {
        switch self {
        case .suoxiaJson: return t("从电脑端或另一台手机导出的加密备份")
        case .kdbx: return t("支持文件夹分组与 2FA 动态密钥")
        case .browserCsvJson: return t("自动识别 Chrome、Edge、Safari、Firefox、Bitwarden 等")
        }
    }

    var badge: String {
        switch self {
        case .suoxiaJson: return t("锁匣加密备份")
        case .kdbx: return "KeePass (.kdbx)"
        case .browserCsvJson: return "CSV / JSON"
        }
    }
}

enum ImportStrategy: String, CaseIterable, Identifiable {
    case skip
    case merge
    case overwrite

    var id: String { rawValue }
}

struct ParsedImportResult {
    var badge: String
    var fileName: String
    var items: [VaultItem]
    var folders: [VaultFolderRecord]
    var standaloneTotps: [StandaloneTotp]
}

enum AppScreen: Equatable {
    case onboarding, unlock, home
}

enum HomeTab: String, CaseIterable {
    case vault
    case totp
    case generator
    case settings

    var label: String {
        switch self {
        case .vault: return t("保险箱")
        case .totp: return t("验证器")
        case .generator: return t("生成器")
        case .settings: return t("首选项")
        }
    }
}

enum VaultCategory: String, CaseIterable, Identifiable {
    case all, fav, login, card, note, identity
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return t("全部")
        case .fav: return t("星标")
        case .login: return t("登录")
        case .card: return t("卡券")
        case .note: return t("备忘")
        case .identity: return t("密保")
        }
    }
}

enum AutoLockOption: String, CaseIterable, Identifiable {
    case immediate = "切后台立即锁定"
    case oneMin = "1 分钟"
    case fiveMin = "5 分钟"
    case fifteenMin = "15 分钟"

    var id: String { rawValue }

    var label: String { t(rawValue) }

    var seconds: TimeInterval {
        switch self {
        case .immediate: return 0
        case .oneMin: return 60
        case .fiveMin: return 300
        case .fifteenMin: return 900
        }
    }
}

enum VaultHelpers {
    static let defaultFolderKey = "默认"
    static let allFoldersKey = "全部"

    static func normalizeFolderName(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "未分组" || trimmed == "未分类" || trimmed == "默认" || trimmed.lowercased() == "default" {
            return defaultFolderKey
        }
        return trimmed
    }

    static func displayFolderName(_ raw: String?) -> String {
        let norm = normalizeFolderName(raw)
        return norm == defaultFolderKey ? t("默认") : norm
    }

    static func computePasswordStrength(_ password: String) -> String {
        let len = password.count
        var classes = 0
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { classes += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { classes += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { classes += 1 }
        if password.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { classes += 1 }
        if len >= 14 && classes >= 3 { return "strong" }
        if len >= 10 { return "medium" }
        return "weak"
    }

    static func currentUpdatedAtString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: Date())
    }

    static func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    static func currentHHMM() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: Date())
    }

    static func formatTotpCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<idx]) \(code[idx...])"
    }

    /// RFC 4180-compatible CSV parser for browser password exports (Chrome, Edge, Safari, Firefox, Bitwarden)
    static func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if c == "\n" {
                    currentRow.append(currentField)
                    if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(c)
                }
            }
            i += 1
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                rows.append(currentRow)
            }
        }
        return rows
    }
}
