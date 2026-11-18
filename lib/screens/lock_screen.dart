import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../bridge/rust_bridge.dart';
import '../state/vault_controller.dart';
import '../widgets/anchored_popover.dart';

class LockScreen extends StatefulWidget {
  final VaultController controller;
  final void Function(String message) onToast;

  const LockScreen({
    super.key,
    required this.controller,
    required this.onToast,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isSetupMode = false;
  bool _obscureUnlockPwd = true;
  bool _busy = false;
  String _ohosAuthType = 'face'; // 'face' | 'finger'

  final TextEditingController _unlockPwdCtrl =
      TextEditingController(text: 'Demo@2026!');
  final TextEditingController _setupPwdCtrl = TextEditingController();

  @override
  void dispose() {
    _unlockPwdCtrl.dispose();
    _setupPwdCtrl.dispose();
    super.dispose();
  }

  String get _biometricButtonLabel {
    if (Platform.isIOS) return '使用 Face ID 解锁';
    if (Platform.isAndroid) return '使用系统生物识别解锁';
    return '使用 3D 人脸 / 屏下指纹解锁';
  }

  Future<void> _handlePasswordUnlock() async {
    final pwd = _unlockPwdCtrl.text.trim();
    if (pwd.isEmpty) {
      widget.onToast('请输入主密码');
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.controller.unlockWithPassword(pwd);
    if (mounted) setState(() => _busy = false);
    if (ok) {
      widget.onToast('Argon2id 密钥派生完成，已解锁');
    } else {
      widget.onToast('主密码错误或密文校验失败');
    }
  }

  Future<void> _handleBiometricUnlock() async {
    final ctrl = widget.controller;
    if (!ctrl.bioEnabled) {
      widget.onToast('尚未开启生物识别，请在设置中验证主密码启用');
      return;
    }
    if (ctrl.bioLockedOut) {
      widget.onToast('生物识别连续失败 3 次已临时锁定，请使用主密码解锁');
      return;
    }
    await _showSystemBiometricSheet();
  }

  Future<void> _showSystemBiometricSheet() async {
    String? failText;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = widget.controller.isDark;
            final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Platform.isIOS
                            ? 'iOS LocalAuthentication'
                            : (Platform.isAndroid
                                ? 'Android BiometricPrompt'
                                : 'HarmonyOS 7.0 · userAuth'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                      if (!Platform.isIOS && !Platform.isAndroid)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _authModePill('3D 人脸', 'face', setSheetState),
                              _authModePill('屏下指纹', 'finger', setSheetState),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (failText != null
                              ? Colors.red
                              : const Color(0xFF4F46E5))
                          .withOpacity(0.12),
                      border: Border.all(
                        color: failText != null
                            ? Colors.redAccent
                            : const Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _ohosAuthType == 'face' ? '😊' : '☝️',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Platform.isIOS
                        ? 'Face ID'
                        : (_ohosAuthType == 'face'
                            ? '请正对屏幕进行人脸识别'
                            : '请按压屏下指纹感应区'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textCol),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    failText ?? '通过 TEE 硬件安全环境解封本地保险箱主密钥',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          failText != null ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final locked =
                                widget.controller.recordBiometricFailure();
                            if (locked) {
                              Navigator.of(sheetCtx).pop();
                              widget.onToast(
                                  '连续失败 3 次，已锁定生物识别，请输主密码');
                            } else {
                              setSheetState(() {
                                failText =
                                    '识别不匹配，请重试（失败 ${widget.controller.bioFailCount}/3）';
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('模拟识别失败',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ok = await NativeBridge.authenticateBiometric(
                              reason: '解封 SecureVault 主密钥',
                              authType: _ohosAuthType,
                            );
                            if (ok) {
                              Navigator.of(sheetCtx).pop();
                              await widget.controller
                                  .unlockWithBiometricSuccess();
                              widget.onToast('TEE 硬件解封密钥成功');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('验证通过',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('改用主密码',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _authModePill(
      String label, String mode, StateSetter setSheetState) {
    final active = _ohosAuthType == mode;
    return GestureDetector(
      onTap: () => setSheetState(() => _ohosAuthType = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isDark = ctrl.isDark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF6366F1),
                      Color(0xFF0EA5E9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🛡️', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 12),
              Text(
                'SecureVault',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ctrl.isZh
                    ? '零知识 · 纯本地 · Rust 加密核心'
                    : 'Zero-Knowledge · Local-First · Rust Core',
                style: TextStyle(
                  fontSize: 12,
                  color: textCol.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeTab('解锁已有库', false),
                    _modeTab('首次创建/恢复', true),
                  ],
                ),
              ),
            ],
          ),
          if (!_isSetupMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctrl.isZh ? '主密码' : 'Master Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textCol.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _unlockPwdCtrl,
                  obscureText: _obscureUnlockPwd,
                  style: TextStyle(fontSize: 14, color: textCol),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => _obscureUnlockPwd = !_obscureUnlockPwd),
                      icon: Text(_obscureUnlockPwd ? '👁️' : '🙈',
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '密钥派生: Argon2id (64MB) · AES-256-GCM',
                  style: TextStyle(
                      fontSize: 12, color: textCol.withOpacity(0.55)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy ? null : _handlePasswordUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _busy
                        ? '正在派生密钥...'
                        : (ctrl.isZh ? '解锁保险箱' : 'Unlock Vault'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _handleBiometricUnlock,
                  icon: const Text('🪪', style: TextStyle(fontSize: 14)),
                  label: Text(_biometricButtonLabel,
                      style: TextStyle(fontSize: 12, color: textCol)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cardBg,
                    side: BorderSide(color: borderCol),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '设置新主密码（至少 8 位）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textCol.withOpacity(0.75)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _setupPwdCtrl,
                  obscureText: true,
                  style: TextStyle(fontSize: 13, color: textCol),
                  decoration: InputDecoration(
                    hintText: '输入高强度主密码',
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderCol),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '密钥派生算法 (KDF)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textCol.withOpacity(0.75)),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (btnCtx) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showAnchoredDropdown<String>(
                        anchorContext: btnCtx,
                        currentValue: ctrl.selectedKdf,
                        isDark: isDark,
                        options: const [
                          DropdownOption(
                              value: 'argon2id',
                              label: 'Argon2id (64MB · 推荐)'),
                          DropdownOption(
                              value: 'pbkdf2',
                              label: 'PBKDF2-SHA256 (10万次)'),
                        ],
                      );
                      if (picked != null) {
                        setState(() => ctrl.selectedKdf = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ctrl.selectedKdf == 'argon2id'
                                ? 'Argon2id (64MB · 推荐)'
                                : 'PBKDF2-SHA256 (10万次)',
                            style: TextStyle(fontSize: 12, color: textCol),
                          ),
                          const Text('▾',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    final pwd = _setupPwdCtrl.text.trim().isEmpty
                        ? 'Demo@2026!'
                        : _setupPwdCtrl.text.trim();
                    await ctrl.createNewVault(pwd, kdf: ctrl.selectedKdf);
                    widget.onToast('已创建新保险箱并初始化安全存储');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('创建本地保险箱',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          Text(
            'v1.0.0 Mobile · 离线优先 · 零知识架构',
            style: TextStyle(fontSize: 12, color: textCol.withOpacity(0.45)),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool setup) {
    final active = _isSetupMode == setup;
    return GestureDetector(
      onTap: () => setState(() => _isSetupMode = setup),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? const Color(0xFF0F172A) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
