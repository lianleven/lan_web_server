#!/usr/bin/env bash
# 构建 example 的 macOS Release，并将 .app 安装到当前用户的「应用程序」目录：
#   ~/Applications/LANWebServer.app
#
# 用法：
#   ./scripts/install_mac_app.sh           # 完整构建并安装
#   ./scripts/install_mac_app.sh --no-build # 仅复制上次构建产物（需已有 Release）
#
# 无需 sudo。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/example"
APP_BUNDLE="LANWebServer.app"
BUILD_APP="${EXAMPLE_DIR}/build/macos/Build/Products/Release/${APP_BUNDLE}"
DEST_DIR="${HOME}/Applications"
DEST_APP="${DEST_DIR}/${APP_BUNDLE}"

do_build=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      do_build=false
      shift
      ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${do_build}" == true ]]; then
  echo "==> flutter build macos --release"
  (cd "${EXAMPLE_DIR}" && flutter build macos --release)
fi

if [[ ! -d "${BUILD_APP}" ]]; then
  echo "错误: 未找到构建产物: ${BUILD_APP}" >&2
  echo "请先执行不带 --no-build 的完整构建。" >&2
  exit 1
fi

echo "==> 安装到 ${DEST_APP}"
mkdir -p "${DEST_DIR}"
rm -rf "${DEST_APP}"
ditto "${BUILD_APP}" "${DEST_APP}"
echo "完成。可在启动台或「应用程序」中找到「LAN Web Server」。"
