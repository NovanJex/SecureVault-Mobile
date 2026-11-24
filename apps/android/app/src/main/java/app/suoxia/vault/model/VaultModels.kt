package app.suoxia.vault.model

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

const val DEFAULT_FOLDER = "默认"
const val ALL_FOLDERS = "全部"

enum class ItemType(val key: String, val label: String) {
    LOGIN("login", "登录"),
    CARD("card", "卡券"),
    NOTE("note", "备忘"),
    IDENTITY("identity", "密保");

    companion object {
        fun fromKey(k: String): ItemType = entries.firstOrNull { it.key == k } ?: LOGIN
    }
}

data class PasswordHistoryEntry(
    val password: String,
    val changedAt: String
)

data class FolderRecord(
    val id: String,
    val name: String,
    val icon: String = "folder"
)

data class VaultItem(
    val id: String,
    val type: ItemType,
    val title: String,
    val folder: String = DEFAULT_FOLDER,
    val username: String = "",
    val password: String = "",
    val url: String = "",
    val cardName: String = "",
    val cardNumber: String = "",
    val cardExpiry: String = "",
    val cardCvv: String = "",
    val identityName: String = "",
    val identityEmail: String = "",
    val identityPhone: String = "",
    val identityAddress: String = "",
    val notes: String = "",
    val otpSecret: String = "",
    val passwordHistory: List<PasswordHistoryEntry> = emptyList(),
    val deletedAt: String? = null,
    val updatedAt: String = "",
    val strength: String = "weak",
    val isFavorite: Boolean = false,
    val rawJson: String? = null
)

data class StandaloneTotp(
    val id: String,
    val issuer: String,
    val account: String,
    val secret: String
)

data class WebDavSnapshot(
    val etag: String? = null,
    val lastModified: String? = null,
    val size: Long = 0L
)

enum class ImportSourceType { SUOXIA_JSON, KDBX, BROWSER_CSV_JSON }
enum class ImportStrategy { SKIP_DUPLICATES, MERGE, OVERWRITE }

data class ImportPreviewData(
    val fileName: String,
    val badge: String,
    val items: List<VaultItem>,
    val folders: List<String>,
    val sourcePassword: String? = null
)

enum class AppScreen { ONBOARDING, UNLOCK, HOME }
enum class HomeTab(val label: String) { VAULT("保险箱"), TOTP("验证器"), GENERATOR("生成器"), SETTINGS("首选项") }

fun normalizeFolderName(raw: String?): String {
    val trimmed = raw?.trim() ?: ""
    return when (trimmed) {
        "", "未分组", "未分类", DEFAULT_FOLDER -> DEFAULT_FOLDER
        else -> trimmed
    }
}

fun isDefaultFolder(raw: String?): Boolean = normalizeFolderName(raw) == DEFAULT_FOLDER

fun computePasswordStrength(password: String): String {
    if (password.isEmpty()) return "weak"
    var classes = 0
    if (password.any { it.isLowerCase() }) classes++
    if (password.any { it.isUpperCase() }) classes++
    if (password.any { it.isDigit() }) classes++
    if (password.any { !it.isLetterOrDigit() }) classes++
    return when {
        password.length >= 14 && classes >= 3 -> "strong"
        password.length >= 10 -> "medium"
        else -> "weak"
    }
}

fun nowUpdatedAt(): String {
    return SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).format(Date())
}

fun todayDateString(): String {
    return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
}

fun nowTimeShort(): String {
    return SimpleDateFormat("HH:mm", Locale.US).format(Date())
}

fun normalizeWebDavUrlPreview(raw: String): String {
    val u = raw.trim()
    if (u.isEmpty()) return ""
    if (u.endsWith("/")) return "${u}vault.enc"
    val after = if (u.contains("://")) u.substringAfter("://") else u
    val idx = after.lastIndexOf('/')
    if (idx == -1) return "$u/vault.enc"
    val last = after.substring(idx + 1)
    if (last.isEmpty()) return "${u}vault.enc"
    return if (last.contains('.')) u else "$u/vault.enc"
}

fun isValidWebDavUrl(raw: String): Boolean {
    val u = raw.trim()
    return u.startsWith("https://") || u.startsWith("http://localhost") || u.startsWith("http://127.0.0.1")
}
