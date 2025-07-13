void logInfo(String message) {
  final timestamp = DateTime.now().toIso8601String();
  print('[INFO][$timestamp] $message');
}

void logError(String message) {
  final timestamp = DateTime.now().toIso8601String();
  print('[ERROR][$timestamp] $message');
} 