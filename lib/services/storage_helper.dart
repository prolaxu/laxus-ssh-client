import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ssh_config.dart';

class StorageHelper {
  static final StorageHelper instance = StorageHelper._init();

  StorageHelper._init();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/ssh_connections.json');
  }

  Future<List<SSHConfig>> readAll() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonData = json.decode(contents);
      return jsonData.map((item) => SSHConfig.fromMap(item)).toList();
    } catch (e) {
      print('Error reading connections: $e');
      return [];
    }
  }

  Future<void> writeAll(List<SSHConfig> configs) async {
    final file = await _localFile;
    final jsonData = configs.map((config) => config.toMap()).toList();
    await file.writeAsString(json.encode(jsonData));
  }

  Future<SSHConfig?> read(String id) async {
    final configs = await readAll();
    try {
      return configs.firstWhere((config) => config.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> create(SSHConfig config) async {
    final configs = await readAll();
    configs.add(config);
    await writeAll(configs);
  }

  Future<void> update(SSHConfig config) async {
    final configs = await readAll();
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      configs[index] = config;
      await writeAll(configs);
    }
  }

  Future<void> delete(String id) async {
    final configs = await readAll();
    configs.removeWhere((config) => config.id == id);
    await writeAll(configs);
  }

  Future<List<SSHConfig>> readByGroup(String? group) async {
    final configs = await readAll();
    if (group == null) {
      return configs.where((c) => c.group == null).toList();
    }
    return configs.where((c) => c.group == group).toList();
  }

  Future<List<String>> getGroups() async {
    final configs = await readAll();
    final groups = configs
        .where((c) => c.group != null)
        .map((c) => c.group!)
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  Future<void> updateLastConnected(String id, DateTime timestamp) async {
    final config = await read(id);
    if (config != null) {
      final updated = config.copyWith(lastConnected: timestamp);
      await update(updated);
    }
  }
}
