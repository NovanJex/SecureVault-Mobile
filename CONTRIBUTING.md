# Contributing to SecureVault Mobile

Thank you for contributing to SecureVault Mobile!

## Prerequisites

- **Rust**: Stable toolchain (`rustup target add aarch64-linux-android armv7-linux-androideabi aarch64-apple-ios aarch64-apple-ios-sim aarch64-unknown-linux-ohos`)
- **Flutter**:
  - Android & iOS: Official Flutter SDK (`stable`)
  - HarmonyOS NEXT: OpenHarmony-adapted Flutter SDK (`openharmony-tpc/flutter_flutter`)
- **Platform SDKs**:
  - Android Studio (SDK + NDK)
  - Xcode (on macOS for iOS builds & Simulator)
  - DevEco Studio (HarmonyOS SDK / API 26+ for Mate 80 signing & deployment)

## Running Tests

```bash
# Rust Core unit & FFI tests
cd rust
cargo test

# Flutter Dart unit tests
flutter test
```

## Architecture Notes

- Never store plaintext master keys or WebDAV passwords on disk.
- All heavy cryptographic, KDBX, and HTTP operations must run inside `RustCoreBridge.invoke` (`Isolate.run` -> `sv_invoke`) to keep the UI responsive.
- Keep `.enc`, `KDBX4`, and `WebDAV` payloads 100% compatible with [SecureVault Desktop](https://github.com/NovanJex/SecureVault).
