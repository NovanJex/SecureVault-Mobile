//! SecureVault Mobile Rust Core (`securevault_core`)
//! 100% compatible with SecureVault Desktop v1.8.0 encryption, KDBX4, TOTP, and WebDAV protocols.
//! Exposes both native Rust functions and a C-ABI JSON FFI (`sv_invoke` / `sv_free_string`)
//! for Flutter (`dart:ffi` across Android, iOS, and HarmonyOS NEXT API 26).

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use argon2::{Algorithm::Argon2id, Argon2, Params, Version};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use pbkdf2::pbkdf2_hmac;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::ffi::{CStr, CString};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};

// ============================================================
// 1. 核心密码学：Argon2id / PBKDF2-SHA256 + AES-256-GCM
// ============================================================

pub fn derive_master_key(password: &str, salt_b64: &str, kdf: Option<&str>) -> Result<String, String> {
    let salt = BASE64
        .decode(salt_b64)
        .map_err(|e| format!("ERR_SALT_B64: {}", e))?;

    let mut key = [0u8; 32];

    match kdf {
        Some("pbkdf2") => {
            pbkdf2_hmac::<Sha256>(password.as_bytes(), &salt, 100_000, &mut key);
        }
        _ => {
            let params = Params::new(65_536, 4, 4, Some(Params::DEFAULT_OUTPUT_LEN))
                .map_err(|e| format!("ERR_KDF: {}", e))?;
            let argon2 = Argon2::new(Argon2id, Version::V0x13, params);
            argon2
                .hash_password_into(password.as_bytes(), &salt, &mut key)
                .map_err(|e| format!("ERR_KDF: {}", e))?;
        }
    }

    Ok(BASE64.encode(key))
}

pub fn encrypt_vault(plaintext: &str, key_b64: &str) -> Result<String, String> {
    let key_bytes = BASE64
        .decode(key_b64)
        .map_err(|e| format!("ERR_KEY_DECODE: {}", e))?;

    if key_bytes.len() != 32 {
        return Err("ERR_KEY_SIZE: must be 32 bytes (256-bit)".into());
    }

    let key = aes_gcm::Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);

    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, plaintext.as_bytes())
        .map_err(|e| format!("ERR_ENCRYPT: {}", e))?;

    let mut packed = Vec::with_capacity(12 + ciphertext.len());
    packed.extend_from_slice(&nonce_bytes);
    packed.extend_from_slice(&ciphertext);

    Ok(BASE64.encode(packed))
}

pub fn decrypt_vault(ciphertext_b64: &str, key_b64: &str) -> Result<String, String> {
    let key_bytes = BASE64
        .decode(key_b64)
        .map_err(|e| format!("ERR_KEY_DECODE: {}", e))?;
    let packed_bytes = BASE64
        .decode(ciphertext_b64)
        .map_err(|e| format!("ERR_CIPHERTEXT_B64: {}", e))?;

    if key_bytes.len() != 32 {
        return Err("ERR_KEY_SIZE".into());
    }
    if packed_bytes.len() < 12 {
        return Err("ERR_CIPHERTEXT_SHORT".into());
    }

    let key = aes_gcm::Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);

    let nonce = Nonce::from_slice(&packed_bytes[..12]);
    let encrypted_data = &packed_bytes[12..];

    let decrypted_bytes = cipher
        .decrypt(nonce, encrypted_data)
        .map_err(|e| format!("ERR_DECRYPT: {}", e))?;

    String::from_utf8(decrypted_bytes).map_err(|e| format!("ERR_UTF8: {}", e))
}

pub fn generate_random_salt_b64() -> String {
    let mut salt = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut salt);
    BASE64.encode(salt)
}

pub fn compute_sha256(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    format!("{:x}", hasher.finalize())
}

// ============================================================
// 2. 本地沙箱文件原子存储（与桌面端 vault.enc / config.json 100% 兼容）
// ============================================================

fn ensure_data_dir(data_dir: &str) -> Result<PathBuf, String> {
    let p = PathBuf::from(data_dir);
    if !p.exists() {
        fs::create_dir_all(&p).map_err(|e| format!("ERR_DATA_DIR_CREATE: {}", e))?;
    }
    Ok(p)
}

fn vault_file_path(data_dir: &str) -> Result<PathBuf, String> {
    Ok(ensure_data_dir(data_dir)?.join("vault.enc"))
}

fn config_file_path(data_dir: &str) -> Result<PathBuf, String> {
    Ok(ensure_data_dir(data_dir)?.join("config.json"))
}

pub fn save_vault_file(data_dir: &str, ciphertext_b64: &str) -> Result<(), String> {
    let file_path = vault_file_path(data_dir)?;
    let tmp_path = file_path.with_extension("enc.tmp");

    let mut file = File::create(&tmp_path).map_err(|e| format!("ERR_TMP_CREATE: {}", e))?;
    file.write_all(ciphertext_b64.as_bytes())
        .map_err(|e| format!("ERR_TMP_WRITE: {}", e))?;
    file.flush().map_err(|e| format!("ERR_FLUSH: {}", e))?;
    drop(file);

    fs::rename(&tmp_path, &file_path).map_err(|e| format!("ERR_RENAME: {}", e))?;
    Ok(())
}

pub fn load_vault_file(data_dir: &str) -> Result<String, String> {
    let file_path = vault_file_path(data_dir)?;
    if !file_path.exists() {
        return Ok(String::new());
    }
    let mut file = File::open(file_path).map_err(|e| format!("ERR_STORAGE_OPEN: {}", e))?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .map_err(|e| format!("ERR_STORAGE_READ: {}", e))?;
    Ok(contents)
}

pub fn write_export_file(path: &str, content: &str) -> Result<(), String> {
    if let Some(parent) = Path::new(path).parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(path, content).map_err(|e| format!("ERR_EXPORT_WRITE: {}", e))
}

pub fn read_export_file(path: &str) -> Result<String, String> {
    let bytes = fs::read(path).map_err(|e| format!("ERR_IMPORT_READ: {}", e))?;
    if let Ok(s) = String::from_utf8(bytes.clone()) {
        return Ok(s);
    }
    let (cow, _, had_errors) = encoding_rs::GBK.decode(&bytes);
    if !had_errors {
        return Ok(cow.into_owned());
    }
    let (cow, _, had_errors) = encoding_rs::UTF_16LE.decode(&bytes);
    if !had_errors {
        return Ok(cow.into_owned());
    }
    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

// ============================================================
// 3. TOTP 两步验证码（RFC 6238，兼容 80-bit 短密钥）
// ============================================================

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TotpResponse {
    pub code: String,
    pub remaining: u64,
}

pub fn normalize_totp_secret(secret: &str) -> String {
    secret
        .trim()
        .to_uppercase()
        .replace([' ', '-', '\t'], "")
        .trim_end_matches('=')
        .to_string()
}

fn url_encode(s: &str) -> String {
    s.bytes()
        .map(|b| {
            if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
                (b as char).to_string()
            } else {
                format!("%{:02X}", b)
            }
        })
        .collect()
}

pub fn generate_totp(secret: &str) -> Result<TotpResponse, String> {
    use totp_rs::{Algorithm, Secret, TOTP};

    let normalized = normalize_totp_secret(secret);
    if normalized.is_empty() {
        return Err("ERR_TOTP_EMPTY".to_string());
    }
    let secret_obj = Secret::Encoded(normalized);
    let bytes = secret_obj
        .to_bytes()
        .map_err(|e| format!("ERR_TOTP_KEY: {}", e))?;
    let totp = TOTP::new_unchecked(Algorithm::SHA1, 6, 0, 30, bytes);
    let code = totp
        .generate_current()
        .map_err(|e| format!("ERR_TOTP_GEN: {}", e))?;
    let remaining = totp.ttl().unwrap_or(0);

    Ok(TotpResponse { code, remaining })
}

// ============================================================
// 4. KeePass KDBX4 双向互操作
// ============================================================

fn parse_iso_dt(s: &str) -> Option<chrono::NaiveDateTime> {
    if s.is_empty() {
        return None;
    }
    let core = if s.len() >= 19 { &s[..19] } else { s };
    chrono::NaiveDateTime::parse_from_str(core, "%Y-%m-%dT%H:%M:%S")
        .or_else(|_| chrono::NaiveDateTime::parse_from_str(core, "%Y-%m-%d %H:%M"))
        .or_else(|_| chrono::NaiveDateTime::parse_from_str(core, "%Y-%m-%dT%H:%M"))
        .ok()
}

pub fn export_kdbx(path: &str, items_json: &str, password: &str) -> Result<(), String> {
    use keepass::config::{DatabaseConfig, DatabaseVersion, KdfConfig};
    use keepass::db::{Database, Entry, Group, History, Value};
    use keepass::DatabaseKey;
    use secstr::SecStr;

    let data: serde_json::Value =
        serde_json::from_str(items_json).map_err(|e| format!("ERR_CRED_PARSE: {}", e))?;
    let items = data
        .get("items")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let mut config = DatabaseConfig::default();
    config.version = DatabaseVersion::KDB4(1);
    let default_version = match DatabaseConfig::default().kdf_config {
        KdfConfig::Argon2 { version, .. } | KdfConfig::Argon2id { version, .. } => version,
        KdfConfig::Aes { .. } => unreachable!(),
    };
    config.kdf_config = KdfConfig::Argon2id {
        iterations: 4,
        memory: 65_536,
        parallelism: 4,
        version: default_version,
    };

    let mut db = Database::new(config);
    db.meta.database_name = Some("SecureVault 保险箱".to_string());

    let get_str = |item: &serde_json::Value, key: &str| -> String {
        item.get(key)
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string()
    };

    let mut folders: Vec<String> = Vec::new();
    for item in &items {
        if !get_str(item, "deletedAt").is_empty() {
            continue;
        }
        let f = get_str(item, "folder");
        let folder = if f.is_empty() {
            "KeePass 导出".to_string()
        } else {
            f
        };
        if !folders.contains(&folder) {
            folders.push(folder);
        }
    }

    const RESERVED: [&str; 10] = [
        "Title",
        "UserName",
        "Password",
        "URL",
        "Notes",
        "SecureVaultFavorite",
        "otp",
        "卡号",
        "有效期",
        "CVV",
    ];

    for folder in folders {
        let mut group = Group::new(&folder);
        for item in &items {
            if !get_str(item, "deletedAt").is_empty() {
                continue;
            }
            let f = get_str(item, "folder");
            let item_folder = if f.is_empty() {
                "KeePass 导出".to_string()
            } else {
                f
            };
            if item_folder != folder {
                continue;
            }

            let mut entry = Entry::new();
            entry
                .fields
                .insert("Title".into(), Value::Unprotected(get_str(item, "title")));
            entry.fields.insert(
                "UserName".into(),
                Value::Unprotected(get_str(item, "username")),
            );
            entry.fields.insert(
                "Password".into(),
                Value::Protected(SecStr::from(get_str(item, "password"))),
            );
            entry
                .fields
                .insert("URL".into(), Value::Unprotected(get_str(item, "url")));
            entry
                .fields
                .insert("Notes".into(), Value::Unprotected(get_str(item, "notes")));

            let item_type = get_str(item, "type");
            if item_type == "card" {
                entry.fields.insert(
                    "卡号".into(),
                    Value::Unprotected(get_str(item, "cardNumber")),
                );
                entry.fields.insert(
                    "有效期".into(),
                    Value::Unprotected(get_str(item, "cardExpiry")),
                );
                entry
                    .fields
                    .insert("CVV".into(), Value::Unprotected(get_str(item, "cardCvv")));
            }
            if item
                .get("isFavorite")
                .and_then(|v| v.as_bool())
                .unwrap_or(false)
            {
                entry
                    .fields
                    .insert("SecureVaultFavorite".into(), Value::Unprotected("1".into()));
            }
            if let Some(custom) = item.get("customFields").and_then(|v| v.as_object()) {
                for (k, v) in custom {
                    if RESERVED.contains(&k.as_str()) {
                        continue;
                    }
                    if let Some(s) = v.as_str() {
                        entry
                            .fields
                            .insert(k.clone(), Value::Unprotected(s.to_string()));
                    }
                }
            }
            let otp = normalize_totp_secret(&get_str(item, "otpSecret"));
            if !otp.is_empty() {
                let otp_url = format!(
                    "otpauth://totp/{}?secret={}&issuer=SecureVault",
                    url_encode(&get_str(item, "title")),
                    otp
                );
                entry.fields.insert("otp".into(), Value::Unprotected(otp_url));
            }
            let expires = get_str(item, "expiresAt");
            if !expires.is_empty() {
                if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(
                    &format!("{}T00:00:00", expires),
                    "%Y-%m-%dT%H:%M:%S",
                ) {
                    entry.times.expires = true;
                    entry.times.set_expiry(dt);
                }
            }
            if let Some(hist) = item.get("passwordHistory").and_then(|v| v.as_array()) {
                if !hist.is_empty() {
                    let mut h = History::default();
                    for rec in hist.iter().rev() {
                        let pw = rec.get("password").and_then(|v| v.as_str()).unwrap_or("");
                        if pw.is_empty() {
                            continue;
                        }
                        let ts = rec.get("changedAt").and_then(|v| v.as_str()).unwrap_or("");
                        let mut old_entry = Entry::new();
                        old_entry.fields.insert(
                            "Title".into(),
                            Value::Unprotected(get_str(item, "title")),
                        );
                        old_entry.fields.insert(
                            "UserName".into(),
                            Value::Unprotected(get_str(item, "username")),
                        );
                        old_entry
                            .fields
                            .insert("Password".into(), Value::Protected(SecStr::from(pw)));
                        if let Some(dt) = parse_iso_dt(ts) {
                            old_entry.times.set_last_modification(dt);
                        }
                        h.add_entry(old_entry);
                    }
                    entry.history = Some(h);
                }
            }
            group.add_child(entry);
        }
        db.root.add_child(group);
    }

    if let Some(parent) = Path::new(path).parent() {
        let _ = fs::create_dir_all(parent);
    }
    let key = DatabaseKey::new().with_password(password);
    let mut file = File::create(path).map_err(|e| format!("ERR_KDBX_CREATE: {}", e))?;
    db.save(&mut file, key)
        .map_err(|e| format!("ERR_KDBX_SAVE: {}", e))?;
    Ok(())
}

pub fn import_kdbx(path: &str, password: &str) -> Result<String, String> {
    use keepass::db::{Database, Group, Value};
    use keepass::DatabaseKey;
    use std::collections::BTreeSet;

    let key = DatabaseKey::new().with_password(password);
    let mut file = File::open(path).map_err(|e| format!("ERR_KDBX_OPEN: {}", e))?;
    let db = Database::open(&mut file, key).map_err(|e| format!("ERR_KDBX_DECRYPT: {}", e))?;

    let mut items: Vec<serde_json::Value> = Vec::new();
    let mut folder_set: BTreeSet<String> = BTreeSet::new();

    fn get_field(fields: &std::collections::HashMap<String, Value>, key: &str) -> String {
        match fields.get(key) {
            Some(Value::Unprotected(s)) => s.clone(),
            Some(Value::Protected(b)) => String::from_utf8_lossy(b.unsecure()).into_owned(),
            Some(Value::Bytes(b)) => String::from_utf8_lossy(b).into_owned(),
            None => String::new(),
        }
    }

    fn walk(
        group: &Group,
        prefix: &str,
        items: &mut Vec<serde_json::Value>,
        folder_set: &mut BTreeSet<String>,
    ) {
        let is_root = prefix.is_empty() && group.name == "Root";
        let path = if is_root {
            String::new()
        } else if prefix.is_empty() {
            group.name.clone()
        } else {
            format!("{}/{}", prefix, group.name)
        };

        for entry in group.entries() {
            let fields = &entry.fields;
            let custom: serde_json::Map<String, serde_json::Value> = fields
                .iter()
                .filter(|(k, _)| {
                    !["Title", "UserName", "Password", "URL", "Notes", "SecureVaultFavorite"]
                        .contains(&k.as_str())
                })
                .map(|(k, v)| {
                    let s = match v {
                        Value::Unprotected(s) => s.clone(),
                        Value::Protected(b) => String::from_utf8_lossy(b.unsecure()).into_owned(),
                        Value::Bytes(b) => String::from_utf8_lossy(b).into_owned(),
                    };
                    (k.clone(), serde_json::Value::String(s))
                })
                .collect();

            let folder = if path.is_empty() {
                "KeePass 导入".to_string()
            } else {
                path.clone()
            };
            folder_set.insert(folder.clone());

            let expires_at = if entry.times.expires {
                entry
                    .times
                    .get_expiry()
                    .map(|dt| dt.format("%Y-%m-%d").to_string())
                    .unwrap_or_default()
            } else {
                String::new()
            };

            let mut pw_hist: Vec<serde_json::Value> = Vec::new();
            if let Some(h) = &entry.history {
                for he in h.get_entries() {
                    let pw = get_field(&he.fields, "Password");
                    if pw.is_empty() {
                        continue;
                    }
                    let ts = he
                        .times
                        .get_last_modification()
                        .map(|dt| dt.format("%Y-%m-%dT%H:%M:%SZ").to_string())
                        .unwrap_or_default();
                    pw_hist.push(serde_json::json!({ "password": pw, "changedAt": ts }));
                    if pw_hist.len() >= 5 {
                        break;
                    }
                }
            }

            items.push(serde_json::json!({
                "title": get_field(fields, "Title"),
                "username": get_field(fields, "UserName"),
                "password": get_field(fields, "Password"),
                "url": get_field(fields, "URL"),
                "notes": get_field(fields, "Notes"),
                "folder": folder,
                "favorite": get_field(fields, "SecureVaultFavorite") == "1",
                "expiresAt": expires_at,
                "custom": serde_json::Value::Object(custom),
                "passwordHistory": pw_hist,
            }));
        }

        for sub in group.groups() {
            walk(sub, &path, items, folder_set);
        }
    }

    walk(&db.root, "", &mut items, &mut folder_set);

    Ok(serde_json::json!({
        "items": items,
        "folders": folder_set.into_iter().collect::<Vec<_>>(),
    })
    .to_string())
}

// ============================================================
// 5. WebDAV 零知识同步（纯 Rust rustls-tls，跨三端无 OpenSSL 依赖）
// ============================================================

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WebDavStat {
    pub exists: bool,
    pub size: u64,
    pub last_modified: Option<String>,
    pub etag: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WebDavDownload {
    pub content: String,
    pub stat: WebDavStat,
}

fn validate_webdav_url(url: &str) -> Result<(), String> {
    let u = url.trim();
    if u.is_empty() {
        return Err("ERR_WEBDAV_URL: 请填写服务器文件地址".to_string());
    }
    if u.starts_with("https://")
        || u.starts_with("http://localhost")
        || u.starts_with("http://127.0.0.1")
    {
        return Ok(());
    }
    Err("ERR_WEBDAV_URL: 仅支持 https:// 服务器地址（本地测试除外）".to_string())
}

fn webdav_client() -> Result<reqwest::blocking::Client, String> {
    reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(45))
        .build()
        .map_err(|e| format!("ERR_WEBDAV_CLIENT: {}", e))
}

fn etag_of(headers: &reqwest::header::HeaderMap) -> Option<String> {
    headers
        .get(reqwest::header::ETAG)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.trim_matches('"').to_string())
}

fn last_modified_of(headers: &reqwest::header::HeaderMap) -> Option<String> {
    headers
        .get(reqwest::header::LAST_MODIFIED)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
}

fn map_webdav_status(code: u16, action: &str) -> String {
    if code == 401 || code == 403 {
        "ERR_WEBDAV_AUTH: 认证失败，请检查用户名与应用专用密码".to_string()
    } else {
        format!("ERR_WEBDAV_STATUS: {}失败，服务器返回 HTTP {}", action, code)
    }
}

pub fn webdav_test(url: &str, username: &str, password: &str) -> Result<String, String> {
    validate_webdav_url(url)?;
    let client = webdav_client()?;
    let resp = client
        .head(url.trim())
        .basic_auth(username, Some(password))
        .send()
        .map_err(|e| format!("ERR_WEBDAV_NET: {}", e))?;
    let code = resp.status().as_u16();
    match code {
        200..=299 => Ok(format!("HTTP {} · 文件已存在", code)),
        404 => Ok("HTTP 404 · 连接成功，服务器上尚无 vault.enc（首次同步将上传）".to_string()),
        _ => Err(map_webdav_status(code, "连接测试")),
    }
}

pub fn webdav_stat(url: &str, username: &str, password: &str) -> Result<WebDavStat, String> {
    validate_webdav_url(url)?;
    let client = webdav_client()?;
    let resp = client
        .head(url.trim())
        .basic_auth(username, Some(password))
        .send()
        .map_err(|e| format!("ERR_WEBDAV_NET: {}", e))?;
    let code = resp.status().as_u16();
    if code == 404 {
        return Ok(WebDavStat {
            exists: false,
            size: 0,
            last_modified: None,
            etag: None,
        });
    }
    if !(200..=299).contains(&code) {
        return Err(map_webdav_status(code, "读取服务器状态"));
    }
    Ok(WebDavStat {
        exists: true,
        size: resp.content_length().unwrap_or(0),
        last_modified: last_modified_of(resp.headers()),
        etag: etag_of(resp.headers()),
    })
}

pub fn webdav_upload(
    data_dir: &str,
    url: &str,
    username: &str,
    password: &str,
) -> Result<WebDavStat, String> {
    validate_webdav_url(url)?;
    let vault_path = vault_file_path(data_dir)?;
    if !vault_path.exists() {
        return Err("ERR_WEBDAV_EMPTY: 本地保险箱文件不存在，无法上传".to_string());
    }
    let content =
        fs::read_to_string(&vault_path).map_err(|e| format!("ERR_STORAGE_READ: {}", e))?;

    let client = webdav_client()?;
    let resp = client
        .put(url.trim())
        .basic_auth(username, Some(password))
        .header(reqwest::header::CONTENT_TYPE, "text/plain; charset=utf-8")
        .body(content)
        .send()
        .map_err(|e| format!("ERR_WEBDAV_NET: {}", e))?;
    let code = resp.status().as_u16();
    if !(200..=299).contains(&code) {
        return Err(map_webdav_status(code, "上传"));
    }

    let stat_resp = client
        .head(url.trim())
        .basic_auth(username, Some(password))
        .send()
        .map_err(|e| format!("ERR_WEBDAV_NET: {}", e))?;
    Ok(WebDavStat {
        exists: true,
        size: stat_resp.content_length().unwrap_or(0),
        last_modified: last_modified_of(stat_resp.headers()),
        etag: etag_of(stat_resp.headers()),
    })
}

pub fn webdav_download(url: &str, username: &str, password: &str) -> Result<WebDavDownload, String> {
    validate_webdav_url(url)?;
    let client = webdav_client()?;
    let resp = client
        .get(url.trim())
        .basic_auth(username, Some(password))
        .send()
        .map_err(|e| format!("ERR_WEBDAV_NET: {}", e))?;
    let code = resp.status().as_u16();
    if code == 404 {
        return Err("ERR_WEBDAV_NOT_FOUND: 服务器上不存在 vault.enc".to_string());
    }
    if !(200..=299).contains(&code) {
        return Err(map_webdav_status(code, "下载"));
    }
    let stat = WebDavStat {
        exists: true,
        size: resp.content_length().unwrap_or(0),
        last_modified: last_modified_of(resp.headers()),
        etag: etag_of(resp.headers()),
    };
    let content = resp
        .text()
        .map_err(|e| format!("ERR_WEBDAV_READ: {}", e))?;
    Ok(WebDavDownload { content, stat })
}

fn read_config_json(data_dir: &str) -> serde_json::Value {
    match config_file_path(data_dir) {
        Ok(p) if p.exists() => fs::read_to_string(&p)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_else(|| serde_json::json!({})),
        _ => serde_json::json!({}),
    }
}

pub fn get_webdav_config(data_dir: &str) -> Option<serde_json::Value> {
    read_config_json(data_dir).get("webdav").cloned()
}

pub fn save_webdav_config(
    data_dir: &str,
    url: &str,
    username: &str,
    password_enc: &str,
) -> Result<(), String> {
    validate_webdav_url(url)?;
    let cfg_path = config_file_path(data_dir)?;
    let mut cfg = read_config_json(data_dir);
    cfg["webdav"] = serde_json::json!({
        "url": url.trim(),
        "username": username,
        "passwordEnc": password_enc,
    });
    let serialized =
        serde_json::to_string_pretty(&cfg).map_err(|e| format!("ERR_CONFIG_SERIALIZE: {}", e))?;
    fs::write(&cfg_path, serialized).map_err(|e| format!("ERR_CONFIG_WRITE: {}", e))
}

pub fn clear_webdav_config(data_dir: &str) -> Result<(), String> {
    let cfg_path = config_file_path(data_dir)?;
    let mut cfg = read_config_json(data_dir);
    if let Some(obj) = cfg.as_object_mut() {
        obj.remove("webdav");
    }
    let serialized =
        serde_json::to_string_pretty(&cfg).map_err(|e| format!("ERR_CONFIG_SERIALIZE: {}", e))?;
    fs::write(&cfg_path, serialized).map_err(|e| format!("ERR_CONFIG_WRITE: {}", e))
}

// ============================================================
// 6. C-ABI 统一 JSON 路由入口（供 Flutter dart:ffi 跨平台调用）
// ============================================================

fn dispatch_command(cmd: &str, args: &serde_json::Value) -> Result<serde_json::Value, String> {
    let s = |k: &str| args.get(k).and_then(|v| v.as_str()).unwrap_or("");
    match cmd {
        "derive_master_key" => {
            let kdf = args.get("kdf").and_then(|v| v.as_str());
            let key = derive_master_key(s("password"), s("saltB64"), kdf)?;
            Ok(serde_json::Value::String(key))
        }
        "generate_salt" => Ok(serde_json::Value::String(generate_random_salt_b64())),
        "encrypt_vault" => {
            let out = encrypt_vault(s("plaintext"), s("keyB64"))?;
            Ok(serde_json::Value::String(out))
        }
        "decrypt_vault" => {
            let out = decrypt_vault(s("ciphertextB64"), s("keyB64"))?;
            Ok(serde_json::Value::String(out))
        }
        "save_vault_file" => {
            save_vault_file(s("dataDir"), s("ciphertextB64"))?;
            Ok(serde_json::Value::Null)
        }
        "load_vault_file" => {
            let out = load_vault_file(s("dataDir"))?;
            Ok(serde_json::Value::String(out))
        }
        "write_export_file" => {
            write_export_file(s("path"), s("content"))?;
            Ok(serde_json::Value::Null)
        }
        "read_export_file" => {
            let out = read_export_file(s("path"))?;
            Ok(serde_json::Value::String(out))
        }
        "compute_sha256" => Ok(serde_json::Value::String(compute_sha256(s("content")))),
        "generate_totp" => {
            let res = generate_totp(s("secret"))?;
            serde_json::to_value(res).map_err(|e| e.to_string())
        }
        "export_kdbx" => {
            export_kdbx(s("path"), s("itemsJson"), s("password"))?;
            Ok(serde_json::Value::Null)
        }
        "import_kdbx" => {
            let out = import_kdbx(s("path"), s("password"))?;
            Ok(serde_json::Value::String(out))
        }
        "webdav_test" => {
            let out = webdav_test(s("url"), s("username"), s("password"))?;
            Ok(serde_json::Value::String(out))
        }
        "webdav_stat" => {
            let out = webdav_stat(s("url"), s("username"), s("password"))?;
            serde_json::to_value(out).map_err(|e| e.to_string())
        }
        "webdav_upload" => {
            let out = webdav_upload(s("dataDir"), s("url"), s("username"), s("password"))?;
            serde_json::to_value(out).map_err(|e| e.to_string())
        }
        "webdav_download" => {
            let out = webdav_download(s("url"), s("username"), s("password"))?;
            serde_json::to_value(out).map_err(|e| e.to_string())
        }
        "get_webdav_config" => Ok(get_webdav_config(s("dataDir")).unwrap_or(serde_json::Value::Null)),
        "save_webdav_config" => {
            save_webdav_config(s("dataDir"), s("url"), s("username"), s("passwordEnc"))?;
            Ok(serde_json::Value::Null)
        }
        "clear_webdav_config" => {
            clear_webdav_config(s("dataDir"))?;
            Ok(serde_json::Value::Null)
        }
        _ => Err(format!("ERR_UNKNOWN_CMD: {}", cmd)),
    }
}

/// C-ABI Entrypoint for Flutter (`dart:ffi`).
/// Returns a newly allocated UTF-8 JSON string: `{"ok": true, "data": ...}` or `{"ok": false, "error": "..."}`.
/// Caller MUST free the returned pointer with `sv_free_string`.
#[no_mangle]
pub unsafe extern "C" fn sv_invoke(
    cmd_ptr: *const c_char,
    args_json_ptr: *const c_char,
) -> *mut c_char {
    let cmd = if cmd_ptr.is_null() {
        ""
    } else {
        CStr::from_ptr(cmd_ptr).to_str().unwrap_or("")
    };
    let args_str = if args_json_ptr.is_null() {
        "{}"
    } else {
        CStr::from_ptr(args_json_ptr).to_str().unwrap_or("{}")
    };

    let parsed_args: serde_json::Value =
        serde_json::from_str(args_str).unwrap_or_else(|_| serde_json::json!({}));

    let response = match dispatch_command(cmd, &parsed_args) {
        Ok(data) => serde_json::json!({ "ok": true, "data": data }),
        Err(err) => serde_json::json!({ "ok": false, "error": err }),
    };

    let out_str = response.to_string();
    CString::new(out_str)
        .unwrap_or_else(|_| CString::new(r#"{"ok":false,"error":"ERR_CSTRING"}"#).unwrap())
        .into_raw()
}

/// Allocates a C-string buffer of `len + 1` bytes (zero-terminated) for Dart FFI callers.
#[no_mangle]
pub unsafe extern "C" fn sv_alloc_cstring(len: usize) -> *mut u8 {
    let mut buf = vec![0u8; len + 1];
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

/// Frees a C string allocated by `sv_invoke` or `sv_alloc_cstring`.
#[no_mangle]
pub unsafe extern "C" fn sv_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kdf_and_aes_gcm_roundtrip() {
        let salt = generate_random_salt_b64();
        let key_argon = derive_master_key("MasterPass#2026", &salt, Some("argon2id")).unwrap();
        let key_pbkdf2 = derive_master_key("MasterPass#2026", &salt, Some("pbkdf2")).unwrap();
        assert_ne!(key_argon, key_pbkdf2);

        let secret_json = r#"{"items":[{"id":"1","title":"GitHub"}],"folders":[]}"#;
        let cipher = encrypt_vault(secret_json, &key_argon).unwrap();
        let plain = decrypt_vault(&cipher, &key_argon).unwrap();
        assert_eq!(plain, secret_json);
        assert!(decrypt_vault(&cipher, &key_pbkdf2).is_err());
    }

    #[test]
    fn test_totp_80bit_and_standard() {
        let r = generate_totp("MFRGGZDFMZTWQ2LK").unwrap();
        assert_eq!(r.code.len(), 6);
        assert!(r.code.chars().all(|c| c.is_ascii_digit()));
    }

    #[test]
    fn test_ffi_invoke_roundtrip() {
        let cmd = CString::new("compute_sha256").unwrap();
        let args = CString::new(r#"{"content":"securevault"}"#).unwrap();
        unsafe {
            let res_ptr = sv_invoke(cmd.as_ptr(), args.as_ptr());
            let res_str = CStr::from_ptr(res_ptr).to_str().unwrap().to_string();
            sv_free_string(res_ptr);
            let val: serde_json::Value = serde_json::from_str(&res_str).unwrap();
            assert_eq!(val["ok"], true);
            assert!(val["data"].as_str().unwrap().len() == 64);
        }
    }
}
