package app.suoxia.vault.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.CloudDownload
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import app.suoxia.vault.i18n.t
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel

@Composable
fun OnboardingScreen(
    p: SvPalette,
    vm: VaultViewModel,
    onOpenWebDavRestore: () -> Unit,
    onOpenImport: () -> Unit
) {
    var showCreate by remember { mutableStateOf(false) }
    var showRestore by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.SpaceBetween,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Brand Hero
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(top = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(modifier = Modifier.size(96.dp), contentAlignment = Alignment.Center) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape)
                        .background(SvIndigo.copy(alpha = 0.12f))
                )
                Box(
                    modifier = Modifier
                        .size(76.dp)
                        .clip(CircleShape)
                        .background(SvIndigo.copy(alpha = 0.16f))
                )
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(listOf(SvIndigo, SvViolet))),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Filled.Shield, contentDescription = null, tint = Color.White, modifier = Modifier.size(28.dp))
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(t("锁匣 · SecureVault"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)
                Text(
                    t("本地加密密码管理器 · 手机与电脑安全同步"),
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center
                )
            }
        }

        // 3 Feature Cards
        Column(
            modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            listOf(
                Triple(Icons.Filled.Lock, SvIndigo, t("本地离线加密") to t("不设官方服务器，主密码仅由你本人掌握")),
                Triple(Icons.Filled.Cloud, SvSky, t("自主多端同步") to t("连接个人网盘或 NAS，手机与电脑加密互通")),
                Triple(Icons.Filled.Fingerprint, SvEmerald, t("灵活应用锁") to t("支持面容、指纹与手势密码，按需自由开启"))
            ).forEach { (icon, tint, pair) ->
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = p.card,
                    border = BorderStroke(1.dp, p.border),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(tint.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(pair.first, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                            Text(pair.second, fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f), lineHeight = 16.sp)
                        }
                    }
                }
            }
        }

        // Bottom CTAs
        Column(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            SvGradientButton(
                text = t("创建新保险箱"),
                onClick = { showCreate = true },
                radius = 999.dp
            )
            Surface(
                shape = CircleShape,
                color = p.card,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .clickable { showRestore = true }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(t("从备份恢复或导入"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                }
            }
        }
    }

    if (showCreate) {
        CreateVaultSheet(
            p = p,
            vm = vm,
            onDismiss = { showCreate = false }
        )
    }

    if (showRestore) {
        SvActionSheet(p = p, onDismiss = { showRestore = false }) {
            Text(
                t("选择恢复方式"),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = p.fg,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = p.sub,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                showRestore = false
                                onOpenWebDavRestore()
                            }
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Box(
                                modifier = Modifier.size(36.dp).clip(CircleShape).background(SvIndigo.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Outlined.CloudDownload, null, tint = SvIndigo, modifier = Modifier.size(18.dp))
                            }
                            Column {
                                Text(t("从 WebDAV 云端恢复"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                                Text(t("从网盘或 NAS 恢复已同步的数据"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                            }
                        }
                        Text("›", fontSize = 18.sp, color = p.fg.copy(alpha = 0.4f))
                    }
                    SvHairlineDivider(p)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                showRestore = false
                                onOpenImport()
                            }
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Box(
                                modifier = Modifier.size(36.dp).clip(CircleShape).background(SvEmerald.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Outlined.UploadFile, null, tint = SvEmerald, modifier = Modifier.size(18.dp))
                            }
                            Column {
                                Text(t("导入本地备份文件"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                                Text(t("支持 JSON 备份 / KeePass (.kdbx) / CSV"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                            }
                        }
                        Text("›", fontSize = 18.sp, color = p.fg.copy(alpha = 0.4f))
                    }
                }
            }
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = p.sub,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier.fillMaxWidth().height(46.dp).clickable { showRestore = false }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(t("取消"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = p.fg)
                }
            }
        }
    }
}

@Composable
fun CreateVaultSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    var pwd1 by remember { mutableStateOf("") }
    var pwd2 by remember { mutableStateOf("") }

    val (strLabel, strColor) = remember(pwd1) {
        if (pwd1.isEmpty()) {
            "" to Color.Transparent
        } else {
            var score = 0
            if (pwd1.length >= 8) score++
            if (pwd1.length >= 12) score++
            val kinds = listOf(
                pwd1.any { it.isLowerCase() },
                pwd1.any { it.isUpperCase() },
                pwd1.any { it.isDigit() },
                pwd1.any { !it.isLetterOrDigit() }
            ).count { it }
            if (kinds >= 2) score++
            if (kinds >= 3) score++
            when {
                pwd1.length < 8 || score <= 1 -> t("强度：偏弱") to SvRose
                score <= 2 -> t("强度：中等") to SvAmber
                else -> t("强度：高") to SvEmerald
            }
        }
    }

    val mismatch = pwd2.isNotEmpty() && pwd1 != pwd2
    val matched = pwd2.isNotEmpty() && pwd1 == pwd2

    SvPageSheet(
        p = p,
        title = t("创建新保险箱"),
        onDismiss = onDismiss,
        leftLabel = t("取消")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Column(modifier = Modifier.padding(horizontal = 4.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(t("设置主密码"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                Text(
                    t("用于本地加密你的全部凭证，建议包含字母、数字与符号。"),
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.6f),
                    lineHeight = 18.sp
                )
            }

            SvInputField(
                p = p,
                value = pwd1,
                onValueChange = { pwd1 = it },
                placeholder = t("输入高强度主密码"),
                label = t("主密码（至少 8 位）"),
                labelEnd = {
                    Text(
                        text = strLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = strColor
                    )
                },
                isPassword = true
            )

            SvInputField(
                p = p,
                value = pwd2,
                onValueChange = { pwd2 = it },
                placeholder = t("再次输入以确认"),
                label = t("确认主密码"),
                labelEnd = {
                    val txt = when {
                        mismatch -> t("两次输入不一致")
                        matched -> t("✓ 一致")
                        else -> ""
                    }
                    val col = if (mismatch) SvRose else SvEmerald
                    Text(text = txt, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = col)
                },
                isPassword = true,
                borderColorOverride = if (mismatch) SvRose.copy(alpha = 0.7f) else null
            )

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = p.sub,
                border = BorderStroke(1.dp, p.border),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        "• ${t("主密码仅由你本人掌握，无法找回或重置，请妥善牢记或手写备份。")}",
                        fontSize = 11.sp,
                        color = p.fg.copy(alpha = 0.72f),
                        lineHeight = 17.sp
                    )
                    Text(
                        "• ${t("日常打开默认直接进入，如需每次验证身份，可在「首选项」中开启应用锁。")}",
                        fontSize = 11.sp,
                        color = p.fg.copy(alpha = 0.72f),
                        lineHeight = 17.sp
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = SvIndigo,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .clickable {
                        if (pwd1.length < 8) {
                            vm.showToast(t("主密码至少 8 位"), true)
                        } else if (pwd1 != pwd2) {
                            vm.showToast(t("两次密码输入不一致"), true)
                        } else if (vm.createFreshVault(pwd1)) {
                            onDismiss()
                        }
                    }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(t("创建并进入"), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
fun UnlockScreen(
    p: SvPalette,
    activity: FragmentActivity,
    vm: VaultViewModel
) {
    var pwd by remember { mutableStateOf("") }
    var forcePassword by remember { mutableStateOf(false) }
    var gestureFails by remember { mutableIntStateOf(0) }

    val useGesture = !forcePassword && vm.gestureOn && vm.gesturePattern.isNotEmpty()
    val bioBtnLabel = when {
        vm.bioFaceOn && vm.bioFingerOn -> t("面容识别解锁（优先）")
        vm.bioFaceOn -> t("面容识别解锁")
        vm.bioFingerOn -> t("指纹解锁")
        else -> ""
    }
    val subtitle = when {
        useGesture && bioBtnLabel.isNotEmpty() -> t("可划动九宫格，或点击下方使用面容/指纹")
        useGesture -> t("请绘制手势图案以解锁")
        bioBtnLabel.isNotEmpty() -> t("输入主密码或通过生物识别快速解锁")
        else -> t("请输入主密码以解锁")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 24.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.SpaceBetween,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(top = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(SvIndigo),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Lock, contentDescription = null, tint = Color.White, modifier = Modifier.size(30.dp))
            }
            Text(t("锁匣已锁定"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)
            Text(subtitle, fontSize = 12.sp, color = p.fg.copy(alpha = 0.6f), textAlign = TextAlign.Center)
        }

        if (useGesture) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                GesturePad(onPatternComplete = { pat ->
                    if (!vm.unlockWithGesture(pat)) {
                        gestureFails++
                        if (gestureFails >= 5) {
                            forcePassword = true
                            gestureFails = 0
                        }
                    }
                })
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    if (bioBtnLabel.isNotEmpty()) {
                        Text(
                            bioBtnLabel,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = SvIndigo,
                            modifier = Modifier.clickable {
                                BiometricAndKeystoreManager.authenticate(
                                    activity = activity,
                                    onSuccess = { vm.unlockWithBiometricSuccess() },
                                    onError = { vm.showToast(it, true) }
                                )
                            }
                        )
                    }
                    Text(
                        t("改用主密码"),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = SvIndigo,
                        modifier = Modifier.clickable { forcePassword = true }
                    )
                }
            }
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                SvInputField(
                    p = p,
                    value = pwd,
                    onValueChange = { pwd = it },
                    placeholder = t("输入主密码"),
                    isPassword = true,
                    height = 44.dp
                )
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = SvIndigo,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clickable {
                            if (vm.unlockWithPassword(pwd)) {
                                pwd = ""
                            }
                        }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(t("解锁"), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                if (bioBtnLabel.isNotEmpty()) {
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = p.card,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(46.dp)
                            .clickable {
                                BiometricAndKeystoreManager.authenticate(
                                    activity = activity,
                                    onSuccess = { vm.unlockWithBiometricSuccess() },
                                    onError = { vm.showToast(it, true) }
                                )
                            }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center,
                            modifier = Modifier.fillMaxSize()
                        ) {
                            Icon(Icons.Filled.Fingerprint, contentDescription = null, tint = SvIndigo, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(bioBtnLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = p.fg)
                        }
                    }
                }
                if (vm.gestureOn && vm.gesturePattern.isNotEmpty()) {
                    Text(
                        t("改用手势密码解锁"),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = SvIndigo,
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .padding(top = 4.dp)
                            .clickable { forcePassword = false }
                    )
                }
            }
        }

        Text(t("本地数据已加密保护"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.45f))
    }
}

@Composable
fun GestureSetupSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    var firstPattern by remember { mutableStateOf<String?>(null) }
    var tipText by remember { mutableStateOf(t("绘制解锁图案")) }

    SvPageSheet(
        p = p,
        title = if (vm.gestureOn) t("修改手势密码") else t("设置手势密码"),
        onDismiss = onDismiss,
        leftLabel = t("取消"),
        rightAction = if (vm.gestureOn) {
            {
                Text(
                    t("关闭"),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = SvRose,
                    modifier = Modifier.clickable {
                        vm.gestureOn = false
                        vm.gesturePattern = ""
                        vm.saveMeta()
                        vm.showToast(t("已关闭手势密码"))
                        onDismiss()
                    }
                )
            }
        } else null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(tipText, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = p.fg)
                Text(
                    t("至少连接 4 个圆点，连续画错 5 次将切回主密码"),
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.55f),
                    textAlign = TextAlign.Center
                )
            }
            GesturePad(onPatternComplete = { pat ->
                if (pat.length < 4) {
                    vm.showToast(t("至少连接 4 个点"), true)
                    return@GesturePad
                }
                val first = firstPattern
                if (first == null) {
                    firstPattern = pat
                    tipText = t("请再绘制一次以确认")
                } else if (pat != first) {
                    firstPattern = null
                    tipText = t("两次图案不一致，请重新绘制")
                    vm.showToast(t("两次绘制不一致"), true)
                } else {
                    vm.gesturePattern = pat
                    vm.gestureOn = true
                    vm.saveMeta()
                    vm.showToast(t("手势密码已设置"))
                    onDismiss()
                }
            })
        }
    }
}
