import 'package:flutter_test/flutter_test.dart';
import 'package:securevault_app/models/vault_models.dart';
import 'package:securevault_app/utils/import_export_utils.dart';

void main() {
  group('VaultModels & Security Utils', () {
    test('VaultPayload JSON serialization roundtrip', () {
      final item = VaultItem(
        id: '1',
        type: ItemType.login,
        title: 'GitHub',
        folder: '开发',
        username: 'user@example.com',
        password: 'StrongPassword#2026',
        otpSecret: 'JBSWY3DPEHPK3PXP',
        updatedAt: '2026-11-18',
        strength: 'strong',
        isFavorite: true,
      );
      final payload = VaultPayload(
        items: [item],
        folders: const [VaultFolder(id: 'f1', name: '开发')],
      );

      final decoded = VaultPayload.fromJson(payload.toJson());
      expect(decoded.items.length, 1);
      expect(decoded.items.first.title, 'GitHub');
      expect(decoded.items.first.otpSecret, 'JBSWY3DPEHPK3PXP');
      expect(decoded.folders.first.name, '开发');
    });

    test('Password strength & OTP extraction', () {
      expect(ImportExportUtils.calculateStrength('123456'), 'weak');
      expect(ImportExportUtils.calculateStrength('K9#mP2\$vL8qX!4zR'), 'strong');
      expect(
        ImportExportUtils.extractOtpSecret(
            'otpauth://totp/GitHub?secret=JBSWY3DPEHPK3PXP&issuer=GitHub'),
        'JBSWY3DPEHPK3PXP',
      );
    });

    test('Audit CSV report excludes plaintext passwords', () {
      const secret = 'SuperSecretPassword!999';
      final item = VaultItem(
        id: '1',
        type: ItemType.login,
        title: 'TestSite',
        folder: '开发',
        username: 'alice',
        password: secret,
        updatedAt: '2026-11-18',
        strength: 'strong',
      );
      final csv = ImportExportUtils.generateAuditCsvReport([item]);
      expect(csv.contains('TestSite'), isTrue);
      expect(csv.contains(secret), isFalse);
    });
  });
}
