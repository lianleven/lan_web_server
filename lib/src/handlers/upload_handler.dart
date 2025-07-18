import 'dart:io';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../utils/response_utils.dart';
import '../utils/log_utils.dart';

class UploadFileInfo {
  final String filename;
  final Stream<List<int>> stream;
  UploadFileInfo(this.filename, this.stream);
}

Future<void> handleUpload(HttpRequest request, String sharedDir) async {
  if (request.method != 'POST') {
    await sendErrorResponse(request, 405, 'Method Not Allowed');
    return;
  }
  final dirParam = request.uri.queryParameters['dir'] ?? '';
  logInfo('Upload request received');
  try {
    final contentType = request.headers.contentType;
    if (contentType == null || !contentType.mimeType.startsWith('multipart/form-data')) {
      await sendErrorResponse(request, 400, 'Invalid content type. Expected multipart/form-data');
      return;
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null) {
      await sendErrorResponse(request, 400, 'No boundary found in content type');
      return;
    }
    final transformer = MimeMultipartTransformer(boundary);
    final List<UploadFileInfo> uploadFiles = [];
    await for (final part in transformer.bind(request)) {
      final header = part.headers['content-disposition'];
      if (header == null) continue;
      final disposition = HeaderValue.parse(header);
      final filename = disposition.parameters['filename'];
      if (filename == null) continue;
      uploadFiles.add(UploadFileInfo(filename, part));
    }
    if (uploadFiles.isEmpty) {
      await sendErrorResponse(request, 400, 'No file found in upload');
      return;
    }
    // 1. 提取所有文件的根目录名
    String? rootDir;
    for (final f in uploadFiles) {
      final segs = path.split(f.filename);
      if (segs.length > 1) {
        rootDir = segs.first;
        break;
      }
    }
    // 2. 检查根目录是否存在，若存在则自动重命名
    String? newRootDir = rootDir;
    if (rootDir != null) {
      var candidate = rootDir;
      var counter = 1;
      while (await Directory(path.join(sharedDir, dirParam, candidate)).exists()) {
        candidate = '${rootDir}_$counter';
        counter++;
      }
      newRootDir = candidate;
    }
    // 3. 保存所有文件，替换根目录名
    for (final f in uploadFiles) {
      String savePath = f.filename;
      if (rootDir != null && newRootDir != null && savePath.startsWith(rootDir)) {
        savePath = newRootDir + savePath.substring(rootDir.length);
      }
      final filePath = path.join(sharedDir, dirParam, savePath);
      final fileDir = Directory(path.dirname(filePath));
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }
      final file = File(filePath);
      final sink = file.openWrite();
      await f.stream.pipe(sink);
      await sink.close();
      logInfo('File uploaded: $savePath (original: ${f.filename})');
    }
    await sendJsonResponse(request, {
      'success': true,
      'message': rootDir != null && newRootDir != null && rootDir != newRootDir
          ? '文件夹已重命名为 $newRootDir'
          : 'File(s) uploaded successfully',
      'newRootDir': newRootDir,
    });
  } catch (e) {
    logError('Error processing upload: $e');
    await sendErrorResponse(request, 500, 'Upload failed: $e');
  }
}
