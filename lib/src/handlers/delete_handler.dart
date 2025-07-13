import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/response_utils.dart';
import '../utils/log_utils.dart';

Future<void> handleDelete(HttpRequest request, String sharedDir) async {
  if (request.method != 'POST') {
    await sendErrorResponse(request, 405, 'Method Not Allowed');
    return;
  }
  final filename = request.uri.queryParameters['file'];
  if (filename == null) {
    await sendErrorResponse(request, 400, 'No file specified');
    return;
  }
  try {
    final filePath = path.join(sharedDir, filename);
    final entity = FileSystemEntity.typeSync(filePath) == FileSystemEntityType.directory
        ? Directory(filePath)
        : File(filePath);
    if (!await entity.exists()) {
      await sendErrorResponse(request, 404, 'File or folder not found');
      return;
    }
    await _deleteEntity(entity);
    logInfo('Deleted: $filename');
    await sendJsonResponse(request, {
      'success': true,
      'message': 'Deleted successfully',
    });
  } catch (e) {
    logError('Error deleting file/folder: $e');
    await sendErrorResponse(request, 500, 'Delete failed: $e');
  }
}

Future<void> _deleteEntity(FileSystemEntity entity) async {
  if (entity is Directory) {
    await for (final child in entity.list(followLinks: false)) {
      await _deleteEntity(child);
    }
    await entity.delete();
  } else if (entity is File) {
    await entity.delete();
  }
} 