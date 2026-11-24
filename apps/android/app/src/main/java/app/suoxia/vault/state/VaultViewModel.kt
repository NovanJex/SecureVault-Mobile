package app.suoxia.vault.state

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.suoxia.vault.bridge.RustCore
import app.suoxia.vault.bridge.WebDavStat
import app.suoxia.vault.i18n.t
import app.suoxia.vault.i18n.tf
import app.suoxia.vault.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class VaultViewModel(application: Application) : AndroidViewModel(application) {
    private val dataDir = application.filesDir.absolutePath
    private val cacheDir = application.cacheDir
    private val metaFile = File(dataDir, "suoxia_meta.json")

    var screen by mutableStateOf(AppScreen.ONBOARDING)
    var activeTab by mutableStateOf(HomeTab.VAULT)
    var items by mutableStateOf<List<VaultItem>>(emptyList())
    var folders by mutableStateOf<List<String>>(emptyList())
    var standaloneTotps by mutableStateOf<List<StandaloneTotp>>(emptyList())
    var genHistory by mutableStateOf<List<String>>(emptyList())

    var activeCat by mutableStateOf("all")
    var activeFolder by mutableStateOf(ALL_FOLDERS)
    var searchQuery by mutableStateOf("")
    var totpSearch by mutableStateOf("")

    var requireUnlock by mutableStateOf(false)
    var bioFaceOn by mutableStateOf(true)
    var bioFingerOn by mutableStateOf(true)
    var gestureOn by mutableStateOf(false)
    var gesturePattern by mutableStateOf("")
    var autoLock by mutableStateOf("5 分钟")
    var privacyMask by mutableStateOf(true)
    var isDark by mutableStateOf(false)

    // WebDAV state
    var webdavConfigured by mutableStateOf(false)
    var webdavUrl by mutableStateOf("")
    var webdavUser by mutableStateOf("")
    var webdavHasSavedPass by mutableStateOf(false)
    var webdavAutoSync by mutableStateOf(true)
    var webdavLastSync by mutableStateOf("")
    var webdavSyncing by mutableStateOf(false)
    var showWebdavConflictSheet by mutableStateOf(false)
    var showRemoteSaltPwdDialog by mutableStateOf(false)

    var toastMsg by mutableStateOf<String?>(null)
    var toastWarn by mutableStateOf(false)

    private var saltB64 = ""
    private var masterKeyB64 = ""
    private var rawRootJson: JSONObject = JSONObject()
    private var folderRecords: MutableList<FolderRecord> = mutableListOf()
    private var localDirty: Boolean = false
    private var webdavSnapshot: WebDavSnapshot? = null
    private var debounceSyncJob: Job? = null
    private var backgroundedAtMs: Long = 0L

    private var pendingRemoteContent: String? = null
    private var pendingRemoteStat: WebDavStat? = null
    private var pendingConflictMode: Boolean = false

    init {
        loadInitialState()
    }

    private fun loadInitialState() {
        if (!metaFile.exists()) {
            screen = AppScreen.ONBOARDING
            return
        }
        try {
            val meta = JSONObject(metaFile.readText())
            if (!meta.optBoolean("hasVault", false)) {
                screen = AppScreen.ONBOARDING
                return
            }
            saltB64 = meta.optString("saltB64", "")
            requireUnlock = meta.optBoolean("requireUnlock", false)
            bioFaceOn = meta.optBoolean("bioFaceOn", true)
            bioFingerOn = meta.optBoolean("bioFingerOn", true)
            gestureOn = meta.optBoolean("gestureOn", false)
            gesturePattern = meta.optString("gesturePattern", "")
            autoLock = meta.optString("autoLock", "5 分钟")
            privacyMask = meta.optBoolean("privacyMask", true)
            isDark = meta.optBoolean("isDark", false)
            webdavAutoSync = meta.optBoolean("webdavAutoSync", true)
            webdavLastSync = meta.optString("webdavLastSync", "")
            localDirty = meta.optBoolean("localDirty", false)
            meta.optJSONObject("webdavSnapshot")?.let { snap ->
                webdavSnapshot = WebDavSnapshot(
                    etag = snap.optString("etag", "").ifEmpty { null },
                    lastModified = snap.optString("lastModified", "").ifEmpty { null },
                    size = snap.optLong("size", 0L)
                )
            }
            loadWebDavConfigMeta()

            val cachedKey = meta.optString("cachedKeyB64", "")
            if (!requireUnlock && cachedKey.isNotEmpty()) {
                masterKeyB64 = cachedKey
                try {
                    decryptLocalVault()
                    screen = AppScreen.HOME
                    onUnlockedTriggerSync()
                } catch (_: Exception) {
                    screen = AppScreen.UNLOCK
                }
            } else {
                screen = AppScreen.UNLOCK
            }
        } catch (_: Exception) {
            screen = AppScreen.ONBOARDING
        }
    }

    private fun loadWebDavConfigMeta() {
        runCatching { RustCore.getWebdavConfig(dataDir) }.getOrNull()?.let { cfg ->
            webdavConfigured = true
            webdavUrl = cfg.url
            webdavUser = cfg.username
            webdavHasSavedPass = cfg.passwordEnc.isNotEmpty()
        } ?: run {
            webdavConfigured = false
            webdavUrl = ""
            webdavUser = ""
            webdavHasSavedPass = false
        }
    }

    fun showToast(msg: String, warn: Boolean = false) {
        toastMsg = msg
        toastWarn = warn
    }

    fun clearToast() {
        toastMsg = null
    }

    fun saveMeta() {
        val obj = JSONObject().apply {
            put("hasVault", saltB64.isNotEmpty())
            put("saltB64", saltB64)
            put("requireUnlock", requireUnlock)
            put("bioFaceOn", bioFaceOn)
            put("bioFingerOn", bioFingerOn)
            put("gestureOn", gestureOn)
            put("gesturePattern", gesturePattern)
            put("autoLock", autoLock)
            put("privacyMask", privacyMask)
            put("isDark", isDark)
            put("webdavConfigured", webdavConfigured)
            put("webdavAutoSync", webdavAutoSync)
            put("webdavLastSync", webdavLastSync)
            put("localDirty", localDirty)
            webdavSnapshot?.let { snap ->
                put("webdavSnapshot", JSONObject().apply {
                    put("etag", snap.etag ?: "")
                    put("lastModified", snap.lastModified ?: "")
                    put("size", snap.size)
                })
            }
            put("cachedKeyB64", if (requireUnlock) "" else masterKeyB64)
        }
        metaFile.writeText(obj.toString())
    }

    fun onAppBackgrounded() {
        if (screen == AppScreen.HOME) {
            backgroundedAtMs = System.currentTimeMillis()
        }
    }

    fun onAppResumed() {
        if (screen != AppScreen.HOME) return
        if (requireUnlock && backgroundedAtMs > 0L) {
            val elapsed = System.currentTimeMillis() - backgroundedAtMs
            val threshold = when (autoLock) {
                "切后台立即锁定" -> 0L
                "1 分钟" -> 60_000L
                "5 分钟" -> 300_000L
                "15 分钟" -> 900_000L
                else -> 300_000L
            }
            if (elapsed >= threshold) {
                backgroundedAtMs = 0L
                lockVaultNow()
                return
            }
        }
        backgroundedAtMs = 0L
        if (webdavConfigured && webdavAutoSync) {
            triggerWebDavSync(manual = false)
        }
    }

    fun lockVaultNow() {
        screen = AppScreen.UNLOCK
        showToast(t("锁匣已锁定"))
    }

    private fun onUnlockedTriggerSync() {
        if (webdavConfigured && webdavAutoSync) {
            triggerWebDavSync(manual = false)
        }
    }

    // ============================================================
    // Vault Create / Unlock / Change Master Password
    // ============================================================

    fun createFreshVault(password: String): Boolean {
        if (password.length < 8) {
            showToast(t("主密码至少 8 位"), true)
            return false
        }
        saltB64 = RustCore.generateSalt()
        masterKeyB64 = RustCore.deriveMasterKey(password, saltB64, "argon2id")
        rawRootJson = JSONObject()
        folderRecords = mutableListOf()
        items = emptyList()
        folders = emptyList()
        standaloneTotps = emptyList()
        activeFolder = ALL_FOLDERS
        persistVault(triggerSync = false)
        saveMeta()
        screen = AppScreen.HOME
        activeTab = HomeTab.VAULT
        showToast(t("保险箱已创建"))
        return true
    }

    private fun parseVaultFileContent(raw: String): Pair<String, String> {
        val trimmed = raw.trim()
        val colonIdx = trimmed.indexOf(':')
        return if (colonIdx > 0) {
            trimmed.substring(0, colonIdx) to trimmed.substring(colonIdx + 1)
        } else {
            saltB64 to trimmed
        }
    }

    private fun deriveAndDecryptWithFallback(password: String, salt: String, cipher: String): Pair<String, String> {
        val keyArgon = RustCore.deriveMasterKey(password, salt, "argon2id")
        return try {
            val plain = RustCore.decryptVault(cipher, keyArgon)
            keyArgon to plain
        } catch (_: Exception) {
            val keyPbkdf2 = RustCore.deriveMasterKey(password, salt, "pbkdf2")
            val plain = RustCore.decryptVault(cipher, keyPbkdf2)
            keyPbkdf2 to plain
        }
    }

    fun unlockWithPassword(password: String): Boolean {
        return try {
            val raw = RustCore.loadVaultFile(dataDir)
            if (raw.isBlank()) {
                showToast(t("主密码不正确"), true)
                return false
            }
            val (fileSalt, cipher) = parseVaultFileContent(raw)
            val isLegacy = !raw.contains(':')
            val (derivedKey, plain) = deriveAndDecryptWithFallback(password, fileSalt, cipher)
            saltB64 = fileSalt
            masterKeyB64 = derivedKey
            applyDecryptedPayload(plain)
            if (isLegacy) {
                persistVault(triggerSync = false)
            }
            saveMeta()
            screen = AppScreen.HOME
            showToast(t("锁匣已解锁"))
            onUnlockedTriggerSync()
            true
        } catch (_: Exception) {
            showToast(t("主密码不正确"), true)
            false
        }
    }

    fun unlockWithBiometricSuccess() {
        if (masterKeyB64.isEmpty() && metaFile.exists()) {
            val meta = JSONObject(metaFile.readText())
            masterKeyB64 = meta.optString("cachedKeyB64", "")
        }
        if (masterKeyB64.isNotEmpty()) {
            runCatching { decryptLocalVault() }
        }
        screen = AppScreen.HOME
        showToast(t("生物识别验证通过"))
        onUnlockedTriggerSync()
    }

    fun unlockWithGesture(pattern: String): Boolean {
        return if (pattern == gesturePattern && gesturePattern.isNotEmpty()) {
            if (masterKeyB64.isEmpty() && metaFile.exists()) {
                val meta = JSONObject(metaFile.readText())
                masterKeyB64 = meta.optString("cachedKeyB64", "")
            }
            if (masterKeyB64.isNotEmpty()) {
                runCatching { decryptLocalVault() }
            }
            screen = AppScreen.HOME
            showToast(t("手势验证通过"))
            onUnlockedTriggerSync()
            true
        } else {
            showToast(t("手势图案错误，请重试"), true)
            false
        }
    }

    fun verifyMasterPassword(password: String): Boolean {
        if (password.isEmpty()) return false
        return try {
            val raw = RustCore.loadVaultFile(dataDir)
            val (fileSalt, cipher) = parseVaultFileContent(raw)
            deriveAndDecryptWithFallback(password, fileSalt, cipher)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun changeMasterPassword(oldPwd: String, newPwd: String, confirmPwd: String, onSuccess: () -> Unit) {
        if (oldPwd.isEmpty()) {
            showToast(t("输入当前主密码"), true)
            return
        }
        if (newPwd.length < 8) {
            showToast(t("主密码至少 8 位"), true)
            return
        }
        if (newPwd != confirmPwd) {
            showToast(t("两次密码输入不一致"), true)
            return
        }
        viewModelScope.launch {
            val ok = withContext(Dispatchers.Default) {
                if (!verifyMasterPassword(oldPwd)) return@withContext false
                val oldKey = masterKeyB64
                val oldWdCfg = runCatching { RustCore.getWebdavConfig(dataDir) }.getOrNull()
                val oldWdPass = if (oldWdCfg != null && oldWdCfg.passwordEnc.isNotEmpty() && oldKey.isNotEmpty()) {
                    runCatching { RustCore.decryptVault(oldWdCfg.passwordEnc, oldKey) }.getOrNull()
                } else null

                val newSalt = RustCore.generateSalt()
                val newKey = RustCore.deriveMasterKey(newPwd, newSalt, "argon2id")
                saltB64 = newSalt
                masterKeyB64 = newKey

                if (oldWdCfg != null && oldWdPass != null) {
                    val newEnc = RustCore.encryptVault(oldWdPass, newKey)
                    RustCore.saveWebdavConfig(dataDir, oldWdCfg.url, oldWdCfg.username, newEnc)
                }
                persistVaultInternal(markDirty = true)
                saveMeta()
                true
            }
            if (ok) {
                showToast(t("主密码已更新"))
                scheduleDebouncedUpload()
                onSuccess()
            } else {
                showToast(t("主密码不正确"), true)
            }
        }
    }

    private fun decryptLocalVault() {
        val raw = RustCore.loadVaultFile(dataDir)
        if (raw.isBlank()) return
        val (fileSalt, cipher) = parseVaultFileContent(raw)
        if (fileSalt.isNotEmpty()) saltB64 = fileSalt
        val plain = RustCore.decryptVault(cipher, masterKeyB64)
        applyDecryptedPayload(plain)
        if (!raw.contains(':') && saltB64.isNotEmpty()) {
            persistVaultInternal(markDirty = false)
        }
    }

    private fun applyDecryptedPayload(plain: String) {
        val root = JSONObject(plain)
        rawRootJson = root

        // Parse folders (both string and {id, name, icon})
        val fArr = root.optJSONArray("folders") ?: JSONArray()
        val parsedRecords = mutableListOf<FolderRecord>()
        val seenNames = mutableSetOf<String>()
        for (i in 0 until fArr.length()) {
            val elem = fArr.opt(i)
            val rec = when (elem) {
                is JSONObject -> {
                    val name = normalizeFolderName(elem.optString("name", ""))
                    FolderRecord(
                        id = elem.optString("id", "f_$i").ifEmpty { "f_$i" },
                        name = name,
                        icon = elem.optString("icon", "folder").ifEmpty { "folder" }
                    )
                }
                is String -> {
                    val name = normalizeFolderName(elem)
                    FolderRecord(id = "f_$i", name = name, icon = "folder")
                }
                else -> null
            }
            if (rec != null && rec.name != DEFAULT_FOLDER && seenNames.add(rec.name)) {
                parsedRecords.add(rec)
            }
        }
        folderRecords = parsedRecords
        folders = parsedRecords.map { it.name }

        // Parse standaloneTotps
        val tArr = root.optJSONArray("standaloneTotps") ?: JSONArray()
        standaloneTotps = (0 until tArr.length()).mapNotNull { idx ->
            val o = tArr.optJSONObject(idx) ?: return@mapNotNull null
            StandaloneTotp(
                id = o.optString("id", "t_$idx"),
                issuer = o.optString("issuer", ""),
                account = o.optString("account", ""),
                secret = o.optString("secret", "")
            )
        }

        // Parse items with round-trip rawJson preservation
        val iArr = root.optJSONArray("items") ?: JSONArray()
        items = (0 until iArr.length()).mapNotNull { idx ->
            val o = iArr.optJSONObject(idx) ?: return@mapNotNull null
            parseVaultItemJson(o)
        }
    }

    private fun parseVaultItemJson(o: JSONObject): VaultItem {
        val histArr = o.optJSONArray("passwordHistory") ?: JSONArray()
        val history = (0 until histArr.length()).mapNotNull { hIdx ->
            val ho = histArr.optJSONObject(hIdx) ?: return@mapNotNull null
            val pw = ho.optString("password", "")
            if (pw.isEmpty()) null else PasswordHistoryEntry(pw, ho.optString("changedAt", ""))
        }
        val pwd = o.optString("password", "")
        return VaultItem(
            id = o.optString("id", "item_${System.currentTimeMillis()}"),
            type = ItemType.fromKey(o.optString("type", "login")),
            title = o.optString("title", ""),
            folder = normalizeFolderName(o.optString("folder", "")),
            username = o.optString("username", ""),
            password = pwd,
            url = o.optString("url", ""),
            cardName = o.optString("cardName", ""),
            cardNumber = o.optString("cardNumber", ""),
            cardExpiry = o.optString("cardExpiry", ""),
            cardCvv = o.optString("cardCvv", ""),
            identityName = o.optString("identityName", ""),
            identityEmail = o.optString("identityEmail", ""),
            identityPhone = o.optString("identityPhone", ""),
            identityAddress = o.optString("identityAddress", ""),
            notes = o.optString("notes", ""),
            otpSecret = o.optString("otpSecret", ""),
            passwordHistory = history,
            deletedAt = if (o.has("deletedAt") && !o.isNull("deletedAt")) o.optString("deletedAt", "").ifEmpty { null } else null,
            updatedAt = o.optString("updatedAt", ""),
            strength = o.optString("strength", "").ifEmpty { computePasswordStrength(pwd) },
            isFavorite = o.optBoolean("isFavorite", false),
            rawJson = o.toString()
        )
    }

    private fun serializeVaultItem(item: VaultItem): JSONObject {
        val base = if (!item.rawJson.isNullOrBlank()) {
            runCatching { JSONObject(item.rawJson) }.getOrElse { JSONObject() }
        } else {
            JSONObject()
        }
        base.put("id", item.id)
        base.put("type", item.type.key)
        base.put("title", item.title)
        base.put("folder", normalizeFolderName(item.folder))
        base.put("username", item.username)
        base.put("password", item.password)
        base.put("url", item.url)
        base.put("cardName", item.cardName)
        base.put("cardNumber", item.cardNumber)
        base.put("cardExpiry", item.cardExpiry)
        base.put("cardCvv", item.cardCvv)
        base.put("identityName", item.identityName)
        base.put("identityEmail", item.identityEmail)
        base.put("identityPhone", item.identityPhone)
        base.put("identityAddress", item.identityAddress)
        base.put("notes", item.notes)
        base.put("otpSecret", item.otpSecret)
        if (item.deletedAt != null) {
            base.put("deletedAt", item.deletedAt)
        } else {
            base.remove("deletedAt")
        }
        base.put("updatedAt", item.updatedAt.ifEmpty { nowUpdatedAt() })
        base.put("strength", computePasswordStrength(item.password))
        base.put("isFavorite", item.isFavorite)
        val histArr = JSONArray()
        item.passwordHistory.forEach { h ->
            histArr.put(JSONObject().apply {
                put("password", h.password)
                put("changedAt", h.changedAt)
            })
        }
        base.put("passwordHistory", histArr)
        return base
    }

    private fun buildFoldersJsonArray(): JSONArray {
        val arr = JSONArray()
        folderRecords.forEach { rec ->
            arr.put(JSONObject().apply {
                put("id", rec.id)
                put("name", rec.name)
                put("icon", rec.icon)
            })
        }
        return arr
    }

    private fun buildPayloadJsonString(): String {
        val root = runCatching { JSONObject(rawRootJson.toString()) }.getOrElse { JSONObject() }
        val iArr = JSONArray()
        items.forEach { iArr.put(serializeVaultItem(it)) }
        val tArr = JSONArray()
        standaloneTotps.forEach { t ->
            tArr.put(JSONObject().apply {
                put("id", t.id)
                put("issuer", t.issuer)
                put("account", t.account)
                put("secret", t.secret)
            })
        }
        root.put("items", iArr)
        root.put("folders", buildFoldersJsonArray())
        root.put("standaloneTotps", tArr)
        rawRootJson = root
        return root.toString()
    }

    private fun persistVaultInternal(markDirty: Boolean) {
        if (masterKeyB64.isEmpty() || saltB64.isEmpty()) return
        val payloadStr = buildPayloadJsonString()
        val cipher = RustCore.encryptVault(payloadStr, masterKeyB64)
        RustCore.saveVaultFile(dataDir, "$saltB64:$cipher")
        if (markDirty) {
            localDirty = true
            saveMeta()
        }
    }

    fun persistVault(triggerSync: Boolean = true) {
        persistVaultInternal(markDirty = true)
        if (triggerSync) {
            scheduleDebouncedUpload()
        }
    }

    // ============================================================
    // CRUD Operations
    // ============================================================

    fun saveItem(draft: VaultItem, isNew: Boolean) {
        val now = nowUpdatedAt()
        val normFolder = normalizeFolderName(draft.folder)
        val updatedItem = if (isNew) {
            draft.copy(
                folder = normFolder,
                updatedAt = now,
                strength = computePasswordStrength(draft.password)
            )
        } else {
            val existing = items.firstOrNull { it.id == draft.id }
            val newHistory = if (existing != null && existing.password.isNotEmpty() && existing.password != draft.password) {
                (listOf(PasswordHistoryEntry(existing.password, todayDateString())) + existing.passwordHistory).take(10)
            } else {
                existing?.passwordHistory ?: draft.passwordHistory
            }
            draft.copy(
                folder = normFolder,
                updatedAt = now,
                strength = computePasswordStrength(draft.password),
                passwordHistory = newHistory,
                rawJson = existing?.rawJson ?: draft.rawJson
            )
        }
        items = if (isNew) {
            listOf(updatedItem) + items
        } else {
            items.map { if (it.id == updatedItem.id) updatedItem else it }
        }
        persistVault()
        showToast(t("已加密保存"))
    }

    fun toggleFavorite(id: String) {
        var nowFav = false
        items = items.map {
            if (it.id == id) {
                nowFav = !it.isFavorite
                it.copy(isFavorite = nowFav)
            } else it
        }
        persistVault()
        showToast(if (nowFav) t("已加星标") else t("已取消星标"))
    }

    fun moveToTrash(id: String) {
        val today = todayDateString()
        items = items.map { if (it.id == id) it.copy(deletedAt = today) else it }
        persistVault()
        showToast(t("已移入回收站"))
    }

    fun restoreFromTrash(id: String) {
        items = items.map { if (it.id == id) it.copy(deletedAt = null) else it }
        persistVault()
        showToast(t("已恢复"))
    }

    fun purgeItem(id: String) {
        items = items.filterNot { it.id == id }
        persistVault()
        showToast(t("已彻底删除"))
    }

    fun emptyTrash() {
        items = items.filter { it.deletedAt == null }
        persistVault()
        showToast(t("已清空回收站"))
    }

    fun restorePasswordFromHistory(itemId: String, historyPwd: String) {
        val today = todayDateString()
        val now = nowUpdatedAt()
        items = items.map { it ->
            if (it.id == itemId) {
                val nextHist = if (it.password.isNotEmpty() && it.password != historyPwd) {
                    (listOf(PasswordHistoryEntry(it.password, today)) + it.passwordHistory).take(10)
                } else it.passwordHistory
                it.copy(
                    password = historyPwd,
                    passwordHistory = nextHist,
                    updatedAt = now,
                    strength = computePasswordStrength(historyPwd)
                )
            } else it
        }
        persistVault()
        showToast(t("已恢复该历史密码"))
    }

    fun addFolder(rawName: String): Boolean {
        val name = rawName.trim()
        if (name.isEmpty()) {
            showToast(t("请输入文件夹名称"), true)
            return false
        }
        if (name == ALL_FOLDERS || name == DEFAULT_FOLDER || folders.contains(name)) {
            showToast(t("文件夹已存在"), true)
            return false
        }
        folderRecords.add(FolderRecord(id = "f_${System.currentTimeMillis()}", name = name, icon = "folder"))
        folders = folderRecords.map { it.name }
        persistVault()
        showToast(tf("已新建文件夹：%s", name))
        return true
    }

    fun deleteFolder(name: String) {
        val movedCount = items.count { it.deletedAt == null && normalizeFolderName(it.folder) == name }
        items = items.map { if (normalizeFolderName(it.folder) == name) it.copy(folder = DEFAULT_FOLDER) else it }
        folderRecords.removeAll { it.name == name }
        folders = folderRecords.map { it.name }
        if (activeFolder == name) activeFolder = ALL_FOLDERS
        persistVault()
        showToast(if (movedCount > 0) t("已删除文件夹，原凭证已移入默认文件夹") else t("已删除文件夹"))
    }

    fun addStandaloneTotp(issuer: String, account: String, secret: String): Boolean {
        val iss = issuer.trim()
        val sec = secret.trim()
        if (iss.isEmpty() || sec.isEmpty()) {
            showToast(t("请填写服务名称和密钥"), true)
            return false
        }
        standaloneTotps = listOf(
            StandaloneTotp("t_${System.currentTimeMillis()}", iss, account.trim(), sec)
        ) + standaloneTotps
        persistVault()
        showToast(t("已添加动态令牌"))
        return true
    }

    fun deleteStandaloneTotp(id: String) {
        standaloneTotps = standaloneTotps.filterNot { it.id == id }
        persistVault()
        showToast(t("已移除令牌"))
    }

    fun addGenHistory(pwd: String) {
        if (pwd.isBlank()) return
        genHistory = (listOf(pwd) + genHistory.filterNot { it == pwd }).take(6)
    }

    fun clearGenHistory() {
        genHistory = emptyList()
        showToast(t("已清空生成记录"))
    }

    // ============================================================
    // Real Bidirectional Event-Driven WebDAV Sync
    // ============================================================

    private fun resolveWebDavCredentials(inputUrl: String? = null, inputUser: String? = null, inputPass: String? = null): Triple<String, String, String>? {
        val cfg = runCatching { RustCore.getWebdavConfig(dataDir) }.getOrNull()
        val url = (inputUrl?.trim()?.ifEmpty { null }) ?: cfg?.url ?: return null
        val user = (inputUser?.trim()?.ifEmpty { null }) ?: cfg?.username ?: return null
        val pass = if (!inputPass.isNullOrEmpty()) {
            inputPass
        } else if (cfg != null && cfg.passwordEnc.isNotEmpty() && masterKeyB64.isNotEmpty()) {
            runCatching { RustCore.decryptVault(cfg.passwordEnc, masterKeyB64) }.getOrNull()
        } else null
        if (pass.isNullOrEmpty()) return null
        return Triple(url, user, pass)
    }

    fun testWebDavConnection(url: String, user: String, pass: String) {
        val u = url.trim()
        val usr = user.trim()
        if (u.isEmpty() || usr.isEmpty() || (pass.isEmpty() && !webdavHasSavedPass)) {
            showToast(t("请先填写完整地址、账号与授权密码"), true)
            return
        }
        if (!isValidWebDavUrl(u)) {
            showToast(t("仅支持 https:// 服务器地址"), true)
            return
        }
        val creds = resolveWebDavCredentials(u, usr, pass.ifEmpty { null })
        if (creds == null) {
            showToast(t("请先填写完整地址、账号与授权密码"), true)
            return
        }
        webdavSyncing = true
        viewModelScope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching { RustCore.webdavTest(creds.first, creds.second, creds.third) }
            }
            webdavSyncing = false
            result.onSuccess {
                showToast(t("连接测试成功 · 路径有效"))
            }.onFailure { err ->
                showToast(err.message ?: t("连接失败"), true)
            }
        }
    }

    fun saveWebDavConfig(url: String, user: String, pass: String, onSaved: () -> Unit = {}) {
        val u = url.trim()
        val usr = user.trim()
        if (u.isEmpty() || usr.isEmpty() || (pass.isEmpty() && !webdavHasSavedPass)) {
            showToast(t("请先填写完整地址、账号与授权密码"), true)
            return
        }
        if (!isValidWebDavUrl(u)) {
            showToast(t("仅支持 https:// 服务器地址"), true)
            return
        }
        if (masterKeyB64.isEmpty()) {
            showToast(t("请先解锁保险箱"), true)
            return
        }
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching {
                    val existingCfg = RustCore.getWebdavConfig(dataDir)
                    val passwordEnc = if (pass.isNotEmpty()) {
                        RustCore.encryptVault(pass, masterKeyB64)
                    } else {
                        existingCfg?.passwordEnc ?: throw IllegalStateException(t("请输入授权密码"))
                    }
                    RustCore.saveWebdavConfig(dataDir, u, usr, passwordEnc)
                    normalizeWebDavUrlPreview(u)
                }
            }
            res.onSuccess { normUrl ->
                webdavUrl = normUrl
                webdavUser = usr
                webdavHasSavedPass = true
                webdavConfigured = true
                saveMeta()
                showToast(t("WebDAV 配置已加密保存"))
                onSaved()
            }.onFailure { err ->
                showToast(err.message ?: t("保存失败"), true)
            }
        }
    }

    fun disconnectWebDav() {
        debounceSyncJob?.cancel()
        runCatching { RustCore.clearWebdavConfig(dataDir) }
        webdavConfigured = false
        webdavUrl = ""
        webdavUser = ""
        webdavHasSavedPass = false
        webdavLastSync = ""
        webdavSnapshot = null
        localDirty = false
        saveMeta()
        showToast(t("已断开 WebDAV 同步"))
    }

    private fun isRemoteChanged(stat: WebDavStat): Boolean {
        if (!stat.exists) return false
        val snap = webdavSnapshot ?: return true
        if (stat.etag != null && snap.etag != null && stat.etag != snap.etag) return true
        if (stat.lastModified != null && snap.lastModified != null && stat.lastModified != snap.lastModified) return true
        if (stat.size != snap.size) return true
        return false
    }

    private fun updateSnapshotAndSyncTime(stat: WebDavStat) {
        webdavSnapshot = WebDavSnapshot(stat.etag, stat.lastModified, stat.size)
        webdavLastSync = if (app.suoxia.vault.i18n.AppI18n.isChinese()) "今天 ${nowTimeShort()}" else nowTimeShort()
        localDirty = false
        saveMeta()
    }

    private fun scheduleDebouncedUpload() {
        if (!webdavConfigured || !webdavAutoSync || screen != AppScreen.HOME) return
        debounceSyncJob?.cancel()
        debounceSyncJob = viewModelScope.launch {
            delay(2000L)
            if (!webdavConfigured || !webdavAutoSync || screen != AppScreen.HOME) return@launch
            val creds = resolveWebDavCredentials() ?: return@launch
            webdavSyncing = true
            val outcome = withContext(Dispatchers.IO) {
                runCatching {
                    val stat = RustCore.webdavStat(creds.first, creds.second, creds.third)
                    if (!stat.exists || !isRemoteChanged(stat)) {
                        val uploaded = RustCore.webdavUpload(dataDir, creds.first, creds.second, creds.third)
                        "UPLOADED" to uploaded
                    } else {
                        "CONFLICT" to stat
                    }
                }
            }
            webdavSyncing = false
            outcome.onSuccess { (tag, stat) ->
                if (tag == "UPLOADED") {
                    updateSnapshotAndSyncTime(stat)
                } else {
                    pendingConflictMode = true
                    showWebdavConflictSheet = true
                }
            }.onFailure { err ->
                showToast(err.message ?: t("同步失败"), true)
            }
        }
    }

    fun triggerWebDavSync(manual: Boolean) {
        if (!webdavConfigured || screen != AppScreen.HOME) {
            if (manual) showToast(t("请先保存服务器配置"), true)
            return
        }
        val creds = resolveWebDavCredentials() ?: run {
            if (manual) showToast(t("请先保存服务器配置"), true)
            return
        }
        if (webdavSyncing) return
        webdavSyncing = true
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching {
                    val stat = RustCore.webdavStat(creds.first, creds.second, creds.third)
                    val remoteChanged = isRemoteChanged(stat)
                    when {
                        !stat.exists -> {
                            val up = RustCore.webdavUpload(dataDir, creds.first, creds.second, creds.third)
                            Triple("UPLOADED", up, null as String?)
                        }
                        remoteChanged && localDirty -> {
                            Triple("CONFLICT", stat, null as String?)
                        }
                        remoteChanged && !localDirty -> {
                            val dl = RustCore.webdavDownload(creds.first, creds.second, creds.third)
                            Triple("DOWNLOADED", dl.stat, dl.content)
                        }
                        !remoteChanged && localDirty -> {
                            val up = RustCore.webdavUpload(dataDir, creds.first, creds.second, creds.third)
                            Triple("UPLOADED", up, null as String?)
                        }
                        else -> Triple("UP_TO_DATE", stat, null as String?)
                    }
                }
            }
            webdavSyncing = false
            res.onSuccess { (action, stat, content) ->
                when (action) {
                    "UPLOADED" -> {
                        updateSnapshotAndSyncTime(stat)
                        if (manual) showToast(t("已同步至云端"))
                    }
                    "CONFLICT" -> {
                        pendingConflictMode = true
                        showWebdavConflictSheet = true
                    }
                    "DOWNLOADED" -> {
                        if (content != null) {
                            applyDownloadedVault(content, stat, manual = manual)
                        }
                    }
                    "UP_TO_DATE" -> {
                        if (manual) showToast(t("云端已是最新"))
                    }
                }
            }.onFailure { err ->
                showToast(err.message ?: t("同步失败"), true)
            }
        }
    }

    fun resolveConflictUseLocal() {
        showWebdavConflictSheet = false
        val creds = resolveWebDavCredentials() ?: return
        webdavSyncing = true
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching { RustCore.webdavUpload(dataDir, creds.first, creds.second, creds.third) }
            }
            webdavSyncing = false
            res.onSuccess { stat ->
                updateSnapshotAndSyncTime(stat)
                showToast(t("已用本机数据覆盖云端"))
            }.onFailure { err ->
                showToast(err.message ?: t("上传失败"), true)
            }
        }
    }

    fun resolveConflictUseRemote() {
        showWebdavConflictSheet = false
        val creds = resolveWebDavCredentials() ?: return
        webdavSyncing = true
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching { RustCore.webdavDownload(creds.first, creds.second, creds.third) }
            }
            webdavSyncing = false
            res.onSuccess { dl ->
                applyDownloadedVault(dl.content, dl.stat, manual = true, isConflictOverride = true)
            }.onFailure { err ->
                showToast(err.message ?: t("下载失败"), true)
            }
        }
    }

    private fun applyDownloadedVault(
        content: String,
        stat: WebDavStat,
        manual: Boolean = false,
        isConflictOverride: Boolean = false
    ) {
        val (remoteSalt, cipher) = parseVaultFileContent(content)
        if (remoteSalt.isNotEmpty() && remoteSalt == saltB64 && masterKeyB64.isNotEmpty()) {
            try {
                val plain = RustCore.decryptVault(cipher, masterKeyB64)
                applyDecryptedPayload(plain)
                RustCore.saveVaultFile(dataDir, "$remoteSalt:$cipher")
                updateSnapshotAndSyncTime(stat)
                if (isConflictOverride) showToast(t("已下载云端版本并更新本机"))
                else if (manual) showToast(t("已从云端更新"))
                return
            } catch (_: Exception) {
                // Fall through to master password prompt
            }
        }
        pendingRemoteContent = content
        pendingRemoteStat = stat
        showRemoteSaltPwdDialog = true
    }

    fun submitRemoteSaltPassword(password: String) {
        val content = pendingRemoteContent ?: return
        val stat = pendingRemoteStat ?: return
        if (password.isEmpty()) {
            showToast(t("输入主密码"), true)
            return
        }
        viewModelScope.launch {
            val res = withContext(Dispatchers.Default) {
                runCatching {
                    val (remoteSalt, cipher) = parseVaultFileContent(content)
                    val (newKey, plain) = deriveAndDecryptWithFallback(password, remoteSalt, cipher)
                    Triple(remoteSalt, newKey, plain)
                }
            }
            res.onSuccess { (remoteSalt, newKey, plain) ->
                val oldKey = masterKeyB64
                val oldWdCfg = runCatching { RustCore.getWebdavConfig(dataDir) }.getOrNull()
                val oldWdPass = if (oldWdCfg != null && oldWdCfg.passwordEnc.isNotEmpty() && oldKey.isNotEmpty()) {
                    runCatching { RustCore.decryptVault(oldWdCfg.passwordEnc, oldKey) }.getOrNull()
                } else null

                saltB64 = remoteSalt
                masterKeyB64 = newKey
                if (oldWdCfg != null && oldWdPass != null) {
                    val newEnc = RustCore.encryptVault(oldWdPass, newKey)
                    runCatching { RustCore.saveWebdavConfig(dataDir, oldWdCfg.url, oldWdCfg.username, newEnc) }
                }
                applyDecryptedPayload(plain)
                RustCore.saveVaultFile(dataDir, content.trim())
                updateSnapshotAndSyncTime(stat)
                pendingRemoteContent = null
                pendingRemoteStat = null
                showRemoteSaltPwdDialog = false
                showToast(t("已从云端更新"))
            }.onFailure {
                showToast(t("主密码不正确"), true)
            }
        }
    }

    fun dismissRemoteSaltDialog() {
        showRemoteSaltPwdDialog = false
        pendingRemoteContent = null
        pendingRemoteStat = null
    }

    fun restoreFromWebDavOnboarding(
        url: String,
        user: String,
        pass: String,
        masterPassword: String,
        onSuccess: () -> Unit
    ) {
        val u = url.trim()
        val usr = user.trim()
        if (u.isEmpty() || usr.isEmpty() || pass.isEmpty() || masterPassword.isEmpty()) {
            showToast(t("请先填写完整地址、账号与授权密码"), true)
            return
        }
        if (!isValidWebDavUrl(u)) {
            showToast(t("仅支持 https:// 服务器地址"), true)
            return
        }
        webdavSyncing = true
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching {
                    val dl = RustCore.webdavDownload(u, usr, pass)
                    val (remoteSalt, cipher) = parseVaultFileContent(dl.content)
                    if (remoteSalt.isEmpty()) throw IllegalStateException("ERR_SALT_MISSING")
                    val (derivedKey, plain) = deriveAndDecryptWithFallback(masterPassword, remoteSalt, cipher)
                    val passEnc = RustCore.encryptVault(pass, derivedKey)
                    RustCore.saveWebdavConfig(dataDir, u, usr, passEnc)
                    RustCore.saveVaultFile(dataDir, "$remoteSalt:$cipher")
                    Triple(remoteSalt, derivedKey, plain to dl.stat)
                }
            }
            webdavSyncing = false
            res.onSuccess { (rSalt, key, pair) ->
                val (plain, stat) = pair
                saltB64 = rSalt
                masterKeyB64 = key
                applyDecryptedPayload(plain)
                webdavConfigured = true
                webdavUrl = normalizeWebDavUrlPreview(u)
                webdavUser = usr
                webdavHasSavedPass = true
                updateSnapshotAndSyncTime(stat)
                screen = AppScreen.HOME
                activeTab = HomeTab.VAULT
                showToast(t("已从云端更新"))
                onSuccess()
            }.onFailure { err ->
                showToast(err.message ?: t("恢复失败，请检查地址与主密码"), true)
            }
        }
    }

    // ============================================================
    // Export (.json / .kdbx via Android SAF)
    // ============================================================

    fun exportJsonToUri(uri: Uri, resolver: ContentResolver, fileName: String) {
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching {
                    val isoFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }
                    val plainObj = JSONObject().apply {
                        put("version", "1.0.0")
                        put("exportedAt", isoFmt.format(Date()))
                        put("folders", buildFoldersJsonArray())
                        val iArr = JSONArray()
                        items.forEach { iArr.put(serializeVaultItem(it)) }
                        put("vaultItems", iArr)
                    }
                    val plainStr = plainObj.toString()
                    val checksum = RustCore.computeSha256(plainStr)
                    val encPayload = RustCore.encryptVault(plainStr, masterKeyB64)
                    val backupObj = JSONObject().apply {
                        put("isEncrypted", true)
                        put("version", "1.0.0")
                        put("kdf", "argon2id")
                        put("salt", saltB64)
                        put("checksum", checksum)
                        put("encryptedPayload", encPayload)
                        put("hint", "")
                    }
                    val out = resolver.openOutputStream(uri) ?: throw IllegalStateException("ERR_OPEN_OUTPUT")
                    out.use { it.write(backupObj.toString(2).toByteArray(Charsets.UTF_8)) }
                }
            }
            res.onSuccess {
                showToast("${t("已保存")}：$fileName")
            }.onFailure { err ->
                showToast(err.message ?: t("导出失败"), true)
            }
        }
    }

    fun exportKdbxToUri(uri: Uri, resolver: ContentResolver, kdbxPassword: String, fileName: String) {
        viewModelScope.launch {
            val res = withContext(Dispatchers.IO) {
                runCatching {
                    val tmpFile = File(cacheDir, "export_${System.currentTimeMillis()}.kdbx")
                    try {
                        val iArr = JSONArray()
                        items.forEach { iArr.put(serializeVaultItem(it)) }
                        val itemsJson = JSONObject().put("items", iArr).toString()
                        RustCore.exportKdbx(tmpFile.absolutePath, itemsJson, kdbxPassword)
                        val out = resolver.openOutputStream(uri) ?: throw IllegalStateException("ERR_OPEN_OUTPUT")
                        out.use { os -> tmpFile.inputStream().use { it.copyTo(os) } }
                    } finally {
                        tmpFile.delete()
                    }
                }
            }
            res.onSuccess {
                showToast("${t("已保存")}：$fileName")
            }.onFailure { err ->
                showToast(err.message ?: t("导出失败"), true)
            }
        }
    }

    // ============================================================
    // 3-Step Import (JSON encrypted/plain, KDBX, CSV)
    // ============================================================

    fun resolveDisplayName(uri: Uri, resolver: ContentResolver): String {
        var name = "backup"
        runCatching {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) name = c.getString(idx) ?: name
                }
            }
        }
        return name
    }

    fun stageImportUri(
        uri: Uri,
        resolver: ContentResolver,
        sourceType: ImportSourceType,
        onNeedsPassword: (cachedPath: String, fileName: String, badge: String) -> Unit,
        onPreviewReady: (ImportPreviewData) -> Unit
    ) {
        viewModelScope.launch {
            val displayName = withContext(Dispatchers.IO) { resolveDisplayName(uri, resolver) }
            val staged = withContext(Dispatchers.IO) {
                runCatching {
                    val ext = displayName.substringAfterLast('.', "tmp")
                    val tmp = File(cacheDir, "import_${System.currentTimeMillis()}.$ext")
                    val ins = resolver.openInputStream(uri) ?: throw IllegalStateException("ERR_OPEN_INPUT")
                    ins.use { i -> tmp.outputStream().use { o -> i.copyTo(o) } }
                    tmp
                }
            }
            staged.onFailure { err ->
                showToast(err.message ?: t("读取文件失败"), true)
                return@launch
            }
            val tmpFile = staged.getOrThrow()

            if (sourceType == ImportSourceType.KDBX || displayName.lowercase(Locale.ROOT).endsWith(".kdbx")) {
                onNeedsPassword(tmpFile.absolutePath, displayName, "KeePass (.kdbx)")
                return@launch
            }

            val textRes = withContext(Dispatchers.IO) {
                runCatching { RustCore.readExportFile(tmpFile.absolutePath) }
            }
            textRes.onFailure { err ->
                tmpFile.delete()
                showToast(err.message ?: t("读取文件失败"), true)
                return@launch
            }
            val text = textRes.getOrThrow()
            val trimmed = text.trim()
            if (trimmed.startsWith("{")) {
                val obj = runCatching { JSONObject(trimmed) }.getOrNull()
                if (obj != null && obj.optBoolean("isEncrypted", false)) {
                    onNeedsPassword(tmpFile.absolutePath, displayName, t("锁匣加密备份"))
                    return@launch
                }
            }

            // Plaintext JSON or CSV
            val parsed = withContext(Dispatchers.Default) {
                runCatching { parsePlaintextImport(text, displayName, sourceType) }
            }
            tmpFile.delete()
            parsed.onSuccess { preview ->
                if (preview.items.isEmpty()) {
                    showToast(t("未在文件中识别到有效凭证"), true)
                } else {
                    onPreviewReady(preview)
                }
            }.onFailure { err ->
                showToast(err.message ?: t("文件解析失败"), true)
            }
        }
    }

    fun decryptImportFile(
        cachedPath: String,
        fileName: String,
        sourceType: ImportSourceType,
        password: String,
        onPreviewReady: (ImportPreviewData) -> Unit
    ) {
        if (password.isEmpty()) {
            showToast(t("请输入备份文件解密密码"), true)
            return
        }
        viewModelScope.launch {
            val res = withContext(Dispatchers.Default) {
                runCatching {
                    if (sourceType == ImportSourceType.KDBX || fileName.lowercase(Locale.ROOT).endsWith(".kdbx")) {
                        val jsonStr = RustCore.importKdbx(cachedPath, password)
                        val obj = JSONObject(jsonStr)
                        val iArr = obj.optJSONArray("items") ?: JSONArray()
                        val parsedItems = mutableListOf<VaultItem>()
                        val folderSet = linkedSetOf<String>()
                        for (i in 0 until iArr.length()) {
                            val o = iArr.getJSONObject(i)
                            val folder = normalizeFolderName(o.optString("folder", ""))
                            if (folder != DEFAULT_FOLDER) folderSet.add(folder)
                            val customObj = o.optJSONObject("custom")
                            val otpRaw = customObj?.optString("otp", "") ?: ""
                            val otpSecret = if (otpRaw.startsWith("otpauth://")) {
                                runCatching { RustCore.parseOtpauthUri(otpRaw).third }.getOrDefault("")
                            } else otpRaw
                            val pwd = o.optString("password", "")
                            parsedItems.add(
                                VaultItem(
                                    id = "imp_${System.currentTimeMillis()}_$i",
                                    type = ItemType.LOGIN,
                                    title = o.optString("title", "").ifEmpty { o.optString("url", "KeePass Item") },
                                    folder = folder,
                                    username = o.optString("username", ""),
                                    password = pwd,
                                    url = o.optString("url", ""),
                                    notes = o.optString("notes", ""),
                                    otpSecret = otpSecret,
                                    isFavorite = o.optBoolean("favorite", false),
                                    updatedAt = nowUpdatedAt(),
                                    strength = computePasswordStrength(pwd)
                                )
                            )
                        }
                        ImportPreviewData(
                            fileName = fileName,
                            badge = "KeePass (.kdbx)",
                            items = parsedItems,
                            folders = folderSet.toList(),
                            sourcePassword = password
                        )
                    } else {
                        val text = RustCore.readExportFile(cachedPath)
                        val obj = JSONObject(text)
                        val salt = obj.getString("salt")
                        val encPayload = obj.getString("encryptedPayload")
                        val kdf = obj.optString("kdf", "argon2id")
                        val expectedChecksum = obj.optString("checksum", "")
                        val plain = try {
                            val k1 = RustCore.deriveMasterKey(password, salt, kdf)
                            RustCore.decryptVault(encPayload, k1)
                        } catch (_: Exception) {
                            val otherKdf = if (kdf == "pbkdf2") "argon2id" else "pbkdf2"
                            val k2 = RustCore.deriveMasterKey(password, salt, otherKdf)
                            RustCore.decryptVault(encPayload, k2)
                        }
                        if (expectedChecksum.isNotEmpty()) {
                            val actual = RustCore.computeSha256(plain)
                            if (!actual.equals(expectedChecksum, ignoreCase = true)) {
                                throw IllegalStateException("ERR_CHECKSUM_MISMATCH")
                            }
                        }
                        parsePlaintextImport(plain, fileName, ImportSourceType.SUOXIA_JSON).copy(
                            badge = t("锁匣加密备份"),
                            sourcePassword = password
                        )
                    }
                }
            }
            res.onSuccess { preview ->
                File(cachedPath).delete()
                showToast(t("备份文件解密成功"))
                onPreviewReady(preview)
            }.onFailure {
                showToast(t("解密失败，请检查文件密码"), true)
            }
        }
    }

    private fun parsePlaintextImport(
        text: String,
        fileName: String,
        sourceType: ImportSourceType
    ): ImportPreviewData {
        val trimmed = text.trim()
        val parsedItems = mutableListOf<VaultItem>()
        val folderSet = linkedSetOf<String>()

        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            val arr: JSONArray = if (trimmed.startsWith("[")) {
                JSONArray(trimmed)
            } else {
                val root = JSONObject(trimmed)
                // Collect folders if present
                val fArr = root.optJSONArray("folders")
                if (fArr != null) {
                    for (i in 0 until fArr.length()) {
                        val el = fArr.opt(i)
                        val fn = when (el) {
                            is JSONObject -> normalizeFolderName(el.optString("name", ""))
                            is String -> normalizeFolderName(el)
                            else -> DEFAULT_FOLDER
                        }
                        if (fn != DEFAULT_FOLDER) folderSet.add(fn)
                    }
                }
                root.optJSONArray("vaultItems")
                    ?: root.optJSONArray("items")
                    ?: JSONArray()
            }
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                // Bitwarden compatibility (login object nested)
                val loginObj = o.optJSONObject("login")
                val item = if (loginObj != null) {
                    val uris = loginObj.optJSONArray("uris")
                    val firstUri = uris?.optJSONObject(0)?.optString("uri", "") ?: ""
                    val pwd = loginObj.optString("password", "")
                    VaultItem(
                        id = "imp_${System.currentTimeMillis()}_$i",
                        type = ItemType.LOGIN,
                        title = o.optString("name", "").ifEmpty { firstUri },
                        folder = DEFAULT_FOLDER,
                        username = loginObj.optString("username", ""),
                        password = pwd,
                        url = firstUri,
                        notes = o.optString("notes", ""),
                        otpSecret = loginObj.optString("totp", ""),
                        updatedAt = nowUpdatedAt(),
                        strength = computePasswordStrength(pwd)
                    )
                } else {
                    parseVaultItemJson(o).copy(id = "imp_${System.currentTimeMillis()}_$i")
                }
                if (item.folder != DEFAULT_FOLDER) folderSet.add(item.folder)
                parsedItems.add(item)
            }
            return ImportPreviewData(
                fileName = fileName,
                badge = if (sourceType == ImportSourceType.SUOXIA_JSON) "JSON" else "JSON",
                items = parsedItems,
                folders = folderSet.toList()
            )
        }

        // CSV parsing (Chrome / Edge / Safari / Firefox)
        val rows = parseCsvRows(trimmed)
        if (rows.size >= 2) {
            val headers = rows.first().map { it.trim().lowercase(Locale.ROOT) }
            val titleIdx = headers.indexOfFirst { it in listOf("name", "title", "website", "service") }
            val urlIdx = headers.indexOfFirst { it in listOf("url", "website", "origin", "login_uri") }
            val userIdx = headers.indexOfFirst { it in listOf("username", "login_username", "user", "email") }
            val passIdx = headers.indexOfFirst { it in listOf("password", "login_password", "pass") }
            val noteIdx = headers.indexOfFirst { it in listOf("note", "notes", "extra") }

            for (rIdx in 1 until rows.size) {
                val row = rows[rIdx]
                val title = row.getOrNull(titleIdx)?.trim().orEmpty()
                val url = row.getOrNull(urlIdx)?.trim().orEmpty()
                val user = row.getOrNull(userIdx)?.trim().orEmpty()
                val pass = row.getOrNull(passIdx)?.trim().orEmpty()
                val note = row.getOrNull(noteIdx)?.trim().orEmpty()
                if (title.isEmpty() && url.isEmpty() && user.isEmpty() && pass.isEmpty()) continue
                parsedItems.add(
                    VaultItem(
                        id = "imp_${System.currentTimeMillis()}_$rIdx",
                        type = ItemType.LOGIN,
                        title = title.ifEmpty { url.ifEmpty { user } },
                        folder = DEFAULT_FOLDER,
                        username = user,
                        password = pass,
                        url = url,
                        notes = note,
                        updatedAt = nowUpdatedAt(),
                        strength = computePasswordStrength(pass)
                    )
                )
            }
        }
        return ImportPreviewData(
            fileName = fileName,
            badge = "CSV",
            items = parsedItems,
            folders = folderSet.toList()
        )
    }

    private fun parseCsvRows(input: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        val currentRow = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < input.length) {
            val c = input[i]
            when {
                inQuotes -> {
                    if (c == '"') {
                        if (i + 1 < input.length && input[i + 1] == '"') {
                            field.append('"')
                            i++
                        } else {
                            inQuotes = false
                        }
                    } else {
                        field.append(c)
                    }
                }
                c == '"' -> inQuotes = true
                c == ',' -> {
                    currentRow.add(field.toString())
                    field.clear()
                }
                c == '\r' -> {
                    // skip
                }
                c == '\n' -> {
                    currentRow.add(field.toString())
                    field.clear()
                    if (currentRow.any { it.isNotEmpty() }) rows.add(currentRow.toList())
                    currentRow.clear()
                }
                else -> field.append(c)
            }
            i++
        }
        if (field.isNotEmpty() || currentRow.isNotEmpty()) {
            currentRow.add(field.toString())
            if (currentRow.any { it.isNotEmpty() }) rows.add(currentRow.toList())
        }
        return rows
    }

    fun executeImport(
        preview: ImportPreviewData,
        strategy: ImportStrategy,
        onboardingMasterPwd: String? = null
    ) {
        val isFromOnboarding = screen == AppScreen.ONBOARDING
        if (isFromOnboarding) {
            val pwd = onboardingMasterPwd?.takeIf { it.length >= 8 }
                ?: preview.sourcePassword?.takeIf { it.length >= 8 }
                ?: "SecureVault#2026"
            saltB64 = RustCore.generateSalt()
            masterKeyB64 = RustCore.deriveMasterKey(pwd, saltB64, "argon2id")
            rawRootJson = JSONObject()
            folderRecords = mutableListOf()
            items = emptyList()
            folders = emptyList()
            standaloneTotps = emptyList()
        }

        val active = items.filter { it.deletedAt == null }
        val existingKeys = active.map { "${it.title}|${it.username.ifEmpty { it.cardNumber }}" }.toSet()

        val incoming = preview.items.mapIndexed { idx, it ->
            it.copy(
                id = "imp_${System.currentTimeMillis()}_$idx",
                folder = normalizeFolderName(it.folder),
                updatedAt = it.updatedAt.ifEmpty { nowUpdatedAt() },
                strength = computePasswordStrength(it.password)
            )
        }

        val addedCount: Int
        when (strategy) {
            ImportStrategy.OVERWRITE -> {
                items = incoming
                folderRecords = incoming.map { it.folder }
                    .filter { it != DEFAULT_FOLDER }
                    .distinct()
                    .mapIndexed { idx, name -> FolderRecord("f_${System.currentTimeMillis()}_$idx", name) }
                    .toMutableList()
                folders = folderRecords.map { it.name }
                addedCount = incoming.size
            }
            ImportStrategy.SKIP_DUPLICATES -> {
                val unique = incoming.filter { "${it.title}|${it.username.ifEmpty { it.cardNumber }}" !in existingKeys }
                items = unique + items
                unique.map { it.folder }.filter { it != DEFAULT_FOLDER }.distinct().forEach { f ->
                    if (folderRecords.none { it.name == f }) {
                        folderRecords.add(FolderRecord("f_${System.currentTimeMillis()}_${folderRecords.size}", f))
                    }
                }
                folders = folderRecords.map { it.name }
                addedCount = unique.size
            }
            ImportStrategy.MERGE -> {
                items = incoming + items
                incoming.map { it.folder }.filter { it != DEFAULT_FOLDER }.distinct().forEach { f ->
                    if (folderRecords.none { it.name == f }) {
                        folderRecords.add(FolderRecord("f_${System.currentTimeMillis()}_${folderRecords.size}", f))
                    }
                }
                folders = folderRecords.map { it.name }
                addedCount = incoming.size
            }
        }

        persistVault(triggerSync = !isFromOnboarding)
        saveMeta()
        if (isFromOnboarding) {
            screen = AppScreen.HOME
            activeTab = HomeTab.VAULT
        }
        val msg = if (strategy == ImportStrategy.OVERWRITE) {
            if (app.suoxia.vault.i18n.AppI18n.isChinese()) "已覆盖导入 $addedCount 条凭证" else "Overwrote with $addedCount items"
        } else {
            if (app.suoxia.vault.i18n.AppI18n.isChinese()) "已成功导入 $addedCount 条凭证" else "Imported $addedCount items"
        }
        showToast(msg)
    }
}
