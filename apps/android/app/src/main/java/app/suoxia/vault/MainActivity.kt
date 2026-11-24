package app.suoxia.vault

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material.icons.outlined.Key
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import app.suoxia.vault.bridge.RustCore
import app.suoxia.vault.i18n.t
import app.suoxia.vault.model.*
import app.suoxia.vault.security.BiometricAndKeystoreManager
import app.suoxia.vault.state.VaultViewModel
import app.suoxia.vault.ui.*
import kotlinx.coroutines.delay

class MainActivity : FragmentActivity() {
    private val vm: VaultViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BiometricAndKeystoreManager.setPrivacyScreen(this, vm.privacyMask)
        setContent {
            SuoxiaRootApp(activity = this, vm = vm)
        }
    }

    override fun onResume() {
        super.onResume()
        vm.onAppResumed()
    }

    override fun onStop() {
        super.onStop()
        vm.onAppBackgrounded()
    }
}

@Composable
fun SuoxiaRootApp(activity: FragmentActivity, vm: VaultViewModel) {
    val ctx = LocalContext.current
    val p = remember(vm.isDark) { svPalette(vm.isDark) }

    // Shared modal state across Onboarding & Home
    var showWebDavSheet by remember { mutableStateOf(false) }
    var webDavOnboardingMode by remember { mutableStateOf(false) }

    var showImportSheet by remember { mutableStateOf(false) }
    var importStep by remember { mutableStateOf("pick") }
    var importSource by remember { mutableStateOf(ImportSourceType.SUOXIA_JSON) }
    var stagedFileName by remember { mutableStateOf("") }
    var stagedBadge by remember { mutableStateOf("") }
    var stagedPath by remember { mutableStateOf("") }
    var importPreview by remember { mutableStateOf<ImportPreviewData?>(null) }

    var showExportFormatSheet by remember { mutableStateOf(false) }
    var showKdbxPwdDialog by remember { mutableStateOf(false) }
    var pendingKdbxPassword by remember { mutableStateOf("") }
    var pendingExportName by remember { mutableStateOf("") }

    // Android SAF Launchers
    val openImportDocLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            vm.stageImportUri(
                uri = uri,
                resolver = ctx.contentResolver,
                sourceType = importSource,
                onNeedsPassword = { path, name, badge ->
                    stagedPath = path
                    stagedFileName = name
                    stagedBadge = badge
                    importStep = "decrypt"
                },
                onPreviewReady = { preview ->
                    importPreview = preview
                    importStep = "preview"
                }
            )
        }
    }

    val createJsonExportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        if (uri != null) {
            vm.exportJsonToUri(uri, ctx.contentResolver, pendingExportName)
        }
    }

    val createKdbxExportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/octet-stream")
    ) { uri ->
        if (uri != null && pendingKdbxPassword.isNotEmpty()) {
            vm.exportKdbxToUri(uri, ctx.contentResolver, pendingKdbxPassword, pendingExportName)
            pendingKdbxPassword = ""
        }
    }

    LaunchedEffect(vm.toastMsg) {
        if (vm.toastMsg != null) {
            delay(2300)
            vm.clearToast()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(p.bg)) {
        when (vm.screen) {
            AppScreen.ONBOARDING -> OnboardingScreen(
                p = p,
                vm = vm,
                onOpenWebDavRestore = {
                    webDavOnboardingMode = true
                    showWebDavSheet = true
                },
                onOpenImport = {
                    importStep = "pick"
                    importPreview = null
                    showImportSheet = true
                }
            )
            AppScreen.UNLOCK -> UnlockScreen(p = p, activity = activity, vm = vm)
            AppScreen.HOME -> HomeShell(
                p = p,
                activity = activity,
                vm = vm,
                onOpenWebDav = {
                    webDavOnboardingMode = false
                    showWebDavSheet = true
                },
                onOpenImport = {
                    importStep = "pick"
                    importPreview = null
                    showImportSheet = true
                },
                onOpenExport = {
                    showExportFormatSheet = true
                }
            )
        }

        // Global WebDAV Sheet
        if (showWebDavSheet) {
            WebDavSheet(
                p = p,
                vm = vm,
                isOnboardingRestore = webDavOnboardingMode,
                onDismiss = { showWebDavSheet = false }
            )
        }

        // Global Import Flow Sheet
        if (showImportSheet) {
            ImportFlowSheet(
                p = p,
                vm = vm,
                step = importStep,
                sourceType = importSource,
                stagedFileName = stagedFileName,
                stagedBadge = stagedBadge,
                stagedPath = stagedPath,
                previewData = importPreview,
                onSelectSourceAndLaunchPicker = { src ->
                    importSource = src
                    openImportDocLauncher.launch(arrayOf("*/*"))
                },
                onDecryptSubmit = { pwd ->
                    vm.decryptImportFile(stagedPath, stagedFileName, importSource, pwd) { preview ->
                        importPreview = preview
                        importStep = "preview"
                    }
                },
                onResetToPick = {
                    importStep = "pick"
                    importPreview = null
                },
                onDismiss = {
                    showImportSheet = false
                    importStep = "pick"
                    importPreview = null
                }
            )
        }

        // Export Format Sheet
        if (showExportFormatSheet) {
            ExportFormatSheet(
                p = p,
                onDismiss = { showExportFormatSheet = false },
                onPickJson = {
                    val fileName = "SecureVault_Backup_${todayDateString()}.json"
                    pendingExportName = fileName
                    createJsonExportLauncher.launch(fileName)
                },
                onPickKdbx = {
                    showKdbxPwdDialog = true
                }
            )
        }

        if (showKdbxPwdDialog) {
            KdbxExportPasswordDialog(
                p = p,
                onDismiss = { showKdbxPwdDialog = false },
                onConfirm = { pwd ->
                    showKdbxPwdDialog = false
                    pendingKdbxPassword = pwd
                    val fileName = "SecureVault_${todayDateString()}.kdbx"
                    pendingExportName = fileName
                    createKdbxExportLauncher.launch(fileName)
                }
            )
        }

        // WebDAV Conflict Sheet & Remote Salt Master Password Dialog
        if (vm.showWebdavConflictSheet) {
            WebDavConflictSheet(p = p, vm = vm)
        }
        if (vm.showRemoteSaltPwdDialog) {
            RemoteSaltPasswordDialog(p = p, vm = vm)
        }

        // Toast HUD
        vm.toastMsg?.let { msg ->
            Surface(
                shape = RoundedCornerShape(24.dp),
                color = Color(0xF20F172A),
                shadowElevation = 8.dp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(bottom = 84.dp, start = 24.dp, end = 24.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = if (vm.toastWarn) "!" else "✓",
                        color = if (vm.toastWarn) Color(0xFFFBBF24) else Color(0xFF34D399),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                    Text(msg, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
            }
        }
    }
}

@Composable
fun HomeShell(
    p: SvPalette,
    activity: FragmentActivity,
    vm: VaultViewModel,
    onOpenWebDav: () -> Unit,
    onOpenImport: () -> Unit,
    onOpenExport: () -> Unit
) {
    val ctx = LocalContext.current
    var detailItemId by remember { mutableStateOf<String?>(null) }
    var showFoldersSheet by remember { mutableStateOf(false) }
    var showTrashSheet by remember { mutableStateOf(false) }
    var showAddTotpSheet by remember { mutableStateOf(false) }
    var showEditSheet by remember { mutableStateOf(false) }
    var editingItem by remember { mutableStateOf<VaultItem?>(null) }
    var scannedOtpForEdit by remember { mutableStateOf<String?>(null) }

    var showQrScanner by remember { mutableStateOf(false) }
    var qrTargetMode by remember { mutableStateOf("standalone") }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            showQrScanner = true
        } else {
            vm.showToast(t("请授予相机权限以扫描二维码"), true)
        }
    }

    fun requestCameraQr(mode: String) {
        qrTargetMode = mode
        val granted = ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            showQrScanner = true
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    if (showQrScanner) {
        QrScannerScreen(
            onScanned = { uri ->
                showQrScanner = false
                try {
                    val (issuer, acc, sec) = RustCore.parseOtpauthUri(uri)
                    if (qrTargetMode == "standalone") {
                        vm.addStandaloneTotp(issuer, acc, sec)
                        showAddTotpSheet = false
                    } else {
                        scannedOtpForEdit = sec
                        vm.showToast(t("已识别并填入验证密钥"))
                    }
                } catch (e: Exception) {
                    vm.showToast(e.message ?: t("无效二维码"), true)
                }
            },
            onClose = { showQrScanner = false }
        )
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = p.bg,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            bottomBar = {
                NavigationBar(
                    containerColor = p.card,
                    tonalElevation = 0.dp
                ) {
                    HomeTab.entries.forEach { tab ->
                        val selected = vm.activeTab == tab
                        NavigationBarItem(
                            selected = selected,
                            onClick = { vm.activeTab = tab },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = SvIndigo,
                                selectedTextColor = SvIndigo,
                                unselectedIconColor = p.fg.copy(alpha = 0.45f),
                                unselectedTextColor = p.fg.copy(alpha = 0.45f),
                                indicatorColor = SvIndigo.copy(alpha = 0.1f)
                            ),
                            icon = {
                                val icon = when (tab) {
                                    HomeTab.VAULT -> if (selected) Icons.Filled.Lock else Icons.Outlined.Lock
                                    HomeTab.TOTP -> if (selected) Icons.Filled.VerifiedUser else Icons.Outlined.VerifiedUser
                                    HomeTab.GENERATOR -> if (selected) Icons.Filled.Key else Icons.Outlined.Key
                                    HomeTab.SETTINGS -> if (selected) Icons.Filled.Settings else Icons.Outlined.Settings
                                }
                                Icon(icon, contentDescription = t(tab.label))
                            },
                            label = {
                                Text(
                                    t(tab.label),
                                    fontSize = 11.sp,
                                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                                )
                            }
                        )
                    }
                }
            }
        ) { innerPadding ->
            Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
                when (vm.activeTab) {
                    HomeTab.VAULT -> VaultTabScreen(
                        p = p,
                        vm = vm,
                        onNewCredential = {
                            editingItem = null
                            showEditSheet = true
                        },
                        onSelectItem = { detailItemId = it.id },
                        onOpenFolders = { showFoldersSheet = true },
                        onOpenTrash = { showTrashSheet = true }
                    )
                    HomeTab.TOTP -> TotpTabScreen(
                        p = p,
                        vm = vm,
                        onAddToken = { showAddTotpSheet = true }
                    )
                    HomeTab.GENERATOR -> GeneratorTabScreen(p = p, vm = vm)
                    HomeTab.SETTINGS -> SettingsTabScreen(
                        p = p,
                        activity = activity,
                        vm = vm,
                        onOpenWebDav = onOpenWebDav,
                        onOpenImport = onOpenImport,
                        onOpenExport = onOpenExport
                    )
                }
            }
        }

        // Horizontal Push Page: Credential Detail ONLY
        AnimatedVisibility(
            visible = detailItemId != null,
            enter = slideInHorizontally(initialOffsetX = { it }),
            exit = slideOutHorizontally(targetOffsetX = { it })
        ) {
            detailItemId?.let { id ->
                DetailPage(
                    p = p,
                    vm = vm,
                    itemId = id,
                    onBack = { detailItemId = null },
                    onEdit = { item ->
                        editingItem = item
                        showEditSheet = true
                    }
                )
            }
        }
    }

    if (showFoldersSheet) {
        FolderManagerSheet(p = p, vm = vm, onDismiss = { showFoldersSheet = false })
    }

    if (showTrashSheet) {
        TrashSheet(p = p, vm = vm, onDismiss = { showTrashSheet = false })
    }

    if (showAddTotpSheet) {
        AddTotpSheet(
            p = p,
            vm = vm,
            onScanQr = { requestCameraQr("standalone") },
            onDismiss = { showAddTotpSheet = false }
        )
    }

    if (showEditSheet) {
        EditCredentialSheet(
            p = p,
            vm = vm,
            existing = editingItem,
            scannedOtpSecret = scannedOtpForEdit,
            onConsumeScannedOtp = { scannedOtpForEdit = null },
            onRequestQrScan = { requestCameraQr("edit") },
            onDismiss = {
                showEditSheet = false
                editingItem = null
            }
        )
    }
}
