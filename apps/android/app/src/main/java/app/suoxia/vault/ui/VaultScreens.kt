package app.suoxia.vault.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.suoxia.vault.i18n.t
import app.suoxia.vault.i18n.tf
import app.suoxia.vault.model.*
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel

@Composable
fun VaultTabScreen(
    p: SvPalette,
    vm: VaultViewModel,
    onNewCredential: () -> Unit,
    onSelectItem: (VaultItem) -> Unit,
    onOpenFolders: () -> Unit,
    onOpenTrash: () -> Unit
) {
    val ctx = LocalContext.current
    var expandedQuickId by remember { mutableStateOf<String?>(null) }

    val activeItems = remember(vm.items) { vm.items.filter { it.deletedAt == null } }
    val trashedCount = remember(vm.items) { vm.items.count { it.deletedAt != null } }

    val filtered = remember(activeItems, vm.activeFolder, vm.activeCat, vm.searchQuery) {
        val q = vm.searchQuery.trim().lowercase()
        activeItems.filter { item ->
            val folderOk = when (vm.activeFolder) {
                ALL_FOLDERS -> true
                DEFAULT_FOLDER -> isDefaultFolder(item.folder)
                else -> normalizeFolderName(item.folder) == vm.activeFolder
            }
            val catOk = when (vm.activeCat) {
                "all" -> true
                "fav" -> item.isFavorite
                else -> item.type.key == vm.activeCat
            }
            val qOk = q.isEmpty() ||
                item.title.lowercase().contains(q) ||
                item.username.lowercase().contains(q) ||
                item.url.lowercase().contains(q)
            folderOk && catOk && qOk
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top App Bar
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(t("保险箱"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = p.fg)
                        Box(modifier = Modifier.heightIn(min = 22.dp), contentAlignment = Alignment.CenterStart) {
                            if (vm.activeFolder == ALL_FOLDERS) {
                                Text(
                                    tf("共 %d 条凭证", activeItems.size),
                                    fontSize = 12.sp,
                                    color = p.fg.copy(alpha = 0.55f)
                                )
                            } else {
                                Row(
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .background(SvIndigo.copy(alpha = 0.1f))
                                        .clickable { vm.activeFolder = ALL_FOLDERS }
                                        .padding(horizontal = 8.dp, vertical = 2.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Icon(Icons.Outlined.Folder, null, tint = SvIndigo, modifier = Modifier.size(12.dp))
                                    Text(
                                        text = if (vm.activeFolder == DEFAULT_FOLDER) t("默认") else vm.activeFolder,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = SvIndigo
                                    )
                                    Icon(Icons.Filled.Close, null, tint = SvIndigo.copy(alpha = 0.8f), modifier = Modifier.size(12.dp))
                                }
                            }
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Surface(
                            shape = CircleShape,
                            color = p.card,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.size(36.dp).clickable { onOpenFolders() }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Outlined.Folder, contentDescription = t("文件夹管理"), tint = p.fg.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
                            }
                        }
                        Box {
                            Surface(
                                shape = CircleShape,
                                color = p.card,
                                border = BorderStroke(1.dp, p.border),
                                modifier = Modifier.size(36.dp).clickable { onOpenTrash() }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(Icons.Outlined.Delete, contentDescription = t("回收站"), tint = p.fg.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
                                }
                            }
                            if (trashedCount > 0) {
                                Box(
                                    modifier = Modifier
                                        .align(Alignment.TopEnd)
                                        .offset(x = 3.dp, y = (-3).dp)
                                        .defaultMinSize(minWidth = 16.dp)
                                        .height(16.dp)
                                        .clip(CircleShape)
                                        .background(SvRose)
                                        .padding(horizontal = 4.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(trashedCount.toString(), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // Search Bar
                SvSearchBar(
                    p = p,
                    value = vm.searchQuery,
                    onValueChange = { vm.searchQuery = it },
                    placeholder = t("搜索标题、账号或网址")
                )

                // Category Pills
                val cats = listOf(
                    "all" to t("全部"),
                    "fav" to t("星标"),
                    "login" to t("登录"),
                    "card" to t("卡券"),
                    "note" to t("备忘"),
                    "identity" to t("密保")
                )
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    cats.forEach { (id, label) ->
                        val on = vm.activeCat == id
                        Surface(
                            shape = CircleShape,
                            color = if (on) SvIndigo else p.card,
                            border = BorderStroke(1.dp, if (on) SvIndigo else p.border),
                            modifier = Modifier.clickable { vm.activeCat = id }
                        ) {
                            Text(
                                text = label,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (on) Color.White else p.fg.copy(alpha = 0.72f),
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                            )
                        }
                    }
                }
            }

            // List or Empty State
            if (activeItems.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(horizontal = 24.dp, vertical = 64.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(t("保险箱当前为空"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                    Text(
                        t("点击右下角 + 添加第一条加密凭证，或在「首选项」中导入备份。"),
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
                    Text(t("当前筛选下暂无凭证"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.5f))
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 84.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(filtered, key = { it.id }) { item ->
                        val quickOpen = expandedQuickId == item.id
                        val subText = item.username
                            .ifEmpty { item.cardNumber }
                            .ifEmpty { item.identityName }
                            .ifEmpty { item.identityPhone }
                            .ifEmpty { if (item.type == ItemType.NOTE) t("加密备忘") else "" }
                            .ifEmpty { if (isDefaultFolder(item.folder)) t("默认") else item.folder }

                        val quickCopyVal = item.password
                            .ifEmpty { item.cardNumber }
                            .ifEmpty { item.notes }
                            .ifEmpty { item.identityPhone }
                            .ifEmpty { item.identityName }
                        val quickCopyLbl = when (item.type) {
                            ItemType.CARD -> t("卡号")
                            ItemType.NOTE -> t("备忘")
                            ItemType.IDENTITY -> t("姓名")
                            ItemType.LOGIN -> t("密码")
                        }

                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = p.card,
                            border = BorderStroke(1.dp, p.border),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { onSelectItem(item) }
                                        .padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    ItemAvatar(item)
                                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Text(
                                                item.title,
                                                fontSize = 14.sp,
                                                fontWeight = FontWeight.SemiBold,
                                                color = p.fg,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                                modifier = Modifier.weight(1f, fill = false)
                                            )
                                            if (item.isFavorite) {
                                                Icon(Icons.Filled.Star, null, tint = Color(0xFFFBBF24), modifier = Modifier.size(14.dp))
                                            }
                                            if (item.otpSecret.isNotBlank()) {
                                                Row(
                                                    modifier = Modifier
                                                        .clip(RoundedCornerShape(6.dp))
                                                        .background(SvEmerald.copy(alpha = 0.12f))
                                                        .padding(horizontal = 5.dp, vertical = 1.dp),
                                                    verticalAlignment = Alignment.CenterVertically,
                                                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                                                ) {
                                                    Icon(Icons.Outlined.Schedule, null, tint = SvEmerald, modifier = Modifier.size(10.dp))
                                                    Text("2FA", fontSize = 10.sp, fontWeight = FontWeight.Medium, color = SvEmerald)
                                                }
                                            }
                                        }
                                        Text(
                                            subText,
                                            fontSize = 12.sp,
                                            color = p.fg.copy(alpha = 0.55f),
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }

                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                        Box(
                                            modifier = Modifier
                                                .clip(CircleShape)
                                                .background(SvIndigo.copy(alpha = 0.12f))
                                                .clickable {
                                                    BiometricAndKeystoreManager.copySensitive(ctx, quickCopyLbl, quickCopyVal)
                                                    vm.showToast(tf("已复制%s", quickCopyLbl))
                                                }
                                                .padding(horizontal = 12.dp, vertical = 5.dp)
                                        ) {
                                            Text(t("复制"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = SvIndigo)
                                        }
                                        Box(
                                            modifier = Modifier
                                                .size(32.dp)
                                                .clip(CircleShape)
                                                .clickable { expandedQuickId = if (quickOpen) null else item.id },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Icon(Icons.Filled.MoreHoriz, null, tint = p.fg.copy(alpha = 0.55f), modifier = Modifier.size(18.dp))
                                        }
                                    }
                                }

                                if (quickOpen) {
                                    HorizontalDivider(thickness = 1.dp, color = p.hairline)
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .background(p.sub)
                                            .padding(horizontal = 14.dp, vertical = 10.dp),
                                        horizontalArrangement = Arrangement.SpaceAround,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        when (item.type) {
                                            ItemType.LOGIN -> {
                                                Text(
                                                    t("复制账号"),
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Medium,
                                                    color = SvIndigo,
                                                    modifier = Modifier.clickable {
                                                        BiometricAndKeystoreManager.copySensitive(ctx, t("账号"), item.username)
                                                        vm.showToast(tf("已复制%s", t("账号")))
                                                        expandedQuickId = null
                                                    }
                                                )
                                                Text(
                                                    t("复制密码"),
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Medium,
                                                    color = SvIndigo,
                                                    modifier = Modifier.clickable {
                                                        BiometricAndKeystoreManager.copySensitive(ctx, t("密码"), item.password)
                                                        vm.showToast(tf("已复制%s", t("密码")))
                                                        expandedQuickId = null
                                                    }
                                                )
                                            }
                                            ItemType.CARD -> {
                                                Text(
                                                    t("复制卡号"),
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Medium,
                                                    color = SvIndigo,
                                                    modifier = Modifier.clickable {
                                                        BiometricAndKeystoreManager.copySensitive(ctx, t("卡号"), item.cardNumber)
                                                        vm.showToast(tf("已复制%s", t("卡号")))
                                                        expandedQuickId = null
                                                    }
                                                )
                                            }
                                            ItemType.NOTE -> {
                                                Text(
                                                    t("复制内容"),
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Medium,
                                                    color = SvIndigo,
                                                    modifier = Modifier.clickable {
                                                        BiometricAndKeystoreManager.copySensitive(ctx, t("备忘"), item.notes)
                                                        vm.showToast(tf("已复制%s", t("备忘")))
                                                        expandedQuickId = null
                                                    }
                                                )
                                            }
                                            ItemType.IDENTITY -> {
                                                val (idActionLabel, idCopyLabel, idCopyVal) = when {
                                                    item.identityPhone.isNotBlank() -> Triple(t("复制手机号"), t("手机号"), item.identityPhone)
                                                    item.identityEmail.isNotBlank() -> Triple(t("复制邮箱"), t("邮箱"), item.identityEmail)
                                                    else -> Triple(t("复制姓名"), t("姓名"), item.identityName)
                                                }
                                                Text(
                                                    idActionLabel,
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Medium,
                                                    color = SvIndigo,
                                                    modifier = Modifier.clickable {
                                                        BiometricAndKeystoreManager.copySensitive(ctx, idCopyLabel, idCopyVal)
                                                        vm.showToast(tf("已复制%s", idCopyLabel))
                                                        expandedQuickId = null
                                                    }
                                                )
                                            }
                                        }
                                        Text(
                                            if (item.isFavorite) t("取消星标") else t("加星标"),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = p.fg,
                                            modifier = Modifier.clickable {
                                                vm.toggleFavorite(item.id)
                                                expandedQuickId = null
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Circular FAB (+)
        FloatingActionButton(
            onClick = onNewCredential,
            shape = CircleShape,
            containerColor = SvIndigo,
            contentColor = Color.White,
            elevation = FloatingActionButtonDefaults.elevation(defaultElevation = 6.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
                .size(48.dp)
        ) {
            Icon(Icons.Filled.Add, contentDescription = t("新建凭证"), modifier = Modifier.size(22.dp))
        }
    }
}

@Composable
fun FolderManagerSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    var newName by remember { mutableStateOf("") }
    var confirmDeleteFolder by remember { mutableStateOf<String?>(null) }

    val activeItems = remember(vm.items) { vm.items.filter { it.deletedAt == null } }
    val defaultCount = remember(activeItems) { activeItems.count { isDefaultFolder(it.folder) } }

    SvPageSheet(
        p = p,
        title = t("文件夹管理"),
        onDismiss = onDismiss,
        leftLabel = t("关闭"),
        rightAction = {
            Text(
                t("完成"),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SvIndigo,
                modifier = Modifier.clickable { onDismiss() }
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
            // New folder input + button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(p.card)
                    .border(1.dp, p.border, RoundedCornerShape(12.dp))
                    .padding(start = 12.dp, end = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (newName.isEmpty()) {
                        Text(t("输入新文件夹名称..."), fontSize = 12.sp, color = p.fg.copy(alpha = 0.45f))
                    }
                    BasicTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        singleLine = true,
                        textStyle = TextStyle(fontSize = 12.sp, color = p.fg),
                        cursorBrush = SolidColor(SvIndigo),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                Box(
                    modifier = Modifier
                        .height(28.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(SvIndigo)
                        .clickable {
                            if (vm.addFolder(newName)) newName = ""
                        }
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(t("新建"), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            // Folder list card
            SvGroupedCard(p = p) {
                // 全部凭证
                FolderRow(
                    p = p,
                    label = t("全部凭证"),
                    count = activeItems.size,
                    selected = vm.activeFolder == ALL_FOLDERS,
                    onClick = {
                        vm.activeFolder = ALL_FOLDERS
                        onDismiss()
                    }
                )
                SvHairlineDivider(p)
                // 默认
                FolderRow(
                    p = p,
                    label = t("默认"),
                    count = defaultCount,
                    selected = vm.activeFolder == DEFAULT_FOLDER,
                    onClick = {
                        vm.activeFolder = DEFAULT_FOLDER
                        onDismiss()
                    }
                )
                // Custom folders
                vm.folders.forEach { folder ->
                    SvHairlineDivider(p)
                    val cnt = activeItems.count { normalizeFolderName(it.folder) == folder }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .clickable {
                                    vm.activeFolder = folder
                                    onDismiss()
                                },
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                folder,
                                fontSize = 14.sp,
                                fontWeight = if (vm.activeFolder == folder) FontWeight.SemiBold else FontWeight.Normal,
                                color = if (vm.activeFolder == folder) SvIndigo else p.fg
                            )
                            Text(
                                "${tf("%d 条", cnt)}${if (vm.activeFolder == folder) " ✓" else ""}",
                                fontSize = 12.sp,
                                color = p.fg.copy(alpha = 0.6f)
                            )
                        }
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(SvRose.copy(alpha = 0.1f))
                                .clickable { confirmDeleteFolder = folder }
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(t("删除"), fontSize = 12.sp, color = SvRose, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }
        }
    }

    confirmDeleteFolder?.let { folder ->
        val cnt = activeItems.count { normalizeFolderName(it.folder) == folder }
        SvConfirmDialog(
            p = p,
            title = tf("删除文件夹「%s」？", folder),
            message = if (cnt > 0) tf("该文件夹内的 %d 条凭证将自动移入「默认」文件夹，不会丢失数据。", cnt) else t("删除后该文件夹将被移除。"),
            confirmText = t("确认删除"),
            isDestructive = true,
            onDismiss = { confirmDeleteFolder = null },
            onConfirm = {
                vm.deleteFolder(folder)
                confirmDeleteFolder = null
            }
        )
    }
}

@Composable
private fun FolderRow(
    p: SvPalette,
    label: String,
    count: Int,
    selected: Boolean,
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
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) SvIndigo else p.fg
        )
        Text(
            "${tf("%d 条", count)}${if (selected) " ✓" else ""}",
            fontSize = 12.sp,
            color = p.fg.copy(alpha = 0.6f)
        )
    }
}

@Composable
fun TrashSheet(
    p: SvPalette,
    vm: VaultViewModel,
    onDismiss: () -> Unit
) {
    val trashed = remember(vm.items) { vm.items.filter { it.deletedAt != null } }
    var showEmptyConfirm by remember { mutableStateOf(false) }
    var purgeTarget by remember { mutableStateOf<VaultItem?>(null) }

    SvPageSheet(
        p = p,
        title = tf("回收站 (%d)", trashed.size),
        onDismiss = onDismiss,
        leftLabel = t("关闭"),
        rightAction = if (trashed.isNotEmpty()) {
            {
                Text(
                    t("清空"),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = SvRose,
                    modifier = Modifier.clickable { showEmptyConfirm = true }
                )
            }
        } else null
    ) {
        if (trashed.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxWidth().padding(vertical = 64.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(t("回收站为空"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.5f))
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                trashed.forEach { item ->
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
                            Column(modifier = Modifier.weight(1f)) {
                                Text(item.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                                Text(t("30 天后自动彻底清理"), fontSize = 12.sp, color = p.fg.copy(alpha = 0.55f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(SvEmerald.copy(alpha = 0.14f))
                                        .clickable { vm.restoreFromTrash(item.id) }
                                        .padding(horizontal = 12.dp, vertical = 6.dp)
                                ) {
                                    Text(t("恢复"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = SvEmerald)
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(SvRose.copy(alpha = 0.14f))
                                        .clickable { purgeTarget = item }
                                        .padding(horizontal = 12.dp, vertical = 6.dp)
                                ) {
                                    Text(t("删除"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = SvRose)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showEmptyConfirm) {
        SvConfirmDialog(
            p = p,
            title = t("清空回收站？"),
            message = t("回收站内所有凭证将被永久销毁且无法恢复。"),
            confirmText = t("确认清空"),
            isDestructive = true,
            onDismiss = { showEmptyConfirm = false },
            onConfirm = {
                vm.emptyTrash()
                showEmptyConfirm = false
            }
        )
    }

    purgeTarget?.let { item ->
        SvConfirmDialog(
            p = p,
            title = tf("彻底删除「%s」？", item.title),
            message = t("删除后将无法恢复，请确认不再需要此凭证。"),
            confirmText = t("彻底删除"),
            isDestructive = true,
            onDismiss = { purgeTarget = null },
            onConfirm = {
                vm.purgeItem(item.id)
                purgeTarget = null
            }
        )
    }
}
