import 'package:flutter/services.dart';

class AssetLoader {

  /// 从assets加载HTML文件
  static const _package = 'web_server';

  static Future<String> loadAsset(String relativePath) async {
    final packagePath = 'packages/$_package/$relativePath';
    try {
      return await rootBundle.loadString(packagePath);
    } catch (_) {
      // fallback: 本地运行组件库时用
      return await rootBundle.loadString(relativePath);
    }
  }

  static Future<String> loadHtmlIndex() => loadAsset('lib/assets/index.html');
}
