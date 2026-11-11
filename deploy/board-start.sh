#!/bin/bash
# 板端 (RK3588S / Ubuntu 20.04 / Node 26) 启动 ws-scrcpy 的封装脚本
#
# 为什么不用 upstream 的 `npm start`:
#   1. 它每次都先跑 webpack, 板端要几分钟; 这里只在缺 dist 时构建
#   2. 它不支持命令行参数 —— dist/index.js 里没有任何 process.argv 解析代码,
#      端口只能靠 WS_SCRCPY_CONFIG 指向的 yaml。`--port` / `--ua=false` 都是无效参数,
#      node 会静默忽略, 端口始终是默认 8000。
#
# 用法: ./deploy/board-start.sh [端口]

set -euo pipefail

PORT="${1:-8000}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -d node_modules ]; then
  echo "[board-start] node_modules 缺失, 执行 npm install (较慢)..."
  npm install
fi

if [ ! -f dist/index.js ]; then
  echo "[board-start] dist/ 缺失, 执行 webpack 构建 (板端约 3-5 分钟)..."
  npm run dist
fi

CONF="$ROOT/deploy/board.config.yaml"
if [ "$PORT" != "8000" ]; then
  CONF="$(mktemp -t wsscrcpy.XXXXXX.yaml)"
  sed "s/port: 8000/port: ${PORT}/" "$ROOT/deploy/board.config.yaml" > "$CONF"
  trap 'rm -f "$CONF"' EXIT
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "[board-start] 警告: PATH 里没有 adb, 设备列表会是空的" >&2
fi

adb start-server >/dev/null 2>&1 || true

echo "[board-start] 配置: $CONF"
echo "[board-start] 监听 http://0.0.0.0:${PORT}/  (需 adb devices 能看到手机)"
# index.js 依赖同目录的 package.json 与 public/, 必须在 dist/ 里启动
cd "$ROOT/dist"
WS_SCRCPY_CONFIG="$CONF" exec node ./index.js
