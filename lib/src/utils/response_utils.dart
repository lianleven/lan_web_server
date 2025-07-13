import 'dart:io';
import 'dart:convert';

Future<void> sendJsonResponse(HttpRequest request, Map<String, dynamic> data) async {
  request.response.headers.set('Content-Type', 'application/json; charset=utf-8');
  request.response.write(jsonEncode(data));
  await request.response.close();
}

Future<void> sendErrorResponse(HttpRequest request, int statusCode, String message) async {
  request.response.statusCode = statusCode;
  request.response.headers.set('Content-Type', 'text/plain; charset=utf-8');
  request.response.write(message);
  await request.response.close();
}

/// 发送HTML响应
Future<void> sendHtmlResponse(HttpRequest request, String html) async {
  request.response.headers.set('Content-Type', 'text/html; charset=utf-8');
  request.response.write(html);
  await request.response.close();
}
