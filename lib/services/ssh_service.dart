import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_config.dart';

class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  final StreamController<String> _outputController = StreamController<String>.broadcast();
  final StreamController<SSHConnectionState> _stateController = StreamController<SSHConnectionState>.broadcast();

  Stream<String> get outputStream => _outputController.stream;
  Stream<SSHConnectionState> get stateStream => _stateController.stream;
  bool get isConnected => _client != null;

  Future<void> connect(SSHConfig config) async {
    try {
      _stateController.add(SSHConnectionState.connecting);

      final socket = await SSHSocket.connect(config.host, config.port);

      // Determine authentication method
      if (config.privateKey != null && config.privateKey!.isNotEmpty) {
        // Key-based authentication
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
        // Password authentication
        _client = SSHClient(
          socket,
          username: config.username,
          onPasswordRequest: () => config.password,
        );
      } else {
        throw Exception('No authentication method provided');
      }

      _stateController.add(SSHConnectionState.connected);
    } catch (e) {
      _stateController.add(SSHConnectionState.error);
      rethrow;
    }
  }

  Future<SSHSession> startShell() async {
    if (_client == null) {
      throw Exception('Not connected to SSH server');
    }

    _session = await _client!.shell(
      pty: SSHPtyConfig(
        width: 80,
        height: 24,
      ),
    );

    _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
      _outputController.add(data);
    });

    _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
      _outputController.add(data);
    });

    return _session!;
  }

  void write(String data) {
    if (_session != null) {
      _session!.write(Uint8List.fromList(data.codeUnits));
    }
  }

  void resizeTerminal(int width, int height) {
    if (_session != null) {
      _session!.resizeTerminal(width, height);
    }
  }

  Future<String> executeCommand(String command) async {
    if (_client == null) {
      throw Exception('Not connected to SSH server');
    }

    final result = await _client!.run(command);
    return utf8.decode(result);
  }

  Future<void> disconnect() async {
    _session?.close();
    await _session?.done;
    _client?.close();
    await _client?.done;
    _session = null;
    _client = null;
    _stateController.add(SSHConnectionState.disconnected);
  }

  void dispose() {
    _outputController.close();
    _stateController.close();
  }
}

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
