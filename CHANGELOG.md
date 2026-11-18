# Changelog

## [1.0.0] - 2026-11-18

### Added
- **Cross-Platform Rust Core (`securevault_core`)**: Extracted Argon2id / PBKDF2-SHA256, AES-256-GCM, atomic `vault.enc` persistence, RFC 6238 TOTP (including 80-bit secrets), KeePass KDBX4 import/export, and `rustls-tls` WebDAV sync with unified C-ABI FFI (`sv_invoke`).
- **Full Mobile Vault Parity**:
  - Lock screen with existing vault unlock & first-time vault creation / cloud restore.
  - High-fidelity platform biometric unlock with hardware keystore custody and 3-attempt lockout fallback.
  - 4 credential types (Login, Card, Note, Identity), folder management, star favorites, expiry reminders, 5-entry password history with one-tap restore, and dedicated Trash view (plaintext viewing & copying disabled in Trash).
  - Password generator supporting Random & BIP39 2048-word passphrases with entropy estimation.
  - 4-dimension security audit (Weak, Reused, Aged >365d, Compromised) with ignore, one-tap fix, and CSV report export.
  - WebDAV configuration, connectivity testing, and 3-way conflict resolution.
- **Native Platform Bridges & CI**:
  - Android (`MainActivity.kt`), iOS (`AppDelegate.swift`), and HarmonyOS NEXT 7.0 API 26 (`EntryAbility.ets`).
  - GitHub Actions workflow `.github/workflows/build-mobile.yml` building Android `.apk`, iOS Simulator `.app` / unsigned `.ipa`, and HarmonyOS unsigned `.hap`.
