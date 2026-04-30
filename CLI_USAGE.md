# 文件操作 CLI 工具使用说明

## 🎯 简介

文件操作 CLI 工具将 Web 界面的文件管理功能转换为命令行工具，让程序员可以通过终端直接操作文件，无需启动 Web 服务器。

## 🚀 功能特性

- ✅ **文件上传**：将本地文件上传到共享目录
- ✅ **文件下载**：从共享目录下载文件到本地
- ✅ **文件列表**：查看共享目录中的文件
- ✅ **文件删除**：删除共享目录中的文件
- ✅ **目录支持**：支持子目录操作
- ✅ **安全确认**：删除操作需要确认

## 📦 安装使用

### 方法1：直接运行
```bash
# 在项目目录中
dart run bin/file_cli.dart <command>
```

### 方法2：全局安装
```bash
# 激活包
dart pub global activate lan_web_server

# 运行CLI
dart pub global run lan_web_server:file_cli <command>
```

## 📋 命令详解

### 📤 上传文件
```bash
# 基本上传
dart run bin/file_cli.dart upload ./myfile.txt

# 上传到指定目录
dart run bin/file_cli.dart upload ./myfile.txt documents

# 上传多个文件
dart run bin/file_cli.dart upload ./file1.txt ./file2.txt
```

**功能说明：**
- 将本地文件复制到共享目录
- 支持指定目标子目录
- 自动创建目标目录

### 📥 下载文件
```bash
# 基本下载
dart run bin/file_cli.dart download /shared/file.txt

# 下载到指定位置
dart run bin/file_cli.dart download /shared/file.txt ./local.txt

# 下载子目录文件
dart run bin/file_cli.dart download /documents/report.pdf
```

**功能说明：**
- 从共享目录复制文件到本地
- 支持指定本地保存路径
- 支持子目录文件下载

### 📋 列出文件
```bash
# 列出根目录
dart run bin/file_cli.dart list

# 列出指定目录
dart run bin/file_cli.dart list documents

# 列出子目录
dart run bin/file_cli.dart list documents/reports
```

**功能说明：**
- 显示文件名称、大小、修改时间
- 支持目录浏览
- 自动格式化显示

### 🗑️ 删除文件
```bash
# 删除文件
dart run bin/file_cli.dart delete /shared/file.txt

# 删除子目录文件
dart run bin/file_cli.dart delete /documents/report.pdf

# 删除目录
dart run bin/file_cli.dart delete /temp
```

**功能说明：**
- 删除前需要确认
- 支持文件和目录删除
- 递归删除目录内容

## 💡 使用示例

### 基本工作流
```bash
# 1. 查看当前文件
dart run bin/file_cli.dart list

# 2. 上传新文件
dart run bin/file_cli.dart upload ./project.zip

# 3. 再次查看文件
dart run bin/file_cli.dart list

# 4. 下载文件
dart run bin/file_cli.dart download /project.zip ./backup.zip

# 5. 删除文件
dart run bin/file_cli.dart delete /project.zip
```

### 目录操作
```bash
# 创建目录结构
dart run bin/file_cli.dart upload ./documents/report.pdf documents
dart run bin/file_cli.dart upload ./documents/data.csv documents

# 查看目录内容
dart run bin/file_cli.dart list documents

# 下载整个目录
dart run bin/file_cli.dart download /documents ./local-docs
```

### 批量操作
```bash
# 批量上传
dart run bin/file_cli.dart upload ./files/*.txt

# 批量下载
dart run bin/file_cli.dart download /shared/*.pdf ./downloads

# 批量删除
dart run bin/file_cli.dart delete /temp/*
```

## 🎨 输出格式

### 文件列表格式
```bash
📋 文件列表:
📁 documents (0B) - 2024-01-15T10:30:00.000Z
📄 report.pdf (2.1MB) - 2024-01-15T10:25:00.000Z
📄 data.csv (1.2KB) - 2024-01-15T10:20:00.000Z
```

### 操作结果格式
```bash
📤 上传文件: ./myfile.txt
📁 目标目录: documents
✅ 上传成功: ./myfile.txt

📥 下载文件: /documents/myfile.txt
💾 保存到: ./local.txt
✅ 下载成功: /documents/myfile.txt -> ./local.txt

🗑️ 删除文件: /documents/myfile.txt
❓ 确定要删除 "/documents/myfile.txt" 吗？(y/N): y
✅ 删除成功: /documents/myfile.txt
```

## 🔧 配置说明

### 共享目录配置
默认共享目录为 `./shared`，可以通过修改代码中的路径来更改：

```dart
final cli = FileOperationsCLI(sharedDir: './your-shared-dir');
```

### 错误处理
CLI工具会显示详细的错误信息：

```bash
❌ 文件不存在: ./nonexistent.txt
❌ 上传失败: 文件不存在: ./nonexistent.txt

❌ 远程文件不存在: /nonexistent.txt
❌ 下载失败: 远程文件不存在: /nonexistent.txt

❌ 目录不存在: /nonexistent
❌ 获取文件列表失败: 目录不存在: /nonexistent
```

## 🚨 注意事项

### 1. 路径格式
- **本地路径**：使用系统路径格式（如 `./file.txt`）
- **远程路径**：使用正斜杠格式（如 `/documents/file.txt`）

### 2. 权限要求
- 需要对共享目录有读写权限
- 删除操作需要确认，避免误删

### 3. 文件覆盖
- 上传时会覆盖同名文件
- 下载时会覆盖本地同名文件

### 4. 目录操作
- 删除目录会递归删除所有内容
- 上传到不存在的目录会自动创建

## 📚 帮助信息

### 查看帮助
```bash
dart run bin/file_cli.dart help
dart run bin/file_cli.dart --help
dart run bin/file_cli.dart -h
```

### 查看版本
```bash
dart run bin/file_cli.dart version
dart run bin/file_cli.dart --version
dart run bin/file_cli.dart -v
```

## 🔗 与Web界面对比

| 功能 | Web界面 | CLI工具 |
|------|---------|---------|
| 文件上传 | ✅ 拖拽上传 | ✅ 命令行上传 |
| 文件下载 | ✅ 点击下载 | ✅ 命令行下载 |
| 文件列表 | ✅ 图形界面 | ✅ 文本列表 |
| 文件删除 | ✅ 点击删除 | ✅ 命令行删除 |
| 目录浏览 | ✅ 图形导航 | ✅ 路径指定 |
| 批量操作 | ✅ 多选操作 | ✅ 通配符支持 |
| 脚本化 | ❌ 不支持 | ✅ 完全支持 |
| 自动化 | ❌ 不支持 | ✅ 完全支持 |

## 🎯 最佳实践

### 1. 脚本化使用
```bash
#!/bin/bash
# 自动化备份脚本

# 上传备份文件
dart run bin/file_cli.dart upload ./backup-$(date +%Y%m%d).tar.gz

# 列出文件确认
dart run bin/file_cli.dart list

# 清理旧备份
dart run bin/file_cli.dart delete /backup-$(date -d '7 days ago' +%Y%m%d).tar.gz
```

### 2. 与Git集成
```bash
# 在Git钩子中使用
#!/bin/bash
# pre-commit hook
dart run bin/file_cli.dart upload $(git diff --cached --name-only) /git-backup/$(date +%Y%m%d)
```

### 3. 与CI/CD集成
```bash
# 在CI脚本中使用
dart run bin/file_cli.dart upload ./build/app.apk /releases
dart run bin/file_cli.dart list /releases
```

## 🚀 高级用法

### 1. 批量上传脚本
```bash
#!/bin/bash
# 批量上传脚本
for file in ./uploads/*; do
    if [ -f "$file" ]; then
        dart run bin/file_cli.dart upload "$file"
    fi
done
```

### 2. 同步脚本
```bash
#!/bin/bash
# 同步本地和远程文件
dart run bin/file_cli.dart list > remote_files.txt
dart run bin/file_cli.dart download /shared/config.json ./local_config.json
```

### 3. 清理脚本
```bash
#!/bin/bash
# 清理临时文件
dart run bin/file_cli.dart list /temp
dart run bin/file_cli.dart delete /temp/old_file.txt
```

---

**CLI工具让文件操作更高效！** 🚀
