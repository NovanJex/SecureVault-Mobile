package app.suoxia.vault.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.suoxia.vault.i18n.t
import app.suoxia.vault.model.*
import app.suoxia.vault.state.VaultViewModel

private data class WebDavPreset(
    val key: String,
    val label: String,
    val placeholder: String,
    val tip: String
)

private val WEBDAV_PRESETS = listOf(
    WebDavPreset("generic", "通用 WebDAV", "https://your-server.com/dav/SecureVault/", "适用 Alist / InfiniCLOUD 等任意标准 HTTPS WebDAV 服务"),
    WebDavPreset("nextcloud", "Nextcloud", "https://cloud.example.com/remote.php/dav/files/用户名/SecureVault/", "路径位于「文件 → 设置」，需在「安全」中创建应用密码"),
    WebDavPreset("nas", "NAS", "https://nas.example.com:5006/SecureVault/", "适用群晖 / 飞牛 / 威联通等，需开启 HTTPS WebDAV 端口"),
    WebDavPreset("jianguoyun", "坚果云", "https://dav.jianguoyun.com/dav/SecureVault/", "需在网页版「安全选项 → 第三方应用」生成专用密码")
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WebDavSheet(
    p: SvPalette,
    vm: VaultViewModel,
    isOnboardingRestore: Boolean = false,
    onDismiss: () -> Unit
) {
    var presetKey by remember { mutableStateOf("generic") }
    var guideOpen by remember { mutableStateOf(false) }
    var url by remember(vm.webdavUrl) { mutableStateOf(vm.webdavUrl) }
    var username by remember(vm.webdavUser) { mutableStateOf(vm.webdavUser) }
    var password by remember { mutableStateOf("") }
    var masterPassword by remember { mutableStateOf("") }
    var showDisconnectConfirm by remember { mutableStateOf(false) }

    val preset = WEBDAV_PRESETS.firstOrNull { it.key == presetKey } ?: WEBDAV_PRESETS.first()
    val normPreview = remember(url) { normalizeWebDavUrlPreview(url) }

    SvPageSheet(
        p = p,
        title = if (isOnboardingRestore) t("从 WebDAV 云端恢复") else t("WebDAV 同步"),
        onDismiss = onDismiss,
        leftLabel = t("关闭"),
        rightAction = if (!isOnboardingRestore && vm.webdavConfigured) {
            {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(SvEmerald))
            }
        } else null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Collapsible Universal Setup Guide
            SvGroupedCard(p = p) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { guideOpen = !guideOpen }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(
                            modifier = Modifier.size(20.dp).clip(CircleShape).background(SvIndigo.copy(alpha = 0.14f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("?", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = SvIndigo)
                        }
                        Text(t("不知道怎么填？查看通用图文指引"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                    }
                    Icon(
                        imageVector = if (guideOpen) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                        contentDescription = null,
                        tint = p.fg.copy(alpha = 0.5f),
                        modifier = Modifier.size(18.dp)
                    )
                }
                if (guideOpen) {
                    HorizontalDivider(thickness = 1.dp, color = p.hairline)
                    Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        // Native schematic diagram
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = p.sub,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Surface(
                                        shape = RoundedCornerShape(10.dp),
                                        color = SvIndigo.copy(alpha = 0.12f),
                                        border = BorderStroke(1.dp, SvIndigo.copy(alpha = 0.35f)),
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Column(modifier = Modifier.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                            Text("锁匣本机加密", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = p.fg)
                                            Text("高强度本地加密", fontSize = 9.sp, color = SvIndigo)
                                        }
                                    }
                                    Box(
                                        modifier = Modifier
                                            .padding(horizontal = 6.dp)
                                            .clip(CircleShape)
                                            .background(SvIndigo)
                                            .padding(horizontal = 8.dp, vertical = 3.dp)
                                    ) {
                                        Text("vault.enc", fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                                    }
                                    Surface(
                                        shape = RoundedCornerShape(10.dp),
                                        color = SvEmerald.copy(alpha = 0.12f),
                                        border = BorderStroke(1.dp, SvEmerald.copy(alpha = 0.35f)),
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Column(modifier = Modifier.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                            Text("你的网盘 / NAS", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = p.fg)
                                            Text("仅存加密文件", fontSize = 9.sp, color = SvEmerald)
                                        }
                                    }
                                }
                                Text(
                                    "1. 服务器地址：https://.../dav/文件夹/\n2. 账号 + 3. 应用专用密码（非网盘登录密码）",
                                    fontSize = 10.sp,
                                    color = p.fg.copy(alpha = 0.7f),
                                    lineHeight = 15.sp
                                )
                            }
                        }

                        // 3 Steps text
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("第 1 步 · 开启 WebDAV 并复制地址：在你的网盘或 NAS 后台开启 WebDAV（需 https://），直接填目录即可，程序会自动补全 /vault.enc。", fontSize = 11.sp, color = p.fg.copy(alpha = 0.78f), lineHeight = 17.sp)
                            Text("第 2 步 · 生成应用专用密码：大多数网盘禁止直接用登录密码连接 WebDAV，请在网盘「安全设置 / 第三方应用」中新建一个授权密码。", fontSize = 11.sp, color = p.fg.copy(alpha = 0.78f), lineHeight = 17.sp)
                            Text("第 3 步 · 多端保持一致：手机端与电脑端填写相同服务器地址并使用相同主密码，即可随时双向同步。", fontSize = 11.sp, color = p.fg.copy(alpha = 0.78f), lineHeight = 17.sp)
                        }
                    }
                }
            }

            // Preset Chips
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(t("常用服务参考格式（可选）"), fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(horizontal = 4.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    WEBDAV_PRESETS.forEach { item ->
                        val on = presetKey == item.key
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (on) SvIndigo.copy(alpha = 0.1f) else p.card,
                            border = BorderStroke(1.dp, if (on) SvIndigo.copy(alpha = 0.4f) else p.border),
                            modifier = Modifier.clickable { presetKey = item.key }
                        ) {
                            Text(
                                t(item.label),
                                fontSize = 11.sp,
                                fontWeight = if (on) FontWeight.SemiBold else FontWeight.Medium,
                                color = if (on) SvIndigo else p.fg.copy(alpha = 0.75f),
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }
                }
                Text(preset.tip, fontSize = 11.sp, color = p.fg.copy(alpha = 0.6f), lineHeight = 16.sp, modifier = Modifier.padding(horizontal = 4.dp))
            }

            // Form Fields
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    SvInputField(p, url, { url = it }, preset.placeholder, label = t("服务器地址 *"))
                    if (normPreview.isNotEmpty()) {
                        Text(
                            "${t("实际同步文件：")}$normPreview",
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Monospace,
                            color = SvIndigo,
                            modifier = Modifier.padding(horizontal = 4.dp)
                        )
                    }
                }
                SvInputField(p, username, { username = it }, t("输入网盘 / NAS 用户名或邮箱"), label = t("账号 *"))
                SvInputField(
                    p = p,
                    value = password,
                    onValueChange = { password = it },
                    placeholder = if (!isOnboardingRestore && vm.webdavHasSavedPass) t("留空则沿用已保存的授权密码") else t("输入 WebDAV 专用密码"),
                    label = t("应用专用密码 / 授权码 *"),
                    isPassword = true
                )
                if (isOnboardingRestore) {
                    SvInputField(
                        p = p,
                        value = masterPassword,
                        onValueChange = { masterPassword = it },
                        placeholder = t("输入主密码"),
                        label = t("主密码（用于解密云端备份）*"),
                        isPassword = true
                    )
                }
            }

            if (isOnboardingRestore) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = SvIndigo,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clickable(enabled = !vm.webdavSyncing) {
                            vm.restoreFromWebDavOnboarding(url, username, password, masterPassword) {
                                onDismiss()
                            }
                        }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            if (vm.webdavSyncing) "..." else t("从 WebDAV 云端恢复"),
                            color = Color.White,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            } else {
                // Auto-Sync Toggle
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = p.card,
                    border = BorderStroke(1.dp, p.border),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
                            Text(t("自动同步"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                            Text(t("启动或修改凭证后自动与云端保持一致"), fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f))
                        }
                        SvSwitch(
                            checked = vm.webdavAutoSync,
                            onCheckedChange = {
                                vm.webdavAutoSync = it
                                vm.saveMeta()
                                vm.showToast(if (it) t("自动同步已开启") else t("手动同步"))
                            }
                        )
                    }
                }

                // Connected status strip
                if (vm.webdavConfigured) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = p.sub,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row {
                                Text(t("同步状态："), fontSize = 11.sp, color = p.fg.copy(alpha = 0.7f))
                                Text(t("已连接"), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = SvEmerald)
                            }
                            Text(
                                if (vm.webdavLastSync.isNotEmpty()) "${t("上次同步")}：${vm.webdavLastSync}" else t("尚未同步"),
                                fontSize = 11.sp,
                                color = p.fg.copy(alpha = 0.55f)
                            )
                        }
                    }
                }

                // Action Buttons
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = p.card,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp)
                            .clickable(enabled = !vm.webdavSyncing) {
                                vm.testWebDavConnection(url, username, password)
                            }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(t("测试连接"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                        }
                    }
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = SvIndigo,
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp)
                            .clickable(enabled = !vm.webdavSyncing) {
                                vm.saveWebDavConfig(url, username, password) {
                                    password = ""
                                }
                            }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(t("保存配置"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                        }
                    }
                }

                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = if (vm.webdavConfigured) SvIndigo.copy(alpha = 0.1f) else p.card,
                    border = BorderStroke(1.dp, if (vm.webdavConfigured) SvIndigo.copy(alpha = 0.3f) else p.border),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .clickable(enabled = !vm.webdavSyncing) {
                            vm.triggerWebDavSync(manual = true)
                        }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            if (vm.webdavSyncing) "..." else t("立即同步"),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (vm.webdavConfigured) SvIndigo else p.fg.copy(alpha = 0.5f)
                        )
                    }
                }

                if (vm.webdavConfigured) {
                    Box(modifier = Modifier.fillMaxWidth().padding(top = 4.dp), contentAlignment = Alignment.CenterEnd) {
                        Text(
                            t("断开同步"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = SvRose,
                            modifier = Modifier.clickable { showDisconnectConfirm = true }.padding(4.dp)
                        )
                    }
                }
            }
        }
    }

    if (showDisconnectConfirm) {
        SvConfirmDialog(
            p = p,
            title = t("断开 WebDAV 同步？"),
            message = t("将清除本机保存的服务器地址与密码，不会删除你本机或云端已有的备份数据。"),
            confirmText = t("确认断开"),
            isDestructive = true,
            onDismiss = { showDisconnectConfirm = false },
            onConfirm = {
                showDisconnectConfirm = false
                vm.disconnectWebDav()
                url = ""
                username = ""
                password = ""
            }
        )
    }
}

@Composable
fun WebDavConflictSheet(
    p: SvPalette,
    vm: VaultViewModel
) {
    SvActionSheet(p = p, onDismiss = { vm.showWebdavConflictSheet = false }) {
        Text(t("发现同步冲突"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Text(
            t("本机与云端的备份数据均有更新，请选择保留哪一份："),
            fontSize = 12.sp,
            color = p.fg.copy(alpha = 0.65f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = SvIndigo,
            modifier = Modifier.fillMaxWidth().height(44.dp).clickable { vm.resolveConflictUseLocal() }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(t("用本机覆盖云端"), color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = p.sub,
            border = BorderStroke(1.dp, p.border),
            modifier = Modifier.fillMaxWidth().height(44.dp).clickable { vm.resolveConflictUseRemote() }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(t("用云端覆盖本机"), color = p.fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(
            t("取消"),
            fontSize = 12.sp,
            color = p.fg.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().clickable { vm.showWebdavConflictSheet = false }.padding(vertical = 8.dp)
        )
    }
}

@Composable
fun RemoteSaltPasswordDialog(
    p: SvPalette,
    vm: VaultViewModel
) {
    var pwd by remember { mutableStateOf("") }
    Dialog(onDismissRequest = { vm.dismissRemoteSaltDialog() }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Surface(
                modifier = Modifier.widthIn(max = 310.dp).fillMaxWidth(0.86f),
                shape = RoundedCornerShape(24.dp),
                color = p.card,
                border = BorderStroke(1.dp, p.border),
                shadowElevation = 16.dp
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(t("输入云端保险箱主密码"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center)
                    Text(
                        t("云端备份使用了不同的加密盐值，请输入对应的主密码以解密并同步。"),
                        fontSize = 12.sp,
                        color = p.fg.copy(alpha = 0.65f),
                        textAlign = TextAlign.Center
                    )
                    SvInputField(p, pwd, { pwd = it }, t("输入主密码"), isPassword = true)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = p.sub,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.weight(1f).height(40.dp).clickable { vm.dismissRemoteSaltDialog() }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(t("取消"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                            }
                        }
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = SvIndigo,
                            modifier = Modifier.weight(1f).height(40.dp).clickable { vm.submitRemoteSaltPassword(pwd) }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(t("确认"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                            }
                        }
                    }
                }
            }
            SvToastOverlay(bottomPadding = 24.dp)
        }
    }
}

@Composable
fun ImportFlowSheet(
    p: SvPalette,
    vm: VaultViewModel,
    step: String,
    sourceType: ImportSourceType,
    stagedFileName: String,
    stagedBadge: String,
    stagedPath: String,
    previewData: ImportPreviewData?,
    onSelectSourceAndLaunchPicker: (ImportSourceType) -> Unit,
    onDecryptSubmit: (password: String) -> Unit,
    onResetToPick: () -> Unit,
    onDismiss: () -> Unit
) {
    var decryptPwd by remember { mutableStateOf("") }
    var strategy by remember { mutableStateOf(ImportStrategy.SKIP_DUPLICATES) }
    var showOverwriteConfirm by remember { mutableStateOf(false) }

    val sheetTitle = when (step) {
        "decrypt" -> t("解密备份文件")
        "preview" -> t("导入预览")
        else -> t("导入凭证")
    }
    val leftLabel = when (step) {
        "decrypt" -> t("‹ 上一步")
        "preview" -> t("‹ 重新选择")
        else -> t("关闭")
    }

    SvPageSheet(
        p = p,
        title = sheetTitle,
        onDismiss = onDismiss,
        leftLabel = leftLabel,
        onLeftClick = {
            if (step == "pick") onDismiss() else onResetToPick()
        }
    ) {
        BackHandler(enabled = step != "pick") {
            onResetToPick()
        }

        when (step) {
            "pick" -> {
                Column(
                    modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(t("请选择要导入的文件格式"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.6f), modifier = Modifier.padding(horizontal = 4.dp))
                    SvGroupedCard(p = p) {
                        ImportFormatRow(p, t("锁匣加密备份 (.json)"), t("从电脑端或另一台手机导出的加密备份")) {
                            onSelectSourceAndLaunchPicker(ImportSourceType.SUOXIA_JSON)
                        }
                        SvHairlineDivider(p)
                        ImportFormatRow(p, t("KeePass 数据库 (.kdbx)"), t("支持文件夹分组与 2FA 动态密钥")) {
                            onSelectSourceAndLaunchPicker(ImportSourceType.KDBX)
                        }
                        SvHairlineDivider(p)
                        ImportFormatRow(p, t("浏览器 / 第三方密码 (.csv / .json)"), t("自动识别 Chrome、Edge、Safari、Firefox、Bitwarden 等")) {
                            onSelectSourceAndLaunchPicker(ImportSourceType.BROWSER_CSV_JSON)
                        }
                    }
                    Text(
                        t("所有文件解析与解密均在设备本地离线完成，不会上传至任何服务器。"),
                        fontSize = 11.sp,
                        color = p.fg.copy(alpha = 0.55f),
                        lineHeight = 16.sp,
                        modifier = Modifier.padding(horizontal = 6.dp)
                    )
                }
            }

            "decrypt" -> {
                Column(
                    modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Surface(shape = RoundedCornerShape(16.dp), color = p.card, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Box(modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(SvIndigo.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 2.dp)) {
                                Text(stagedBadge, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = SvIndigo)
                            }
                            Text(stagedFileName, fontSize = 11.sp, color = p.fg.copy(alpha = 0.75f))
                            Text(t("该文件受密码保护，请输入备份对应的解密密码。"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                        }
                    }
                    SvInputField(p, decryptPwd, { decryptPwd = it }, t("输入备份文件密码"), label = t("文件解密密码 *"), isPassword = true)
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = SvIndigo,
                        modifier = Modifier.fillMaxWidth().height(48.dp).clickable { onDecryptSubmit(decryptPwd) }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(t("解密并解析文件"), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }

            "preview" -> {
                val data = previewData ?: return@SvPageSheet
                val active = remember(vm.items) { vm.items.filter { it.deletedAt == null } }
                val existingKeys = remember(active) {
                    active.map { "${it.title}|${it.username.ifEmpty { it.cardNumber }}" }.toSet()
                }
                val dupFlags = remember(data, existingKeys) {
                    data.items.map { "${it.title}|${it.username.ifEmpty { it.cardNumber }}" in existingKeys }
                }
                val dupCount = dupFlags.count { it }
                val newCount = data.items.size - dupCount
                val finalCount = if (strategy == ImportStrategy.SKIP_DUPLICATES) newCount else data.items.size

                val needsOnboardingMasterPwd = !vm.hasVault && (data.sourcePassword == null || data.sourcePassword.length < 8)
                var onboardingPwd1 by remember(data) { mutableStateOf("") }
                var onboardingPwd2 by remember(data) { mutableStateOf("") }
                val onboardingMismatch = onboardingPwd2.isNotEmpty() && onboardingPwd1 != onboardingPwd2
                val onboardingMatched = onboardingPwd2.isNotEmpty() && onboardingPwd1 == onboardingPwd2
                val onboardingPwdValid = !needsOnboardingMasterPwd || (onboardingPwd1.length >= 8 && onboardingPwd1 == onboardingPwd2)
                val canSubmit = !vm.isBusy && onboardingPwdValid

                Column(modifier = Modifier.fillMaxWidth().weight(1f, fill = false)) {
                    Column(
                        modifier = Modifier.fillMaxWidth().weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        // Summary Card
                        Surface(shape = RoundedCornerShape(16.dp), color = p.card, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(SvIndigo.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 2.dp)) {
                                    Text(data.badge, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = SvIndigo)
                                }
                                Text(data.fileName, fontSize = 11.sp, color = p.fg.copy(alpha = 0.75f))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    StatBox(p, data.items.size.toString(), t("识别条数"), p.fg, Modifier.weight(1f))
                                    StatBox(p, newCount.toString(), t("新增条目"), SvEmerald, Modifier.weight(1f))
                                    StatBox(p, dupCount.toString(), t("重复条目"), if (dupCount > 0) SvAmber else p.fg.copy(alpha = 0.6f), Modifier.weight(1f))
                                }
                            }
                        }

                        // Onboarding Master Password Section (required when importing plaintext / short-password backup without an existing vault)
                        if (needsOnboardingMasterPwd) {
                            Surface(
                                shape = RoundedCornerShape(16.dp),
                                color = p.card,
                                border = BorderStroke(1.dp, p.border),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    verticalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                        Text(t("设置本机主密码"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                                        Text(
                                            t("该备份未包含主密码，请为本机保险箱设置主密码（至少 8 位）。"),
                                            fontSize = 11.sp,
                                            color = p.fg.copy(alpha = 0.6f),
                                            lineHeight = 16.sp
                                        )
                                    }
                                    SvInputField(
                                        p = p,
                                        value = onboardingPwd1,
                                        onValueChange = { onboardingPwd1 = it },
                                        placeholder = t("输入高强度主密码"),
                                        label = t("主密码（至少 8 位）"),
                                        isPassword = true
                                    )
                                    SvInputField(
                                        p = p,
                                        value = onboardingPwd2,
                                        onValueChange = { onboardingPwd2 = it },
                                        placeholder = t("再次输入以确认"),
                                        label = t("确认主密码"),
                                        labelEnd = {
                                            val txt = when {
                                                onboardingMismatch -> t("两次输入不一致")
                                                onboardingMatched -> t("✓ 一致")
                                                else -> ""
                                            }
                                            val col = if (onboardingMismatch) SvRose else SvEmerald
                                            Text(text = txt, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = col)
                                        },
                                        isPassword = true,
                                        borderColorOverride = if (onboardingMismatch) SvRose.copy(alpha = 0.7f) else null
                                    )
                                }
                            }
                        }

                        // Preview List (cap visual list to 20)
                        SvGroupedCard(p = p) {
                            data.items.take(20).forEachIndexed { idx, rec ->
                                if (idx > 0) SvHairlineDivider(p)
                                val isDup = dupFlags[idx]
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                                        Text(rec.title, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = p.fg, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                        Text(
                                            rec.username.ifEmpty { rec.cardNumber.ifEmpty { rec.identityEmail.ifEmpty { t("加密备忘") } } },
                                            fontSize = 11.sp,
                                            color = p.fg.copy(alpha = 0.55f),
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(if (isDup) SvAmber.copy(alpha = 0.14f) else SvEmerald.copy(alpha = 0.12f))
                                            .padding(horizontal = 8.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            if (isDup) t("重复") else t("新增"),
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = if (isDup) SvAmber else SvEmerald
                                        )
                                    }
                                }
                            }
                        }

                        // 3 Strategies
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(t("选择导入方式"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(horizontal = 4.dp))
                            SvGroupedCard(p = p) {
                                StrategyRow(
                                    p = p,
                                    title = t("合并并跳过重复项"),
                                    tag = t("推荐"),
                                    desc = "仅新增 $newCount 条不重复凭证，自动跳过 $dupCount 条重复项",
                                    selected = strategy == ImportStrategy.SKIP_DUPLICATES,
                                    danger = false,
                                    onClick = { strategy = ImportStrategy.SKIP_DUPLICATES }
                                )
                                SvHairlineDivider(p)
                                StrategyRow(
                                    p = p,
                                    title = t("全部合并（保留重复项）"),
                                    tag = "",
                                    desc = "将全部 ${data.items.size} 条凭证追加至当前保险箱",
                                    selected = strategy == ImportStrategy.MERGE,
                                    danger = false,
                                    onClick = { strategy = ImportStrategy.MERGE }
                                )
                                SvHairlineDivider(p)
                                StrategyRow(
                                    p = p,
                                    title = t("完全覆盖当前保险箱"),
                                    tag = t("谨慎"),
                                    desc = "清空现有 ${active.size} 条凭证，并以导入文件完整替换",
                                    selected = strategy == ImportStrategy.OVERWRITE,
                                    danger = true,
                                    onClick = { strategy = ImportStrategy.OVERWRITE }
                                )
                            }
                        }
                    }

                    // Sticky footer CTA
                    HorizontalDivider(thickness = 1.dp, color = p.hairline)
                    Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                        val baseBtnColor = if (strategy == ImportStrategy.OVERWRITE) SvRose else SvIndigo
                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = if (canSubmit) baseBtnColor else baseBtnColor.copy(alpha = 0.45f),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                                .clickable(enabled = canSubmit) {
                                    if (strategy == ImportStrategy.OVERWRITE) {
                                        showOverwriteConfirm = true
                                    } else {
                                        vm.executeImport(
                                            preview = data,
                                            strategy = strategy,
                                            onboardingMasterPwd = if (needsOnboardingMasterPwd) onboardingPwd1 else null
                                        ) { ok ->
                                            if (ok) onDismiss()
                                        }
                                    }
                                }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    text = if (vm.isBusy) "..." else if (strategy == ImportStrategy.OVERWRITE) "覆盖并导入（$finalCount 条）" else "确认导入（$finalCount 条）",
                                    color = Color.White,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                }

                if (showOverwriteConfirm) {
                    SvConfirmDialog(
                        p = p,
                        title = t("确认覆盖当前保险箱？"),
                        message = "当前保险箱中所有现有凭证将被清空，并替换为导入文件中的 ${data.items.size} 条凭证，此操作无法撤销。",
                        confirmText = t("确认覆盖"),
                        isDestructive = true,
                        onDismiss = { showOverwriteConfirm = false },
                        onConfirm = {
                            showOverwriteConfirm = false
                            vm.executeImport(
                                preview = data,
                                strategy = ImportStrategy.OVERWRITE,
                                onboardingMasterPwd = if (needsOnboardingMasterPwd) onboardingPwd1 else null
                            ) { ok ->
                                if (ok) onDismiss()
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun ImportFormatRow(p: SvPalette, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
            Text(subtitle, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(top = 2.dp))
        }
        Text("›", fontSize = 18.sp, color = p.fg.copy(alpha = 0.4f))
    }
}

@Composable
private fun StatBox(p: SvPalette, value: String, label: String, color: Color, modifier: Modifier = Modifier) {
    Surface(shape = RoundedCornerShape(12.dp), color = p.sub, border = BorderStroke(1.dp, p.border), modifier = modifier) {
        Column(modifier = Modifier.padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = color)
            Text(label, fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f))
        }
    }
}

@Composable
private fun StrategyRow(
    p: SvPalette,
    title: String,
    tag: String,
    desc: String,
    selected: Boolean,
    danger: Boolean,
    onClick: () -> Unit
) {
    val accent = if (danger) SvRose else SvIndigo
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (danger) SvRose else p.fg)
                if (tag.isNotEmpty()) {
                    Box(modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(accent.copy(alpha = 0.1f)).padding(horizontal = 6.dp, vertical = 2.dp)) {
                        Text(tag, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = accent)
                    }
                }
            }
            Text(desc, fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(top = 2.dp))
        }
        Box(
            modifier = Modifier
                .size(18.dp)
                .clip(CircleShape)
                .border(2.dp, if (selected) accent else Color(0x8094A3B8), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            if (selected) {
                Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(accent))
            }
        }
    }
}

@Composable
fun ExportFormatSheet(
    p: SvPalette,
    onDismiss: () -> Unit,
    onPickJson: () -> Unit,
    onPickKdbx: () -> Unit
) {
    SvActionSheet(p = p, onDismiss = onDismiss) {
        Text(t("导出加密备份"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Surface(shape = RoundedCornerShape(16.dp), color = p.sub, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
            Column {
                Text(
                    t("导出为 锁匣加密备份 (.json)"),
                    fontSize = 14.sp,
                    color = p.fg,
                    modifier = Modifier.fillMaxWidth().clickable { onDismiss(); onPickJson() }.padding(16.dp)
                )
                SvHairlineDivider(p)
                Text(
                    t("导出为 KeePass (.kdbx)"),
                    fontSize = 14.sp,
                    color = p.fg,
                    modifier = Modifier.fillMaxWidth().clickable { onDismiss(); onPickKdbx() }.padding(16.dp)
                )
            }
        }
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = p.sub,
            border = BorderStroke(1.dp, p.border),
            modifier = Modifier.fillMaxWidth().height(44.dp).clickable { onDismiss() }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(t("取消"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
            }
        }
    }
}

@Composable
fun KdbxExportPasswordDialog(
    p: SvPalette,
    onDismiss: () -> Unit,
    onEmptyPassword: () -> Unit = {},
    onConfirm: (String) -> Unit
) {
    var pwd by remember { mutableStateOf("") }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Surface(
                modifier = Modifier.widthIn(max = 310.dp).fillMaxWidth(0.86f),
                shape = RoundedCornerShape(24.dp),
                color = p.card,
                border = BorderStroke(1.dp, p.border),
                shadowElevation = 16.dp
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(t("设置 KeePass 导出密码"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center)
                    Text(t("输入用于加密 .kdbx 文件的密码"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.65f), textAlign = TextAlign.Center)
                    SvInputField(p, pwd, { pwd = it }, t("输入主密码"), isPassword = true)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = p.sub,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.weight(1f).height(40.dp).clickable { onDismiss() }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(t("取消"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                            }
                        }
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = SvIndigo,
                            modifier = Modifier.weight(1f).height(40.dp).clickable {
                                if (pwd.isNotEmpty()) onConfirm(pwd) else onEmptyPassword()
                            }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(t("确认"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                            }
                        }
                    }
                }
            }
            SvToastOverlay(bottomPadding = 24.dp)
        }
    }
}
