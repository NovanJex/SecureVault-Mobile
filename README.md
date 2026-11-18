<h1 align="center">SecureVault Mobile</h1>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="version" />
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Rust-FFI-orange?logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20HarmonyOS%20NEXT-lightgrey" alt="platform" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license" />
</p>

<p align="center">
  <b>零知识 · 纯本地 · 跨平台移动端密码管理器</b>
</p>

<p align="center">
  基于 <b>Flutter + Rust FFI (`securevault_core`)</b> 构建。所有核心加解密、KDBX4 互操作、TOTP 动态码与 WebDAV 同步均在 Rust 底层完成，数据格式与 <a href="https://github.com/NovanJex/SecureVault">SecureVault 桌面端</a> 100% 互通。
</p>

<p align="center">
  📖 <a href="README_EN.md">English Documentation</a> · 📋 <a href="CHANGELOG.md">更新日志</a> · 🤝 <a href="CONTRIBUTING.md">开发与贡献指南</a>
</p>

---

## 🔒 安全架构

| 层级 | 技术 / 算法 | 说明 |
| --- | --- | --- |
| 密钥派生 | **Argon2id** (64MB) / **PBKDF2-SHA256** (10万次) | 双算法可选，抗 GPU/ASIC 暴力破解 |
| 数据加密 | **AES-256-GCM** | 12-byte 随机 Nonce，认证加密防篡改 |
| 跨端核心 | **Rust `securevault_core` (C-ABI FFI)** | 通过 `dart:ffi` + `Isolate.run` 异步调用 |
| 硬件安全区 | **HUKS (鸿蒙) / Secure Enclave (iOS) / Keystore (Android)** | 生物识别解锁托管主密钥，连续失败 3 次强制回退主密码 |
| 隐私防护 | **系统级防截屏 / 后台模糊** | 鸿蒙 `setWindowPrivacyMode` / Android `FLAG_SECURE` |
| 剪贴板安全 | **30 秒自动擦除** | 复制敏感字段后自动清空系统剪贴板 |

---

## ✨ 核心功能

- **🔐 全功能保险箱**：支持登录账号 / 虚拟卡券 / 安全备忘 / 密保资料 4 类凭证；文件夹管理与筛选、星标收藏、到期日期提醒、最近 5 条密码历史一键恢复、顶部独立回收站（回收站内禁止查看明文与复制）。
- **🧬 生物识别硬件托管**：支持 HarmonyOS 7.0（3D 人脸 / 屏下指纹）、iOS Face ID / Touch ID、Android 生物识别；开启需先验证主密码，连续失败 3 次自动锁定并回退主密码。
- **🔢 TOTP 两步验证**：内置 RFC 6238 动态验证码生成器（兼容 GitHub 等 80-bit 短密钥），实时 30 秒倒计时。
- **🎲 密码生成器**：随机密码 + BIP39 2048 词库助记词双模式，实时熵值与破译时间估算、生成历史缓存。
- **🛡️ 4 维度安全审计**：弱密码、跨服务复用、超 365 天老化、已知泄露特征碰撞；支持忽略警告、一键生成强密码修补、导出不含明文的 CSV 健康报告。
- **☁️ WebDAV 零知识同步与互操作**：支持坚果云 / NAS / Nextcloud（本地加密后上传、三选一冲突处理）、KeePass KDBX4 双向导入导出、Chrome / Bitwarden / 1Password CSV 与 JSON 导入。
- **🎨 原生级移动端交互**：浅色 / 深色主题自适应、中 / 英双语切换、原地锚定下拉菜单与日历选择器。

---

## 🛠️ 本地开发环境

### 1. Rust 核心库测试（Windows / macOS / Linux）

```bash
cd rust
cargo test
```

### 2. macOS 15.7.2 一键运行 iOS 模拟器

```bash
chmod +x scripts/macos_run_sim.sh
./scripts/macos_run_sim.sh
```

### 3. 目录结构

```text
securevault_app/
├── .github/workflows/
│   └── build-mobile.yml          # Android / iOS / HarmonyOS 三端 CI 构建
├── rust/                         # 跨平台 Rust 核心库 (securevault_core)
├── lib/                          # Flutter UI、状态管理、FFI 桥接与工具库
├── test/                         # Dart 单元测试
├── platform_overrides/           # Android / iOS / HarmonyOS 原生 MethodChannel 桥接
├── scripts/                      # macOS iOS 模拟器一键启动脚本
├── README.md / README_EN.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```
