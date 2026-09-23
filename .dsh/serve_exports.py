"""临时静态服务器：用于本地验证 Godot Web 导出。

两个关键点（缺一个就会"一直转圈"）：
1. Godot 的网页加载器会**并发**请求 wasm / pck / js，必须用多线程服务器，
   Python 自带的单线程 TCPServer 会把并发请求串行化甚至卡死。
2. 启用线程的导出会用到 SharedArrayBuffer，浏览器要求页面带 COOP/COEP 响应头。

仅监听 127.0.0.1，只服务 EXPORTS 目录。
"""
import functools
import http.server
from http.server import ThreadingHTTPServer

ROOT = r"D:\Fox_n\!PROJECTS\#teamwork\FirstProject\retro-game-jam-2026\EXPORTS"
PORT = 8137


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    handler = functools.partial(Handler, directory=ROOT)
    ThreadingHTTPServer.allow_reuse_address = True
    with ThreadingHTTPServer(("127.0.0.1", PORT), handler) as httpd:
        print("threading server on http://127.0.0.1:%d/ serving %s" % (PORT, ROOT), flush=True)
        httpd.serve_forever()
