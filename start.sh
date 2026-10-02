#!/usr/bin/env bash
# ===================================================================
#  Kimi Chen 个人主页 — 本地预览（macOS / Linux / WSL）
#  用法：./start.sh  [端口]        默认端口 8080
#  端口被占用时 dev_server.py 会自动顺延，浏览器也由它负责打开。
# ===================================================================
set -euo pipefail

cd "$(dirname "$0")"

PY=""
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "  [X] 没有找到 Python 3，请先安装。" >&2
  exit 1
fi

export PYTHONUTF8=1

exec "$PY" dev_server.py "$@"
