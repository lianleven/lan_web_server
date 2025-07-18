[中文文档 (Chinese README)](README_ZH.md)

# web_server

A cross-platform Flutter/Dart LAN file sharing server. Easily upload, download, delete, and browse files or folders via a beautiful web interface. Works on desktop, mobile, and embedded devices, making local file access and management simple and efficient.

## Features

- 📁 **File/Folder Upload**: Supports multiple files and nested directories
- 📥 **File/Folder Download**: Large files and folders are zipped and streamed for efficient download
- 🗑️ **File/Folder Deletion**: Easily remove content from the shared directory
- 🖥️ **Cross-Platform**: Runs on Windows, macOS, Linux, Android, and iOS
- 🌐 **User-Friendly Web UI**: Modern web interface with drag-and-drop upload and file browsing
- 📝 **Online Text Editing**: Preview, edit, and save text files (txt, json, yaml, etc.) directly in the browser
- 🧹 **JSON Power Tools**: One-click format, real-time validation, error line highlighting for JSON files
- 🎨 **Pro Editor Experience**: Syntax highlighting, line numbers, dark mode, full screen, find/replace, error highlighting
- 🔒 **Security**: Path validation prevents directory traversal; LAN-only by default
- 🚀 **High Performance**: Streams large files/folders, minimizing memory usage
- 📝 **Logging & State Streams**: Easy integration into Flutter apps

## Quick Start

### 1. Install Dependencies

In the project root:

```bash
flutter pub get
```

### 2. Run the Example (Desktop/Mobile)

```bash
cd example
flutter run
```

### 3. Integrate into Your Dart/Flutter Project

```dart
import 'package:web_server/web_server.dart';

final server = WebServerService(port: 8080, sharedDir: '/your/shared/dir');
await server.start();
```

### 4. Access the Web UI

Open your browser and visit:

```
http://<your-local-ip>:8080/
```

## API Endpoints

| Path             | Method | Description                        |
|------------------|--------|------------------------------------|
| `/`              | GET    | Home page (Web UI)                 |
| `/files`         | GET    | List files/folders                 |
| `/upload`        | POST   | Upload files/folders               |
| `/download`      | GET    | Download files/folders             |
| `/delete`        | POST   | Delete files/folders               |
| `/save`          | POST   | Save edited text file              |
| `/static-path`   | GET    | Direct access to shared files      |

- **Folder download**: Automatically zipped and streamed, supports large directories
- **Large file download**: Streamed to minimize memory usage
- **Text file editing**: Edit and save text files (txt/json/yaml) online
- **JSON editing**: Format, validate, and highlight errors with line numbers

## Typical Use Cases

- File transfer between devices on the same LAN
- Temporary file sharing between mobile and desktop
- Cross-platform local file management
- Lightweight file server for intranet environments

## FAQ

- **Q: How do I change the shared directory?**  
  A: Specify the `sharedDir` parameter when creating `WebServerService`.

- **Q: Does it support concurrent users?**  
  A: Yes, it uses Dart async IO and is suitable for lightweight concurrent scenarios.

- **Q: Will large files or directories cause memory issues?**  
  A: No, streaming and temporary file strategies keep memory usage low.

- **Q: How to use on mobile?**  
  A: See the `example` directory. On mobile, the app uses the application documents directory as the shared folder.

## Contributing & Feedback

Issues, PRs, and suggestions are welcome!  
For custom features, bug reports, or ideas, please contact the author or submit to [GitHub Issues](https://github.com/lianleven/web_server/issues).

---

If you need more detailed developer documentation or have special requirements, feel free to ask!
