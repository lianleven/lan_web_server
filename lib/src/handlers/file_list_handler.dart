import 'dart:io';
import 'dart:convert'; // Added for utf8.decoder
import 'package:path/path.dart' as path;
import '../utils/response_utils.dart';
import '../utils/log_utils.dart';
import '../utils/file_utils.dart';

Future<void> handleFileList(HttpRequest request, String sharedDir) async {
  try {
    final dirParam = request.uri.queryParameters['dir'] ?? '';
    final dir = Directory(path.join(sharedDir, dirParam));
    final files = await _getFileListRecursively(dir);
    await sendJsonResponse(request, {'files': files});
  } catch (e) {
    logError('Error getting file list: $e');
    await sendErrorResponse(request, 500, 'Failed to get file list');
  }
}

Future<void> handleSaveTextFile(HttpRequest request, String sharedDir) async {
  final filename = request.uri.queryParameters['file'];
  if (filename == null) {
    await sendJsonResponse(request, {'success': false, 'error': 'No file specified'});
    return;
  }
  final filePath = path.join(sharedDir, filename);
  try {
    final content = await utf8.decoder.bind(request).join();
    final file = File(filePath);
    await file.writeAsString(content);
    await sendJsonResponse(request, {'success': true});
  } catch (e) {
    await sendJsonResponse(request, {'success': false, 'error': e.toString()});
  }
}

Future<List<Map<String, dynamic>>> _getFileListRecursively(Directory dir) async {
  if (!await dir.exists()) {
    return [];
  }
  final List<Map<String, dynamic>> entries = [];
  await for (final entity in dir.list(followLinks: false)) {
    final stat = await entity.stat();
    final name = path.basename(entity.path);
    if (entity is File) {
      entries.add({
        'name': name,
        'type': 'file',
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'sizeFormatted': formatBytes(stat.size),
      });
    } else if (entity is Directory) {
      entries.add({
        'name': name,
        'type': 'folder',
        'children': await _getFileListRecursively(entity),
      });
    }
  }
  // 文件夹和文件分别排序，文件夹在前，文件按修改时间降序
  entries.sort((a, b) {
    if (a['type'] != b['type']) {
      return a['type'] == 'folder' ? -1 : 1;
    }
    if (a['type'] == 'file' && b['type'] == 'file') {
      return DateTime.parse(b['modified']).compareTo(DateTime.parse(a['modified']));
    }
    return a['name'].compareTo(b['name']);
  });
  return entries;
}
