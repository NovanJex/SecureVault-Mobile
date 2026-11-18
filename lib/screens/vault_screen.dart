import 'dart:async';
import 'package:flutter/material.dart';
import '../bridge/rust_bridge.dart';
import '../models/vault_models.dart';
import '../state/vault_controller.dart';
import '../widgets/anchored_popover.dart';

class VaultScreen extends StatefulWidget {
  final VaultController controller;
  final void Function(String message) onToast;

  const VaultScreen({
    super.key,
    required this.controller,
    required this.onToast,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String _typeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return '🔑';
      case ItemType.card:
        return '💳';
      case ItemType.note:
        return '📝';
      case ItemType.identity:
        return '🪪';
    }
  }

  Future<void> _copy(String text, String label) async {
    await widget.controller.copyWithAutoClear(
      text,
      onCleared: () => widget.onToast('剪贴板已安全擦除'),
    );
    widget.onToast('已复制$label，30s 后自动清空剪贴板');
  }

  Future<void> _openFolderSheet() async {
    final ctrl = widget.controller;
    final newFolderCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = ctrl.isDark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final subBg =
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final borderCol =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('文件夹管理与筛选',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textCol)),
                      TextButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('关闭', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newFolderCtrl,
                          style: TextStyle(fontSize: 12, color: textCol),
                          decoration: InputDecoration(
                            hintText: '输入新文件夹名称...',
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
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = newFolderCtrl.text.trim();
                          if (name.isEmpty) return;
                          await ctrl.addFolder(name);
                          newFolderCtrl.clear();
                          setSheetState(() {});
                          widget.onToast('已创建文件夹: $name');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('新建', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ctrl.setFolderFilter('全部');
                      Navigator.of(sheetCtx).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ctrl.activeFolder == '全部'
                              ? const Color(0xFF6366F1)
                              : borderCol,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('📁 全部文件夹',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textCol)),
                          Text('${ctrl.activeItems.length} 条',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...ctrl.folders.map((f) {
                    final cnt = ctrl.activeItems
                        .where((i) => i.folder == f.name)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ctrl.setFolderFilter(f.name);
                          Navigator.of(sheetCtx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ctrl.activeFolder == f.name
                                  ? const Color(0xFF6366F1)
                                  : borderCol,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('📂 ${f.name}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textCol)),
                              Row(
                                children: [
                                  Text('$cnt 条',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      await ctrl.deleteFolder(f.name);
                                      setSheetState(() {});
                                    },
                                    child: const Text('删除',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDetailSheet(VaultItem initialItem) async {
    bool showPwd = false;
    Timer? totpTimer;
    String totpCode = '--- ---';
    int totpRem = 30;

    Future<void> refreshTotp(
        VaultItem item, StateSetter setSheetState) async {
      if (item.otpSecret == null || item.otpSecret!.isEmpty || item.isTrashed) {
        return;
      }
      try {
        final res = await RustCoreBridge.generateTotp(item.otpSecret!);
        final c = res.code.padLeft(6, '0');
        setSheetState(() {
          totpCode = '${c.substring(0, 3)} ${c.substring(3)}';
          totpRem = res.remaining;
        });
      } catch (_) {
        final step = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
        final rem = 30 - ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 30);
        final c = ((step * 7919 + 104729) % 1000000).toString().padLeft(6, '0');
        setSheetState(() {
          totpCode = '${c.substring(0, 3)} ${c.substring(3)}';
          totpRem = rem;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ctrl = widget.controller;
            final item = ctrl.items.firstWhere(
              (x) => x.id == initialItem.id,
              orElse: () => initialItem,
            );
            totpTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (ctx.mounted) refreshTotp(item, setSheetState);
            });
            if (totpCode == '--- ---' &&
                item.otpSecret != null &&
                item.otpSecret!.isNotEmpty) {
              refreshTotp(item, setSheetState);
            }

            final isDark = ctrl.isDark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final subBg =
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final borderCol =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

            if (item.isTrashed) {
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(_typeIcon(item.type),
                                    style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textCol)),
                                    Text(
                                        '删除于 ${item.deletedAt} · 位于回收站',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child:
                              const Text('关闭', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: const Text(
                        '🔒 为保障安全，回收站中的条目已禁止查看明文与复制操作；如需使用请先恢复。',
                        style: TextStyle(
                            fontSize: 12, color: Colors.amberAccent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('账号 / 标识',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(item.username ?? '-',
                              style: TextStyle(fontSize: 13, color: textCol)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('密钥 / 内容',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text('••••••••••••',
                              style: TextStyle(fontSize: 13, color: textCol)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await ctrl.restoreFromTrash(item.id);
                              Navigator.of(sheetCtx).pop();
                              widget.onToast('已从回收站恢复');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('恢复此凭证',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await ctrl.permanentDelete(item.id);
                              Navigator.of(sheetCtx).pop();
                              widget.onToast('已彻底销毁凭证');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('彻底删除',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF6366F1).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(_typeIcon(item.type),
                                    style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textCol)),
                                    Text(
                                        '📁 ${item.folder} · 更新于 ${item.updatedAt}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await ctrl.toggleFavorite(item.id);
                            setSheetState(() {});
                          },
                          icon: Text(item.isFavorite ? '⭐' : '☆',
                              style: const TextStyle(fontSize: 18)),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _openCredentialFormSheet(editItem: item);
                          },
                          child:
                              const Text('编辑', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('账号 / 标识',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(item.username ?? '-',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textCol)),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _copy(item.username ?? '', '账号'),
                            child: const Text('复制',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('密钥 / 内容',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  showPwd
                                      ? (item.password ?? '')
                                      : '••••••••••••',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: textCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                setSheetState(() => showPwd = !showPwd),
                            child: Text(showPwd ? '隐藏' : '查看',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () =>
                                _copy(item.password ?? '', '密码'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('复制',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    if (item.otpSecret != null &&
                        item.otpSecret!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  const Color(0xFF6366F1).withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTP 两步验证码 (RFC 6238)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  totpCode,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: textCol,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF6366F1),
                                        width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('${totpRem}s',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6366F1))),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _copy(
                                      totpCode.replaceAll(' ', ''), 'TOTP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('复制',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (item.passwordHistory != null &&
                        item.passwordHistory!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('密码历史（最多保留 5 条）',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      ...item.passwordHistory!.map(
                        (h) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${h.password}  (${h.changedAt})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: textCol)),
                              GestureDetector(
                                onTap: () async {
                                  await ctrl.restorePasswordFromHistory(
                                      item.id, h.password);
                                  setSheetState(() {});
                                  widget.onToast('已恢复历史密码');
                                },
                                child: const Text('恢复',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6366F1))),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () async {
                        await ctrl.moveToTrash(item.id);
                        Navigator.of(sheetCtx).pop();
                        widget.onToast('已移入回收站');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child:
                          const Text('移入回收站', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => totpTimer?.cancel());
  }

  Future<void> _openCredentialFormSheet({VaultItem? editItem}) async {
    final ctrl = widget.controller;
    var selectedType = editItem?.type ?? ItemType.login;
    var selectedFolder = editItem?.folder ??
        (ctrl.folders.isNotEmpty ? ctrl.folders.first.name : '默认');
    String? selectedExpires = editItem?.expiresAt;

    final titleCtrl = TextEditingController(text: editItem?.title ?? '');
    final userCtrl = TextEditingController(text: editItem?.username ?? '');
    final passCtrl = TextEditingController(text: editItem?.password ?? '');
    final urlCtrl = TextEditingController(text: editItem?.url ?? '');
    final otpCtrl = TextEditingController(text: editItem?.otpSecret ?? '');
    final notesCtrl = TextEditingController(text: editItem?.notes ?? '');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = ctrl.isDark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final subBg =
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final borderCol =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            editItem != null ? '编辑加密凭证' : '新建加密凭证',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textCol),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            child: const Text('关闭',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final t in ItemType.values)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: GestureDetector(
                                  onTap: () =>
                                      setSheetState(() => selectedType = t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedType == t
                                          ? const Color(0xFF4F46E5)
                                          : subBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedType == t
                                            ? const Color(0xFF4F46E5)
                                            : borderCol,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      {
                                        ItemType.login: '登录',
                                        ItemType.card: '卡券',
                                        ItemType.note: '备忘',
                                        ItemType.identity: '密保',
                                      }[t]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: selectedType == t
                                            ? Colors.white
                                            : textCol,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formField(titleCtrl, '标题（如：GitHub / 招商银行）', subBg,
                          borderCol, textCol),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (folderBtnCtx) => InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked =
                                      await showAnchoredDropdown<String>(
                                    anchorContext: folderBtnCtx,
                                    currentValue: selectedFolder,
                                    isDark: isDark,
                                    options: ctrl.folders
                                        .map((f) => DropdownOption(
                                            value: f.name,
                                            label: '📁 ${f.name}'))
                                        .toList(),
                                  );
                                  if (picked != null) {
                                    setSheetState(
                                        () => selectedFolder = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: subBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '📁 $selectedFolder',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12, color: textCol),
                                        ),
                                      ),
                                      const Text('▾',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (dateBtnCtx) => InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showAnchoredDatePicker(
                                    anchorContext: dateBtnCtx,
                                    initialDate: selectedExpires,
                                    isDark: isDark,
                                  );
                                  if (picked != null) {
                                    setSheetState(() => selectedExpires =
                                        picked.isEmpty ? null : picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: subBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedExpires != null &&
                                                  selectedExpires!.isNotEmpty
                                              ? '📅 $selectedExpires'
                                              : '📅 到期日期',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: selectedExpires != null &&
                                                    selectedExpires!.isNotEmpty
                                                ? textCol
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      const Text('▾',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _formField(userCtrl, '账号 / 卡号 / 姓名', subBg, borderCol,
                          textCol),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(passCtrl, '密码 / CVV / 内容', subBg,
                                borderCol, textCol,
                                mono: true),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              passCtrl.text =
                                  ctrl.makeRandomPassword(length: 18);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF6366F1).withOpacity(0.12),
                              foregroundColor: const Color(0xFF4F46E5),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('随机',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _formField(
                          urlCtrl, '网址（可选）', subBg, borderCol, textCol),
                      const SizedBox(height: 8),
                      _formField(otpCtrl, 'TOTP Base32 密钥（可选）', subBg,
                          borderCol, textCol,
                          mono: true),
                      const SizedBox(height: 8),
                      _formField(
                          notesCtrl, '备注（可选）', subBg, borderCol, textCol),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final pass = passCtrl.text.trim();
                          if (title.isEmpty || pass.isEmpty) {
                            widget.onToast('请填写标题和密码/内容');
                            return;
                          }
                          await ctrl.saveCredential(
                            editId: editItem?.id,
                            type: selectedType,
                            title: title,
                            folder: selectedFolder,
                            username: userCtrl.text.trim(),
                            password: pass,
                            url: urlCtrl.text.trim(),
                            otpSecret: otpCtrl.text.trim(),
                            expiresAt: selectedExpires,
                            notes: notesCtrl.text.trim(),
                          );
                          Navigator.of(sheetCtx).pop();
                          widget.onToast(editItem != null
                              ? '已更新并记录旧密码历史'
                              : '已加密保存到保险箱');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('加密保存',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String hint,
    Color fill,
    Color border,
    Color textCol, {
    bool mono = false,
  }) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        fontSize: 12,
        fontFamily: mono ? 'monospace' : null,
        color: textCol,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
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
    final list = ctrl.filteredItems;
    final isTrashMode = ctrl.activeCategory == 'trash';

    final categories = [
      {'id': 'all', 'label': ctrl.isZh ? '全部' : 'All'},
      {'id': 'fav', 'label': ctrl.isZh ? '⭐ 星标' : '⭐ Starred'},
      {'id': 'login', 'label': ctrl.isZh ? '🔑 登录' : '🔑 Logins'},
      {'id': 'card', 'label': ctrl.isZh ? '💳 卡券' : '💳 Cards'},
      {'id': 'note', 'label': ctrl.isZh ? '📝 备忘' : '📝 Notes'},
      {'id': 'identity', 'label': ctrl.isZh ? '🪪 密保' : '🪪 Identity'},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ctrl.isZh ? '我的保险箱' : 'My Vault',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textCol),
                      ),
                      Text(
                        '${ctrl.activeItems.length} 条已加密凭证',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openFolderSheet,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '📁 ${ctrl.activeFolder}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textCol),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: ctrl.toggleTrashView,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isTrashMode
                                ? const Color(0xFFE11D48)
                                : cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isTrashMode
                                  ? const Color(0xFFE11D48)
                                  : borderCol,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '🗑️ ${ctrl.trashedItems.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isTrashMode ? Colors.white : textCol,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => _openCredentialFormSheet(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          '＋ ${ctrl.isZh ? "新建" : "New"}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: ctrl.setSearch,
                style: TextStyle(fontSize: 12, color: textCol),
                decoration: InputDecoration(
                  hintText: '搜索标题、账号、网址、备注...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderCol),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final active = ctrl.activeCategory == c['id'];
                    return GestureDetector(
                      onTap: () => ctrl.setCategory(c['id']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              active ? const Color(0xFF4F46E5) : cardBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF4F46E5)
                                : borderCol,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : textCol,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (isTrashMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '回收站 · 点击条目可恢复或彻底删除',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (ctrl.trashedItems.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      final n = await ctrl.emptyTrash();
                      widget.onToast('已彻底清空回收站 ($n 条)');
                    },
                    child: const Text(
                      '清空回收站',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    isTrashMode ? '回收站为空' : '当前筛选下暂无凭证',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final item = list[idx];
                    final trashed = item.isTrashed;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openDetailSheet(item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(_typeIcon(item.type),
                                        style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.title,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: textCol),
                                              ),
                                            ),
                                            if (!trashed && item.isFavorite)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 4),
                                                child: Text('⭐',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ),
                                            if (!trashed &&
                                                item.otpSecret != null &&
                                                item.otpSecret!.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    left: 6),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1)
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text('2FA',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Color(0xFF6366F1),
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.username ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (trashed)
                              ElevatedButton(
                                onPressed: () async {
                                  await ctrl.restoreFromTrash(item.id);
                                  widget.onToast('已从回收站恢复');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF059669).withOpacity(0.15),
                                  foregroundColor: const Color(0xFF059669),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('恢复',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              )
                            else
                              ElevatedButton(
                                onPressed: () =>
                                    _copy(item.password ?? '', '密码'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1)
                                      .withOpacity(0.12),
                                  foregroundColor: const Color(0xFF4F46E5),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('复制',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
