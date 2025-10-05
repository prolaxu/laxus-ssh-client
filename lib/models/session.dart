import 'package:flutter/material.dart';
import 'ssh_config.dart';

enum SessionType { ssh, sftp }

class Session {
  final String id;
  final SSHConfig config;
  final SessionType type;
  final Widget widget;
  final DateTime createdAt;

  Session({
    required this.id,
    required this.config,
    required this.type,
    required this.widget,
    required this.createdAt,
  });

  String get title => '${config.name} - ${type == SessionType.ssh ? 'SSH' : 'SFTP'}';
}
