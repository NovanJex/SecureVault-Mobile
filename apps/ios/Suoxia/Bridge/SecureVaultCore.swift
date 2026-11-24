import Foundation
import SecureVaultCoreFFI

enum RustCoreError: LocalizedError, Sendable {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let msg): return msg
        }
    }
}

struct WebDavStat: Codable, Equatable, Sendable {
    let exists: Bool
    let size: UInt64
    let lastModified: String?
    let etag: String?

    enum CodingKeys: String, CodingKey {
        case exists
        case size
        case lastModified = "last_modified"
        case etag
    }
}

struct WebDavDownload: Sendable {
    let content: String
    let stat: WebDavStat
}

struct WebDavSavedConfig: Sendable {
    let url: String
    let username: String
    let passwordEnc: String
}

final class SecureVaultCore {
    static func invoke(_ cmd: String, args: [String: Any] = [:]) throws -> Any? {
        let jsonData = try JSONSerialization.data(withJSONObject: args)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let rawPtr = cmd.withCString { cCmd in
            jsonStr.withCString { cArgs in
                sv_invoke(cCmd, cArgs)
            }
        }
        guard let ptr = rawPtr else {
            throw RustCoreError.message("ERR_NULL_PTR")
        }
        defer { sv_free_string(ptr) }
        let outStr = String(cString: ptr)
        guard let outData = outStr.data(using: .utf8),
              let envelope = try JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
            throw RustCoreError.message("ERR_JSON_PARSE")
        }
        if let ok = envelope["ok"] as? Bool, !ok {
            throw RustCoreError.message((envelope["error"] as? String) ?? "ERR_RUST_CORE")
        }
        return envelope["data"]
    }

    // MARK: - Crypto & Vault Storage

    static func generateSalt() throws -> String {
        (try invoke("generate_salt") as? String) ?? ""
    }

    static func deriveMasterKey(password: String, saltB64: String, kdf: String = "argon2id") throws -> String {
        (try invoke("derive_master_key", args: ["password": password, "saltB64": saltB64, "kdf": kdf]) as? String) ?? ""
    }

    static func encryptVault(plaintext: String, keyB64: String) throws -> String {
        (try invoke("encrypt_vault", args: ["plaintext": plaintext, "keyB64": keyB64]) as? String) ?? ""
    }

    static func decryptVault(ciphertextB64: String, keyB64: String) throws -> String {
        (try invoke("decrypt_vault", args: ["ciphertextB64": ciphertextB64, "keyB64": keyB64]) as? String) ?? ""
    }

    static func computeSha256(_ content: String) throws -> String {
        (try invoke("compute_sha256", args: ["content": content]) as? String) ?? ""
    }

    static func saveVaultFile(dataDir: String, ciphertextB64: String) throws {
        _ = try invoke("save_vault_file", args: ["dataDir": dataDir, "ciphertextB64": ciphertextB64])
    }

    static func loadVaultFile(dataDir: String) throws -> String {
        (try invoke("load_vault_file", args: ["dataDir": dataDir]) as? String) ?? ""
    }

    // MARK: - File Import / Export & KDBX

    static func writeExportFile(path: String, content: String) throws {
        _ = try invoke("write_export_file", args: ["path": path, "content": content])
    }

    static func readExportFile(path: String) throws -> String {
        (try invoke("read_export_file", args: ["path": path]) as? String) ?? ""
    }

    static func exportKdbx(path: String, itemsJson: String, password: String) throws {
        _ = try invoke("export_kdbx", args: ["path": path, "itemsJson": itemsJson, "password": password])
    }

    static func importKdbx(path: String, password: String) throws -> String {
        (try invoke("import_kdbx", args: ["path": path, "password": password]) as? String) ?? ""
    }

    // MARK: - TOTP & Generators

    static func generateTotp(secret: String) throws -> (code: String, remaining: Int) {
        guard let dict = try invoke("generate_totp", args: ["secret": secret]) as? [String: Any] else {
            return ("------", 30)
        }
        let code = (dict["code"] as? String) ?? "------"
        let rem = (dict["remaining"] as? Int)
            ?? (dict["remaining"] as? NSNumber)?.intValue
            ?? (dict["remainingSeconds"] as? Int)
            ?? 30
        return (code, rem)
    }

    static func parseOtpauthUri(_ uri: String) throws -> (issuer: String, account: String, secret: String) {
        guard let dict = try invoke("parse_otpauth_uri", args: ["uri": uri]) as? [String: Any] else {
            throw RustCoreError.message("ERR_OTP_PARSE")
        }
        return (
            (dict["issuer"] as? String) ?? "",
            (dict["account"] as? String) ?? "",
            (dict["secret"] as? String) ?? ""
        )
    }

    static func generatePassword(length: Int, upper: Bool, lower: Bool, numbers: Bool, symbols: Bool, excludeAmbiguous: Bool) throws -> String {
        (try invoke("generate_password", args: [
            "length": length, "upper": upper, "lower": lower,
            "numbers": numbers, "symbols": symbols, "excludeAmbiguous": excludeAmbiguous
        ]) as? String) ?? ""
    }

    static func generateBip39(words: Int, sep: String, capitalize: Bool) throws -> String {
        (try invoke("generate_bip39", args: ["words": words, "sep": sep, "capitalize": capitalize]) as? String) ?? ""
    }

    // MARK: - WebDAV Sync

    static func normalizeWebDavUrl(_ raw: String) -> String {
        let u = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return "" }
        if u.hasSuffix("/") { return u + "vault.enc" }
        let afterScheme: String
        if let range = u.range(of: "://") {
            afterScheme = String(u[range.upperBound...])
        } else {
            afterScheme = u
        }
        guard let slashIdx = afterScheme.lastIndex(of: "/") else {
            return u + "/vault.enc"
        }
        let lastSeg = String(afterScheme[afterScheme.index(after: slashIdx)...])
        if lastSeg.isEmpty { return u + "vault.enc" }
        return lastSeg.contains(".") ? u : u + "/vault.enc"
    }

    private static func parseWebDavStat(_ obj: Any?) -> WebDavStat {
        guard let dict = obj as? [String: Any] else {
            return WebDavStat(exists: false, size: 0, lastModified: nil, etag: nil)
        }
        let exists = (dict["exists"] as? Bool) ?? false
        let size = (dict["size"] as? UInt64) ?? (dict["size"] as? NSNumber)?.uint64Value ?? 0
        let lastModified = dict["last_modified"] as? String
        let etag = dict["etag"] as? String
        return WebDavStat(exists: exists, size: size, lastModified: lastModified, etag: etag)
    }

    static func webdavTest(url: String, username: String, password: String) throws -> String {
        (try invoke("webdav_test", args: ["url": url, "username": username, "password": password]) as? String) ?? ""
    }

    static func webdavStat(url: String, username: String, password: String) throws -> WebDavStat {
        let res = try invoke("webdav_stat", args: ["url": url, "username": username, "password": password])
        return parseWebDavStat(res)
    }

    static func webdavUpload(dataDir: String, url: String, username: String, password: String) throws -> WebDavStat {
        let res = try invoke("webdav_upload", args: ["dataDir": dataDir, "url": url, "username": username, "password": password])
        return parseWebDavStat(res)
    }

    static func webdavDownload(url: String, username: String, password: String) throws -> WebDavDownload {
        guard let dict = try invoke("webdav_download", args: ["url": url, "username": username, "password": password]) as? [String: Any] else {
            throw RustCoreError.message("ERR_WEBDAV_DOWNLOAD")
        }
        let content = (dict["content"] as? String) ?? ""
        let stat = parseWebDavStat(dict["stat"])
        return WebDavDownload(content: content, stat: stat)
    }

    static func getWebdavConfig(dataDir: String) throws -> WebDavSavedConfig? {
        guard let dict = try invoke("get_webdav_config", args: ["dataDir": dataDir]) as? [String: Any] else {
            return nil
        }
        guard let url = dict["url"] as? String, !url.isEmpty else { return nil }
        return WebDavSavedConfig(
            url: url,
            username: (dict["username"] as? String) ?? "",
            passwordEnc: (dict["passwordEnc"] as? String) ?? ""
        )
    }

    static func saveWebdavConfig(dataDir: String, url: String, username: String, passwordEnc: String) throws {
        _ = try invoke("save_webdav_config", args: [
            "dataDir": dataDir,
            "url": url,
            "username": username,
            "passwordEnc": passwordEnc
        ])
    }

    static func clearWebdavConfig(dataDir: String) throws {
        _ = try invoke("clear_webdav_config", args: ["dataDir": dataDir])
    }
}
