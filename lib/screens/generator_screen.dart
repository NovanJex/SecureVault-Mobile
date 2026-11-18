import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/anchored_popover.dart';

class GeneratorScreen extends StatelessWidget {
  final VaultController controller;
  final void Function(String message) onToast;

  const GeneratorScreen({
    super.key,
    required this.controller,
    required this.onToast,
  });

  Future<void> _copy(String text, String label) async {
    await controller.copyWithAutoClear(
      text,
      onCleared: () => onToast('剪贴板已安全擦除'),
    );
    onToast('已复制$label，30s 后自动清空剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final subBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderCol =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final bits = controller.currentEntropyBits;
    final strengthLabel =
        bits >= 75 ? '极强' : (bits >= 50 ? '较强' : '一般');
    final crackLabel =
        bits >= 80 ? '约数百万年' : (bits >= 55 ? '约数百年' : '数天内');

    final sepLabelMap = {
      '-': '连字符 (-)',
      '_': '下划线 (_)',
      '.': '点号 (.)',
      ' ': '空格',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              controller.isZh ? '密码生成器' : 'Generator',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _modeBtn('随机密码', 'random'),
                  _modeBtn('BIP39 助记词', 'bip39'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.generatedPassword,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$bits bits · $strengthLabel',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6EE7B7),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(crackLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: controller.generateNewPassword,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        child:
                            const Text('↻ 换一个', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () =>
                            _copy(controller.generatedPassword, '生成密码'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                        ),
                        child:
                            const Text('复制', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (controller.genMode == 'random')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('密码长度',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textCol)),
                    Text('${controller.genConfig.length}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5))),
                  ],
                ),
                Slider(
                  min: 8,
                  max: 48,
                  divisions: 40,
                  value: controller.genConfig.length.toDouble(),
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(length: v.round()),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text('大写字母 A-Z',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.genConfig.useUppercase,
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(useUppercase: v),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text('小写字母 a-z',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.genConfig.useLowercase,
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(useLowercase: v),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text('数字 0-9',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.genConfig.useNumbers,
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(useNumbers: v),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text('特殊符号 !@#\$',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.genConfig.useSymbols,
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(useSymbols: v),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text('排除易混淆字符 (0/O, 1/l/I)',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.genConfig.excludeConfuse,
                  onChanged: (v) => controller.updateGeneratorConfig(
                    controller.genConfig.copyWith(excludeConfuse: v),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('助记词数量 (BIP39 2048 词库)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textCol)),
                    Text('${controller.passphraseWords}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5))),
                  ],
                ),
                Slider(
                  min: 3,
                  max: 10,
                  divisions: 7,
                  value: controller.passphraseWords.toDouble(),
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (v) =>
                      controller.updateBip39Config(words: v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('分隔符',
                        style: TextStyle(fontSize: 12, color: textCol)),
                    Builder(
                      builder: (sepBtnCtx) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showAnchoredDropdown<String>(
                            anchorContext: sepBtnCtx,
                            currentValue: controller.passphraseSeparator,
                            isDark: isDark,
                            options: const [
                              DropdownOption(value: '-', label: '连字符 (-)'),
                              DropdownOption(value: '_', label: '下划线 (_)'),
                              DropdownOption(value: '.', label: '点号 (.)'),
                              DropdownOption(value: ' ', label: '空格'),
                            ],
                          );
                          if (picked != null) {
                            controller.updateBip39Config(sep: picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Row(
                            children: [
                              Text(
                                sepLabelMap[controller.passphraseSeparator] ??
                                    '连字符 (-)',
                                style:
                                    TextStyle(fontSize: 12, color: textCol),
                              ),
                              const SizedBox(width: 8),
                              const Text('▾',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  title: Text('首字母大写',
                      style: TextStyle(fontSize: 12, color: textCol)),
                  value: controller.passphraseCapitalize,
                  onChanged: (v) => controller.updateBip39Config(cap: v),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text('最近生成历史',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey)),
        const SizedBox(height: 8),
        ...controller.generatorHistory.map(
          (h) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    h,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, fontFamily: 'monospace', color: textCol),
                  ),
                ),
                GestureDetector(
                  onTap: () => _copy(h, '历史密码'),
                  child: const Text('复制',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeBtn(String label, String mode) {
    final active = controller.genMode == mode;
    return GestureDetector(
      onTap: () => controller.setGeneratorMode(mode),
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
