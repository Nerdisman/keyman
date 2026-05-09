enum KeyType {
  rsa2048('RSA', 2048),
  rsa4096('RSA', 4096),
  ed25519('Ed25519', 256);

  const KeyType(this.name, this.bits);

  final String name;
  final int bits;

  String get displayName => '$name $bits位';

  String get privateKeyExtension => 'id_$name'.toLowerCase();
  String get publicKeyExtension => 'id_$name.pub'.toLowerCase();
}

enum KeyStatus {
  valid,
  invalid,
  encrypted,
  missing,
}

class SSHKey {
  final String id;
  final String name;
  final String? comment;
  final KeyType type;
  final String privateKeyPath;
  final String publicKeyPath;
  final DateTime createdAt;
  final KeyStatus status;
  final bool hasPassphrase;

  SSHKey({
    required this.id,
    required this.name,
    this.comment,
    required this.type,
    required this.privateKeyPath,
    required this.publicKeyPath,
    required this.createdAt,
    this.status = KeyStatus.valid,
    this.hasPassphrase = false,
  });

  SSHKey copyWith({
    String? name,
    String? comment,
    KeyStatus? status,
  }) {
    return SSHKey(
      id: id,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      type: type,
      privateKeyPath: privateKeyPath,
      publicKeyPath: publicKeyPath,
      createdAt: createdAt,
      status: status ?? this.status,
      hasPassphrase: hasPassphrase,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'comment': comment,
      'type': type.name,
      'privateKeyPath': privateKeyPath,
      'publicKeyPath': publicKeyPath,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'hasPassphrase': hasPassphrase,
    };
  }

  static SSHKey fromJson(Map<String, dynamic> json) {
    return SSHKey(
      id: json['id'],
      name: json['name'],
      comment: json['comment'],
      type: KeyType.values.byName(json['type']),
      privateKeyPath: json['privateKeyPath'],
      publicKeyPath: json['publicKeyPath'],
      createdAt: DateTime.parse(json['createdAt']),
      status: KeyStatus.values.byName(json['status']),
      hasPassphrase: json['hasPassphrase'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSHKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
