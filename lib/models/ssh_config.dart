class SSHConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final String? group;
  final DateTime createdAt;
  final DateTime? lastConnected;

  SSHConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.group,
    required this.createdAt,
    this.lastConnected,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'private_key': privateKey,
      'passphrase': passphrase,
      'group': group,
      'created_at': createdAt.toIso8601String(),
      'last_connected': lastConnected?.toIso8601String(),
    };
  }

  factory SSHConfig.fromMap(Map<String, dynamic> map) {
    return SSHConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      port: map['port'] as int,
      username: map['username'] as String,
      password: map['password'] as String?,
      privateKey: map['private_key'] as String?,
      passphrase: map['passphrase'] as String?,
      group: map['group'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastConnected: map['last_connected'] != null
          ? DateTime.parse(map['last_connected'] as String)
          : null,
    );
  }

  SSHConfig copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    String? group,
    DateTime? createdAt,
    DateTime? lastConnected,
  }) {
    return SSHConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      group: group ?? this.group,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}
