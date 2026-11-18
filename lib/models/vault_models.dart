import 'dart:convert';

enum ItemType {
  login,
  card,
  note,
  identity;

  String get value => name;

  static ItemType fromString(String? raw) {
    switch (raw) {
      case 'card':
        return ItemType.card;
      case 'note':
        return ItemType.note;
      case 'identity':
        return ItemType.identity;
      default:
        return ItemType.login;
    }
  }
}

class PasswordHistoryEntry {
  final String password;
  final String changedAt;

  const PasswordHistoryEntry({
    required this.password,
    required this.changedAt,
  });

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PasswordHistoryEntry(
      password: (json['password'] ?? '') as String,
      changedAt: (json['changedAt'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'password': password,
        'changedAt': changedAt,
      };
}

class VaultItem {
  final String id;
  final ItemType type;
  final String title;
  final String folder;
  final String? username;
  final String? password;
  final String? url;
  final String? cardName;
  final String? cardNumber;
  final String? cardExpiry;
  final String? cardCvv;
  final String? identityName;
  final String? identityEmail;
  final String? identityPhone;
  final String? identityAddress;
  final String? notes;
  final Map<String, String>? customFields;
  final String? otpSecret;
  final String? expiresAt;
  final List<PasswordHistoryEntry>? passwordHistory;
  final String? deletedAt;
  final String? lastUsedAt;
  final String updatedAt;
  final String strength; // "weak" | "medium" | "strong"
  final bool isFavorite;
  final bool ignoreSecurityWarning;

  const VaultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.folder,
    this.username,
    this.password,
    this.url,
    this.cardName,
    this.cardNumber,
    this.cardExpiry,
    this.cardCvv,
    this.identityName,
    this.identityEmail,
    this.identityPhone,
    this.identityAddress,
    this.notes,
    this.customFields,
    this.otpSecret,
    this.expiresAt,
    this.passwordHistory,
    this.deletedAt,
    this.lastUsedAt,
    required this.updatedAt,
    required this.strength,
    this.isFavorite = false,
    this.ignoreSecurityWarning = false,
  });

  bool get isTrashed => deletedAt != null && deletedAt!.isNotEmpty;

  VaultItem copyWith({
    String? id,
    ItemType? type,
    String? title,
    String? folder,
    String? username,
    String? password,
    String? url,
    String? cardName,
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? identityName,
    String? identityEmail,
    String? identityPhone,
    String? identityAddress,
    String? notes,
    Map<String, String>? customFields,
    String? otpSecret,
    String? expiresAt,
    bool clearExpiresAt = false,
    List<PasswordHistoryEntry>? passwordHistory,
    String? deletedAt,
    bool clearDeletedAt = false,
    String? lastUsedAt,
    String? updatedAt,
    String? strength,
    bool? isFavorite,
    bool? ignoreSecurityWarning,
  }) {
    return VaultItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      folder: folder ?? this.folder,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      cardName: cardName ?? this.cardName,
      cardNumber: cardNumber ?? this.cardNumber,
      cardExpiry: cardExpiry ?? this.cardExpiry,
      cardCvv: cardCvv ?? this.cardCvv,
      identityName: identityName ?? this.identityName,
      identityEmail: identityEmail ?? this.identityEmail,
      identityPhone: identityPhone ?? this.identityPhone,
      identityAddress: identityAddress ?? this.identityAddress,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      otpSecret: otpSecret ?? this.otpSecret,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      passwordHistory: passwordHistory ?? this.passwordHistory,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      strength: strength ?? this.strength,
      isFavorite: isFavorite ?? this.isFavorite,
      ignoreSecurityWarning:
          ignoreSecurityWarning ?? this.ignoreSecurityWarning,
    );
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    Map<String, String>? custom;
    if (json['customFields'] is Map) {
      custom = (json['customFields'] as Map).map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    }
    List<PasswordHistoryEntry>? hist;
    if (json['passwordHistory'] is List) {
      hist = (json['passwordHistory'] as List)
          .whereType<Map>()
          .map((e) =>
              PasswordHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return VaultItem(
      id: (json['id'] ?? '') as String,
      type: ItemType.fromString(json['type'] as String?),
      title: (json['title'] ?? '') as String,
      folder: (json['folder'] ?? '默认') as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
      url: json['url'] as String?,
      cardName: json['cardName'] as String?,
      cardNumber: json['cardNumber'] as String?,
      cardExpiry: json['cardExpiry'] as String?,
      cardCvv: json['cardCvv'] as String?,
      identityName: json['identityName'] as String?,
      identityEmail: json['identityEmail'] as String?,
      identityPhone: json['identityPhone'] as String?,
      identityAddress: json['identityAddress'] as String?,
      notes: json['notes'] as String?,
      customFields: custom,
      otpSecret: json['otpSecret'] as String?,
      expiresAt: json['expiresAt'] as String?,
      passwordHistory: hist,
      deletedAt: json['deletedAt'] as String?,
      lastUsedAt: json['lastUsedAt'] as String?,
      updatedAt: (json['updatedAt'] ?? '') as String,
      strength: (json['strength'] ?? 'medium') as String,
      isFavorite: json['isFavorite'] == true,
      ignoreSecurityWarning: json['ignoreSecurityWarning'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'type': type.value,
      'title': title,
      'folder': folder,
      'updatedAt': updatedAt,
      'strength': strength,
      'isFavorite': isFavorite,
      'ignoreSecurityWarning': ignoreSecurityWarning,
    };
    if (username != null) map['username'] = username;
    if (password != null) map['password'] = password;
    if (url != null) map['url'] = url;
    if (cardName != null) map['cardName'] = cardName;
    if (cardNumber != null) map['cardNumber'] = cardNumber;
    if (cardExpiry != null) map['cardExpiry'] = cardExpiry;
    if (cardCvv != null) map['cardCvv'] = cardCvv;
    if (identityName != null) map['identityName'] = identityName;
    if (identityEmail != null) map['identityEmail'] = identityEmail;
    if (identityPhone != null) map['identityPhone'] = identityPhone;
    if (identityAddress != null) map['identityAddress'] = identityAddress;
    if (notes != null) map['notes'] = notes;
    if (customFields != null && customFields!.isNotEmpty) {
      map['customFields'] = customFields;
    }
    if (otpSecret != null && otpSecret!.isNotEmpty) {
      map['otpSecret'] = otpSecret;
    }
    if (expiresAt != null && expiresAt!.isNotEmpty) {
      map['expiresAt'] = expiresAt;
    }
    if (passwordHistory != null && passwordHistory!.isNotEmpty) {
      map['passwordHistory'] = passwordHistory!.map((e) => e.toJson()).toList();
    }
    if (deletedAt != null && deletedAt!.isNotEmpty) {
      map['deletedAt'] = deletedAt;
    }
    if (lastUsedAt != null && lastUsedAt!.isNotEmpty) {
      map['lastUsedAt'] = lastUsedAt;
    }
    return map;
  }
}

class VaultFolder {
  final String id;
  final String name;
  final String icon;

  const VaultFolder({
    required this.id,
    required this.name,
    this.icon = 'folder',
  });

  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      icon: (json['icon'] ?? 'folder') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
      };
}

class VaultPayload {
  final List<VaultItem> items;
  final List<VaultFolder> folders;
  final int autoLockTimeout;

  const VaultPayload({
    required this.items,
    required this.folders,
    this.autoLockTimeout = 5,
  });

  factory VaultPayload.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final rawFolders = (json['folders'] as List?) ?? const [];
    return VaultPayload(
      items: rawItems
          .whereType<Map>()
          .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      folders: rawFolders
          .whereType<Map>()
          .map((e) => VaultFolder.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      autoLockTimeout: (json['autoLockTimeout'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'folders': folders.map((e) => e.toJson()).toList(),
        'autoLockTimeout': autoLockTimeout,
      };

  String toJsonString() => jsonEncode(toJson());
}

class PasswordConfig {
  final int length;
  final bool useUppercase;
  final bool useLowercase;
  final bool useNumbers;
  final bool useSymbols;
  final bool excludeConfuse;

  const PasswordConfig({
    this.length = 18,
    this.useUppercase = true,
    this.useLowercase = true,
    this.useNumbers = true,
    this.useSymbols = true,
    this.excludeConfuse = true,
  });

  PasswordConfig copyWith({
    int? length,
    bool? useUppercase,
    bool? useLowercase,
    bool? useNumbers,
    bool? useSymbols,
    bool? excludeConfuse,
  }) {
    return PasswordConfig(
      length: length ?? this.length,
      useUppercase: useUppercase ?? this.useUppercase,
      useLowercase: useLowercase ?? this.useLowercase,
      useNumbers: useNumbers ?? this.useNumbers,
      useSymbols: useSymbols ?? this.useSymbols,
      excludeConfuse: excludeConfuse ?? this.excludeConfuse,
    );
  }
}

class TotpResult {
  final String code;
  final int remaining;

  const TotpResult({required this.code, required this.remaining});

  factory TotpResult.fromJson(Map<String, dynamic> json) {
    return TotpResult(
      code: (json['code'] ?? '') as String,
      remaining: (json['remaining'] as num?)?.toInt() ?? 30,
    );
  }
}

class WebDavStat {
  final bool exists;
  final int size;
  final String? lastModified;
  final String? etag;

  const WebDavStat({
    required this.exists,
    required this.size,
    this.lastModified,
    this.etag,
  });

  factory WebDavStat.fromJson(Map<String, dynamic> json) {
    return WebDavStat(
      exists: json['exists'] == true,
      size: (json['size'] as num?)?.toInt() ?? 0,
      lastModified: json['last_modified'] as String?,
      etag: json['etag'] as String?,
    );
  }
}

class WebDavDownload {
  final String content;
  final WebDavStat stat;

  const WebDavDownload({required this.content, required this.stat});

  factory WebDavDownload.fromJson(Map<String, dynamic> json) {
    return WebDavDownload(
      content: (json['content'] ?? '') as String,
      stat: WebDavStat.fromJson(
          Map<String, dynamic>.from((json['stat'] as Map?) ?? const {})),
    );
  }
}

class WebDavConfig {
  final String url;
  final String username;
  final String passwordEnc;

  const WebDavConfig({
    required this.url,
    required this.username,
    required this.passwordEnc,
  });

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      url: (json['url'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      passwordEnc: (json['passwordEnc'] ?? '') as String,
    );
  }
}
