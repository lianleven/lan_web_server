import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:lan_web_server/src/utils/asset_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:lan_web_server/src/handlers/upload_handler.dart';
import 'package:lan_web_server/src/handlers/download_handler.dart';
import 'package:lan_web_server/src/handlers/file_list_handler.dart';
import 'package:lan_web_server/src/handlers/delete_handler.dart';
import 'package:lan_web_server/src/utils/file_utils.dart';
import 'package:lan_web_server/src/utils/response_utils.dart';

/// Web服务器状态
enum WebServerState { stopped, starting, running, stopping, error }

/// Web服务器服务
class WebServerService {
  HttpServer? _server;
  final int port;
  final String sharedDir;

  final _stateController = StreamController<WebServerState>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final _uploadController = StreamController<String>.broadcast();

  Stream<WebServerState> get onStateChanged => _stateController.stream;
  Stream<String> get onLog => _logController.stream;
  Stream<String> get onUpload => _uploadController.stream;

  WebServerState _state = WebServerState.stopped;
  WebServerState get state => _state;

  String get uploadDir => sharedDir;
  String get downloadDir => sharedDir;
  String get sharedDirectory => sharedDir;

  WebServerService({required this.port, required this.sharedDir}) {
    _ensureDirectoryExists();
  }

  /// 确保目录存在
  Future<void> _ensureDirectoryExists() async {
    try {
      final dir = Directory(sharedDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        _log('Created shared directory: $sharedDir');
      }
    } catch (e) {
      _log('Error creating directory: $e');
    }
  }

  /// 启动Web服务器
  Future<void> start() async {
    if (_state != WebServerState.stopped) {
      _log('Server is already running or starting');
      return;
    }

    try {
      _setState(WebServerState.starting);
      _log('Starting web server on port $port...');

      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _log('Web server started on port $port');

      _server!.listen(_handleRequest);
      _setState(WebServerState.running);
      _log('Web server is ready');
    } catch (e) {
      _setState(WebServerState.error);
      _log('Failed to start web server: $e');
      rethrow;
    }
  }

  /// 停止Web服务器
  Future<void> stop() async {
    if (_state == WebServerState.stopped) {
      return;
    }

    try {
      _setState(WebServerState.stopping);
      _log('Stopping web server...');

      await _server?.close();
      _server = null;

      _setState(WebServerState.stopped);
      _log('Web server stopped');
    } catch (e) {
      _setState(WebServerState.error);
      _log('Error stopping web server: $e');
      rethrow;
    }
  }

  /// 处理HTTP请求
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      _log('${request.method} $path');

      switch (path) {
        case '/':
          await _handleHomePage(request);
          break;
        case '/upload':
          await handleUpload(request, sharedDir);
          break;
        case '/download':
          await handleDownload(request, sharedDir);
          break;
        case '/files':
          await handleFileList(request, sharedDir);
          break;
        case '/delete':
          await handleDelete(request, sharedDir);
          break;
        case '/save':
          if (request.method == 'POST') {
            await handleSaveTextFile(request, sharedDir);
          } else {
            await sendErrorResponse(request, 405, 'Method Not Allowed');
          }
          break;
        default:
          await _handleFile(request);
      }
    } catch (e) {
      _log('Error handling request: $e');
      await sendErrorResponse(request, 500, 'Internal Server Error');
    }
  }

  /// 处理主页
  Future<void> _handleHomePage(HttpRequest request) async {
    final html = await AssetLoader.loadHtmlIndex();
    await sendHtmlResponse(request, html);
  }

  /// 处理静态文件
  Future<void> _handleFile(HttpRequest request) async {
    final filePath = path.join(sharedDir, request.uri.path.substring(1));
    final file = File(filePath);

    if (!await file.exists()) {
      await sendErrorResponse(request, 404, 'File not found');
      return;
    }

    try {
      final stream = file.openRead();
      final length = await file.length();

      // 设置正确的Content-Type
      final ext = path.extension(filePath).toLowerCase();
      final contentType = getContentType(ext);
      request.response.headers.set('Content-Type', contentType);
      request.response.headers.set('Content-Length', length.toString());

      await request.response.addStream(stream);
      await request.response.close();
    } catch (e) {
      _log('Error serving file: $e');
      await sendErrorResponse(request, 500, 'Failed to serve file');
    }
  }

  /// 设置状态
  void _setState(WebServerState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 记录日志
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _logController.add(logMessage);
    if (kDebugMode) {
      print(logMessage);
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _stateController.close();
    _logController.close();
    _uploadController.close();
  }
}
