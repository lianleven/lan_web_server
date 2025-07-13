import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/response_utils.dart';
import '../utils/log_utils.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'dart:typed_data';
import '../utils/file_utils.dart';

Future<void> handleDownload(HttpRequest request, String sharedDir) async {
  final filename = request.uri.queryParameters['file'];
  if (filename == null) {
    await sendErrorResponse(request, 400, 'No file specified');
    return;
  }
  final filePath = path.join(sharedDir, filename);
  final fileType = FileSystemEntity.typeSync(filePath);
  if (fileType == FileSystemEntityType.notFound) {
    await sendErrorResponse(request, 404, 'File or folder not found');
    return;
  }
  try {
    if (fileType == FileSystemEntityType.directory) {
      // 目录，打包为 zip，先写入临时文件再流式发送
      final dir = Directory(filePath);
      final archive = Archive();
      await _addDirectoryToArchive(archive, dir, dir.path);
      // 创建临时 zip 文件
      final tempDir = Directory.systemTemp;
      final tempZip = File(
        path.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filename)}.zip'),
      );
      final outputStream = OutputFileStream(tempZip.path);
      ZipEncoder().encode(archive, output: outputStream);
      await outputStream.close();
      final zipLength = await tempZip.length();
      final zipFilename = '${path.basename(filename)}.zip';
      final asciiZipFilename = zipFilename.replaceAll(RegExp(r'[^\x00-\x7F]'), '_');
      final encodedZipFilename = Uri.encodeComponent(zipFilename);
      final contentDisposition = 'attachment; filename="$asciiZipFilename"; filename*=UTF-8\'\'$encodedZipFilename';
      request.response.headers.set('Content-Type', 'application/zip');
      request.response.headers.set('Content-Disposition', contentDisposition);
      request.response.headers.set('Content-Length', zipLength.toString());
      await request.response.addStream(tempZip.openRead());
      await request.response.close();
      await tempZip.delete();
      logInfo('Folder downloaded as zip (streamed): $filename');
    } else {
      // 文件，原有逻辑
      final file = File(filePath);
      final fileStream = file.openRead();
      final fileLength = await file.length();
      final ext = path.extension(filePath);
      final contentType = getContentType(ext);
      // 修正Content-Disposition，filename只用ASCII
      final asciiFilename = filename.replaceAll(RegExp(r'[^\x00-\x7F]'), '_');
      final encodedFilename = Uri.encodeComponent(filename);
      final contentDisposition = 'attachment; filename="$asciiFilename"; filename*=UTF-8\'\'$encodedFilename';
      request.response.headers.set('Content-Type', contentType);
      request.response.headers.set('Content-Disposition', contentDisposition);
      request.response.headers.set('Content-Length', fileLength.toString());
      await request.response.addStream(fileStream);
      await request.response.close();
      logInfo('File downloaded: $filename');
    }
  } catch (e) {
    logError('Error downloading file/folder: $e');
    await sendErrorResponse(request, 500, 'Download failed：${e.toString()}');
  }
}

Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String rootPath) async {
  // final relativePath = path.relative(dir.path, from: rootPath);
  // if (relativePath.isNotEmpty) {
  //   archive.addFile(ArchiveFile('$relativePath/', 0, []));
  // }
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is File) {
      final fileRelativePath = path.relative(entity.path, from: rootPath);
      final data = await entity.readAsBytes();
      archive.addFile(ArchiveFile(fileRelativePath, data.length, data));
    } else if (entity is Directory) {
      await _addDirectoryToArchive(archive, entity, rootPath);
    }
  }
} 