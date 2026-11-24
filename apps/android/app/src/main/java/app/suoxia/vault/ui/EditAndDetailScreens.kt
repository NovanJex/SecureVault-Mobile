package app.suoxia.vault.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.suoxia.vault.bridge.RustCore
import app.suoxia.vault.i18n.t
import app.suoxia.vault.i18n.tf
import app.suoxia.vault.model.*
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel
import kotlinx.coroutines.delay

@Composable
fun DetailPage(
    p: SvPalette,
    vm: VaultViewModel,
    itemId: String,
    onBack: () -> Unit,
    onEdit: (VaultItem) -> Unit
) {
    BackHandler { onBack() }

    val ctx = LocalContext.current
    val item = vm.items.firstOrNull { it.id == itemId }
    if (item == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    var showSecret by remember(itemId) { mutableStateOf(false) }
    var showMoreSheet by remember { mutableStateOf(false) }
    var showTrashConfirm by remember { mutableStateOf(false) }
    var largeTypePwd by remember { mutableStateOf<String?>(null) }

    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(item.otpSecret) {
        if (item.otpSecret.isNotBlank()) {
            while (true) {
                delay(1000)
                tick++
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(p.bg)) {
        Column(modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            // Top Bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .padding(horizontal = 16.dp)
            ) {
                Text(
                    t("‹ 返回"),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = SvIndigo,
                    modifier = Modifier.align(Alignment.CenterStart).clickable { onBack() }.padding(vertical = 8.dp)
                )
                Text(
                    item.title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = p.fg,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.align(Alignment.Center).widthIn(max = 170.dp)
                )
                Row(
                    modifier = Modifier.align(Alignment.CenterEnd),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        t("编辑"),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = SvIndigo,
                        modifier = Modifier.clickable { onEdit(item) }.padding(horizontal = 4.dp, vertical = 6.dp)
                    )
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .clickable { showMoreSheet = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Filled.MoreHoriz, contentDescription = null, tint = SvIndigo, modifier = Modifier.size(18.dp))
                    }
                }
            }
            HorizontalDivider(thickness = 1.dp, color = p.hairline)

            // Scrollable Body
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Header card
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = p.card,
                    border = BorderStroke(1.dp, p.border),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        ItemAvatar(item)
                        Column(modifier = Modifier.weight(1f)) {
                            Text(item.title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = p.fg, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            val folderLbl = if (isDefaultFolder(item.folder)) t("默认") else item.folder
                            Text(
                                "$folderLbl · ${tf("更新于 %s", item.updatedAt.ifEmpty { "-" })}",
                                fontSize = 12.sp,
                                color = p.fg.copy(alpha = 0.55f)
                            )
                        }
                        IconButton(onClick = { vm.toggleFavorite(item.id) }) {
                            Icon(
                                imageVector = if (item.isFavorite) Icons.Filled.Star else Icons.Outlined.StarBorder,
                                contentDescription = null,
                                tint = if (item.isFavorite) Color(0xFFFBBF24) else p.fg.copy(alpha = 0.4f),
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                }

                // Type-specific Fields
                when (item.type) {
                    ItemType.CARD -> {
                        SvGroupedCard(p = p) {
                            if (item.cardName.isNotBlank()) {
                                DetailCopyRow(p, t("持卡人"), item.cardName) {
                                    BiometricAndKeystoreManager.copySensitive(ctx, t("持卡人"), item.cardName)
                                    vm.showToast(tf("已复制%s", t("持卡人")))
                                }
                                SvHairlineDivider(p)
                            }
                            DetailCopyRow(p, t("卡号"), item.cardNumber.ifEmpty { "-" }, monospace = true) {
                                BiometricAndKeystoreManager.copySensitive(ctx, t("卡号"), item.cardNumber)
                                vm.showToast(tf("已复制%s", t("卡号")))
                            }
                            SvHairlineDivider(p)
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(t("有效期"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                    Text(item.cardExpiry.ifEmpty { "-" }, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace, color = p.fg)
                                }
                                Row(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(t("安全码 CVV"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                        Text(
                                            if (showSecret) item.cardCvv.ifEmpty { "-" } else "•••",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            fontFamily = FontFamily.Monospace,
                                            color = p.fg
                                        )
                                    }
                                    Text(
                                        if (showSecret) t("隐藏") else t("显示"),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = SvIndigo,
                                        modifier = Modifier.clickable { showSecret = !showSecret }
                                    )
                                }
                            }
                        }
                    }

                    ItemType.NOTE -> {
                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = p.card,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(t("加密备忘正文"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                        Text(
                                            if (showSecret) t("隐藏") else t("查看"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = SvIndigo,
                                            modifier = Modifier.clickable { showSecret = !showSecret }
                                        )
                                        Text(
                                            t("复制"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = SvIndigo,
                                            modifier = Modifier.clickable {
                                                BiometricAndKeystoreManager.copySensitive(ctx, t("备忘"), item.notes)
                                                vm.showToast(tf("已复制%s", t("备忘")))
                                            }
                                        )
                                    }
                                }
                                Text(
                                    text = if (showSecret) item.notes.ifEmpty { t("无内容") } else "••••••••••••••••••••",
                                    fontSize = 14.sp,
                                    color = p.fg,
                                    lineHeight = 22.sp
                                )
                            }
                        }
                    }

                    ItemType.IDENTITY -> {
                        val rows = listOf(
                            t("姓名") to item.identityName,
                            t("邮箱") to item.identityEmail,
                            t("手机号") to item.identityPhone,
                            t("地址 / 证件信息") to item.identityAddress
                        ).filter { it.second.isNotBlank() }
                        SvGroupedCard(p = p) {
                            if (rows.isEmpty()) {
                                Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                                    Text(t("暂无身份详情"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                }
                            } else {
                                rows.forEachIndexed { idx, (lbl, value) ->
                                    if (idx > 0) SvHairlineDivider(p)
                                    DetailCopyRow(p, lbl, value) {
                                        BiometricAndKeystoreManager.copySensitive(ctx, lbl, value)
                                        vm.showToast(tf("已复制%s", lbl))
                                    }
                                }
                            }
                        }
                    }

                    ItemType.LOGIN -> {
                        SvGroupedCard(p = p) {
                            DetailCopyRow(p, t("账号"), item.username.ifEmpty { "-" }) {
                                BiometricAndKeystoreManager.copySensitive(ctx, t("账号"), item.username)
                                vm.showToast(tf("已复制%s", t("账号")))
                            }
                            SvHairlineDivider(p)
                            Column(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(t("密码"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                        Text(
                                            t("大字查看"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = SvIndigo,
                                            modifier = Modifier.clickable { largeTypePwd = item.password }
                                        )
                                        Text(
                                            if (showSecret) t("隐藏") else t("显示"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = SvIndigo,
                                            modifier = Modifier.clickable { showSecret = !showSecret }
                                        )
                                        Text(
                                            t("复制"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.SemiBold,
                                            color = SvIndigo,
                                            modifier = Modifier.clickable {
                                                BiometricAndKeystoreManager.copySensitive(ctx, t("密码"), item.password)
                                                vm.showToast(tf("已复制%s", t("密码")))
                                            }
                                        )
                                    }
                                }
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFF0F172A))
                                        .padding(12.dp)
                                ) {
                                    if (showSecret) {
                                        Text(
                                            text = colorizePasswordAnnotated(item.password),
                                            fontFamily = FontFamily.Monospace,
                                            fontSize = 14.sp
                                        )
                                    } else {
                                        Text("••••••••••••", color = Color.White, fontFamily = FontFamily.Monospace, fontSize = 14.sp)
                                    }
                                }
                            }
                            if (item.url.isNotBlank()) {
                                SvHairlineDivider(p)
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(t("网址"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                                        Text(item.url, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = SvIndigo, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    }
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = p.sub,
                                        border = BorderStroke(1.dp, p.border),
                                        modifier = Modifier.clickable {
                                            runCatching {
                                                val targetUrl = if (item.url.startsWith("http")) item.url else "https://${item.url}"
                                                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(targetUrl)))
                                            }
                                        }
                                    ) {
                                        Text(t("打开"), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = p.fg, modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp))
                                    }
                                }
                            }
                        }
                    }
                }

                // Live TOTP Card
                if (item.otpSecret.isNotBlank()) {
                    val (code, rem) = remember(tick, item.otpSecret) {
                        runCatching { RustCore.generateTotp(item.otpSecret) }.getOrDefault("------" to 30)
                    }
                    val formatted = if (code.length == 6) "${code.substring(0, 3)} ${code.substring(3)}" else code
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = p.card,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(t("两步动态验证码"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = SvIndigo)
                                Text(formatted, fontSize = 24.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = p.fg, letterSpacing = 1.sp)
                            }
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                val ringCol = if (rem <= 5) SvRose else SvIndigo
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .border(2.dp, ringCol, CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("${rem}s", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ringCol)
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(SvIndigo)
                                        .clickable {
                                            BiometricAndKeystoreManager.copySensitive(ctx, t("两步动态验证码"), code)
                                            vm.showToast(tf("已复制%s", t("两步动态验证码")))
                                        }
                                        .padding(horizontal = 14.dp, vertical = 8.dp)
                                ) {
                                    Text(t("复制"), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                // Notes (for non-note types)
                if (item.notes.isNotBlank() && item.type != ItemType.NOTE) {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = p.card,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(t("备注"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                            Text(item.notes, fontSize = 14.sp, color = p.fg, lineHeight = 20.sp)
                        }
                    }
                }

                // Password History (masked)
                if (item.passwordHistory.isNotEmpty()) {
                    SvGroupedCard(p = p) {
                        Text(
                            t("历史密码（已隐藏）"),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = p.fg.copy(alpha = 0.6f),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                        )
                        item.passwordHistory.forEach { h ->
                            SvHairlineDivider(p)
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("••••••••••••", fontFamily = FontFamily.Monospace, fontSize = 14.sp, color = p.fg)
                                    Text(tf("%s 修改", h.changedAt), fontSize = 11.sp, color = p.fg.copy(alpha = 0.5f))
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                    Text(
                                        t("复制"),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = SvIndigo,
                                        modifier = Modifier.clickable {
                                            BiometricAndKeystoreManager.copySensitive(ctx, t("密码"), h.password)
                                            vm.showToast(tf("已复制%s", t("密码")))
                                        }
                                    )
                                    Text(
                                        t("恢复"),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = SvIndigo,
                                        modifier = Modifier.clickable {
                                            vm.restorePasswordFromHistory(item.id, h.password)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Large Type Full-Screen Overlay
        largeTypePwd?.let { pwd ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xF2020617))
                    .clickable { largeTypePwd = null }
                    .padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Text(t("大字防混淆视图"), fontSize = 12.sp, color = Color(0xFF94A3B8), letterSpacing = 2.sp)
                    Text(
                        text = colorizePasswordAnnotated(pwd),
                        fontSize = 26.sp,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        lineHeight = 36.sp
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text(t("白色: 字母"), fontSize = 12.sp, color = Color(0xFF94A3B8))
                        Text(t("蓝色: 数字"), fontSize = 12.sp, color = Color(0xFF38BDF8))
                        Text(t("橙色: 符号"), fontSize = 12.sp, color = Color(0xFFFBBF24))
                    }
                    Text(t("轻触屏幕任意处关闭"), fontSize = 12.sp, color = Color(0xFF64748B))
                }
            }
        }
    }

    if (showMoreSheet) {
        SvActionSheet(p = p, onDismiss = { showMoreSheet = false }) {
            Text(item.title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = p.sub,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    Text(
                        if (item.isFavorite) t("取消星标") else t("设为星标"),
                        fontSize = 14.sp,
                        color = p.fg,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                vm.toggleFavorite(item.id)
                                showMoreSheet = false
                            }
                            .padding(16.dp)
                    )
                    SvHairlineDivider(p)
                    Text(
                        t("移入回收站"),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = SvRose,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                showMoreSheet = false
                                showTrashConfirm = true
                            }
                            .padding(16.dp)
                    )
                }
            }
        }
    }

    if (showTrashConfirm) {
        SvConfirmDialog(
            p = p,
            title = tf("将「%s」移入回收站？", item.title),
            message = t("移入后该凭证将从列表隐藏，30 天内可在回收站随时恢复。"),
            confirmText = t("确认移入"),
            isDestructive = true,
            onDismiss = { showTrashConfirm = false },
            onConfirm = {
                showTrashConfirm = false
                vm.moveToTrash(item.id)
                onBack()
            }
        )
    }
}

@Composable
private fun DetailCopyRow(
    p: SvPalette,
    label: String,
    value: String,
    monospace: Boolean = false,
    onCopy: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
            Text(label, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
            Text(
                value,
                fontSize = 14.sp,
                fontWeight = if (monospace) FontWeight.SemiBold else FontWeight.Medium,
                fontFamily = if (monospace) FontFamily.Monospace else FontFamily.Default,
                color = p.fg
            )
        }
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = p.sub,
            border = BorderStroke(1.dp, p.border),
            modifier = Modifier.clickable { onCopy() }
        ) {
            Text(t("复制"), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = p.fg, modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EditCredentialSheet(
    p: SvPalette,
    vm: VaultViewModel,
    existing: VaultItem?,
    scannedOtpSecret: String?,
    onConsumeScannedOtp: () -> Unit,
    onRequestQrScan: () -> Unit,
    onDismiss: () -> Unit
) {
    val isNew = existing == null
    var itemType by remember { mutableStateOf(existing?.type ?: ItemType.LOGIN) }
    var title by remember { mutableStateOf(existing?.title ?: "") }
    var folder by remember {
        mutableStateOf(
            existing?.folder?.let { normalizeFolderName(it) }
                ?: if (vm.activeFolder != ALL_FOLDERS) vm.activeFolder else DEFAULT_FOLDER
        )
    }
    var username by remember { mutableStateOf(existing?.username ?: "") }
    var password by remember { mutableStateOf(existing?.password ?: "") }
    var url by remember { mutableStateOf(existing?.url ?: "") }
    var otpSecret by remember { mutableStateOf(existing?.otpSecret ?: "") }
    var cardName by remember { mutableStateOf(existing?.cardName ?: "") }
    var cardNumber by remember { mutableStateOf(existing?.cardNumber ?: "") }
    var cardExpiry by remember { mutableStateOf(existing?.cardExpiry ?: "") }
    var cardCvv by remember { mutableStateOf(existing?.cardCvv ?: "") }
    var idName by remember { mutableStateOf(existing?.identityName ?: "") }
    var idEmail by remember { mutableStateOf(existing?.identityEmail ?: "") }
    var idPhone by remember { mutableStateOf(existing?.identityPhone ?: "") }
    var idAddr by remember { mutableStateOf(existing?.identityAddress ?: "") }
    var notes by remember { mutableStateOf(existing?.notes ?: "") }

    var showQuickGen by remember { mutableStateOf(false) }

    LaunchedEffect(scannedOtpSecret) {
        if (!scannedOtpSecret.isNullOrBlank()) {
            otpSecret = scannedOtpSecret
            onConsumeScannedOtp()
        }
    }

    val titlePlaceholder = when (itemType) {
        ItemType.LOGIN -> t("例如：GitHub、微信")
        ItemType.CARD -> t("例如：招商银行信用卡")
        ItemType.NOTE -> t("例如：服务器恢复秘钥")
        ItemType.IDENTITY -> t("例如：个人常用身份")
    }

    SvPageSheet(
        p = p,
        title = if (isNew) t("新建凭证") else t("编辑凭证"),
        onDismiss = onDismiss,
        leftLabel = t("取消"),
        rightAction = {
            Text(
                t("保存"),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SvIndigo,
                modifier = Modifier.clickable {
                    if (title.trim().isEmpty()) {
                        vm.showToast(t("请填写标题"), true)
                        return@clickable
                    }
                    val draft = VaultItem(
                        id = existing?.id ?: System.currentTimeMillis().toString(),
                        type = itemType,
                        title = title.trim(),
                        folder = folder,
                        username = username,
                        password = password,
                        url = url,
                        cardName = cardName,
                        cardNumber = cardNumber,
                        cardExpiry = cardExpiry,
                        cardCvv = cardCvv,
                        identityName = idName,
                        identityEmail = idEmail,
                        identityPhone = idPhone,
                        identityAddress = idAddr,
                        notes = notes,
                        otpSecret = otpSecret,
                        isFavorite = existing?.isFavorite ?: false,
                        passwordHistory = existing?.passwordHistory ?: emptyList(),
                        rawJson = existing?.rawJson
                    )
                    vm.saveItem(draft, isNew)
                    onDismiss()
                }
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 460.dp)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Sliding-thumb Segmented Control
            val typeOrder = ItemType.entries
            val selectedIdx = typeOrder.indexOf(itemType).coerceAtLeast(0)
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (p.isDark) Color(0xE61E293B) else Color(0xB3E2E8F0))
                    .padding(4.dp)
            ) {
                val segWidth = maxWidth / typeOrder.size
                val thumbOffset by animateDpAsState(
                    targetValue = segWidth * selectedIdx,
                    animationSpec = tween(180),
                    label = "segThumb"
                )
                Surface(
                    shape = RoundedCornerShape(9.dp),
                    color = if (p.isDark) Color(0xFF334155) else Color.White,
                    shadowElevation = 1.dp,
                    modifier = Modifier
                        .offset(x = thumbOffset)
                        .width(segWidth)
                        .height(30.dp)
                ) {}
                Row(modifier = Modifier.fillMaxWidth().height(30.dp)) {
                    typeOrder.forEach { typ ->
                        val on = typ == itemType
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null
                                ) { itemType = typ },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = t(typ.label),
                                fontSize = 12.sp,
                                fontWeight = if (on) FontWeight.SemiBold else FontWeight.Medium,
                                color = when {
                                    on && p.isDark -> Color.White
                                    on -> SvIndigo
                                    else -> p.fg.copy(alpha = 0.6f)
                                }
                            )
                        }
                    }
                }
            }

            // Title
            SvInputField(
                p = p,
                value = title,
                onValueChange = { title = it },
                placeholder = titlePlaceholder,
                label = t("标题 *")
            )

            // Folder Chips
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    modifier = Modifier.padding(horizontal = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(Icons.Outlined.Folder, null, tint = p.fg.copy(alpha = 0.6f), modifier = Modifier.size(13.dp))
                    Text(t("存放文件夹"), fontSize = 11.sp, color = p.fg.copy(alpha = 0.6f))
                }
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    val allFolderChoices = listOf(DEFAULT_FOLDER) + vm.folders
                    allFolderChoices.forEach { f ->
                        val on = folder == f
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (on) SvIndigo.copy(alpha = 0.1f) else p.card,
                            border = BorderStroke(1.dp, if (on) SvIndigo.copy(alpha = 0.4f) else p.border),
                            modifier = Modifier.clickable { folder = f }
                        ) {
                            Text(
                                text = if (f == DEFAULT_FOLDER) t("默认") else f,
                                fontSize = 12.sp,
                                fontWeight = if (on) FontWeight.SemiBold else FontWeight.Medium,
                                color = if (on) SvIndigo else p.fg.copy(alpha = 0.8f),
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }
                }
            }

            // Type-specific fields (in-place switch, no divider lines)
            when (itemType) {
                ItemType.LOGIN -> {
                    SvInputField(p, username, { username = it }, t("输入登录账号或邮箱"), label = t("账号 / 邮箱"))
                    SvInputField(
                        p = p,
                        value = password,
                        onValueChange = { password = it },
                        placeholder = t("输入登录密码"),
                        label = t("密码"),
                        labelEnd = {
                            Text(
                                t("生成强密码"),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = SvIndigo,
                                modifier = Modifier.clickable { showQuickGen = true }
                            )
                        },
                        isPassword = true,
                        initiallyVisible = isNew,
                        monospace = true
                    )
                    SvInputField(p, url, { url = it }, "https://...", label = t("网址 / 域名（可选）"))
                    SvInputField(
                        p = p,
                        value = otpSecret,
                        onValueChange = { otpSecret = it },
                        placeholder = t("输入或扫码填入动态密钥"),
                        label = t("两步验证密钥（可选）"),
                        labelEnd = {
                            Text(
                                t("相机扫码"),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = SvIndigo,
                                modifier = Modifier.clickable { onRequestQrScan() }
                            )
                        },
                        monospace = true
                    )
                    SvTextAreaField(p, notes, { notes = it }, t("补充安全提示或恢复说明..."), label = t("备注（可选）"))
                }

                ItemType.CARD -> {
                    SvInputField(p, cardName, { cardName = it }, t("卡片上的姓名拼音或中文"), label = t("持卡人姓名"))
                    SvInputField(p, cardNumber, { cardNumber = it }, t("输入银行卡号"), label = t("卡号 *"), monospace = true)
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        SvInputField(p, cardExpiry, { cardExpiry = it }, "MM/YY", label = t("有效期"), monospace = true, modifier = Modifier.weight(1f))
                        SvInputField(p, cardCvv, { cardCvv = it }, t("3-4 位数字"), label = t("安全码 CVV"), isPassword = true, monospace = true, modifier = Modifier.weight(1f))
                    }
                    SvTextAreaField(p, notes, { notes = it }, t("补充安全提示或恢复说明..."), label = t("备注（可选）"))
                }

                ItemType.NOTE -> {
                    SvTextAreaField(
                        p = p,
                        value = notes,
                        onValueChange = { notes = it },
                        placeholder = t("输入需要加密保存的文本、助记信息或密钥片段..."),
                        label = t("加密备忘正文 *"),
                        minHeight = 160.dp
                    )
                }

                ItemType.IDENTITY -> {
                    SvInputField(p, idName, { idName = it }, t("真实姓名或常用昵称"), label = t("姓名"))
                    SvInputField(p, idEmail, { idEmail = it }, "name@example.com", label = t("邮箱"))
                    SvInputField(p, idPhone, { idPhone = it }, t("手机号码"), label = t("手机号"), monospace = true)
                    SvInputField(p, idAddr, { idAddr = it }, t("居住地址、身份证号或密保问题"), label = t("地址 / 证件信息"))
                    SvTextAreaField(p, notes, { notes = it }, t("补充安全提示或恢复说明..."), label = t("备注（可选）"))
                }
            }
        }
    }

    if (showQuickGen) {
        QuickGenSheet(
            p = p,
            onDismiss = { showQuickGen = false },
            onUse = { generated ->
                password = generated
                showQuickGen = false
                vm.showToast(t("已填入生成的随机密码"))
            }
        )
    }
}

@Composable
fun QuickGenSheet(
    p: SvPalette,
    onDismiss: () -> Unit,
    onUse: (String) -> Unit
) {
    var pwd by remember { mutableStateOf(RustCore.generatePassword(18, true, true, true, true, true)) }

    SvActionSheet(p = p, onDismiss = onDismiss) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(t("快速生成密码"), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = p.fg)
            Text(
                t("换一个"),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SvIndigo,
                modifier = Modifier.clickable {
                    pwd = RustCore.generatePassword(18, true, true, true, true, true)
                }
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color(0xFF0F172A))
                .padding(16.dp)
        ) {
            Text(
                text = colorizePasswordAnnotated(pwd),
                fontFamily = FontFamily.Monospace,
                fontSize = 16.sp,
                lineHeight = 24.sp
            )
        }
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = SvIndigo,
            modifier = Modifier
                .fillMaxWidth()
                .height(46.dp)
                .clickable { onUse(pwd) }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(t("使用此密码"), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
