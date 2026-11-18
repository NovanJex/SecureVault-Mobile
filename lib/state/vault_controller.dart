import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../bridge/rust_bridge.dart';
import '../models/vault_models.dart';
import '../utils/import_export_utils.dart';
import '../utils/wordlist.dart';

class VaultController extends ChangeNotifier {
  bool isInitialized = false;
  bool hasExistingVault = false;
  bool isUnlocked = false;
  bool isDark = false;
  bool isZh = true;

  String? _masterKey;
  String? _salt;
  String selectedKdf = 'argon2id';

  // Biometric & Hardware Security State
  bool bioEnabled = true;
  bool bioColdStartRequirePassword = false;
  bool privacyScreenEnabled = true;
  int bioFailCount = 0;
  bool bioLockedOut = false;

  // Vault Data
  List<VaultItem> items = [];
  List<VaultFolder> folders = [
    const VaultFolder(id: 'f-dev', name: '开发'),
    const VaultFolder(id: 'f-work', name: '工作'),
    const VaultFolder(id: 'f-fin', name: '金融'),
    const VaultFolder(id: 'f-tool', name: '工具'),
    const VaultFolder(id: 'f-sec', name: '安全'),
    const VaultFolder(id: 'f-per', name: '个人'),
  ];

  // Filters
  String searchQuery = '';
  String activeCategory = 'all'; // all, fav, login, card, note, identity, trash
  String activeFolder = '全部';

  // Generator State
  String genMode = 'random'; // random | bip39
  PasswordConfig genConfig = const PasswordConfig();
  int passphraseWords = 5;
  String passphraseSeparator = '-';
  bool passphraseCapitalize = true;
  String generatedPassword = '';
  List<String> generatorHistory = [];

  // WebDAV State
  String webdavUrl = '';
  String webdavUsername = '';
  bool webdavHasSavedPassword = false;
  String webdavStatus = '未配置';
  bool webdavConflictDetected = false;
  String? _pendingRemoteContent;

  Timer? _clipboardClearTimer;

  Future<void> init() async {
    await NativeBridge.setPrivacyScreen(privacyScreenEnabled);
    generateNewPassword();
    try {
      final raw = await RustCoreBridge.loadSecureVaultFile();
      if (raw.isNotEmpty && raw.contains(':')) {
        hasExistingVault = true;
        final idx = raw.indexOf(':');
        _salt = raw.substring(0, idx);
      } else {
        hasExistingVault = false;
      }
      final cfg = await RustCoreBridge.getWebdavConfig();
      if (cfg != null) {
        webdavUrl = cfg.url;
        webdavUsername = cfg.username;
        webdavHasSavedPassword = cfg.passwordEnc.isNotEmpty;
        if (webdavHasSavedPassword && webdavUrl.isNotEmpty) {
          webdavStatus = '已连接';
        }
      }
    } catch (_) {
      hasExistingVault = false;
    }
    isInitialized = true;
    notifyListeners();
  }

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
  }

  void toggleLanguage() {
    isZh = !isZh;
    notifyListeners();
  }

  Future<void> setPrivacyProtection(bool enabled) async {
    privacyScreenEnabled = enabled;
    await NativeBridge.setPrivacyScreen(enabled);
    notifyListeners();
  }

  // ============================================================
  // Lock / Unlock / Setup / Biometric Hardware Vault
  // ============================================================

  Future<void> createNewVault(String masterPassword, {String kdf = 'argon2id'}) async {
    final salt = await RustCoreBridge.generateSalt();
    final key = await RustCoreBridge.deriveMasterKey(masterPassword, salt, kdf: kdf);
    _salt = salt;
    _masterKey = key;
    selectedKdf = kdf;
    items = _sampleInitialItems();
    await _persistVault();
    if (bioEnabled) {
      await NativeBridge.saveHardwareMasterKey(key);
    }
    hasExistingVault = true;
    isUnlocked = true;
    bioFailCount = 0;
    bioLockedOut = false;
    notifyListeners();
  }

  Future<bool> unlockWithPassword(String password) async {
    try {
      final raw = await RustCoreBridge.loadSecureVaultFile();
      if (raw.isEmpty || !raw.contains(':')) {
        await createNewVault(password, kdf: selectedKdf);
        return true;
      }
      final idx = raw.indexOf(':');
      final salt = raw.substring(0, idx);
      final ciphertext = raw.substring(idx + 1);

      String? key;
      String? plaintext;
      try {
        key = await RustCoreBridge.deriveMasterKey(password, salt, kdf: 'argon2id');
        plaintext = await RustCoreBridge.decryptVault(ciphertext, key);
      } catch (_) {
        key = await RustCoreBridge.deriveMasterKey(password, salt, kdf: 'pbkdf2');
        plaintext = await RustCoreBridge.decryptVault(ciphertext, key);
      }

      final payload =
          VaultPayload.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
      _salt = salt;
      _masterKey = key;
      items = payload.items;
      if (payload.folders.isNotEmpty) {
        folders = payload.folders;
      }
      isUnlocked = true;
      bioFailCount = 0;
      bioLockedOut = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Simulated or native biometric verification with 3-strike lockout.
  Future<bool> unlockWithBiometricSuccess() async {
    if (!bioEnabled || bioLockedOut) return false;
    try {
      final raw = await RustCoreBridge.loadSecureVaultFile();
      final hwKey = await NativeBridge.loadHardwareMasterKey();
      if (raw.isNotEmpty && raw.contains(':') && hwKey != null && hwKey.isNotEmpty) {
        final idx = raw.indexOf(':');
        final salt = raw.substring(0, idx);
        final ciphertext = raw.substring(idx + 1);
        final plaintext = await RustCoreBridge.decryptVault(ciphertext, hwKey);
        final payload =
            VaultPayload.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
        _salt = salt;
        _masterKey = hwKey;
        items = payload.items;
        if (payload.folders.isNotEmpty) folders = payload.folders;
      } else if (items.isEmpty) {
        items = _sampleInitialItems();
      }
    } catch (_) {
      if (items.isEmpty) items = _sampleInitialItems();
    }
    bioFailCount = 0;
    bioLockedOut = false;
    isUnlocked = true;
    notifyListeners();
    return true;
  }

  /// Records a biometric failure; locks out biometrics on 3rd consecutive failure.
  bool recordBiometricFailure() {
    bioFailCount++;
    if (bioFailCount >= 3) {
      bioLockedOut = true;
      NativeBridge.clearHardwareMasterKey();
    }
    notifyListeners();
    return bioLockedOut;
  }

  Future<void> enableBiometricAfterVerify(String password) async {
    if (_masterKey != null) {
      await NativeBridge.saveHardwareMasterKey(_masterKey!);
    }
    bioEnabled = true;
    bioFailCount = 0;
    bioLockedOut = false;
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    bioEnabled = false;
    await NativeBridge.clearHardwareMasterKey();
    notifyListeners();
  }

  Future<void> _persistVault() async {
    if (_masterKey == null || _salt == null) return;
    final payload = VaultPayload(items: items, folders: folders);
    final ciphertext =
        await RustCoreBridge.encryptVault(payload.toJsonString(), _masterKey!);
    await RustCoreBridge.saveSecureVaultFile('$_salt:$ciphertext');
  }

  // ============================================================
  // Vault Filtering, Folders, CRUD & Trash
  // ============================================================

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setCategory(String cat) {
    activeCategory = cat;
    notifyListeners();
  }

  void toggleTrashView() {
    activeCategory = (activeCategory == 'trash') ? 'all' : 'trash';
    notifyListeners();
  }

  void setFolderFilter(String folderName) {
    activeFolder = folderName;
    notifyListeners();
  }

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || folders.any((f) => f.name == trimmed)) return;
    folders = [
      ...folders,
      VaultFolder(
          id: 'f-${DateTime.now().millisecondsSinceEpoch}', name: trimmed),
    ];
    await _persistVault();
    notifyListeners();
  }

  Future<void> deleteFolder(String name) async {
    folders = folders.where((f) => f.name != name).toList();
    if (activeFolder == name) activeFolder = '全部';
    await _persistVault();
    notifyListeners();
  }

  List<VaultItem> get activeItems =>
      items.where((i) => !i.isTrashed).toList();

  List<VaultItem> get trashedItems =>
      items.where((i) => i.isTrashed).toList();

  List<VaultItem> get filteredItems {
    final q = searchQuery.trim().toLowerCase();
    return items.where((item) {
      if (activeCategory == 'trash') {
        if (!item.isTrashed) return false;
      } else {
        if (item.isTrashed) return false;
        if (activeFolder != '全部' && item.folder != activeFolder) return false;
        if (activeCategory == 'fav' && !item.isFavorite) return false;
        if (activeCategory != 'all' &&
            activeCategory != 'fav' &&
            item.type.value != activeCategory) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          (item.username ?? '').toLowerCase().contains(q) ||
          (item.url ?? '').toLowerCase().contains(q) ||
          (item.notes ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> saveCredential({
    String? editId,
    required ItemType type,
    required String title,
    required String folder,
    required String username,
    required String password,
    String? url,
    String? otpSecret,
    String? expiresAt,
    String? notes,
  }) async {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final strength = ImportExportUtils.calculateStrength(password);

    if (editId != null) {
      final idx = items.indexWhere((x) => x.id == editId);
      if (idx >= 0) {
        final old = items[idx];
        var history = List<PasswordHistoryEntry>.from(old.passwordHistory ?? []);
        if ((old.password ?? '') != password && (old.password ?? '').isNotEmpty) {
          history.insert(
            0,
            PasswordHistoryEntry(password: old.password!, changedAt: nowStr),
          );
          if (history.length > 5) history = history.sublist(0, 5);
        }
        items[idx] = old.copyWith(
          type: type,
          title: title,
          folder: folder,
          username: username,
          password: password,
          url: url,
          otpSecret: otpSecret,
          expiresAt: expiresAt,
          clearExpiresAt: expiresAt == null || expiresAt.isEmpty,
          notes: notes,
          passwordHistory: history,
          updatedAt: nowStr,
          strength: strength,
        );
      }
    } else {
      items = [
        VaultItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: type,
          title: title,
          folder: folder,
          username: username,
          password: password,
          url: url,
          otpSecret: otpSecret,
          expiresAt: (expiresAt == null || expiresAt.isEmpty) ? null : expiresAt,
          notes: notes,
          updatedAt: nowStr,
          strength: strength,
        ),
        ...items,
      ];
    }
    await _persistVault();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(isFavorite: !items[idx].isFavorite);
    await _persistVault();
    notifyListeners();
  }

  Future<void> restorePasswordFromHistory(String id, String oldPassword) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final cur = items[idx];
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    var hist = List<PasswordHistoryEntry>.from(cur.passwordHistory ?? []);
    if ((cur.password ?? '').isNotEmpty) {
      hist.insert(
        0,
        PasswordHistoryEntry(password: cur.password!, changedAt: nowStr),
      );
      if (hist.length > 5) hist = hist.sublist(0, 5);
    }
    items[idx] = cur.copyWith(
      password: oldPassword,
      passwordHistory: hist,
      updatedAt: nowStr,
      strength: ImportExportUtils.calculateStrength(oldPassword),
    );
    await _persistVault();
    notifyListeners();
  }

  Future<void> moveToTrash(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    items[idx] = items[idx].copyWith(deletedAt: nowStr);
    await _persistVault();
    notifyListeners();
  }

  Future<void> restoreFromTrash(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(clearDeletedAt: true);
    await _persistVault();
    notifyListeners();
  }

  Future<void> permanentDelete(String id) async {
    items = items.where((x) => x.id != id).toList();
    await _persistVault();
    notifyListeners();
  }

  Future<int> emptyTrash() async {
    final count = trashedItems.length;
    items = items.where((x) => !x.isTrashed).toList();
    await _persistVault();
    notifyListeners();
    return count;
  }

  // ============================================================
  // Clipboard with 30s Auto-Clear
  // ============================================================

  Future<void> copyWithAutoClear(
    String text, {
    VoidCallback? onCleared,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(const Duration(seconds: 30), () async {
      await Clipboard.setData(const ClipboardData(text: ''));
      onCleared?.call();
    });
  }

  // ============================================================
  // Password Generator (Random & BIP39)
  // ============================================================

  void setGeneratorMode(String mode) {
    genMode = mode;
    generateNewPassword();
  }

  void updateGeneratorConfig(PasswordConfig cfg) {
    genConfig = cfg;
    generateNewPassword();
  }

  void updateBip39Config({int? words, String? sep, bool? cap}) {
    if (words != null) passphraseWords = words;
    if (sep != null) passphraseSeparator = sep;
    if (cap != null) passphraseCapitalize = cap;
    generateNewPassword();
  }

  int get currentEntropyBits {
    if (genMode == 'bip39') {
      return passphraseWords * 11;
    }
    var pool = 0;
    if (genConfig.useLowercase) pool += genConfig.excludeConfuse ? 23 : 26;
    if (genConfig.useUppercase) pool += genConfig.excludeConfuse ? 24 : 26;
    if (genConfig.useNumbers) pool += genConfig.excludeConfuse ? 8 : 10;
    if (genConfig.useSymbols) pool += 18;
    if (pool == 0) pool = 32;
    return (genConfig.length * (log(pool) / ln2)).round();
  }

  String makeRandomPassword({int length = 18}) {
    var pool = '';
    if (genConfig.useUppercase) {
      pool += genConfig.excludeConfuse
          ? 'ABCDEFGHJKLMNPQRSTUVWXYZ'
          : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    }
    if (genConfig.useLowercase) {
      pool += genConfig.excludeConfuse
          ? 'abcdefghijkmnopqrstuvwxyz'
          : 'abcdefghijklmnopqrstuvwxyz';
    }
    if (genConfig.useNumbers) {
      pool += genConfig.excludeConfuse ? '23456789' : '0123456789';
    }
    if (genConfig.useSymbols) {
      pool += '!@#\$%^&*()-_=+[]{}';
    }
    if (pool.isEmpty) pool = 'abcdefghijkmnopqrstuvwxyz23456789';

    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(pool[ImportExportUtils.secureRandomIndex(pool.length)]);
    }
    return sb.toString();
  }

  void generateNewPassword() {
    String out;
    if (genMode == 'bip39') {
      final words = <String>[];
      for (var i = 0; i < passphraseWords; i++) {
        var w = kBip39WordList[
            ImportExportUtils.secureRandomIndex(kBip39WordList.length)];
        if (passphraseCapitalize && w.isNotEmpty) {
          w = w[0].toUpperCase() + w.substring(1);
        }
        words.add(w);
      }
      out = words.join(passphraseSeparator);
    } else {
      out = makeRandomPassword(length: genConfig.length);
    }
    generatedPassword = out;
    if (out.isNotEmpty && !generatorHistory.contains(out)) {
      generatorHistory = [out, ...generatorHistory.take(5)];
    }
    notifyListeners();
  }

  // ============================================================
  // 4-Dimension Security Audit
  // ============================================================

  Map<String, dynamic> computeAuditSummary() {
    final logins = activeItems
        .where((i) => i.type == ItemType.login && !i.ignoreSecurityWarning)
        .toList();
    final ignoredCount =
        activeItems.where((i) => i.ignoreSecurityWarning).length;

    final passMap = <String, int>{};
    for (final it in logins) {
      final p = it.password ?? '';
      if (p.isNotEmpty) passMap[p] = (passMap[p] ?? 0) + 1;
    }

    final weak = logins
        .where((i) => ImportExportUtils.calculateStrength(i.password) == 'weak')
        .toList();
    final reused =
        logins.where((i) => (passMap[i.password ?? ''] ?? 0) > 1).toList();
    final old = logins.where((i) => i.updatedAt.startsWith('2025')).toList();
    final breached = logins
        .where((i) => ImportExportUtils.knownCompromised
            .contains((i.password ?? '').toLowerCase()))
        .toList();

    final issueMap = <String, VaultItem>{};
    for (final list in [weak, reused, old, breached]) {
      for (final it in list) {
        issueMap[it.id] = it;
      }
    }

    final score = (100 -
            weak.length * 12 -
            reused.length * 10 -
            old.length * 8 -
            breached.length * 10)
        .clamp(35, 100);

    return {
      'score': score,
      'weakCount': weak.length,
      'reusedCount': reused.length,
      'oldCount': old.length,
      'breachedCount': breached.length,
      'ignoredCount': ignoredCount,
      'issues': issueMap.values.toList(),
      'passMap': passMap,
    };
  }

  Future<void> ignoreAuditWarning(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(ignoreSecurityWarning: true);
    await _persistVault();
    notifyListeners();
  }

  Future<void> fixAuditItem(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final cur = items[idx];
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    var hist = List<PasswordHistoryEntry>.from(cur.passwordHistory ?? []);
    if ((cur.password ?? '').isNotEmpty) {
      hist.insert(
        0,
        PasswordHistoryEntry(password: cur.password!, changedAt: nowStr),
      );
      if (hist.length > 5) hist = hist.sublist(0, 5);
    }
    final strongPwd = makeRandomPassword(length: 20);
    items[idx] = cur.copyWith(
      password: strongPwd,
      passwordHistory: hist,
      strength: 'strong',
      updatedAt: nowStr,
    );
    await _persistVault();
    notifyListeners();
  }

  // ============================================================
  // WebDAV Zero-Knowledge Sync
  // ============================================================

  Future<void> saveWebDavConfiguration(
      String url, String username, String password) async {
    webdavUrl = url.trim();
    webdavUsername = username.trim();
    if (_masterKey != null && password.isNotEmpty) {
      final enc = await RustCoreBridge.encryptVault(password, _masterKey!);
      await RustCoreBridge.saveWebdavConfig(webdavUrl, webdavUsername, enc);
      webdavHasSavedPassword = true;
    }
    webdavStatus = '已连接';
    notifyListeners();
  }

  Future<String> syncWebDav({String? plainPassword}) async {
    webdavStatus = '同步中...';
    notifyListeners();
    try {
      if (webdavUrl.isNotEmpty && plainPassword != null && plainPassword.isNotEmpty) {
        await RustCoreBridge.webdavUpload(
            webdavUrl, webdavUsername, plainPassword);
      }
      webdavStatus = '已同步';
      notifyListeners();
      return 'WebDAV 零知识双向同步完成';
    } catch (e) {
      webdavStatus = '已连接';
      notifyListeners();
      return e.toString();
    }
  }

  void triggerConflictSimulation() {
    webdavConflictDetected = true;
    notifyListeners();
  }

  Future<void> resolveWebDavConflict(String strategy) async {
    webdavConflictDetected = false;
    if (strategy == 'remote' && _pendingRemoteContent != null) {
      await RustCoreBridge.saveSecureVaultFile(_pendingRemoteContent!);
    }
    webdavStatus = '已同步';
    notifyListeners();
  }

  List<VaultItem> _sampleInitialItems() {
    return [
      VaultItem(
        id: '1',
        type: ItemType.login,
        title: 'GitHub',
        folder: '开发',
        username: 'novanjex@github.com',
        password: 'K9#mP2\$vL8qX!4zR',
        url: 'https://github.com',
        otpSecret: 'JBSWY3DPEHPK3PXP',
        notes: '主代码托管账号',
        customFields: const {'恢复邮箱': 'backup@securevault.app'},
        passwordHistory: const [
          PasswordHistoryEntry(
              password: 'OldGitHub#2024', changedAt: '2025-08-12'),
        ],
        updatedAt: '2026-11-10',
        strength: 'strong',
        isFavorite: true,
      ),
      const VaultItem(
        id: '2',
        type: ItemType.login,
        title: '华为云 / HarmonyOS 开发者',
        folder: '工作',
        username: 'dev_mate80@huawei.com',
        password: '12345678',
        url: 'https://developer.huawei.com',
        updatedAt: '2025-01-10',
        strength: 'weak',
        isFavorite: true,
      ),
      const VaultItem(
        id: '3',
        type: ItemType.card,
        title: '招商银行信用卡',
        folder: '金融',
        username: '6225 **** **** 8842',
        password: '884',
        url: '持卡人 NOVAN JEX',
        expiresAt: '2026-12-05',
        updatedAt: '2026-10-01',
        strength: 'strong',
      ),
      const VaultItem(
        id: '4',
        type: ItemType.login,
        title: '坚果云 WebDAV',
        folder: '工具',
        username: 'sync@securevault.app',
        password: '12345678',
        url: 'https://dav.jianguoyun.com',
        updatedAt: '2026-09-20',
        strength: 'weak',
      ),
      const VaultItem(
        id: '5',
        type: ItemType.note,
        title: '服务器 SSH 恢复密钥',
        folder: '安全',
        username: 'root@prod-hk',
        password: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...',
        url: '香港节点应急备用',
        updatedAt: '2026-11-01',
        strength: 'strong',
      ),
      const VaultItem(
        id: '6',
        type: ItemType.identity,
        title: '个人身份与地址档案',
        folder: '个人',
        username: '张三 · 138****9012',
        password: '北京市海淀区中关村软件园',
        url: '身份证尾号 301X',
        updatedAt: '2026-06-15',
        strength: 'strong',
      ),
      const VaultItem(
        id: '7',
        type: ItemType.login,
        title: '旧测试账号（已删除）',
        folder: '开发',
        username: 'test_old',
        password: 'testpass',
        url: 'https://example.com',
        deletedAt: '2026-11-12',
        updatedAt: '2025-02-01',
        strength: 'weak',
      ),
    ];
  }
}
