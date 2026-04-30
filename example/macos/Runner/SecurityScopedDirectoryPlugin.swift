import Cocoa
import FlutterMacOS

/// macOS 沙盒下，用户通过 NSOpenPanel 选择的目录必须 startAccessingSecurityScopedResource，
/// 否则 Dart/io 对该路径的列目录、读文件会得到 Operation not permitted。
/// 持久化路径依赖 security-scoped bookmark，否则下次启动会丢失访问权限。
public final class SecurityScopedDirectoryPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "lan_web_server/security_scoped_directory",
      binaryMessenger: registrar.messenger)
    let instance = SecurityScopedDirectoryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.allowsMultipleSelection = false
      panel.prompt = "选择"
      if panel.runModal() == .OK, let url = panel.url {
        guard url.startAccessingSecurityScopedResource() else {
          result(FlutterError(code: "access", message: "无法获得对该文件夹的访问权限", details: nil))
          return
        }
        var bookmark: String?
        do {
          let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
          bookmark = data.base64EncodedString()
        } catch {
          bookmark = nil
        }
        result([
          "path": url.path,
          "bookmark": bookmark as Any,
        ])
      } else {
        result(nil)
      }

    case "restoreBookmark":
      guard let bookmarkB64 = call.arguments as? String,
            let bookmarkData = Data(base64Encoded: bookmarkB64) else {
        result(FlutterError(code: "bad_arg", message: "无效的 bookmark", details: nil))
        return
      }
      var stale = false
      do {
        let url = try URL(
          resolvingBookmarkData: bookmarkData,
          options: [.withSecurityScope, .withoutUI],
          relativeTo: nil,
          bookmarkDataIsStale: &stale)
        if stale {
          result(FlutterError(code: "stale", message: "访问授权已过期，请重新选择共享文件夹", details: nil))
          return
        }
        guard url.startAccessingSecurityScopedResource() else {
          result(FlutterError(code: "access", message: "无法恢复对该文件夹的访问", details: nil))
          return
        }
        result(url.path)
      } catch {
        result(FlutterError(code: "restore", message: error.localizedDescription, details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
