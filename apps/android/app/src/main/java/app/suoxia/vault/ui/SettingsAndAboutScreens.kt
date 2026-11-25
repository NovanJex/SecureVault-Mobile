package app.suoxia.vault.ui

import android.content.Intent
import android.net.Uri
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
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import app.suoxia.vault.i18n.t
import app.suoxia.vault.i18n.tf
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel

private const val MOBILE_REPO_URL = "https://github.com/NovanJex/SecureVault-Mobile"
private const val MOBILE_ISSUES_URL = "https://github.com/NovanJex/SecureVault-Mobile/issues"
private const val FEEDBACK_EMAIL = "feedback@suoxia.app"

@Composable
fun SettingsTabScreen(
    p: SvPalette,
    activity: FragmentActivity,
    vm: VaultViewModel,
    onOpenWebDav: () -> Unit,
    onOpenImport: () -> Unit,
    onOpenExport: () -> Unit
) {
    var showChangePwd by remember { mutableStateOf(false) }
    var showGestureSetup by remember { mutableStateOf(false) }
    var showAutoLockSheet by remember { mutableStateOf(false) }
    var showAbout by remember { mutableStateOf(false) }
    var pendingBioVerify by remember { mutableStateOf<(() -> Unit)?>(null) }

    val webdavHost = remember(vm.webdavUrl) {
        runCatching { java.net.URI(vm.webdavUrl).host ?: "" }.getOrDefault("")
    }
    val webdavSub = remember(vm.webdavConfigured, webdavHost, vm.webdavLastSync, vm.webdavAutoSync) {
        if (!vm.webdavConfigured) "" else {
            val syncPart = when {
                vm.webdavLastSync.isNotEmpty() -> "${t("上次同步")} ${vm.webdavLastSync}"
                vm.webdavAutoSync -> t("自动同步已开启")
                else -> t("手动同步")
            }
            if (webdavHost.isNotEmpty()) "$webdavHost · $syncPart" else syncPart
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(t("首选项"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)

        // Group 1: Security & Privacy
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                t("安全与隐私"),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = p.fg.copy(alpha = 0.55f),
                modifier = Modifier.padding(horizontal = 8.dp)
            )
            SvGroupedCard(p = p) {
                SettingsNavRow(p, t("修改主密码"), onClick = { showChangePwd = true })
                SvHairlineDivider(p)
                SettingsSwitchRow(
                    p = p,
                    title = t("应用锁"),
                    subtitle = t("开启后启动应用需验证身份"),
                    checked = vm.requireUnlock,
                    onCheckedChange = { enabled ->
                        vm.requireUnlock = enabled
                        vm.saveMeta()
                    }
                )
                if (vm.requireUnlock) {
                    SvHairlineDivider(p)
                    SettingsSwitchRow(
                        p = p,
                        title = t("面容识别"),
                        subtitle = t("设备支持时优先使用面容解锁"),
                        checked = vm.bioFaceOn,
                        onCheckedChange = { target ->
                            if (target) {
                                pendingBioVerify = {
                                    vm.bioFaceOn = true
                                    vm.saveMeta()
                                    vm.showToast("${t("面容识别")}${t("已开启")}")
                                }
                            } else {
                                vm.bioFaceOn = false
                                vm.saveMeta()
                            }
                        }
                    )
                    SvHairlineDivider(p)
                    SettingsSwitchRow(
                        p = p,
                        title = t("指纹识别"),
                        subtitle = t("面容不可用或失败时快速切换指纹"),
                        checked = vm.bioFingerOn,
                        onCheckedChange = { target ->
                            if (target) {
                                pendingBioVerify = {
                                    vm.bioFingerOn = true
                                    vm.saveMeta()
                                    vm.showToast("${t("指纹识别")}${t("已开启")}")
                                }
                            } else {
                                vm.bioFingerOn = false
                                vm.saveMeta()
                            }
                        }
                    )
                    SvHairlineDivider(p)
                    SettingsNavRow(
                        p = p,
                        title = t("手势密码"),
                        subtitle = t("绘制九宫格图案，作为快捷或备用解锁方式"),
                        trailingValue = if (vm.gestureOn) t("已开启") else t("未设置"),
                        onClick = { showGestureSetup = true }
                    )
                    SvHairlineDivider(p)
                    SettingsNavRow(
                        p = p,
                        title = t("自动锁定"),
                        trailingValue = t(vm.autoLock),
                        onClick = { showAutoLockSheet = true }
                    )
                }
                SvHairlineDivider(p)
                SettingsSwitchRow(
                    p = p,
                    title = t("防截屏与后台隐私保护"),
                    subtitle = t("禁止截屏录屏，切出应用时自动保护"),
                    checked = vm.privacyMask,
                    onCheckedChange = { enabled ->
                        vm.privacyMask = enabled
                        BiometricAndKeystoreManager.setPrivacyScreen(activity, enabled)
                        vm.saveMeta()
                    }
                )
            }
        }

        // Group 2: Sync & Backup
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                t("同步与备份"),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = p.fg.copy(alpha = 0.55f),
                modifier = Modifier.padding(horizontal = 8.dp)
            )
            SvGroupedCard(p = p) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenWebDav() }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                        Text(t("WebDAV 同步"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                        if (webdavSub.isNotEmpty()) {
                            Text(
                                webdavSub,
                                fontSize = 11.sp,
                                color = p.fg.copy(alpha = 0.55f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(top = 2.dp)
                            )
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (vm.webdavConfigured) {
                            Box(modifier = Modifier.size(6.dp).clip(CircleShape).background(SvEmerald))
                            Text(t("已连接"), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = SvEmerald)
                        } else {
                            Text(t("未配置"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.6f))
                        }
                        Text("›", fontSize = 18.sp, color = p.fg.copy(alpha = 0.4f))
                    }
                }
                SvHairlineDivider(p)
                SettingsNavRow(p, t("导入凭证"), trailingValue = "JSON / KDBX / CSV", onClick = onOpenImport)
                SvHairlineDivider(p)
                SettingsNavRow(p, t("导出加密备份"), onClick = onOpenExport)
            }
        }

        // Group 3: General (NO language switcher — follows system locale)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 16.dp)) {
            Text(
                t("通用"),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = p.fg.copy(alpha = 0.55f),
                modifier = Modifier.padding(horizontal = 8.dp)
            )
            SvGroupedCard(p = p) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(t("外观模式"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(p.sub)
                            .border(1.dp, p.border, RoundedCornerShape(10.dp))
                            .padding(2.dp)
                    ) {
                        listOf(false to t("浅色"), true to t("深色")).forEach { (darkOpt, lbl) ->
                            val on = vm.isDark == darkOpt
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (on) SvIndigo else Color.Transparent)
                                    .clickable {
                                        if (vm.isDark != darkOpt) {
                                            vm.isDark = darkOpt
                                            vm.saveMeta()
                                        }
                                    }
                                    .padding(horizontal = 12.dp, vertical = 5.dp)
                            ) {
                                Text(
                                    lbl,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = if (on) Color.White else p.fg.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
                SvHairlineDivider(p)
                SettingsNavRow(p, t("关于锁匣"), trailingValue = "v1.0.0", onClick = { showAbout = true })
            }
        }
    }

    if (showChangePwd) {
        ChangeMasterPwdSheet(p = p, vm = vm, onDismiss = { showChangePwd = false })
    }

    if (showGestureSetup) {
        GestureSetupSheet(p = p, vm = vm, onDismiss = { showGestureSetup = false })
    }

    if (showAutoLockSheet) {
        val options = listOf("切后台立即锁定", "1 分钟", "5 分钟", "15 分钟")
        SvActionSheet(p = p, onDismiss = { showAutoLockSheet = false }) {
            Text(t("自动锁定"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Surface(shape = RoundedCornerShape(16.dp), color = p.sub, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
                Column {
                    options.forEachIndexed { idx, opt ->
                        if (idx > 0) SvHairlineDivider(p)
                        val selected = vm.autoLock == opt
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    vm.autoLock = opt
                                    vm.saveMeta()
                                    showAutoLockSheet = false
                                }
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(t(opt), fontSize = 14.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal, color = if (selected) SvIndigo else p.fg)
                            if (selected) Text("✓", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = SvIndigo)
                        }
                    }
                }
            }
        }
    }

    pendingBioVerify?.let { onVerified ->
        VerifyPasswordSheet(
            p = p,
            vm = vm,
            onDismiss = { pendingBioVerify = null },
            onVerified = {
                pendingBioVerify = null
                onVerified()
            }
        )
    }

    if (showAbout) {
        AboutSheet(p = p, vm = vm, onDismiss = { showAbout = false })
    }
}

@Composable
private fun SettingsNavRow(
    p: SvPalette,
    title: String,
    subtitle: String? = null,
    trailingValue: String? = null,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
            if (!subtitle.isNullOrEmpty()) {
                Text(subtitle, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(top = 2.dp))
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (!trailingValue.isNullOrEmpty()) {
                Text(trailingValue, fontSize = 12.sp, color = p.fg.copy(alpha = 0.6f))
            }
            Text("›", fontSize = 18.sp, color = p.fg.copy(alpha = 0.4f))
        }
    }
}

@Composable
private fun SettingsSwitchRow(
    p: SvPalette,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
            Text(subtitle, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(top = 2.dp))
        }
        SvSwitch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
fun VerifyPasswordSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit,
    onVerified: () -> Unit
) {
    var pwd by remember { mutableStateOf("") }
    SvActionSheet(p = p, onDismiss = onDismiss) {
        Text(t("验证主密码"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Text(t("开启生物识别前需先验证当前主密码"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.6f), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        SvInputField(p = p, value = pwd, onValueChange = { pwd = it }, placeholder = t("输入当前主密码"), isPassword = true, height = 44.dp)
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = p.sub,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier.weight(1f).height(44.dp).clickable { onDismiss() }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(t("取消"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                }
            }
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = SvIndigo,
                modifier = Modifier.weight(1f).height(44.dp).clickable(enabled = !vm.isBusy) {
                    if (pwd.isEmpty()) {
                        vm.showToast(t("输入当前主密码"), true)
                    } else {
                        vm.verifyMasterPassword(pwd) { ok ->
                            if (ok) {
                                onVerified()
                            } else {
                                vm.showToast(t("主密码不正确"), true)
                            }
                        }
                    }
                }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        if (vm.isBusy) "..." else t("确认开启"),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@Composable
fun ChangeMasterPwdSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    var oldPwd by remember { mutableStateOf("") }
    var newPwd by remember { mutableStateOf("") }
    var confirmPwd by remember { mutableStateOf("") }

    SvPageSheet(
        p = p,
        title = t("修改主密码"),
        onDismiss = onDismiss,
        leftLabel = t("取消")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SvInputField(p, oldPwd, { oldPwd = it }, t("输入当前主密码"), label = t("当前主密码"), isPassword = true)
            SvInputField(p, newPwd, { newPwd = it }, t("至少 8 位"), label = t("新主密码"), isPassword = true)
            SvInputField(p, confirmPwd, { confirmPwd = it }, t("再次输入新主密码"), label = t("确认新主密码"), isPassword = true)
            Text(
                t("修改后将使用新密码重新加密本地数据；同步到云端后，其他设备需使用新主密码解锁。"),
                fontSize = 11.sp,
                color = p.fg.copy(alpha = 0.5f),
                lineHeight = 16.sp,
                modifier = Modifier.padding(horizontal = 4.dp)
            )
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = SvIndigo,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .clickable(enabled = !vm.isBusy) {
                        vm.changeMasterPassword(oldPwd, newPwd, confirmPwd) {
                            onDismiss()
                        }
                    }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        if (vm.isBusy) "..." else t("确认修改"),
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
fun AboutSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    val ctx = LocalContext.current
    var subPage by remember { mutableStateOf<String?>(null) }
    var externalLinkTarget by remember { mutableStateOf<Pair<String, String>?>(null) }

    val sheetTitle = when (subPage) {
        "privacy" -> t("隐私政策")
        "security" -> t("安全说明")
        "license" -> t("开源许可")
        "contact" -> t("联系我们")
        else -> t("关于锁匣")
    }

    SvPageSheet(
        p = p,
        title = sheetTitle,
        onDismiss = onDismiss,
        leftLabel = if (subPage != null) t("‹ 返回") else t("关闭"),
        onLeftClick = {
            if (subPage != null) subPage = null else onDismiss()
        }
    ) {
        BackHandler(enabled = subPage != null) {
            subPage = null
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            when (subPage) {
                "privacy" -> {
                    ReadingCard(p, null, "「锁匣 · SecureVault」是一款离线优先的本地密码管理工具。以下内容说明本应用如何保护你的数据与使用系统权限。", footnote = "更新日期：2026 年 11 月")
                    ReadingCard(p, "一、我们不收集你的个人数据", "本应用不设账号注册与登录体系，不运营任何官方云端服务器，也不会收集、上传或共享你的任何密码、账号、卡券、备忘录、两步验证密钥或设备使用行为。应用内不包含任何广告及第三方数据追踪工具。")
                    ReadingCard(p, "二、数据如何存储与保护", "你的全部敏感凭证仅在当前设备本地使用你的主密码完成加密，并保存在系统为应用分配的私有安全目录中。你的主密码仅由你本人掌握，应用及开发者均无法获取或重置你的主密码。")
                    ReadingCard(p, "三、自主云同步与文件导入导出", "本应用默认完全离线运行。仅当你主动配置并开启 WebDAV 同步时，应用才会连接你本人指定的网盘或 NAS 服务器，且仅传输已加密的备份文件，云盘服务商无法读取其中的任何内容。本地备份的导入与导出均在设备本地完成。")
                    ReadingCard(
                        p,
                        "四、系统权限使用说明",
                        "1. 相机权限：仅在你主动点击扫描二维码添加两步验证密钥时申请，不会在后台调用或保存任何画面。\n2. 面容 / 指纹识别：仅在你开启「应用锁」时由系统完成本地身份验证，应用无法获取你的生物特征信息。\n3. 网络权限：仅用于你主动配置的 WebDAV 同步与手动检查版本更新。",
                        footnote = "本应用不会申请定位、通讯录、短信、通话记录或后台常驻等无关权限。"
                    )
                    ReadingCard(p, "五、你的控制权与数据清除", "你对自己的数据拥有完全控制权，可随时在应用内编辑、导出、彻底删除任意凭证或断开 WebDAV 同步。卸载本应用时，系统将自动清除应用私有目录内的全部本地数据，请在卸载或换机前提前做好备份。")
                    ReadingCard(p, "六、政策更新与联系我们", "如因功能演进需要修订本隐私政策，我们会在应用内同步更新说明。如你对隐私与数据安全有任何疑问，欢迎通过「关于锁匣 → 联系我们」中的反馈邮箱或在线问题反馈与我们联系。")
                }

                "security" -> {
                    ReadingCard(p, null, "「锁匣 · SecureVault」以本地加密、离线可用、数据归你所有为核心原则。以下说明你的密码如何被保护及日常注意事项。")
                    ReadingCard(p, "一、本地高强度加密", "你存入的每一条账号、密码、银行卡、备忘和两步验证密钥，都会在当前设备本地使用你的主密码完成高强度加密后再保存。即使备份文件被他人获取，没有主密码也无法还原出任何内容。")
                    ReadingCard(p, "二、主密码无法找回", "本应用不会保存或上传你的主密码，也不存在「忘记密码」或人工重置通道。一旦遗忘主密码，本地和云端的加密数据都无法解开。请务必牢记主密码，或将其手写保存在家中安全位置。")
                    ReadingCard(p, "三、应用锁与防窥保护", "你可以在「首选项」中按需开启应用锁，支持系统面容、指纹与手势密码快速验证，并可设置切出后台后自动锁定。同时建议保持隐私保护开启，防止切后台或截屏时泄露敏感信息。")
                    ReadingCard(p, "四、多端加密同步", "开启 WebDAV 同步后，应用仅向你指定的个人网盘或 NAS 传输已加密的备份文件，且全程采用加密连接。网盘服务商无法读取其中的密码内容。手机端与电脑端连接同一地址并使用相同主密码即可双向同步。")
                    ReadingCard(p, "五、换机与卸载前请先备份", "卸载应用会导致系统清除应用私有目录内的全部本地数据。更换手机、刷机或卸载前，请先确认 WebDAV 已完成最新同步，或在「首选项 → 导出加密备份」中导出加密文件妥善留存。")
                    ReadingCard(p, "六、日常使用建议", "1. 及时清理明文文件：从浏览器导出的 CSV 密码表属于未加密明文，导入完成后请及时从手机或电脑中彻底删除。\n2. 保护好设备环境：尽量避免在已 Root 或越狱的设备上存放高敏感金融与核心账号。\n3. 定期更新重要密码：可借助「生成器」为重要账号生成高强度随机密码，避免多平台共用同一密码。")
                }

                "license" -> {
                    ReadingCard(p, null, "「锁匣 · SecureVault」遵循开源精神发布，核心加密与数据同步代码公开透明，欢迎任何人审阅与监督。")
                    Surface(shape = RoundedCornerShape(16.dp), color = p.card, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text("本应用许可协议", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg)
                                Box(modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(SvIndigo.copy(alpha = 0.1f)).padding(horizontal = 8.dp, vertical = 2.dp)) {
                                    Text("MIT License", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = SvIndigo)
                                }
                            }
                            Text("• 允许免费使用、复制、修改、合并、发布和分发本软件。\n• 再分发时需在副本中保留原作者的版权声明与本许可说明。\n• 本软件按「现状」提供，不附带任何明示或暗示的担保。", fontSize = 13.sp, lineHeight = 20.sp, color = p.fg.copy(alpha = 0.8f))
                            Text("Copyright © 2026 SecureVault Contributors", fontSize = 11.sp, color = p.fg.copy(alpha = 0.5f))
                        }
                    }
                    SvGroupedCard(p = p) {
                        Text("致谢 · 使用的开源组件", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg.copy(alpha = 0.55f), modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp))
                        val deps = listOf(
                            Triple("RustCrypto", "本地高强度加密与密钥派生支持", "MIT / Apache-2.0"),
                            Triple("keepass-rs", "KeePass (.kdbx) 数据库读写支持", "MIT"),
                            Triple("reqwest & rustls", "WebDAV 安全加密网络通信支持", "MIT / Apache-2.0"),
                            Triple("serde", "本地备份文件结构解析支持", "MIT / Apache-2.0"),
                            Triple("Jetpack Compose & Material 3", "Android 界面组件支持", "Apache-2.0")
                        )
                        deps.forEach { (name, desc, lic) ->
                            SvHairlineDivider(p)
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                                    Text(name, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                                    Text(desc, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                }
                                Text(lic, fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f))
                            }
                        }
                    }
                }

                "contact" -> {
                    ReadingCard(p, null, "如果你在使用「锁匣 · SecureVault」过程中遇到问题、有改进建议，或对隐私与数据安全存在疑问，欢迎通过以下方式联系我们。")
                    SvGroupedCard(p = p) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(t("反馈邮箱"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                Text(FEEDBACK_EMAIL, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                            }
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = p.sub,
                                border = BorderStroke(1.dp, p.border),
                                modifier = Modifier.clickable {
                                    BiometricAndKeystoreManager.copySensitive(ctx, t("反馈邮箱"), FEEDBACK_EMAIL)
                                    vm.showToast(tf("已复制%s", t("反馈邮箱")))
                                }
                            ) {
                                Text(t("复制"), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = p.fg, modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp))
                            }
                        }
                        SvHairlineDivider(p)
                        SettingsNavRow(
                            p = p,
                            title = t("在线问题反馈"),
                            subtitle = "提交使用问题、改进建议或隐私安全咨询",
                            onClick = { externalLinkTarget = t("在线问题反馈") to MOBILE_ISSUES_URL }
                        )
                    }
                    ReadingCard(p, t("反馈安全提醒"), "为保护你的数据安全，在发送邮件或提交反馈时，请勿附带你的主密码、账号密码、银行卡号或包含敏感信息的截图。")
                }

                else -> {
                    // Brand Header Card
                    Surface(shape = RoundedCornerShape(16.dp), color = p.card, border = BorderStroke(1.dp, p.border), modifier = Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(20.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(56.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(Brush.linearGradient(listOf(SvIndigo, SvViolet))),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Filled.Shield, null, tint = Color.White, modifier = Modifier.size(28.dp))
                            }
                            Text(t("锁匣 · SecureVault"), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = p.fg)
                            Text(t("本地加密密码管理器 · 手机与电脑加密同步"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f), textAlign = TextAlign.Center)
                        }
                    }

                    // 5 Info Rows
                    SvGroupedCard(p = p) {
                        SettingsNavRow(p, t("隐私政策"), onClick = { subPage = "privacy" })
                        SvHairlineDivider(p)
                        SettingsNavRow(p, t("安全说明"), onClick = { subPage = "security" })
                        SvHairlineDivider(p)
                        SettingsNavRow(p, t("开源许可"), onClick = { subPage = "license" })
                        SvHairlineDivider(p)
                        SettingsNavRow(p, t("联系我们"), onClick = { subPage = "contact" })
                        SvHairlineDivider(p)
                        SettingsNavRow(p, t("检查更新"), trailingValue = t("已是最新"), onClick = { vm.showToast(t("当前已是最新版本 v1.0.0")) })
                    }

                    // Footer
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(t("版本 v1.0.0"), fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f))
                        Text("  ·  ", fontSize = 11.sp, color = p.fg.copy(alpha = 0.55f))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.clickable {
                                externalLinkTarget = t("开源仓库") to MOBILE_REPO_URL
                            }
                        ) {
                            Icon(Icons.Outlined.Code, null, tint = p.fg.copy(alpha = 0.65f), modifier = Modifier.size(14.dp))
                            Text(t("开源地址"), fontSize = 11.sp, color = p.fg.copy(alpha = 0.65f))
                        }
                    }
                }
            }
        }
    }

    externalLinkTarget?.let { (label, url) ->
        SvConfirmDialog(
            p = p,
            title = tf("将在浏览器中打开%s", label),
            message = url,
            confirmText = t("前往打开"),
            isDestructive = false,
            onDismiss = { externalLinkTarget = null },
            onConfirm = {
                externalLinkTarget = null
                runCatching {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }
            }
        )
    }
}

@Composable
private fun ReadingCard(
    p: SvPalette,
    heading: String?,
    body: String,
    footnote: String? = null
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = p.card,
        border = BorderStroke(1.dp, p.border),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (!heading.isNullOrEmpty()) {
                Text(heading, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg)
            }
            Text(body, fontSize = 13.sp, lineHeight = 22.sp, color = p.fg.copy(alpha = 0.8f))
            if (!footnote.isNullOrEmpty()) {
                Text(footnote, fontSize = 11.sp, color = p.fg.copy(alpha = 0.5f), modifier = Modifier.padding(top = 2.dp))
            }
        }
    }
}
