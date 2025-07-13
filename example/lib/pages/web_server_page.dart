import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_server/web_server.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web服务器页面
class WebServerPage extends StatefulWidget {
  const WebServerPage({super.key});

  @override
  State<WebServerPage> createState() => _WebServerPageState();
}

class _WebServerPageState extends State<WebServerPage> {
  late final WebServerService _webServer;

  bool _isWebServerRunning = false;
  String? _errorMessage;
  List<String> _localIps = [];
  String? _selectedIp;
  final int _webServerPort = 8080;
  String _sharedDir = '';
  List<Map<String, dynamic>> _files = [];
  bool _isLoadingFiles = false;
  bool _isOperating = false;

  StreamSubscription<dynamic>? _uploadSubscription;
  StreamSubscription<dynamic>? _logSubscription;
  StreamSubscription<dynamic>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      // Get all local IPv4 addresses
      _localIps = await _getAllLocalIps();
      _selectedIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
      // Get default shared directory
      _sharedDir = await _getDefaultSharedDir();
      // Create WebServerService
      _webServer = WebServerService(port: _webServerPort, sharedDir: _sharedDir);
      _stateSubscription = _webServer.onStateChanged.listen((state) {
        setState(() {
          _isWebServerRunning = state == WebServerState.running;
        });
      });
      _logSubscription = _webServer.onLog.listen((log) {
        debugPrint(log);
      });
      _uploadSubscription = _webServer.onUpload.listen((upload) {
        debugPrint(upload);
        if (upload == 'uploading') {
        } else if (upload == 'uploaded') {
          _loadFiles();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<List<String>> _getAllLocalIps() async {
    final interfaces = await NetworkInterface.list();
    final ips = <String>[];
    for (var iface in interfaces) {
      for (var addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          ips.add(addr.address);
        }
      }
    }
    return ips;
  }

  Future<void> _startWebServer() async {
    setState(() { _isOperating = true; });
    try {
      await _webServer.start();
      setState(() {
        _errorMessage = null;
      });
      _loadFiles();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start web server: $e';
      });
    } finally {
      setState(() { _isOperating = false; });
    }
  }

  Future<void> _stopWebServer() async {
    setState(() { _isOperating = true; });
    try {
      await _webServer.stop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop web server: $e';
      });
    } finally {
      setState(() { _isOperating = false; });
    }
  }

  @override
  void dispose() {
    _webServer.dispose();
    _stateSubscription?.cancel();
    _logSubscription?.cancel();
    _uploadSubscription?.cancel();
    super.dispose();
  }

  Future<String> _getDefaultSharedDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      await Directory('${dir.parent.path}/LANFileTransfer/test').create(recursive: true);
      return dir.parent.path;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/LANFileTransfer/shared';
    }
  }

  void _copyToClipboard(String text) {
    try {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied to clipboard: $text'), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
    }
  }

  Future<void> _loadFiles() async {
    if (!_isWebServerRunning) return;
    setState(() { _isLoadingFiles = true; });
    try {
      final response = await HttpClient().getUrl(
        Uri.parse('http://${_selectedIp ?? '127.0.0.1'}:$_webServerPort/files'),
      );
      final httpResponse = await response.close();
      if (httpResponse.statusCode == 200) {
        final data = await httpResponse.transform(utf8.decoder).join();
        final json = jsonDecode(data) as Map<String, dynamic>;
        final files = (json['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _files = files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load files: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoadingFiles = false; });
    }
  }

  Future<void> _downloadFile(String? filename) async {
    if (filename == null) return;
    final url = 'http://${_selectedIp ?? '127.0.0.1'}:$_webServerPort/download?file=${Uri.encodeComponent(filename)}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please open in browser: $url'), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _confirmDelete(String? filename) async {
    if (filename == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$filename"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (result == true) {
      await _deleteFile(filename);
    }
  }

  Future<void> _deleteFile(String? filename) async {
    if (filename == null) return;
    setState(() { _isOperating = true; });
    try {
      final request = await HttpClient().postUrl(
        Uri.parse('http://${_selectedIp ?? '127.0.0.1'}:$_webServerPort/delete?file=${Uri.encodeComponent(filename)}'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted'), backgroundColor: Colors.green),
        );
        _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete file'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isOperating = false; });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Icon _getFileIcon(String filename, {bool isFolder = false}) {
    if (isFolder) return const Icon(Icons.folder, color: Colors.amber);
    final ext = filename.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return const Icon(Icons.image, color: Colors.blue);
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return const Icon(Icons.archive, color: Colors.deepPurple);
    if (['pdf'].contains(ext)) return const Icon(Icons.picture_as_pdf, color: Colors.red);
    if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) return const Icon(Icons.audiotrack, color: Colors.green);
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return const Icon(Icons.movie, color: Colors.orange);
    if (['txt', 'md', 'json', 'xml', 'csv'].contains(ext)) return const Icon(Icons.description, color: Colors.grey);
    return const Icon(Icons.insert_drive_file, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Server'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Usage',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            children: [
              _StatusCard(
                isRunning: _isWebServerRunning,
                localIps: _localIps,
                selectedIp: _selectedIp,
                onIpChanged: (ip) => setState(() => _selectedIp = ip),
                port: _webServerPort,
                sharedDir: _sharedDir,
                errorMessage: _errorMessage,
                onCopy: _copyToClipboard,
              ),
              _ControlButtons(
                isRunning: _isWebServerRunning,
                isOperating: _isOperating,
                onStart: _startWebServer,
                onStop: _stopWebServer,
              ),
              _QrCodeCard(
                isRunning: _isWebServerRunning,
                selectedIp: _selectedIp,
                port: _webServerPort,
              ),
              _FeatureCard(),
              if (_isWebServerRunning)
                _FileListCard(
                  files: _files,
                  isLoading: _isLoadingFiles,
                  onRefresh: _loadFiles,
                  onDownload: _downloadFile,
                  onDelete: _confirmDelete,
                  getFileIcon: _getFileIcon,
                  formatDate: _formatDate,
                ),
              const SizedBox(height: 24),
              const _FooterCard(),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Web Server Usage'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Features:'),
              SizedBox(height: 8),
              Text('• Access this device from other devices via browser'),
              Text('• Supports file upload and download'),
              Text('• No extra software required'),
              SizedBox(height: 16),
              Text('Scenarios:'),
              SizedBox(height: 8),
              Text('• Start the web server when only local devices are present'),
              Text('• Other devices can access files via browser'),
              Text('• Suitable for temporary file sharing'),
              SizedBox(height: 16),
              Text('Notes:'),
              SizedBox(height: 8),
              Text('• Ensure devices are on the same LAN'),
              Text('• Firewall may need to allow port access'),
              Text('• Use in a secure network environment'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}

// 独立状态卡片组件
class _StatusCard extends StatelessWidget {
  final bool isRunning;
  final List<String> localIps;
  final String? selectedIp;
  final ValueChanged<String?> onIpChanged;
  final int port;
  final String sharedDir;
  final String? errorMessage;
  final void Function(String) onCopy;
  const _StatusCard({
    required this.isRunning,
    required this.localIps,
    required this.selectedIp,
    required this.onIpChanged,
    required this.port,
    required this.sharedDir,
    required this.errorMessage,
    required this.onCopy,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Web Server Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isRunning ? Icons.check_circle : Icons.error,
                  color: isRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('Web Server: ${isRunning ? "Running" : "Stopped"}'),
              ],
            ),
            if (localIps.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('IP: '),
                  DropdownButton<String?>(
                    value: selectedIp,
                    items: localIps.map((ip) => DropdownMenuItem(value: ip, child: Text(ip))).toList(),
                    onChanged: onIpChanged,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => onCopy(selectedIp ?? ''),
                    tooltip: 'Copy IP',
                  ),
                ],
              ),
            ],
            if (isRunning) ...[
              const SizedBox(height: 4),
              Text('Web Port: $port'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Web: http://${selectedIp ?? ''}:$port',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => onCopy('http://${selectedIp ?? ''}:$port'),
                    tooltip: 'Copy URL',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Shared Dir: $sharedDir'),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 控制按钮组件
class _ControlButtons extends StatelessWidget {
  final bool isRunning;
  final bool isOperating;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _ControlButtons({
    required this.isRunning,
    required this.isOperating,
    required this.onStart,
    required this.onStop,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isRunning || isOperating ? null : onStart,
              icon: const Icon(Icons.web),
              label: const Text('Start Web Server'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isRunning && !isOperating ? onStop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Web Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 二维码访问卡片
class _QrCodeCard extends StatelessWidget {
  final bool isRunning;
  final String? selectedIp;
  final int port;
  const _QrCodeCard({required this.isRunning, required this.selectedIp, required this.port, super.key});
  @override
  Widget build(BuildContext context) {
    if (!isRunning || selectedIp == null) return const SizedBox.shrink();
    final url = 'http://$selectedIp:$port';
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan QR Code to Access', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(child: QrImageView(data: url, size: 120)),
            const SizedBox(height: 8),
            Center(child: Text(url, style: const TextStyle(color: Colors.blue))),
          ],
        ),
      ),
    );
  }
}

// 功能说明卡片
class _FeatureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Features', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('• Start the web server, access from other devices via browser'),
            const Text('• Supports file upload, download, and delete'),
            const Text('• Unified shared directory management'),
            const Text('• Uses sandbox dir on mobile, documents dir on desktop'),
            const Text('• Recommended for use in local network only'),
          ],
        ),
      ),
    );
  }
}

// 文件列表卡片分组 folders/files
class _FileListCard extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final bool isLoading;
  final VoidCallback onRefresh;
  final void Function(String?) onDownload;
  final void Function(String?) onDelete;
  final Icon Function(String, {bool isFolder}) getFileIcon;
  final String Function(String) formatDate;
  const _FileListCard({
    required this.files,
    required this.isLoading,
    required this.onRefresh,
    required this.onDownload,
    required this.onDelete,
    required this.getFileIcon,
    required this.formatDate,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final folders = files.where((f) => f['type'] == 'folder').toList();
    final regularFiles = files.where((f) => f['type'] != 'folder').toList();
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Shared Files (${files.length})', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!isLoading && files.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.folder_open, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No files', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (!isLoading) ...[
              if (folders.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...folders.map((folder) => ListTile(
                  leading: getFileIcon(folder['name'] ?? '', isFolder: true),
                  title: Text(folder['name'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => onDelete(folder['name']),
                    tooltip: 'Delete folder',
                  ),
                )),
              ],
              if (regularFiles.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Files', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...regularFiles.map((file) => ListTile(
                  leading: getFileIcon(file['name'] ?? '', isFolder: false),
                  title: Text(file['name'] ?? ''),
                  subtitle: Text('${file['sizeFormatted'] ?? ''} • ${formatDate(file['modified'] ?? '')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => onDownload(file['name']),
                        tooltip: 'Download',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => onDelete(file['name']),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// 底部版权卡片
class _FooterCard extends StatelessWidget {
  const _FooterCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'web_server © 2025 by lianleven | v1.0.0',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
    );
  }
}
