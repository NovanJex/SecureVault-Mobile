#!/usr/bin/env bash
set -euo pipefail

echo "=== SecureVault iOS Simulator One-Click Runner (macOS 15.7.2) ==="

# 1. Ensure Rust iOS targets are installed
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# 2. Generate iOS runner scaffolding if not yet generated
if [ ! -d "ios" ]; then
  cp pubspec.yaml pubspec.yaml.bak
  cp lib/main.dart lib/main.dart.bak
  flutter create --org com.securevault --project-name securevault_app --platforms=ios .
  mv pubspec.yaml.bak pubspec.yaml
  mv lib/main.dart.bak lib/main.dart
  cp platform_overrides/ios/AppDelegate.swift ios/Runner/AppDelegate.swift
fi

# 3. Compile Rust Core for iOS Simulator
cd rust
cargo build --release --target aarch64-apple-ios-sim
cd ..

# 4. Ensure static library is linked
if ! grep -q "libsecurevault_core.a" ios/Flutter/Debug.xcconfig; then
  echo "OTHER_LDFLAGS = \$(inherited) -force_load \$(SRCROOT)/../rust/target/aarch64-apple-ios-sim/release/libsecurevault_core.a" >> ios/Flutter/Debug.xcconfig
fi

# 5. Boot Simulator & Run
open -a Simulator || true
flutter pub get
flutter run
