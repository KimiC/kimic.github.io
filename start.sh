#!/usr/bin/env bash
# ===================================================================
#  Kimi Chen 个人主页 — 本地预览（macOS / Linux）
#  用法：./start.sh  [端口]        默认端口 8080
# ===================================================================
set -euo pipefail

cd "$(dirname "$0")"

PORT="${1:-8080}"

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "  [X] 没有找到 Python 3，请先安装。" >&2
  exit 1
fi

export PYTHONUTF8=1

# 尽量自动打开浏览器（打不开也不影响服务）
URL="http://127.0.0.1:${PORT}/"
if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 || true
fi

exec "$PY" dev_server.py --port "$PORT"
