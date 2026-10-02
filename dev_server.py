#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本地预览服务器 —— 仅用于开发预览，不是生产环境。

特性：
  * 关闭缓存，改完文件刷新就能看到效果
  * 自动注入热重载脚本：保存 HTML/CSS/JS 后浏览器自动刷新
  * 支持目录形式的干净链接（/about -> /about/index.html）
  * 纯标准库，不需要 pip 安装任何东西

用法：
    python dev_server.py                 # http://127.0.0.1:8080
    python dev_server.py -p 5500         # 换端口
    python dev_server.py --host 0.0.0.0  # 允许同一局域网的其他设备访问
    python dev_server.py --no-reload     # 关闭自动刷新
"""

from __future__ import annotations

import argparse
import functools
import http.server
import io
import os
import socket
import socketserver
import sys
import threading
import time
from http import HTTPStatus
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
WATCH_SUFFIXES = {".html", ".css", ".js", ".mjs", ".json", ".svg", ".webp", ".avif", ".png", ".jpg"}
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".idea", ".vscode", "deploy"}

RELOAD_SNIPPET = """
<script>
(function () {
  var current = null;
  function poll() {
    fetch('/__reload', { cache: 'no-store' })
      .then(function (r) { return r.text(); })
      .then(function (v) {
        if (current === null) { current = v; }
        else if (v !== current) { location.reload(); }
      })
      .catch(function () {});
  }
  setInterval(poll, 900);
  poll();
})();
</script>
"""


def scan_version() -> str:
    """把所有被监视文件的最新修改时间汇总成一个版本号。"""
    newest = 0.0
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for name in filenames:
            if Path(name).suffix.lower() not in WATCH_SUFFIXES:
                continue
            try:
                mtime = os.stat(os.path.join(dirpath, name)).st_mtime
            except OSError:
                continue
            if mtime > newest:
                newest = mtime
    return f"{newest:.6f}"


class VersionCache:
    """带缓存的版本号，避免每次轮询都遍历整个目录树。"""

    def __init__(self, ttl: float = 0.6) -> None:
        self._ttl = ttl
        self._value = scan_version()
        self._checked_at = time.monotonic()
        self._lock = threading.Lock()

    def get(self) -> str:
        with self._lock:
            if time.monotonic() - self._checked_at >= self._ttl:
                self._value = scan_version()
                self._checked_at = time.monotonic()
            return self._value


class DevHandler(http.server.SimpleHTTPRequestHandler):
    """静态文件处理器：无缓存 + 热重载注入。"""

    reload_enabled = True
    version_cache: VersionCache | None = None
    protocol_version = "HTTP/1.1"

    # ---------- 日志 ----------
    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        sys.stderr.write("  %s\n" % (fmt % args))

    def log_error(self, fmt: str, *args) -> None:
        self.log_message(fmt, *args)

    # ---------- 路由 ----------
    def do_GET(self) -> None:  # noqa: N802
        if urlparse(self.path).path == "/__reload":
            self._serve_version()
            return
        super().do_GET()

    def do_HEAD(self) -> None:  # noqa: N802
        if urlparse(self.path).path == "/__reload":
            self._serve_version(body=False)
            return
        super().do_HEAD()

    def _serve_version(self, body: bool = True) -> None:
        payload = (self.version_cache.get() if self.version_cache else scan_version()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if body:
            self.wfile.write(payload)

    # ---------- MIME 与缓存 ----------
    def guess_type(self, path):
        """给文本类 MIME 补上 charset。

        Python 3.14 的 SimpleHTTPRequestHandler 已经自带 charset，
        这里只是保证在更老的 3.x 上也一致，重复时不会叠加。
        """
        ctype = http.server.SimpleHTTPRequestHandler.guess_type(self, path)
        if isinstance(ctype, str) and ctype.startswith(
            ("text/html", "text/css", "application/javascript", "text/javascript")
        ):
            if "charset" not in ctype:
                ctype += "; charset=utf-8"
        return ctype

    def end_headers(self) -> None:
        """开发环境一律禁用缓存。"""
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    # ---------- 请求处理：干净链接 + HTML 注入热重载 ----------
    def send_head(self):
        path = urlparse(self.path).path

        # ① 目录没带末尾斜杠 -> 301 重定向到带斜杠的地址，
        #    和真实 Web 服务器（含 Nginx）行为一致，避免相对路径解析出错
        local = self.translate_path(path)
        if os.path.isdir(local) and not path.endswith("/"):
            self.send_response(HTTPStatus.MOVED_PERMANENTLY)
            self.send_header("Location", path + "/")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None

        # ② 把请求路径解析成实际文件：/、/about/ -> index.html；/about -> about.html
        candidate = self._resolve_page(path)
        if candidate is None:
            # ③ 非 HTML 的部分（静态文件、目录列表、404）交给父类
            return http.server.SimpleHTTPRequestHandler.send_head(self)

        # ④ HTML 自己处理：注入必须发生在写出响应头之前。
        #    父类的 send_head 内部就会 end_headers()，之后再改 Content-Length 已经晚了。
        self.path = candidate
        return self._open_html(self.translate_path(candidate))

    def _resolve_page(self, path: str):
        """把 URL 路径解析成本机上真实存在的 HTML 文件；不是 HTML 就返回 None。"""
        # /about -> /about.html
        base = path.rstrip("/")
        if not os.path.splitext(path)[1]:
            for candidate in (path + ".html", path + ".htm"):
                if os.path.isfile(self.translate_path(candidate)):
                    return candidate

        # / 或 /about/ -> 目录下的 index.html
        local = self.translate_path(path)
        if os.path.isdir(local):
            for index in ("index.html", "index.htm"):
                if os.path.isfile(os.path.join(local, index)):
                    return base + "/" + index if base else "/" + index

        # 直接请求某个 .html
        if os.path.splitext(local)[1].lower() in (".html", ".htm") and os.path.isfile(local):
            return path
        return None

    def _open_html(self, local: str):
        """读取 HTML、注入热重载脚本、发送响应头，返回待写出的数据流。"""
        try:
            with open(local, "rb") as fp:
                raw = fp.read()
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        text = raw.decode("utf-8", errors="replace")
        if self.reload_enabled:
            if "</body>" in text:
                text = text.replace("</body>", RELOAD_SNIPPET + "</body>", 1)
            else:
                text += RELOAD_SNIPPET
        data = text.encode("utf-8")

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        return io.BytesIO(data)


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def lan_ip() -> str | None:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description="个人主页本地预览服务器")
    parser.add_argument("-p", "--port", type=int, default=8080, help="端口，默认 8080")
    parser.add_argument("--host", default="127.0.0.1", help="绑定地址，默认 127.0.0.1；用 0.0.0.0 允许局域网访问")
    parser.add_argument("--no-reload", action="store_true", help="关闭自动刷新")
    args = parser.parse_args()

    if not (ROOT / "index.html").is_file():
        print(f"[!] 在 {ROOT} 里没找到 index.html，请把本脚本放在站点根目录。", file=sys.stderr)
        return 1

    DevHandler.reload_enabled = not args.no_reload
    DevHandler.version_cache = VersionCache()
    handler = functools.partial(DevHandler, directory=str(ROOT))

    try:
        httpd = ThreadingServer((args.host, args.port), handler)
    except OSError as exc:
        print(f"[!] 无法绑定 {args.host}:{args.port} —— {exc}", file=sys.stderr)
        print("    端口可能被占用，试试：python dev_server.py -p 8081", file=sys.stderr)
        return 1

    local = f"http://127.0.0.1:{args.port}/"
    print()
    print("  个人主页 · 本地预览已启动")
    print("  " + "-" * 46)
    print(f"  本机访问 : {local}")
    if args.host == "0.0.0.0":
        ip = lan_ip()
        if ip:
            print(f"  局域网   : http://{ip}:{args.port}/")
    print(f"  站点目录 : {ROOT}")
    print(f"  自动刷新 : {'开启' if not args.no_reload else '关闭'}")
    print("  " + "-" * 46)
    print("  按 Ctrl+C 停止服务")
    print()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n  已停止。")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
