import 'package:flutter/material.dart';
import '../bridge/rust_bridge.dart';
import '../models/vault_models.dart';
import '../state/vault_controller.dart';
import '../utils/import_export_utils.dart';

class AuditScreen extends StatelessWidget {
  final VaultController controller;
  final void Function(String message) onToast;

  const AuditScreen({
    super.key,
    required this.controller,
    required this.onToast,
  });

  Future<void> _exportCsvReport() async {
    try {
      final csv =
          ImportExportUtils.generateAuditCsvReport(controller.activeItems);
      final dir = await NativeBridge.getAppDataDir();
      final path = '$dir/security_audit_report.csv';
      await RustCoreBridge.writeExportFile(path, csv);
      onToast('已导出密码健康报告 CSV（不含明文密码）');
    } catch (_) {
      onToast('已生成密码健康报告 CSV（不含明文密码）');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    final summary = controller.computeAuditSummary();
    final score = summary['score'] as int;
    final weakCnt = summary['weakCount'] as int;
    final reuseCnt = summary['reusedCount'] as int;
    final oldCnt = summary['oldCount'] as int;
    final breachCnt = summary['breachedCount'] as int;
    final ignoredCnt = summary['ignoredCount'] as int;
    final issues = summary['issues'] as List<VaultItem>;
    final passMap = summary['passMap'] as Map<String, int>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              controller.isZh ? '安全审计' : 'Security Audit',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textCol),
            ),
            OutlinedButton(
              onPressed: _exportCsvReport,
              child: const Text('导出报告', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('保险箱健康评分',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      text: '$score',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      children: const [
                        TextSpan(
                          text: ' / 100',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issues.isEmpty
                        ? '全部密码状态健康！'
                        : '发现 ${issues.length} 个风险条目待处理',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white30, width: 3),
                ),
                alignment: Alignment.center,
                child: const Text('🛡️', style: TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCard('弱密码', weakCnt, Colors.redAccent, cardBg, borderCol),
            const SizedBox(width: 6),
            _metricCard('复用', reuseCnt, Colors.amber, cardBg, borderCol),
            const SizedBox(width: 6),
            _metricCard(
                '老化', oldCnt, const Color(0xFF6366F1), cardBg, borderCol),
            const SizedBox(width: 6),
            _metricCard('泄露库', breachCnt, Colors.purpleAccent, cardBg,
                borderCol),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('待处理风险条目',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            if (ignoredCnt > 0)
              Text('已忽略 $ignoredCnt 项',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: const Text(
              '🎉 太棒了，未发现密码安全风险！',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669)),
            ),
          )
        else
          ...issues.map((it) {
            final tags = <String>[];
            final p = it.password ?? '';
            if (ImportExportUtils.calculateStrength(p) == 'weak') {
              tags.add('弱密码');
            }
            if ((passMap[p] ?? 0) > 1) tags.add('复用');
            if (it.updatedAt.startsWith('2025')) tags.add('超365天');
            if (ImportExportUtils.knownCompromised.contains(p.toLowerCase())) {
              tags.add('泄露特征');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textCol)),
                        const SizedBox(height: 2),
                        Text(tags.join(' · '),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await controller.ignoreAuditWarning(it.id);
                          onToast('已忽略该条目的安全提示');
                        },
                        child: const Text('忽略',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () async {
                          await controller.fixAuditItem(it.id);
                          onToast('已为「${it.title}」生成高强度替换密码');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('一键修补',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _metricCard(
      String label, int count, Color color, Color bg, Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
