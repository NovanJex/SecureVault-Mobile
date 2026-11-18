import 'dart:convert';
import 'dart:math';
import '../models/vault_models.dart';

class ImportResult {
  final List<VaultItem> items;
  final int total;
  final int skipped;
  final String sourceName;
  final List<String> folderNames;

  const ImportResult({
    required this.items,
    required this.total,
    required this.skipped,
    required this.sourceName,
    required this.folderNames,
  });
}

class ImportExportUtils {
  static final Random _rng = Random.secure();

  static int secureRandomIndex(int max) => _rng.nextInt(max);

  static String calculateStrength(String? password) {
    if (password == null || password.length < 8) return 'weak';
    var score = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (password.length >= 14 && score >= 3) return 'strong';
    if (password.length >= 10 && score >= 2) return 'medium';
    return 'weak';
  }

  static final Set<String> knownCompromised = {
    'password',
    'password123',
    '123456',
    '12345678',
    'qwerty',
    'admin',
    'letmein',
  };

  /// Extracts Base32 secret from raw secret or `otpauth://totp/...?secret=XXXX` URI.
  static String? extractOtpSecret(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().startsWith('otpauth://')) {
      final uri = Uri.tryParse(trimmed);
      final secret = uri?.queryParameters['secret'];
      if (secret != null && secret.trim().isNotEmpty) {
        return secret.trim().toUpperCase();
      }
    }
    final cleaned = trimmed
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-=]'), '');
    if (cleaned.length >= 16 && RegExp(r'^[A-Z2-7]+$').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }

  /// Parses KDBX JSON returned by `RustCoreBridge.importKdbx`.
  static ImportResult convertKdbxPayload(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    final rawItems = (map['items'] as List?) ?? const [];
    final items = <VaultItem>[];
    final folderSet = <String>{};
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);

    for (final entry in rawItems.whereType<Map>()) {
      final raw = Map<String, dynamic>.from(entry);
      final title = (raw['title'] ?? '').toString();
      final username = (raw['username'] ?? '').toString();
      final password = (raw['password'] ?? '').toString();
      final url = (raw['url'] ?? '').toString();
      final notes = (raw['notes'] ?? '').toString();
      if (title.isEmpty &&
          username.isEmpty &&
          password.isEmpty &&
          url.isEmpty &&
          notes.isEmpty) {
        continue;
      }

      final folder = (raw['folder'] ?? 'KeePass 导入').toString();
      folderSet.add(folder);

      final customMap = <String, String>{};
      if (raw['custom'] is Map) {
        (raw['custom'] as Map).forEach((k, v) {
          customMap[k.toString()] = v?.toString() ?? '';
        });
      }

      final hasCard = customMap.containsKey('CVV') ||
          customMap.containsKey('有效期') ||
          customMap.containsKey('卡号');
      final type = hasCard
          ? ItemType.card
          : (username.isEmpty && password.isEmpty && url.isEmpty
              ? ItemType.note
              : ItemType.login);

      final otpSecret =
          extractOtpSecret(customMap['otp'] ?? customMap['TOTP']);
      customMap.remove('otp');
      customMap.remove('TOTP');
      customMap.remove('卡号');
      customMap.remove('有效期');
      customMap.remove('CVV');

      List<PasswordHistoryEntry>? hist;
      if (raw['passwordHistory'] is List) {
        hist = (raw['passwordHistory'] as List)
            .whereType<Map>()
            .map((e) =>
                PasswordHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
            .take(5)
            .toList();
      }

      items.add(VaultItem(
        id: 'kdbx-${DateTime.now().millisecondsSinceEpoch}-${secureRandomIndex(100000)}',
        type: type,
        title: title.isEmpty ? '未命名条目' : title,
        folder: folder,
        username: username,
        password: password,
        url: url,
        notes: notes,
        cardNumber: customMap['卡号'] ?? username,
        cardExpiry: customMap['有效期'],
        cardCvv: customMap['CVV'],
        customFields: customMap.isEmpty ? null : customMap,
        otpSecret: otpSecret,
        expiresAt: (raw['expiresAt'] ?? '').toString().isEmpty
            ? null
            : raw['expiresAt'].toString(),
        passwordHistory: hist,
        updatedAt: nowStr,
        strength: calculateStrength(password),
        isFavorite: raw['favorite'] == true,
      ));
    }

    return ImportResult(
      items: items,
      total: rawItems.length,
      skipped: rawItems.length - items.length,
      sourceName: 'KeePass KDBX',
      folderNames: folderSet.toList(),
    );
  }

  /// Parses external CSV / Bitwarden JSON files (Chrome, Edge, Firefox, 1Password, LastPass, Bitwarden, Safari).
  static ImportResult parseExternalContent(String content) {
    final trimmed = content.trim();
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);

    // Check Bitwarden JSON
    if (trimmed.startsWith('{')) {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final rawItems = (json['items'] as List?) ?? const [];
      final items = <VaultItem>[];
      final folders = <String>{'Bitwarden 导入'};
      for (final r in rawItems.whereType<Map>()) {
        final login = (r['login'] as Map?) ?? const {};
        final title = (r['name'] ?? '未命名').toString();
        final username = (login['username'] ?? '').toString();
        final password = (login['password'] ?? '').toString();
        final totp = extractOtpSecret(login['totp']?.toString());
        String url = '';
        if (login['uris'] is List && (login['uris'] as List).isNotEmpty) {
          final firstUri = (login['uris'] as List).first;
          if (firstUri is Map) url = (firstUri['uri'] ?? '').toString();
        }
        items.add(VaultItem(
          id: 'bw-${DateTime.now().millisecondsSinceEpoch}-${secureRandomIndex(100000)}',
          type: ItemType.login,
          title: title,
          folder: 'Bitwarden 导入',
          username: username,
          password: password,
          url: url,
          otpSecret: totp,
          notes: r['notes']?.toString(),
          updatedAt: nowStr,
          strength: calculateStrength(password),
          isFavorite: r['favorite'] == true,
        ));
      }
      return ImportResult(
        items: items,
        total: rawItems.length,
        skipped: rawItems.length - items.length,
        sourceName: 'Bitwarden JSON',
        folderNames: folders.toList(),
      );
    }

    // CSV Parser
    final rows = _parseCsv(trimmed);
    if (rows.length < 2) {
      return const ImportResult(
        items: [],
        total: 0,
        skipped: 0,
        sourceName: 'CSV',
        folderNames: [],
      );
    }
    final headers = rows.first.map((e) => e.toLowerCase()).toList();
    int idxOf(List<String> keys) {
      for (final k in keys) {
        final i = headers.indexOf(k);
        if (i >= 0) return i;
      }
      return -1;
    }

    final titleIdx = idxOf(['name', 'title', 'login_name']);
    final urlIdx = idxOf(['url', 'login_uri', 'website']);
    final userIdx = idxOf(['username', 'login_username']);
    final passIdx = idxOf(['password', 'login_password']);
    final otpIdx = idxOf(['totp', 'login_totp', 'otp']);
    final folderIdx = idxOf(['folder', 'grouping']);

    final items = <VaultItem>[];
    final folderSet = <String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      String cell(int idx) => (idx >= 0 && idx < row.length) ? row[idx] : '';
      final pass = cell(passIdx);
      final user = cell(userIdx);
      final url = cell(urlIdx);
      final title = cell(titleIdx).isNotEmpty ? cell(titleIdx) : url;
      if (title.isEmpty && pass.isEmpty) continue;
      final folder =
          cell(folderIdx).isNotEmpty ? cell(folderIdx) : '浏览器导入';
      folderSet.add(folder);
      items.add(VaultItem(
        id: 'csv-${DateTime.now().millisecondsSinceEpoch}-$i',
        type: ItemType.login,
        title: title.isEmpty ? '未命名站点' : title,
        folder: folder,
        username: user,
        password: pass,
        url: url,
        otpSecret: extractOtpSecret(cell(otpIdx)),
        updatedAt: nowStr,
        strength: calculateStrength(pass),
      ));
    }

    return ImportResult(
      items: items,
      total: rows.length - 1,
      skipped: (rows.length - 1) - items.length,
      sourceName: 'CSV 密码表',
      folderNames: folderSet.toList(),
    );
  }

  static List<List<String>> _parseCsv(String text) {
    final content = text.replaceFirst('\uFEFF', '');
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentField = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      final next = (i + 1 < content.length) ? content[i + 1] : '';
      if (inQuotes) {
        if (ch == '"' && next == '"') {
          currentField.write('"');
          i++;
        } else if (ch == '"') {
          inQuotes = false;
        } else {
          currentField.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
        } else if (ch == '\n' || (ch == '\r' && next == '\n')) {
          currentRow.add(currentField.toString().trim());
          if (currentRow.any((f) => f.isNotEmpty)) rows.add(currentRow);
          currentRow = [];
          currentField.clear();
          if (ch == '\r') i++;
        } else {
          currentField.write(ch);
        }
      }
    }
    currentRow.add(currentField.toString().trim());
    if (currentRow.any((f) => f.isNotEmpty)) rows.add(currentRow);
    return rows;
  }

  /// Generates an Excel-compatible UTF-8 BOM CSV Security Health Report (without plaintext passwords).
  static String generateAuditCsvReport(List<VaultItem> activeItems) {
    final logins =
        activeItems.where((i) => !i.isTrashed && i.type == ItemType.login).toList();
    final passCount = <String, int>{};
    for (final it in logins) {
      final p = it.password ?? '';
      if (p.isNotEmpty) passCount[p] = (passCount[p] ?? 0) + 1;
    }

    final sb = StringBuffer('\uFEFF');
    sb.writeln('标题,文件夹,账号,网址,密码强度,是否复用,是否已知泄露,最后更新日期');
    for (final it in logins) {
      final p = it.password ?? '';
      final reused = (passCount[p] ?? 0) > 1 ? '是' : '否';
      final breached = knownCompromised.contains(p.toLowerCase()) ? '是' : '否';
      String esc(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';
      sb.writeln([
        esc(it.title),
        esc(it.folder),
        esc(it.username),
        esc(it.url),
        esc(it.strength),
        esc(reused),
        esc(breached),
        esc(it.updatedAt),
      ].join(','));
    }
    return sb.toString();
  }
}
