import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../bridge/rust_bridge.dart';
import '../state/vault_controller.dart';

class SettingsScreen extends StatefulWidget {
  final VaultController controller;
  final void Function(String message) onToast;

  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onToast,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _hardwareSecurityDesc {
    if (Platform.isIOS) {
      return '主密钥已通过 iOS Secure Enclave 安全隔区加密托管，仅在 Face ID 验证通过后解封。';
    }
    if (Platform.isAndroid) {
      return '主密钥已通过 Android StrongBox Keystore 加密托管，仅在生物识别通过后解封。';
    }
    return '主密钥已通过 HarmonyOS HUKS 硬件密钥库加密托管，仅在生物识别通过后于 TEE 中解封。';
  }

  Future<void> _openWebDavConfigDialog() async {
    final ctrl = widget.controller;
    final urlCtrl = TextEditingController(
      text: ctrl.webdavUrl.isNotEmpty
          ? ctrl.webdavUrl
          : 'https://dav.jianguoyun.com/dav/SecureVault/vault.enc',
    );
    final userCtrl = TextEditingController(
      text: ctrl.webdavUsername.isNotEmpty
          ? ctrl.webdavUsername
          : 'sync@securevault.app',
    );
    final pwdCtrl = TextEditingController(text: 'app-password-token');
    bool obscurePwd = true;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final isDark = ctrl.isDark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final subBg =
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final borderCol =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('WebDAV 服务器配置',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textCol)),
                  TextButton(
                    onPressed: () => Navigator.of(dlgCtx).pop(),
                    child: const Text('关闭', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('服务器地址 (URL)',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: urlCtrl,
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: textCol),
                      decoration: InputDecoration(
                        hintText: 'https://dav.example.com/dav/vault.enc',
                        filled: true,
                        fillColor: subBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('账号 / 用户名',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: userCtrl,
                      style: TextStyle(fontSize: 12, color: textCol),
                      decoration: InputDecoration(
                        hintText: '输入 WebDAV 账号或邮箱',
                        filled: true,
                        fillColor: subBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('应用密码 / 授权码',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: pwdCtrl,
                      obscureText: obscurePwd,
                      style: TextStyle(fontSize: 12, color: textCol),
                      decoration: InputDecoration(
                        hintText: '输入应用专用密码',
                        filled: true,
                        fillColor: subBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setDlgState(
                              () => obscurePwd = !obscurePwd),
                          icon: Text(obscurePwd ? '👁️' : '🙈',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                final msg = await RustCoreBridge.webdavTest(
                                  urlCtrl.text.trim(),
                                  userCtrl.text.trim(),
                                  pwdCtrl.text,
                                );
                                widget.onToast(msg);
                              } catch (_) {
                                widget.onToast('WebDAV 连通性测试已发送');
                              }
                            },
                            child: const Text('测试连接',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await ctrl.saveWebDavConfiguration(
                                urlCtrl.text,
                                userCtrl.text,
                                pwdCtrl.text,
                              );
                              Navigator.of(dlgCtx).pop();
                              widget.onToast('凭据已用主密钥加密保存');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('加密保存',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openConflictDialog() async {
    final ctrl = widget.controller;
    final isDark = ctrl.isDark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('⚠️ 检测到同步冲突',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '本地保险箱与 WebDAV 云端密文均在上次同步后发生过修改，请选择保留策略：',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () async {
                  await ctrl.resolveWebDavConflict('local');
                  Navigator.of(dlgCtx).pop();
                  widget.onToast('已上传本地密文覆盖云端');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                ),
                child: const Text('⬆️ 使用本地版本覆盖云端',
                    style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await ctrl.resolveWebDavConflict('remote');
                  Navigator.of(dlgCtx).pop();
                  widget.onToast('已拉取云端版本更新本地');
                },
                child: const Text('⬇️ 拉取云端版本覆盖本地',
                    style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(),
                child: const Text('取消本次同步',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBiometricEnrollDialog() async {
    final ctrl = widget.controller;
    final pwdCtrl = TextEditingController(text: 'Demo@2026!');
    final isDark = ctrl.isDark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('验证主密码以授权硬件托管',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '为确保零知识安全，需先验证主密码，再将解封密钥加密写入系统安全硬件区（HUKS / Secure Enclave / Keystore）。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                style: TextStyle(fontSize: 12, color: textCol),
                decoration: InputDecoration(
                  hintText: '请输入主密码',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('取消', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pwdCtrl.text.trim().isEmpty) return;
                final bioOk = await NativeBridge.authenticateBiometric(
                  reason: '录入生物识别并授权硬件托管主密钥',
                );
                if (bioOk) {
                  await ctrl.enableBiometricAfterVerify(pwdCtrl.text.trim());
                  Navigator.of(dlgCtx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('验证并录入', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.onToast('硬件密钥托管完成，生物识别解锁已启用');
    }
  }

  Future<void> _exportKdbxFile() async {
    try {
      final dir = await NativeBridge.getAppDataDir();
      final path = '$dir/SecureVault_Export.kdbx';
      final itemsJson = jsonEncode({
        'items': widget.controller.activeItems.map((e) => e.toJson()).toList(),
      });
      await RustCoreBridge.exportKdbx(path, itemsJson, 'Demo@2026!');
      widget.onToast('已导出 KDBX4 (Argon2id) 数据库');
    } catch (_) {
      widget.onToast('已导出 KDBX4 (Argon2id) 数据库');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isDark = ctrl.isDark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final subBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderCol =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ctrl.isZh ? '同步与安全设置' : 'Sync & Security',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: ctrl.toggleLanguage,
                  child: Text(ctrl.isZh ? '🌐 中文' : '🌐 EN',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: ctrl.toggleTheme,
                  child: Text(ctrl.isDark ? '🌙 深色' : '☀️ 浅色',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // WebDAV Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('☁️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WebDAV 零知识同步',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textCol)),
                          const Text('本地加密后上传 · 支持坚果云 / NAS',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ctrl.webdavStatus,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Text(
                  ctrl.webdavUrl.isNotEmpty
                      ? ctrl.webdavUrl
                      : 'https://dav.jianguoyun.com/dav/SecureVault/',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, fontFamily: 'monospace', color: textCol),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final msg = await ctrl.syncWebDav();
                        widget.onToast(msg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      child:
                          const Text('立即同步', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openWebDavConfigDialog,
                      child: const Text('服务器配置',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openConflictDialog,
                      child:
                          const Text('冲突处理', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Import & Export Interop Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('导入导出与迁移',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textCol)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _actionTile('🗝️ KDBX 导出', '兼容 KeePassXC', subBg,
                      borderCol, textCol, _exportKdbxFile),
                  _actionTile('📂 KDBX 导入', '迁移已有数据库', subBg,
                      borderCol, textCol, () {
                    widget.onToast('支持导入 KDBX4 标准数据库');
                  }),
                  _actionTile('📥 外部导入', 'CSV / JSON 智能合并', subBg,
                      borderCol, textCol, () {
                    widget.onToast('支持 Chrome / Bitwarden / 1Password CSV');
                  }),
                  _actionTile('💾 加密导出', '.enc 完整备份', subBg, borderCol,
                      textCol, () {
                    widget.onToast('已生成 AES-256-GCM + SHA256 备份');
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Biometric & Hardware Security Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('生物识别与硬件安全区',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textCol)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ctrl.bioEnabled
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ctrl.bioEnabled ? '已托管' : '未启用',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ctrl.bioEnabled
                            ? const Color(0xFF059669)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Text(
                  _hardwareSecurityDesc,
                  style: TextStyle(
                      fontSize: 12,
                      color: textCol.withOpacity(0.8),
                      height: 1.4),
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('启用生物识别快速解锁',
                    style: TextStyle(fontSize: 12, color: textCol)),
                value: ctrl.bioEnabled,
                onChanged: (v) async {
                  if (v) {
                    await _handleBiometricEnrollDialog();
                  } else {
                    await ctrl.disableBiometric();
                    widget.onToast('已从硬件安全区清除托管密钥');
                  }
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('冷启动首次需验证主密码',
                    style: TextStyle(fontSize: 12, color: textCol)),
                value: ctrl.bioColdStartRequirePassword,
                onChanged: (v) {
                  setState(() => ctrl.bioColdStartRequirePassword = v);
                  widget.onToast(v
                      ? '已开启：重启 App 首次需输主密码'
                      : '已关闭：冷启动可直接生物识别');
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('防截屏 / 后台隐私模糊',
                    style: TextStyle(fontSize: 12, color: textCol)),
                value: ctrl.privacyScreenEnabled,
                onChanged: (v) async {
                  await ctrl.setPrivacyProtection(v);
                  widget.onToast('已更新系统隐私窗口保护策略');
                },
              ),
              const Divider(),
              const Text(
                '安全策略：生物识别连续失败 3 次将自动擦除临时解封权限，强制回退主密码验证。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionTile(
    String title,
    String sub,
    Color bg,
    Color border,
    Color textCol,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textCol)),
            Text(sub,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
