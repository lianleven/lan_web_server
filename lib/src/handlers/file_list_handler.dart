import 'dart:io';
import 'dart:convert'; // Added for utf8.decoder
import 'package:path/path.dart' as path;
import '../utils/response_utils.dart';
import '../utils/log_utils.dart';
import '../utils/file_utils.dart';

Future<void> handleFileList(HttpRequest request, String sharedDir) async {
  try {
    var dirParam = request.uri.queryParameters['dir'] ?? '';
    dirParam = dirParam.replaceAll('\\', '/');
    final segments =
        dirParam.split('/').where((String s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '..')) {
      await sendJsonResponse(request, {'files': [], 'error': 'invalid path'});
      return;
    }
    final dir = Directory(path.normalize(path.join(sharedDir, dirParam)));
    // 仅列出一层（与网页 /files?dir= 及 App 列表一致）；避免整棵子树递归带来的巨量 JSON 与磁盘遍历。
    final files = await _getFileListShallow(dir);
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

Future<List<Map<String, dynamic>>> _getFileListShallow(Directory dir) async {
  if (!await dir.exists()) {
    return [];
  }
  final entities = <FileSystemEntity>[];
  await for (final entity in dir.list(followLinks: false)) {
    entities.add(entity);
  }
  final entries = await Future.wait(entities.map((entity) async {
    try {
      final stat = await entity.stat();
      final name = path.basename(entity.path);
      if (entity is File) {
        return {
          'name': name,
          'type': 'file',
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
          'sizeFormatted': formatBytes(stat.size),
        };
      }
      if (entity is Directory) {
        return {
          'name': name,
          'type': 'folder',
          'modified': stat.modified.toIso8601String(),
        };
      }
      return null;
    } catch (_) {
      // 无权访问、断链符号链接等：跳过该条目，避免整表 500
      return null;
    }
  }));

  final list = entries.whereType<Map<String, dynamic>>().toList();

  list.sort((a, b) {
    if (a['type'] != b['type']) {
      return a['type'] == 'folder' ? -1 : 1;
    }
    if (a['type'] == 'file' && b['type'] == 'file') {
      return DateTime.parse(b['modified'] as String).compareTo(DateTime.parse(a['modified'] as String));
    }
    return (a['name'] as String).compareTo(b['name'] as String);
  });
  return list;
}
