package app.suoxia.vault.bridge

import org.json.JSONObject

data class WebDavStat(
    val exists: Boolean,
    val size: Long,
    val lastModified: String?,
    val etag: String?
)

data class WebDavDownload(
    val content: String,
    val stat: WebDavStat
)

data class WebDavConfigRecord(
    val url: String,
    val username: String,
    val passwordEnc: String
)

object RustCore {
    init {
        System.loadLibrary("suoxia_jni")
    }

    private external fun svInvoke(cmd: String, argsJson: String): String

    fun invoke(cmd: String, args: Map<String, Any?> = emptyMap()): Any? {
        val jsonArgs = JSONObject(args).toString()
        val raw = svInvoke(cmd, jsonArgs)
        val env = JSONObject(raw)
        if (!env.optBoolean("ok", false)) {
            throw IllegalStateException(env.optString("error", "ERR_RUST_CORE"))
        }
        val data = env.opt("data")
        return if (data == null || data == JSONObject.NULL) null else data
    }

    fun generateSalt(): String = invoke("generate_salt") as String

    fun deriveMasterKey(password: String, saltB64: String, kdf: String = "argon2id"): String =
        invoke("derive_master_key", mapOf("password" to password, "saltB64" to saltB64, "kdf" to kdf)) as String

    fun encryptVault(plaintext: String, keyB64: String): String =
        invoke("encrypt_vault", mapOf("plaintext" to plaintext, "keyB64" to keyB64)) as String

    fun decryptVault(ciphertextB64: String, keyB64: String): String =
        invoke("decrypt_vault", mapOf("ciphertextB64" to ciphertextB64, "keyB64" to keyB64)) as String

    fun computeSha256(content: String): String =
        invoke("compute_sha256", mapOf("content" to content)) as String

    fun saveVaultFile(dataDir: String, ciphertextB64: String) {
        invoke("save_vault_file", mapOf("dataDir" to dataDir, "ciphertextB64" to ciphertextB64))
    }

    fun loadVaultFile(dataDir: String): String =
        invoke("load_vault_file", mapOf("dataDir" to dataDir)) as String

    fun writeExportFile(path: String, content: String) {
        invoke("write_export_file", mapOf("path" to path, "content" to content))
    }

    fun readExportFile(path: String): String =
        invoke("read_export_file", mapOf("path" to path)) as String

    fun exportKdbx(path: String, itemsJson: String, password: String) {
        invoke("export_kdbx", mapOf("path" to path, "itemsJson" to itemsJson, "password" to password))
    }

    fun importKdbx(path: String, password: String): String =
        invoke("import_kdbx", mapOf("path" to path, "password" to password)) as String

    fun generateTotp(secret: String): Pair<String, Int> {
        val obj = invoke("generate_totp", mapOf("secret" to secret)) as JSONObject
        val remaining = obj.optInt("remaining", obj.optInt("remainingSeconds", 30))
        return obj.getString("code") to remaining
    }

    fun parseOtpauthUri(uri: String): Triple<String, String, String> {
        val obj = invoke("parse_otpauth_uri", mapOf("uri" to uri)) as JSONObject
        return Triple(obj.getString("issuer"), obj.getString("account"), obj.getString("secret"))
    }

    fun generatePassword(
        length: Int,
        upper: Boolean,
        lower: Boolean,
        numbers: Boolean,
        symbols: Boolean,
        excludeAmbiguous: Boolean
    ): String = invoke(
        "generate_password",
        mapOf(
            "length" to length,
            "upper" to upper,
            "lower" to lower,
            "numbers" to numbers,
            "symbols" to symbols,
            "excludeAmbiguous" to excludeAmbiguous
        )
    ) as String

    fun generateBip39(words: Int, sep: String, capitalize: Boolean): String =
        invoke("generate_bip39", mapOf("words" to words, "sep" to sep, "capitalize" to capitalize)) as String

    fun webdavTest(url: String, username: String, password: String): String =
        invoke("webdav_test", mapOf("url" to url, "username" to username, "password" to password)) as String

    fun webdavStat(url: String, username: String, password: String): WebDavStat {
        val obj = invoke("webdav_stat", mapOf("url" to url, "username" to username, "password" to password)) as JSONObject
        return parseStat(obj)
    }

    fun webdavUpload(dataDir: String, url: String, username: String, password: String): WebDavStat {
        val obj = invoke(
            "webdav_upload",
            mapOf("dataDir" to dataDir, "url" to url, "username" to username, "password" to password)
        ) as JSONObject
        return parseStat(obj)
    }

    fun webdavDownload(url: String, username: String, password: String): WebDavDownload {
        val obj = invoke(
            "webdav_download",
            mapOf("url" to url, "username" to username, "password" to password)
        ) as JSONObject
        return WebDavDownload(
            content = obj.getString("content"),
            stat = parseStat(obj.getJSONObject("stat"))
        )
    }

    fun getWebdavConfig(dataDir: String): WebDavConfigRecord? {
        val obj = invoke("get_webdav_config", mapOf("dataDir" to dataDir)) as? JSONObject ?: return null
        val url = obj.optString("url", "")
        if (url.isBlank()) return null
        return WebDavConfigRecord(
            url = url,
            username = obj.optString("username", ""),
            passwordEnc = obj.optString("passwordEnc", "")
        )
    }

    fun saveWebdavConfig(dataDir: String, url: String, username: String, passwordEnc: String) {
        invoke(
            "save_webdav_config",
            mapOf("dataDir" to dataDir, "url" to url, "username" to username, "passwordEnc" to passwordEnc)
        )
    }

    fun clearWebdavConfig(dataDir: String) {
        invoke("clear_webdav_config", mapOf("dataDir" to dataDir))
    }

    private fun parseStat(obj: JSONObject): WebDavStat {
        val lm = if (obj.isNull("last_modified")) null else obj.optString("last_modified", "").ifEmpty { null }
        val etag = if (obj.isNull("etag")) null else obj.optString("etag", "").ifEmpty { null }
        return WebDavStat(
            exists = obj.optBoolean("exists", false),
            size = obj.optLong("size", 0L),
            lastModified = lm,
            etag = etag
        )
    }
}
