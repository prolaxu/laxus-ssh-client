import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../models/ssh_config.dart';
import '../services/ssh_service.dart';

class TerminalScreen extends StatefulWidget {
  final SSHConfig config;
  final VoidCallback? onClose;

  const TerminalScreen({
    super.key,
    required this.config,
    this.onClose,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final SSHService _sshService = SSHService();
  late final Terminal _terminal;

  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _connectAndStartShell();
  }

  Future<void> _connectAndStartShell() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await _sshService.connect(widget.config);
      await _sshService.startShell();

      // Listen to SSH output and write to terminal
      _sshService.outputStream.listen((data) {
        _terminal.write(data);
      });

      // Listen to terminal input and send to SSH
      _terminal.onOutput = (data) {
        _sshService.write(data);
      };

      // Handle terminal resize
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _sshService.resizeTerminal(width, height);
      };

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sshService.disconnect();
    _sshService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.config.username}@${widget.config.host}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isConnecting && _errorMessage == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _connectAndStartShell,
              tooltip: 'Reconnect',
            ),
        ],
      ),
      body: _isConnecting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to SSH server...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Connection Failed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _connectAndStartShell,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: TerminalView(
                    _terminal,
                    autofocus: true,
                    backgroundOpacity: 1.0,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
    );
  }
}
