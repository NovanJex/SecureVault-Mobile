package app.suoxia.vault.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
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
import app.suoxia.vault.model.StandaloneTotp
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel
import kotlinx.coroutines.delay

@Composable
fun TotpTabScreen(
    p: SvPalette,
    vm: VaultViewModel,
    onAddToken: () -> Unit
) {
    val ctx = LocalContext.current
    var tick by remember { mutableIntStateOf(0) }
    var deleteTarget by remember { mutableStateOf<StandaloneTotp?>(null) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            tick++
        }
    }

    val filtered = remember(vm.standaloneTotps, vm.totpSearch) {
        val q = vm.totpSearch.trim().lowercase()
        vm.standaloneTotps.filter {
            q.isEmpty() || it.issuer.lowercase().contains(q) || it.account.lowercase().contains(q)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(t("验证器"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)
                    Text(tf("共 %d 个动态令牌", vm.standaloneTotps.size), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                }
                SvSearchBar(
                    p = p,
                    value = vm.totpSearch,
                    onValueChange = { vm.totpSearch = it },
                    placeholder = t("搜索令牌名称或备注账号")
                )
            }

            if (vm.standaloneTotps.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(horizontal = 24.dp, vertical = 64.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(t("暂无动态令牌"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                    Text(
                        t("点击右下角 + 扫描二维码或输入密钥，添加两步验证码。"),
                        fontSize = 12.sp,
                        color = p.fg.copy(alpha = 0.55f),
                        textAlign = TextAlign.Center,
                        lineHeight = 18.sp
                    )
                }
            } else if (filtered.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(top = 56.dp),
                    contentAlignment = Alignment.TopCenter
                ) {
                    Text(t("未找到匹配的令牌"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.5f))
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 84.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(filtered, key = { it.id }) { token ->
                        val (code, rem) = remember(tick, token.secret) {
                            runCatching { RustCore.generateTotp(token.secret) }.getOrDefault("------" to 30)
                        }
                        val formatted = if (code.length == 6) "${code.substring(0, 3)} ${code.substring(3)}" else code
                        val ringColor = if (rem <= 5) SvRose else SvIndigo

                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = p.card,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    BiometricAndKeystoreManager.copySensitive(ctx, token.issuer, code)
                                    vm.showToast(tf("已复制%s", token.issuer))
                                }
                        ) {
                            Row(
                                modifier = Modifier.padding(16.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
                                    Text(token.issuer, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    Text(
                                        token.account.ifEmpty { t("动态令牌") },
                                        fontSize = 12.sp,
                                        color = p.fg.copy(alpha = 0.55f),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        formatted,
                                        fontSize = 24.sp,
                                        fontWeight = FontWeight.Bold,
                                        fontFamily = FontFamily.Monospace,
                                        color = SvIndigo,
                                        letterSpacing = 1.sp,
                                        modifier = Modifier.padding(top = 4.dp)
                                    )
                                }
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Box(
                                        modifier = Modifier
                                            .size(40.dp)
                                            .clip(CircleShape)
                                            .border(2.dp, ringColor, CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text("${rem}s", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ringColor)
                                    }
                                    Box(
                                        modifier = Modifier
                                            .size(32.dp)
                                            .clip(CircleShape)
                                            .clickable { deleteTarget = token },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(Icons.Outlined.Delete, contentDescription = t("删除"), tint = SvRose.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = onAddToken,
            shape = CircleShape,
            containerColor = SvIndigo,
            contentColor = Color.White,
            elevation = FloatingActionButtonDefaults.elevation(defaultElevation = 6.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
                .size(48.dp)
        ) {
            Icon(Icons.Filled.Add, contentDescription = t("添加动态令牌"), modifier = Modifier.size(22.dp))
        }
    }

    deleteTarget?.let { tok ->
        SvConfirmDialog(
            p = p,
            title = tf("移除「%s」？", tok.issuer),
            message = t("移除后将无法再通过此令牌生成两步验证码，请确认对应平台已解绑。"),
            confirmText = t("确认移除"),
            isDestructive = true,
            onDismiss = { deleteTarget = null },
            onConfirm = {
                vm.deleteStandaloneTotp(tok.id)
                deleteTarget = null
            }
        )
    }
}

@Composable
fun AddTotpSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onScanQr: () -> Unit,
    onDismiss: () -> Unit
) {
    var issuer by remember { mutableStateOf("") }
    var account by remember { mutableStateOf("") }
    var secret by remember { mutableStateOf("") }

    SvPageSheet(
        p = p,
        title = t("添加动态令牌"),
        onDismiss = onDismiss,
        leftLabel = t("取消"),
        rightAction = {
            Text(
                t("保存"),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SvIndigo,
                modifier = Modifier.clickable {
                    if (vm.addStandaloneTotp(issuer, account, secret)) {
                        onDismiss()
                    }
                }
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Gradient QR button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(SvIndigo, SvViolet)))
                    .clickable { onScanQr() }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.16f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Filled.QrCodeScanner, null, tint = Color.White, modifier = Modifier.size(20.dp))
                    }
                    Column {
                        Text(t("扫描二维码快速添加"), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        Text(t("对准服务商二维码自动识别"), color = Color.White.copy(alpha = 0.8f), fontSize = 12.sp)
                    }
                }
                Text("›", color = Color.White.copy(alpha = 0.85f), fontSize = 18.sp)
            }

            // Divider
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                HorizontalDivider(modifier = Modifier.weight(1f), color = p.fg.copy(alpha = 0.15f))
                Text(t("手动输入密钥"), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = p.fg.copy(alpha = 0.5f))
                HorizontalDivider(modifier = Modifier.weight(1f), color = p.fg.copy(alpha = 0.15f))
            }

            SvInputField(p, issuer, { issuer = it }, t("例如：GitHub、Steam、Apple"), label = t("服务 / 令牌名称 *"))
            SvInputField(p, account, { account = it }, "name@example.com", label = t("备注账号或说明（可选）"))
            SvInputField(p, secret, { secret = it }, t("输入服务商提供的两步验证密钥"), label = t("动态密钥 *"), monospace = true)

            Text(
                t("适用于仅需动态验证码的场景；若需与账号密码绑定，可在「保险箱」内编辑配置。"),
                fontSize = 11.sp,
                color = p.fg.copy(alpha = 0.5f),
                lineHeight = 16.sp,
                modifier = Modifier.padding(horizontal = 4.dp)
            )
        }
    }
}

@Composable
fun GeneratorTabScreen(
    p: SvPalette,
    vm: VaultViewModel
) {
    val ctx = LocalContext.current
    var mode by remember { mutableStateOf("random") }
    var length by remember { mutableIntStateOf(18) }
    var upper by remember { mutableStateOf(true) }
    var lower by remember { mutableStateOf(true) }
    var numbers by remember { mutableStateOf(true) }
    var symbols by remember { mutableStateOf(true) }
    var excludeAmbiguous by remember { mutableStateOf(true) }

    var bipWords by remember { mutableIntStateOf(5) }
    var bipSep by remember { mutableStateOf("-") }
    var bipCap by remember { mutableStateOf(true) }

    var showClearConfirm by remember { mutableStateOf(false) }

    fun nextPassword(): String {
        val out = if (mode == "random") {
            RustCore.generatePassword(length, upper, lower, numbers, symbols, excludeAmbiguous)
        } else {
            RustCore.generateBip39(bipWords, bipSep, bipCap)
        }
        vm.addGenHistory(out)
        return out
    }

    var currentPwd by remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        if (currentPwd.isEmpty()) currentPwd = nextPassword()
    }

    val strengthBadge = if (mode == "random") {
        val score = (length * 5.9).toInt()
        when {
            score >= 90 -> t("密码强度：极强")
            score >= 65 -> t("密码强度：高")
            else -> t("密码强度：中等")
        }
    } else {
        if (bipWords * 11 >= 66) t("密码强度：极强") else t("密码强度：高")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Header + mode toggle
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(t("生成器"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0x2664748B))
                    .padding(2.dp)
            ) {
                listOf("random" to t("随机密码"), "bip39" to t("助记词")).forEach { (key, lbl) ->
                    val on = mode == key
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (on) Color.White else Color.Transparent)
                            .clickable {
                                if (mode != key) {
                                    mode = key
                                    currentPwd = nextPassword()
                                }
                            }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text(
                            lbl,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = if (on) Color(0xFF0F172A) else p.fg.copy(alpha = 0.7f)
                        )
                    }
                }
            }
        }

        // Output card
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = Color(0xFF0F172A),
            border = BorderStroke(1.dp, Color(0xFF1E293B)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = colorizePasswordAnnotated(currentPwd),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp)
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(SvEmerald.copy(alpha = 0.2f))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(strengthBadge, color = Color(0xFF6EE7B7), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(0xFF1E293B))
                                .clickable { currentPwd = nextPassword() }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(t("换一个"), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        }
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(SvIndigo)
                                .clickable {
                                    BiometricAndKeystoreManager.copySensitive(ctx, t("密码"), currentPwd)
                                    vm.showToast(tf("已复制%s", t("密码")))
                                }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(t("复制"), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // Controls card
        SvGroupedCard(p = p) {
            if (mode == "random") {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(t("密码长度"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                        Text(length.toString(), fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = SvIndigo)
                    }
                    Slider(
                        value = length.toFloat(),
                        onValueChange = {
                            length = it.toInt()
                            currentPwd = nextPassword()
                        },
                        valueRange = 8f..48f,
                        colors = SliderDefaults.colors(thumbColor = SvIndigo, activeTrackColor = SvIndigo)
                    )
                }
                val toggles = listOf(
                    Triple(t("大写字母 (A-Z)"), upper) { v: Boolean -> upper = v; currentPwd = nextPassword() },
                    Triple(t("小写字母 (a-z)"), lower) { v: Boolean -> lower = v; currentPwd = nextPassword() },
                    Triple(t("数字 (0-9)"), numbers) { v: Boolean -> numbers = v; currentPwd = nextPassword() },
                    Triple(t("特殊符号 (!@#\$%)"), symbols) { v: Boolean -> symbols = v; currentPwd = nextPassword() },
                    Triple(t("排除易混淆字符 (0/O, 1/l/I)"), excludeAmbiguous) { v: Boolean -> excludeAmbiguous = v; currentPwd = nextPassword() }
                )
                toggles.forEach { (lbl, checked, onChange) ->
                    SvHairlineDivider(p)
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(lbl, fontSize = 14.sp, color = p.fg, modifier = Modifier.weight(1f))
                        SvSwitch(checked = checked, onCheckedChange = onChange)
                    }
                }
            } else {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(t("助记词数量"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                        Text(tf("%d 词", bipWords), fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = SvIndigo)
                    }
                    Slider(
                        value = bipWords.toFloat(),
                        onValueChange = {
                            bipWords = it.toInt()
                            currentPwd = nextPassword()
                        },
                        valueRange = 3f..10f,
                        steps = 6,
                        colors = SliderDefaults.colors(thumbColor = SvIndigo, activeTrackColor = SvIndigo)
                    )
                }
                SvHairlineDivider(p)
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(t("分隔符"), fontSize = 14.sp, color = p.fg)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(p.sub)
                            .border(1.dp, p.border, RoundedCornerShape(12.dp))
                            .padding(4.dp),
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        listOf("-" to t("连字符 -"), "_" to t("下划线 _"), "." to t("点号 ."), " " to t("空格")).forEach { (sep, lbl) ->
                            val on = bipSep == sep
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (on) SvIndigo else Color.Transparent)
                                    .clickable {
                                        bipSep = sep
                                        currentPwd = nextPassword()
                                    }
                                    .padding(vertical = 6.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(lbl, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = if (on) Color.White else p.fg.copy(alpha = 0.7f), maxLines = 1)
                            }
                        }
                    }
                }
                SvHairlineDivider(p)
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(t("单词首字母大写"), fontSize = 14.sp, color = p.fg)
                    SvSwitch(checked = bipCap, onCheckedChange = { bipCap = it; currentPwd = nextPassword() })
                }
            }
        }

        // Recent History
        Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(t("最近生成"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg.copy(alpha = 0.6f))
                if (vm.genHistory.isNotEmpty()) {
                    Text(
                        t("清空"),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = SvRose,
                        modifier = Modifier.clickable { showClearConfirm = true }
                    )
                }
            }
            SvGroupedCard(p = p) {
                if (vm.genHistory.isEmpty()) {
                    Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                        Text(t("暂无记录"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.45f))
                    }
                } else {
                    vm.genHistory.forEachIndexed { idx, hPwd ->
                        if (idx > 0) SvHairlineDivider(p)
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                hPwd,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                color = p.fg,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f).padding(end = 12.dp)
                            )
                            Text(
                                t("复制"),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = SvIndigo,
                                modifier = Modifier.clickable {
                                    BiometricAndKeystoreManager.copySensitive(ctx, t("密码"), hPwd)
                                    vm.showToast(tf("已复制%s", t("密码")))
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    if (showClearConfirm) {
        SvConfirmDialog(
            p = p,
            title = t("清空最近生成记录？"),
            message = t("清空后将无法找回此前生成的临时密码，请确认重要密码已保存至保险箱。"),
            confirmText = t("确认清空"),
            isDestructive = true,
            onDismiss = { showClearConfirm = false },
            onConfirm = {
                vm.clearGenHistory()
                showClearConfirm = false
            }
        )
    }
}
