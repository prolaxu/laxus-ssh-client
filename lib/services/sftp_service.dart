import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_config.dart';

class SFTPService {
  SSHClient? _client;
  SftpClient? _sftp;

  Future<void> connect(SSHConfig config) async {
    final socket = await SSHSocket.connect(config.host, config.port);

    // Determine authentication method
    if (config.privateKey != null && config.privateKey!.isNotEmpty) {
      _client = SSHClient(
        socket,
        username: config.username,
        identities: [
          ...SSHKeyPair.fromPem(
            config.privateKey!,
            config.passphrase,
          )
        ],
      );
    } else if (config.password != null && config.password!.isNotEmpty) {
      _client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password,
      );
    } else {
      throw Exception('No authentication method provided');
    }

    _sftp = await _client!.sftp();
  }

  Future<List<SftpName>> listDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    return await _sftp!.listdir(path);
  }

  Future<void> downloadFile(String remotePath, String localPath) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }

    final file = await _sftp!.open(remotePath);
    final localFile = File(localPath);
    final sink = localFile.openWrite();

    await for (final chunk in file.read()) {
      sink.add(chunk);
    }

    await sink.close();
    await file.close();
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }

    final localFile = File(localPath);
    final content = await localFile.readAsBytes();

    final file = await _sftp!.open(
      remotePath,
      mode: SftpFileOpenMode.create |
             SftpFileOpenMode.write |
             SftpFileOpenMode.truncate,
    );

    await file.write(Stream.value(content));
    await file.close();
  }

  Future<void> deleteFile(String path) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    await _sftp!.remove(path);
  }

  Future<void> deleteDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    await _sftp!.rmdir(path);
  }

  Future<void> createDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    await _sftp!.mkdir(path);
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    await _sftp!.rename(oldPath, newPath);
  }

  Future<SftpFileAttrs> stat(String path) async {
    if (_sftp == null) {
      throw Exception('Not connected to SFTP server');
    }
    return await _sftp!.stat(path);
  }

  Future<void> disconnect() async {
    _sftp?.close();
    _client?.close();
    await _client?.done;
    _sftp = null;
    _client = null;
  }
}

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    this.modified,
  });

  factory FileItem.fromSftpName(SftpName sftpName, String parentPath) {
    return FileItem(
      name: sftpName.filename,
      path: '$parentPath/${sftpName.filename}',
      isDirectory: sftpName.attr.isDirectory,
      size: sftpName.attr.size ?? 0,
      modified: sftpName.attr.modifyTime != null
          ? DateTime.fromMillisecondsSinceEpoch(sftpName.attr.modifyTime! * 1000)
          : null,
    );
  }
}
