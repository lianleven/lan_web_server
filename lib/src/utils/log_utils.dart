import 'package:flutter/foundation.dart';

void logInfo(String message) {
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('[INFO][$timestamp] $message');
}

void logError(String message) {
  final timestamp = DateTime.now().toIso8601String();
  debugPrint('[ERROR][$timestamp] $message');
}
