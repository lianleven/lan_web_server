import 'dart:io';
import 'package:path/path.dart' as path;

/// 文件操作CLI类
class FileOperationsCLI {
  final String sharedDir;
  
  FileOperationsCLI({required this.sharedDir});
  
  /// 上传文件
  Future<bool> uploadFile(String filePath, {String targetDir = ''}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final targetPath = path.join(sharedDir, targetDir, path.basename(filePath));
      final targetFile = File(targetPath);
      
      // 确保目标目录存在
      await targetFile.parent.create(recursive: true);
      
      // 复制文件
      await file.copy(targetPath);
      
      return true;
    } catch (e) {
      throw Exception('上传失败: $e');
    }
  }
  
  /// 上传多个文件
  Future<Map<String, bool>> uploadFiles(List<String> filePaths, {String targetDir = ''}) async {
    final results = <String, bool>{};
    
    for (final filePath in filePaths) {
      try {
        final success = await uploadFile(filePath, targetDir: targetDir);
        results[filePath] = success;
      } catch (e) {
        results[filePath] = false;
      }
    }
    
    return results;
  }
  
  /// 下载文件
  Future<bool> downloadFile(String remotePath, String localPath) async {
    try {
      final sourcePath = path.join(sharedDir, remotePath);
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        throw Exception('远程文件不存在: $remotePath');
      }
      
      final targetFile = File(localPath);
      
      // 确保目标目录存在
      await targetFile.parent.create(recursive: true);
      
      // 复制文件
      await sourceFile.copy(localPath);
      
      return true;
    } catch (e) {
      throw Exception('下载失败: $e');
    }
  }
  
  /// 列出文件
  Future<List<Map<String, dynamic>>> listFiles({String dir = ''}) async {
    try {
      final targetDir = path.join(sharedDir, dir);
      final directory = Directory(targetDir);
      
      if (!await directory.exists()) {
        throw Exception('目录不存在: $dir');
      }
      
      final files = <Map<String, dynamic>>[];
      final entities = await directory.list().toList();
      
      for (final entity in entities) {
        final stat = await entity.stat();
        final relativePath = path.relative(entity.path, from: sharedDir);
        
        files.add({
          'name': path.basename(entity.path),
          'type': stat.type == FileSystemEntityType.directory ? 'folder' : 'file',
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
          'path': relativePath,
        });
      }
      
      // 按名称排序
      files.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      
      return files;
    } catch (e) {
      throw Exception('获取文件列表失败: $e');
    }
  }
  
  /// 删除文件
  Future<bool> deleteFile(String filePath) async {
    try {
      final targetPath = path.join(sharedDir, filePath);
      final entity = FileSystemEntity.typeSync(targetPath);
      
      if (entity == FileSystemEntityType.notFound) {
        throw Exception('文件不存在: $filePath');
      }
      
      if (entity == FileSystemEntityType.directory) {
        await Directory(targetPath).delete(recursive: true);
      } else {
        await File(targetPath).delete();
      }
      
      return true;
    } catch (e) {
      throw Exception('删除失败: $e');
    }
  }
  
  /// 删除多个文件
  Future<Map<String, bool>> deleteFiles(List<String> filePaths) async {
    final results = <String, bool>{};
    
    for (final filePath in filePaths) {
      try {
        final success = await deleteFile(filePath);
        results[filePath] = success;
      } catch (e) {
        results[filePath] = false;
      }
    }
    
    return results;
  }
  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// 格式化文件列表
  static String formatFileList(List<Map<String, dynamic>> files, {bool long = false, bool human = false}) {
    if (files.isEmpty) return '📁 目录为空';
    
    final buffer = StringBuffer();
    
    for (final file in files) {
      final name = file['name'] as String;
      final type = file['type'] as String;
      final size = file['size'] as int;
      final modified = file['modified'] as String;
      
      final icon = type == 'folder' ? '📁' : '📄';
      
      if (long) {
        final sizeStr = human ? formatFileSize(size) : size.toString();
        buffer.writeln('$icon $name ($sizeStr) - $modified');
      } else {
        buffer.writeln('$icon $name');
      }
    }
    
    return buffer.toString();
  }
}
