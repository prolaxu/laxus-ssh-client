import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ssh_config.dart';
import '../services/storage_helper.dart';

class HomeScreen extends StatefulWidget {
  final Function(SSHConfig)? onOpenSSH;
  final Function(SSHConfig)? onOpenSFTP;

  const HomeScreen({super.key, this.onOpenSSH, this.onOpenSFTP});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SSHConfig> _connections = [];
  List<String> _groups = [];
  String? _selectedGroup;
  bool _isLoading = true;
  SSHConfig? _selectedHost;
  bool _showEditor = false;
  SSHConfig? _editingHost;
  bool _isGridView = false;
  bool _passwordVisible = false;
  bool _passphraseVisible = false;

  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _groupController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    try {
      setState(() => _isLoading = true);
      final connections = _selectedGroup == null
          ? await StorageHelper.instance.readAll()
          : await StorageHelper.instance.readByGroup(_selectedGroup);
      final groups = await StorageHelper.instance.getGroups();

      if (!mounted) return;
      setState(() {
        _connections = connections;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConnection(SSHConfig config) async {
    await StorageHelper.instance.delete(config.id);
    _loadConnections();
  }

  void _showEditorPanel([SSHConfig? config]) {
    setState(() {
      _editingHost = config;
      _showEditor = true;
      _nameController.text = config?.name ?? '';
      _hostController.text = config?.host ?? '';
      _portController.text = config?.port.toString() ?? '22';
      _usernameController.text = config?.username ?? '';
      _passwordController.text = config?.password ?? '';
      _privateKeyController.text = config?.privateKey ?? '';
      _passphraseController.text = config?.passphrase ?? '';
      _groupController.text = config?.group ?? '';
    });
  }

  void _closeEditor() {
    setState(() {
      _showEditor = false;
      _editingHost = null;
      _nameController.clear();
      _hostController.clear();
      _portController.text = '22';
      _usernameController.clear();
      _passwordController.clear();
      _privateKeyController.clear();
      _passphraseController.clear();
      _groupController.clear();
    });
  }

  Future<void> _saveHost() async {
    if (_nameController.text.isEmpty || _hostController.text.isEmpty) {
      return;
    }

    final config = SSHConfig(
      id: _editingHost?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 22,
      username: _usernameController.text,
      password: _passwordController.text,
      privateKey: _privateKeyController.text.isEmpty
          ? null
          : _privateKeyController.text,
      passphrase: _passphraseController.text.isEmpty
          ? null
          : _passphraseController.text,
      group: _groupController.text.isEmpty ? null : _groupController.text,
      createdAt: _editingHost?.createdAt ?? DateTime.now(),
    );

    if (_editingHost != null) {
      await StorageHelper.instance.update(config);
    } else {
      await StorageHelper.instance.create(config);
    }

    _closeEditor();
    _loadConnections();
  }

  void _connectSSH(SSHConfig config) async {
    await StorageHelper.instance.updateLastConnected(config.id, DateTime.now());
    widget.onOpenSSH?.call(config);
  }

  void _connectSFTP(SSHConfig config) async {
    await StorageHelper.instance.updateLastConnected(config.id, DateTime.now());
    widget.onOpenSFTP?.call(config);
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Hosts'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Import hosts from a CSV file.'),
              const SizedBox(height: 16),
              const Text(
                'CSV format:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const SelectableText(
                  'name,host,port,username,password,group,privateKey,passphrase\n'
                  'My Server,192.168.1.100,22,root,password123,Production,,\n'
                  'Dev Server,192.168.1.101,22,admin,pass456,Development,,',
                  style: TextStyle(
                    fontSize: 12, 
                    fontFamily: 'monospace',
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download Sample'),
                    onPressed: () {
                      _downloadSampleFile();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Select File'),
            onPressed: () {
              Navigator.pop(context);
              _importHosts();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFileLocation(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: try to open the directory containing the file
        final directory = Directory(uri.path.substring(0, uri.path.lastIndexOf('/')));
        final dirUri = Uri.file(directory.path);
        if (await canLaunchUrl(dirUri)) {
          await launchUrl(dirUri);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file location: $e')),
      );
    }
  }

  Future<void> _downloadSampleFile() async {
    final sample = [
      ['name', 'host', 'port', 'username', 'password', 'group', 'privateKey', 'passphrase'],
      ['Example Server', '192.168.1.100', '22', 'root', 'password123', 'Production', '', ''],
      ['Dev Server', '192.168.1.101', '22', 'admin', 'pass456', 'Development', '', ''],
    ];

    try {
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/laxus_ssh_sample.csv');
      final csvString = const ListToCsvConverter().convert(sample);
      await file.writeAsString(csvString);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample file saved to: ${file.path}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Open Location',
            onPressed: () => _openFileLocation(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sample file: $e')),
      );
    }
  }

  Future<void> _importHosts() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(contents);

      if (csvData.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // Skip header row
      final dataRows = csvData.skip(1).toList();
      
      int imported = 0;
      for (final row in dataRows) {
        if (row.length < 4) continue; // Skip rows with insufficient data
        
        final config = SSHConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString() + imported.toString(),
          name: row[0]?.toString() ?? 'Imported Host',
          host: row[1]?.toString() ?? '',
          port: int.tryParse(row[2]?.toString() ?? '22') ?? 22,
          username: row[3]?.toString() ?? '',
          password: row.length > 4 ? row[4]?.toString() : null,
          privateKey: row.length > 6 && row[6]?.toString().isNotEmpty == true ? row[6]?.toString() : null,
          passphrase: row.length > 7 && row[7]?.toString().isNotEmpty == true ? row[7]?.toString() : null,
          group: row.length > 5 && row[5]?.toString().isNotEmpty == true ? row[5]?.toString() : null,
          createdAt: DateTime.now(),
        );

        await StorageHelper.instance.create(config);
        imported++;
      }

      _loadConnections();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $imported hosts')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing hosts: $e')),
      );
    }
  }

  Future<void> _exportHosts() async {
    try {
      final hosts = await StorageHelper.instance.readAll();

      // Create CSV data with header row
      final csvData = <List<String>>[
        ['name', 'host', 'port', 'username', 'password', 'group', 'privateKey', 'passphrase'],
      ];

      // Add data rows
      for (final host in hosts) {
        csvData.add([
          host.name,
          host.host,
          host.port.toString(),
          host.username,
          host.password ?? '',
          host.group ?? '',
          host.privateKey ?? '',
          host.passphrase ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/laxus_ssh_export_$timestamp.csv');
      await file.writeAsString(csvString);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${hosts.length} hosts to: ${file.path}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Open Location',
            onPressed: () => _openFileLocation(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting hosts: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAED),
      body: Row(
        children: [
          // Main hosts list
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Toolbar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFE8EAED),
                  child: Row(
                    children: [
                      // Search bar
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                          ),
                          child: TextField(
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Find a host or ssh user@hostname...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 20,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CONNECT button
                      ElevatedButton(
                        onPressed: _selectedHost != null
                            ? () => _connectSSH(_selectedHost!)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('CONNECT'),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildActionButton('NEW HOST', Icons.add, () {
                        _showEditorPanel();
                      }),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        'TERMINAL',
                        Icons.terminal_outlined,
                        null,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        'SFTP',
                        Icons.folder_outlined,
                        _selectedHost != null
                            ? () => _connectSFTP(_selectedHost!)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton('SERIAL', Icons.usb_outlined, null),
                      const Spacer(),
                      // View options
                      PopupMenuButton<String>(
                        icon: Icon(
                          _isGridView ? Icons.grid_view : Icons.view_list,
                          size: 20,
                          color: Colors.black54,
                        ),
                        onSelected: (value) {
                          setState(() {
                            _isGridView = value == 'grid';
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'grid',
                            child: Row(
                              children: [
                                const Icon(Icons.grid_view, size: 18),
                                const SizedBox(width: 12),
                                const Text('Grid'),
                                const Spacer(),
                                if (_isGridView)
                                  const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'list',
                            child: Row(
                              children: [
                                const Icon(Icons.view_list, size: 18),
                                const SizedBox(width: 12),
                                const Text('List'),
                                const Spacer(),
                                if (!_isGridView)
                                  const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload, size: 20),
                        onPressed: _showImportDialog,
                        color: Colors.black54,
                        tooltip: 'Import',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: _exportHosts,
                        color: Colors.black54,
                        tooltip: 'Export',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Hosts label
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hosts',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Hosts list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _connections.isEmpty
                      ? const Center(child: Text('No hosts yet'))
                      : _isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.4,
                              ),
                          itemCount: _connections.length,
                          itemBuilder: (context, index) {
                            final config = _connections[index];
                            final isSelected = _selectedHost?.id == config.id;
                            return GestureDetector(
                              onTap: () {
                                _showEditorPanel(config);
                              },
                              onDoubleTap: () => _connectSSH(config),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          config.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Name and details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            config.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ssh, ${config.username}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _connections.length,
                          itemBuilder: (context, index) {
                            final config = _connections[index];
                            final isSelected = _selectedHost?.id == config.id;
                            return GestureDetector(
                              onTap: () {
                                _showEditorPanel(config);
                              },
                              onDoubleTap: () => _connectSSH(config),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          config.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Name and details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            config.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ssh, ${config.username}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Right panel (host editor)
          if (_showEditor)
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                border: Border(
                  left: BorderSide(color: Color(0xFFE1E3E6), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Text(
                          _editingHost != null ? 'Edit Host' : 'New Host',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _closeEditor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Editor form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Label'),
                          _buildTextField(_nameController, 'Host name'),
                          const SizedBox(height: 16),
                          _buildLabel('Address'),
                          _buildTextField(_hostController, 'hostname or IP'),
                          const SizedBox(height: 16),
                          _buildLabel('Port'),
                          _buildTextField(_portController, '22'),
                          const SizedBox(height: 16),
                          _buildLabel('Username'),
                          _buildTextField(_usernameController, 'username'),
                          const SizedBox(height: 16),
                          _buildLabel('Password'),
                          _buildPasswordField(
                            _passwordController,
                            'password',
                            _passwordVisible,
                            () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Private Key (optional)'),
                          _buildTextField(
                            _privateKeyController,
                            'Path to private key file',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Passphrase (optional)'),
                          _buildPasswordField(
                            _passphraseController,
                            'Key passphrase',
                            _passphraseVisible,
                            () {
                              setState(() {
                                _passphraseVisible = !_passphraseVisible;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Group (optional)'),
                          _buildTextField(_groupController, 'Group name'),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _closeEditor,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveHost,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0EA5E9),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4B5563),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String hint,
    bool visible,
    VoidCallback onToggle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              visible ? Icons.visibility : Icons.visibility_off,
              size: 18,
              color: Colors.grey[600],
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
