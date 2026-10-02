@echo off
rem ===================================================================
rem  Kimi Chen 个人主页 — Windows 一键本地预览
rem  双击本文件即可；不需要安装任何依赖，只用到 Python 自带模块。
rem ===================================================================
chcp 65001 >nul 2>&1
setlocal

title 个人主页 - 本地预览

rem 切到脚本所在目录，双击运行时也正确
cd /d "%~dp0"

rem ---- 找一个可用的 Python（优先用 py 启动器） ----
set "PY="
where py >nul 2>&1 && set "PY=py"
if not defined PY (
  where python >nul 2>&1 && set "PY=python"
)

if not defined PY (
  echo.
  echo   [X] 没有找到 Python。
  echo       请先安装 Python 3，安装时勾选 "Add Python to PATH"。
  echo       下载地址：https://www.python.org/downloads/
  echo.
  echo   如果你习惯用 WSL，可以在 WSL 里执行：
  echo       ./start.sh
  echo.
  pause
  exit /b 1
)

set "PYTHONUTF8=1"

rem 端口被占用时，dev_server.py 会自动顺延；浏览器由它负责打开
%PY% dev_server.py %*

echo.
echo   服务已退出。
pause
