<h1 align="center">SecureVault Mobile</h1>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="version" />
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Rust-FFI-orange?logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20HarmonyOS%20NEXT-lightgrey" alt="platform" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license" />
</p>

<p align="center">
  <b>Zero-Knowledge · Offline-First · Cross-Platform Mobile Password Manager</b>
</p>

<p align="center">
  Built with <b>Flutter + Rust FFI (`securevault_core`)</b>. All cryptography, KDBX4 interoperability, TOTP generation, and WebDAV sync run in Rust and remain 100% compatible with <a href="https://github.com/NovanJex/SecureVault">SecureVault Desktop</a>.
</p>

<p align="center">
  📖 <a href="README.md">中文文档</a> · 📋 <a href="CHANGELOG.md">Changelog</a> · 🤝 <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

## 🔒 Security Architecture

- **Key Derivation**: `Argon2id` (64 MiB, 4 iterations, 4 parallelism) or `PBKDF2-HMAC-SHA256` (100,000 iterations)
- **Authenticated Encryption**: `AES-256-GCM` with random 12-byte nonces
- **Hardware Key Custody**: HarmonyOS `HUKS` / iOS `Secure Enclave` / Android `Keystore` with 3-strike biometric lockout
- **Clipboard & Screen Protection**: 30-second clipboard auto-clear and OS-level anti-screenshot flags (`setWindowPrivacyMode` / `FLAG_SECURE`)

---

## 🛠️ Local Verification

```bash
# Run Rust core unit & FFI tests
cd rust && cargo test

# Run iOS Simulator on macOS
chmod +x scripts/macos_run_sim.sh && ./scripts/macos_run_sim.sh
```
