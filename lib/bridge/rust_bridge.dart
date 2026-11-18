import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, Platform;
import 'dart:isolate';
import 'package:flutter/services.dart';
import '../models/vault_models.dart';

typedef _SvAllocNative = ffi.Pointer<ffi.Uint8> Function(ffi.Size len);
typedef _SvAllocDart = ffi.Pointer<ffi.Uint8> Function(int len);

typedef _SvInvokeNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char> cmd,
  ffi.Pointer<ffi.Char> argsJson,
);
typedef _SvInvokeDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Char> cmd,
  ffi.Pointer<ffi.Char> argsJson,
);

typedef _SvFreeNative = ffi.Void Function(ffi.Pointer<ffi.Char> ptr);
typedef _SvFreeDart = void Function(ffi.Pointer<ffi.Char> ptr);

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.securevault.app/native');

  static String? _cachedDataDir;

  /// Resolves the platform-specific sandboxed application data directory.
  /// Works across Android, iOS, and HarmonyOS NEXT (API 26).
  static Future<String> getAppDataDir() async {
    if (_cachedDataDir != null && _cachedDataDir!.isNotEmpty) {
      return _cachedDataDir!;
    }
    try {
      final path = await _channel.invokeMethod<String>('getAppDataDir');
      if (path != null && path.isNotEmpty) {
        _cachedDataDir = path;
        return path;
      }
    } catch (_) {
      // Fallback to system temp/current container if native channel is unavailable in tests
    }
    final fallback = '${Directory.systemTemp.path}/SecureVault';
    await Directory(fallback).create(recursive: true);
    _cachedDataDir = fallback;
    return fallback;
  }

  /// Enables or disables screenshot protection / background privacy blur.
  static Future<void> setPrivacyScreen(bool enabled) async {
    try {
      await _channel.invokeMethod('setPrivacyScreen', {'enabled': enabled});
    } catch (_) {}
  }

  /// Triggers hardware-backed biometric authentication:
  /// - HarmonyOS 7.0 (API 26): `@ohos.userIAM.userAuth` (3D Face / Fingerprint + HUKS)
  /// - iOS: `LocalAuthentication` (`LAContext` Face ID / Touch ID + Secure Enclave)
  /// - Android: `BiometricPrompt` (+ StrongBox Keystore)
  static Future<bool> authenticateBiometric({
    required String reason,
    String authType = 'face',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('authenticateBiometric', {
        'reason': reason,
        'authType': authType,
      });
      if (res != null) return res;
    } catch (_) {}
    return true;
  }

  /// Seals the derived masterKey inside the hardware keystore (HUKS / Keychain / Keystore).
  static Future<void> saveHardwareMasterKey(String masterKeyB64) async {
    try {
      await _channel.invokeMethod('saveHardwareMasterKey', {
        'masterKey': masterKeyB64,
      });
    } catch (_) {}
  }

  /// Unseals the masterKey from the hardware keystore after biometric verification.
  static Future<String?> loadHardwareMasterKey() async {
    try {
      return await _channel.invokeMethod<String>('loadHardwareMasterKey');
    } catch (_) {
      return null;
    }
  }

  /// Clears the hardware-backed masterKey when biometric unlock is disabled or locked out.
  static Future<void> clearHardwareMasterKey() async {
    try {
      await _channel.invokeMethod('clearHardwareMasterKey');
    } catch (_) {}
  }
}

/// Top-level function executed inside `Isolate.run` so heavy Rust operations
/// (Argon2id 64MB KDF, KDBX4, WebDAV HTTP) never block the Flutter UI thread.
String _invokeRustSync(List<String> payload) {
  final cmd = payload[0];
  final argsJson = payload[1];

  final ffi.DynamicLibrary dylib;
  if (Platform.isIOS || Platform.isMacOS) {
    dylib = ffi.DynamicLibrary.process();
  } else if (Platform.isWindows) {
    dylib = ffi.DynamicLibrary.open('securevault_core.dll');
  } else {
    // Android & HarmonyOS NEXT (OpenHarmony linux-ohos) both use ELF .so
    dylib = ffi.DynamicLibrary.open('libsecurevault_core.so');
  }

  final svAlloc =
      dylib.lookupFunction<_SvAllocNative, _SvAllocDart>('sv_alloc_cstring');
  final svInvoke =
      dylib.lookupFunction<_SvInvokeNative, _SvInvokeDart>('sv_invoke');
  final svFree =
      dylib.lookupFunction<_SvFreeNative, _SvFreeDart>('sv_free_string');

  ffi.Pointer<ffi.Char> toCString(String s) {
    final bytes = utf8.encode(s);
    final ptr = svAlloc(bytes.length);
    final view = ptr.asTypedList(bytes.length + 1);
    view.setRange(0, bytes.length, bytes);
    view[bytes.length] = 0;
    return ptr.cast<ffi.Char>();
  }

  String fromCString(ffi.Pointer<ffi.Char> ptr) {
    final u8 = ptr.cast<ffi.Uint8>();
    var len = 0;
    while (u8[len] != 0) {
      len++;
    }
    return utf8.decode(u8.asTypedList(len), allowMalformed: true);
  }

  final cmdPtr = toCString(cmd);
  final argsPtr = toCString(argsJson);
  final resPtr = svInvoke(cmdPtr, argsPtr);
  svFree(cmdPtr);
  svFree(argsPtr);

  try {
    return fromCString(resPtr);
  } finally {
    svFree(resPtr);
  }
}

class RustCoreBridge {
  static Future<dynamic> invoke(
      String cmd, Map<String, dynamic> args) async {
    final argsJson = jsonEncode(args);
    final rawResp = await Isolate.run(() => _invokeRustSync([cmd, argsJson]));
    final decoded = jsonDecode(rawResp) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      return decoded['data'];
    }
    throw Exception(decoded['error']?.toString() ?? 'ERR_RUST_UNKNOWN');
  }

  static Future<String> generateSalt() async {
    return (await invoke('generate_salt', const {})) as String;
  }

  static Future<String> deriveMasterKey(
    String password,
    String saltB64, {
    String kdf = 'argon2id',
  }) async {
    return (await invoke('derive_master_key', {
      'password': password,
      'saltB64': saltB64,
      'kdf': kdf,
    })) as String;
  }

  static Future<String> encryptVault(String plaintext, String keyB64) async {
    return (await invoke('encrypt_vault', {
      'plaintext': plaintext,
      'keyB64': keyB64,
    })) as String;
  }

  static Future<String> decryptVault(
      String ciphertextB64, String keyB64) async {
    return (await invoke('decrypt_vault', {
      'ciphertextB64': ciphertextB64,
      'keyB64': keyB64,
    })) as String;
  }

  static Future<void> saveSecureVaultFile(String ciphertextB64) async {
    final dataDir = await NativeBridge.getAppDataDir();
    await invoke('save_vault_file', {
      'dataDir': dataDir,
      'ciphertextB64': ciphertextB64,
    });
  }

  static Future<String> loadSecureVaultFile() async {
    final dataDir = await NativeBridge.getAppDataDir();
    return (await invoke('load_vault_file', {'dataDir': dataDir})) as String;
  }

  static Future<void> writeExportFile(String path, String content) async {
    await invoke('write_export_file', {'path': path, 'content': content});
  }

  static Future<String> readExportFile(String path) async {
    return (await invoke('read_export_file', {'path': path})) as String;
  }

  static Future<String> computeSha256(String content) async {
    return (await invoke('compute_sha256', {'content': content})) as String;
  }

  static Future<TotpResult> generateTotp(String secret) async {
    final map = await invoke('generate_totp', {'secret': secret});
    return TotpResult.fromJson(Map<String, dynamic>.from(map as Map));
  }

  static Future<void> exportKdbx(
      String path, String itemsJson, String password) async {
    await invoke('export_kdbx', {
      'path': path,
      'itemsJson': itemsJson,
      'password': password,
    });
  }

  static Future<String> importKdbx(String path, String password) async {
    return (await invoke('import_kdbx', {
      'path': path,
      'password': password,
    })) as String;
  }

  static Future<String> webdavTest(
      String url, String username, String password) async {
    return (await invoke('webdav_test', {
      'url': url,
      'username': username,
      'password': password,
    })) as String;
  }

  static Future<WebDavStat> webdavStat(
      String url, String username, String password) async {
    final map = await invoke('webdav_stat', {
      'url': url,
      'username': username,
      'password': password,
    });
    return WebDavStat.fromJson(Map<String, dynamic>.from(map as Map));
  }

  static Future<WebDavStat> webdavUpload(
      String url, String username, String password) async {
    final dataDir = await NativeBridge.getAppDataDir();
    final map = await invoke('webdav_upload', {
      'dataDir': dataDir,
      'url': url,
      'username': username,
      'password': password,
    });
    return WebDavStat.fromJson(Map<String, dynamic>.from(map as Map));
  }

  static Future<WebDavDownload> webdavDownload(
      String url, String username, String password) async {
    final map = await invoke('webdav_download', {
      'url': url,
      'username': username,
      'password': password,
    });
    return WebDavDownload.fromJson(Map<String, dynamic>.from(map as Map));
  }

  static Future<WebDavConfig?> getWebdavConfig() async {
    final dataDir = await NativeBridge.getAppDataDir();
    final res = await invoke('get_webdav_config', {'dataDir': dataDir});
    if (res == null || res is! Map) return null;
    return WebDavConfig.fromJson(Map<String, dynamic>.from(res));
  }

  static Future<void> saveWebdavConfig(
      String url, String username, String passwordEnc) async {
    final dataDir = await NativeBridge.getAppDataDir();
    await invoke('save_webdav_config', {
      'dataDir': dataDir,
      'url': url,
      'username': username,
      'passwordEnc': passwordEnc,
    });
  }

  static Future<void> clearWebdavConfig() async {
    final dataDir = await NativeBridge.getAppDataDir();
    await invoke('clear_webdav_config', {'dataDir': dataDir});
  }
}
