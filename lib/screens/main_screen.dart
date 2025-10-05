import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import '../models/ssh_config.dart';
import '../models/session.dart';
import 'home_screen.dart';
import 'terminal_screen.dart';
import 'sftp_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Session> _sessions = [];
  int _currentIndex = -1; // -1 means showing home
  String _selectedMenuItem = 'Hosts';

  void _openSSHSession(SSHConfig config) {
    final sessionId = const Uuid().v4();
    final session = Session(
      id: sessionId,
      config: config,
      type: SessionType.ssh,
      widget: TerminalScreen(
        key: ValueKey('terminal-$sessionId'),
        config: config,
        onClose: () {},
      ),
      createdAt: DateTime.now(),
    );

    setState(() {
      _sessions.add(session);
      _currentIndex = _sessions.length - 1;
    });
  }

  void _openSFTPSession(SSHConfig config) {
    final sessionId = const Uuid().v4();
    final session = Session(
      id: sessionId,
      config: config,
      type: SessionType.sftp,
      widget: SFTPScreen(
        key: ValueKey('sftp-$sessionId'),
        config: config,
        onClose: () {},
      ),
      createdAt: DateTime.now(),
    );

    setState(() {
      _sessions.add(session);
      _currentIndex = _sessions.length - 1;
    });
  }

  void _closeSession(int index) {
    setState(() {
      if (_currentIndex == index) {
        if (index > 0) {
          _currentIndex = index - 1;
        } else if (_sessions.length > 1) {
          _currentIndex = 0;
        } else {
          _currentIndex = -1;
        }
      } else if (_currentIndex > index) {
        _currentIndex--;
      }
      _sessions.removeAt(index);
    });
  }

  void _switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showHome() {
    setState(() {
      _currentIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAED),
      body: Column(
        children: [
          // Termius Top Bar (Dark)
          GestureDetector(
            onPanStart: (details) {
              windowManager.startDragging();
            },
            child: Container(
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF2D3139),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E2228), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  // App title
                  const Text(
                    'Laxus SSH Client',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Home button
                  IconButton(
                    icon: const Icon(Icons.home, color: Colors.white70, size: 20),
                    onPressed: () {
                      _showHome();
                    },
                  ),
                  const SizedBox(width: 8),
                // SFTP tab
                if (_sessions.any((s) => s.type == SessionType.sftp))
                  _buildTopTab(
                    label: 'SFTP',
                    icon: Icons.folder_outlined,
                    isActive: false,
                    onTap: () {},
                    showClose: false,
                  ),
                // Session tabs
                ...List.generate(_sessions.length, (index) {
                  final session = _sessions[index];
                  return _buildTopTab(
                    label: session.config.name,
                    icon: session.type == SessionType.ssh
                        ? Icons.terminal
                        : Icons.folder_outlined,
                    isActive: _currentIndex == index,
                    onTap: () => _switchToTab(index),
                    onClose: () => _closeSession(index),
                    showClose: true,
                    avatarColor: const Color(0xFFFF6B35),
                  );
                }),
                // Add tab button
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                  onPressed: () {
                    _showHome();
                  },
                ),
                const Spacer(),
                // Right side icons
                IconButton(
                  icon: const Icon(Icons.info_outline,
                      color: Colors.white70, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Laxus SSH Client',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('A modern SSH and SFTP client built with Flutter.'),
                            const SizedBox(height: 16),
                            const Text('Developer:'),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                // Could open URL here with url_launcher package
                              },
                              child: const Text(
                                'https://github.com/prolaxu/',
                                style: TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.minimize, color: Colors.white70, size: 20),
                  onPressed: () async {
                    await windowManager.minimize();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.crop_square, color: Colors.white70, size: 18),
                  onPressed: () async {
                    bool isMaximized = await windowManager.isMaximized();
                    if (isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () async {
                      await windowManager.close();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex + 1,
              children: [
                HomeScreen(
                  onOpenSSH: _openSSHSession,
                  onOpenSFTP: _openSFTPSession,
                ),
                ..._sessions.map((session) => session.widget).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3F4A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Icon(icon, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  Widget _buildTopTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClose,
    required bool showClose,
    Color? avatarColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3F4550) : const Color(0xFF353A44),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarColor != null)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Icon(Icons.terminal, color: Colors.white, size: 12),
                ),
              )
            else
              Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (showClose) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String label, IconData icon, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              _selectedMenuItem = label;
              if (label == 'Hosts') {
                _showHome();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.black87 : Colors.black54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.black87 : Colors.black54,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
