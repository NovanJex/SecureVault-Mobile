import 'dart:math';
import 'package:flutter/material.dart';

class DropdownOption<T> {
  final T value;
  final String label;

  const DropdownOption({required this.value, required this.label});
}

/// Shows an in-place anchored floating dropdown popover directly below (or above if near the bottom)
/// the clicked trigger widget `anchorContext`, with zero horizontal coordinate glide.
Future<T?> showAnchoredDropdown<T>({
  required BuildContext anchorContext,
  required List<DropdownOption<T>> options,
  required T currentValue,
  required bool isDark,
}) async {
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
  if (renderBox == null || overlay == null) return null;

  final buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final buttonSize = renderBox.size;
  final screenSize = overlay.size;

  final menuWidth = max(buttonSize.width, 176.0);
  var left = buttonOffset.dx;
  if (left + menuWidth > screenSize.width - 12) {
    left = screenSize.width - menuWidth - 12;
  }
  if (left < 12) left = 12;

  final estimatedHeight = min(options.length * 42.0 + 8.0, 250.0);
  final spaceBelow =
      screenSize.height - (buttonOffset.dy + buttonSize.height) - 16;
  final top = spaceBelow >= estimatedHeight
      ? (buttonOffset.dy + buttonSize.height + 6)
      : max(48.0, buttonOffset.dy - estimatedHeight - 6);

  return showGeneralDialog<T>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) {
      final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
      final borderCol =
          isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: borderCol.withOpacity(0.6)),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final active = opt.value == currentValue;
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(opt.value),
                        child: Container(
                          color: active
                              ? const Color(0xFF4F46E5).withOpacity(0.12)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  opt.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: active
                                        ? const Color(0xFF6366F1)
                                        : textCol,
                                  ),
                                ),
                              ),
                              if (active)
                                const Text(
                                  '✓',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Shows an in-place anchored calendar date picker popover with a balanced 3-column
/// quick action footer (`1年后` | `3年后` | `清除`).
/// Returns `null` if dismissed without change, `""` if cleared, or `"YYYY-MM-DD"`.
Future<String?> showAnchoredDatePicker({
  required BuildContext anchorContext,
  required String? initialDate,
  required bool isDark,
}) async {
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
  if (renderBox == null || overlay == null) return null;

  final buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final buttonSize = renderBox.size;
  final screenSize = overlay.size;

  const menuWidth = 264.0;
  var left = buttonOffset.dx + buttonSize.width - menuWidth;
  if (left < 12) left = 12;
  if (left + menuWidth > screenSize.width - 12) {
    left = screenSize.width - menuWidth - 12;
  }

  const estHeight = 290.0;
  final spaceBelow =
      screenSize.height - (buttonOffset.dy + buttonSize.height) - 16;
  final top = spaceBelow >= estHeight
      ? (buttonOffset.dy + buttonSize.height + 6)
      : max(48.0, buttonOffset.dy - estHeight - 6);

  var year = DateTime.now().year;
  var month = DateTime.now().month;
  if (initialDate != null && initialDate.contains('-')) {
    final parts = initialDate.split('-');
    if (parts.length >= 2) {
      year = int.tryParse(parts[0]) ?? year;
      month = int.tryParse(parts[1]) ?? month;
    }
  }

  return showGeneralDialog<String>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) {
      final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
      final borderCol =
          isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

      return StatefulBuilder(
        builder: (context, setModalState) {
          final firstWeekday = DateTime(year, month, 1).weekday % 7;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final mStr = month.toString().padLeft(2, '0');

          String addYears(int delta) {
            final now = DateTime.now();
            final target = DateTime(now.year + delta, now.month, now.day);
            return target.toIso8601String().substring(0, 10);
          }

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setModalState(() {
                                month--;
                                if (month < 1) {
                                  month = 12;
                                  year--;
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text('‹',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textCol)),
                              ),
                            ),
                            Text(
                              '$year年 $month月',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textCol,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setModalState(() {
                                month++;
                                if (month > 12) {
                                  month = 1;
                                  year++;
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text('›',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textCol)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const ['日', '一', '二', '三', '四', '五', '六']
                              .map((d) => SizedBox(
                                    width: 30,
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          children: [
                            for (var i = 0; i < firstWeekday; i++)
                              const SizedBox.shrink(),
                            for (var d = 1; d <= daysInMonth; d++)
                              Builder(builder: (_) {
                                final dStr =
                                    '$year-$mStr-${d.toString().padLeft(2, '0')}';
                                final selected = initialDate == dStr;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => Navigator.of(ctx).pop(dStr),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF4F46E5)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$d',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color:
                                            selected ? Colors.white : textCol,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: borderCol),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () =>
                                    Navigator.of(ctx).pop(addYears(1)),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '1年后',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () =>
                                    Navigator.of(ctx).pop(addYears(3)),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '3年后',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => Navigator.of(ctx).pop(''),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '清除',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textCol.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
