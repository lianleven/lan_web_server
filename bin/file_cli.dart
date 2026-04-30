#!/usr/bin/env dart

/// 文件操作 CLI 工具
/// 提供命令行界面来直接操作文件，替代Web界面

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:lan_web_server/src/cli/file_operations.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _showHelp();
    return;
  }

  final command = arguments[0];
  
  try {
    switch (command) {
      case 'upload':
        await _handleUpload(arguments.skip(1).toList());
        break;
      case 'download':
        await _handleDownload(arguments.skip(1).toList());
        break;
      case 'list':
        await _handleList(arguments.skip(1).toList());
        break;
      case 'delete':
        await _handleDelete(arguments.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _showHelp();
        break;
      case 'version':
      case '--version':
      case '-v':
        _showVersion();
        break;
      default:
        print('❌ 未知命令: $command');
        print('使用 "file_cli help" 查看帮助信息');
        exit(1);
    }
  } catch (e) {
    print('❌ 错误: $e');
    exit(1);
  }
}

/// 处理上传命令
Future<void> _handleUpload(List<String> args) async {
  if (args.isEmpty) {
    print('❌ 请指定要上传的文件');
    print('用法: file_cli upload <文件路径> [目标目录]');
    return;
  }

  final filePath = args[0];
  final targetDir = args.length > 1 ? args[1] : '';
  
  final file = File(filePath);
  if (!await file.exists()) {
    print('❌ 文件不存在: $filePath');
    return;
  }

  print('📤 上传文件: $filePath');
  if (targetDir.isNotEmpty) {
    print('📁 目标目录: $targetDir');
  }

  try {
    final cli = FileOperationsCLI(sharedDir: './shared');
    final success = await cli.uploadFile(filePath, targetDir: targetDir);
    
    if (success) {
      print('✅ 上传成功: $filePath');
    } else {
      print('❌ 上传失败: $filePath');
    }
  } catch (e) {
    print('❌ 上传失败: $e');
  }
}

/// 处理下载命令
Future<void> _handleDownload(List<String> args) async {
  if (args.isEmpty) {
    print('❌ 请指定要下载的文件');
    print('用法: file_cli download <远程文件路径> [本地保存路径]');
    return;
  }

  final remotePath = args[0];
  final localPath = args.length > 1 ? args[1] : path.basename(remotePath);
  
  print('📥 下载文件: $remotePath');
  print('💾 保存到: $localPath');

  try {
    final cli = FileOperationsCLI(sharedDir: './shared');
    final success = await cli.downloadFile(remotePath, localPath);
    
    if (success) {
      print('✅ 下载成功: $remotePath -> $localPath');
    } else {
      print('❌ 下载失败: $remotePath');
    }
  } catch (e) {
    print('❌ 下载失败: $e');
  }
}

/// 处理列表命令
Future<void> _handleList(List<String> args) async {
  final dir = args.isNotEmpty ? args[0] : '';
  
  print('📋 列出文件${dir.isNotEmpty ? ': $dir' : ''}');

  try {
    final cli = FileOperationsCLI(sharedDir: './shared');
    final files = await cli.listFiles(dir: dir);
    
    if (files.isEmpty) {
      print('📁 目录为空');
      return;
    }

    print('📋 文件列表:');
    final formatted = FileOperationsCLI.formatFileList(files, long: true, human: true);
    print(formatted);
  } catch (e) {
    print('❌ 获取文件列表失败: $e');
  }
}

/// 处理删除命令
Future<void> _handleDelete(List<String> args) async {
  if (args.isEmpty) {
    print('❌ 请指定要删除的文件');
    print('用法: file_cli delete <文件路径>');
    return;
  }

  final filePath = args[0];
  
  // 询问确认
  stdout.write('❓ 确定要删除 "$filePath" 吗？(y/N): ');
  final input = stdin.readLineSync();
  if (input?.toLowerCase() != 'y') {
    print('⏭️ 操作已取消');
    return;
  }

  print('🗑️ 删除文件: $filePath');

  try {
    final cli = FileOperationsCLI(sharedDir: './shared');
    final success = await cli.deleteFile(filePath);
    
    if (success) {
      print('✅ 删除成功: $filePath');
    } else {
      print('❌ 删除失败: $filePath');
    }
  } catch (e) {
    print('❌ 删除失败: $e');
  }
}



/// 显示帮助信息
void _showHelp() {
  print('''
🌐 文件操作 CLI 工具

用法:
  file_cli <command> [options]

命令:
  upload <文件路径> [目标目录]    上传文件
  download <远程路径> [本地路径]  下载文件
  list [目录]                   列出文件
  delete <文件路径>             删除文件
  help                         显示帮助信息
  version                      显示版本信息

示例:
  file_cli upload ./myfile.txt
  file_cli upload ./myfile.txt /documents
  file_cli download /shared/file.txt
  file_cli download /shared/file.txt ./local.txt
  file_cli list
  file_cli list /documents
  file_cli delete /shared/file.txt

更多信息请访问: https://github.com/your-repo/lan-web-server
''');
}

/// 显示版本信息
void _showVersion() {
  print('文件操作 CLI 工具 v1.0.0');
  print('Dart SDK: ${Platform.version}');
}
