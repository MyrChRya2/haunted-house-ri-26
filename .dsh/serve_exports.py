"""临时静态服务器：用于本地验证 Godot Web 导出。

Godot 4 的 Web 导出在启用线程时会用到 SharedArrayBuffer，
浏览器要求页面带 COOP/COEP 响应头才允许，故这里手动加上。
仅监听 127.0.0.1，只服务 EXPORTS 目录。
"""
import functools
import http.server
import socketserver

ROOT = r"D:\Fox_n\!PROJECTS\#teamwork\FirstProject\retro-game-jam-2026\EXPORTS"
PORT = 8137


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    handler = functools.partial(Handler, directory=ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), handler) as httpd:
        print("serving %s at http://127.0.0.1:%d/" % (ROOT, PORT), flush=True)
        httpd.serve_forever()
