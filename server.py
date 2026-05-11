"""
Tally — The Controls App
GCP VM server

  • Serves static files on port 80 (or 9000 for dev)
  • Proxies /jira-proxy/* → Atlassian Jira Cloud REST API (bypasses CORS)
  • Proxies /starburst-query → Starburst / Trino REST API

Usage:
    python3 server.py              # port 9000 (dev)
    sudo python3 server.py --prod  # port 80  (GCP VM)
"""

import json
import sys
import time
import urllib.request
import urllib.error
from http.server import HTTPServer, SimpleHTTPRequestHandler


class TallyHandler(SimpleHTTPRequestHandler):

    # ── CORS pre-flight ──────────────────────────────────────────
    def do_OPTIONS(self):
        self._cors(200)
        self.end_headers()

    # ── Static files ─────────────────────────────────────────────
    def do_GET(self):
        if self.path.startswith('/jira-proxy/'):
            self._proxy('GET')
        else:
            super().do_GET()

    # ── POST routing ─────────────────────────────────────────────
    def do_POST(self):
        if self.path.startswith('/jira-proxy/'):
            self._proxy('POST')
        elif self.path == '/starburst-query':
            self._starburst_query()
        else:
            self.send_error(405)

    # ── Starburst / Trino query proxy ────────────────────────────
    def _starburst_query(self):
        length  = int(self.headers.get('Content-Length', 0))
        payload = json.loads(self.rfile.read(length)) if length else {}

        host     = payload.get('host', '').strip()
        sql      = payload.get('sql', '').strip()
        catalog  = payload.get('catalog', '').strip()
        schema   = payload.get('schema', '').strip()
        username = payload.get('username', 'tally').strip()
        token    = payload.get('token', '').strip()

        if not host or not sql:
            self._json_error(400, 'host and sql are required')
            return

        headers = {
            'X-Trino-User':    username or 'tally',
            'X-Trino-Catalog': catalog,
            'X-Trino-Schema':  schema,
            'Content-Type':    'application/json',
            'Accept':          'application/json',
        }
        if token:
            headers['Authorization'] = f'Bearer {token}'

        protocol = 'https' if not host.startswith('http') else ''
        base_url = f'{protocol}{"://" if protocol else ""}{host}' if protocol else host

        print(f'  [Starburst] {host} → {sql[:120]}')

        try:
            req = urllib.request.Request(
                f'{base_url}/v1/statement',
                data=sql.encode(), method='POST',
                headers=headers
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                result = json.loads(r.read())

            cols, rows = [], []
            for _ in range(120):
                if result.get('columns') and not cols:
                    cols = [c['name'] for c in result['columns']]
                for row in result.get('data') or []:
                    rows.append(dict(zip(cols, row)))
                next_uri = result.get('nextUri')
                if not next_uri:
                    break
                time.sleep(0.5)
                req = urllib.request.Request(next_uri, headers=headers)
                with urllib.request.urlopen(req, timeout=30) as r:
                    result = json.loads(r.read())

            error = result.get('error')
            if error:
                self._json_error(400, error.get('message') or 'Starburst error')
                return

            self._relay(200, json.dumps({'cols': cols, 'rows': rows}).encode())

        except urllib.error.HTTPError as e:
            body = e.read()
            try:
                msg = json.loads(body).get('error', {}).get('message', f'HTTP {e.code}')
            except Exception:
                msg = f'HTTP {e.code}'
            self._json_error(e.code, msg)
        except Exception as e:
            self._json_error(502, str(e))

    # ── Jira proxy ───────────────────────────────────────────────
    def _proxy(self, method):
        jira_path = self.path[len('/jira-proxy/'):]
        domain    = self.headers.get('X-Jira-Domain', '').strip()
        auth      = self.headers.get('X-Jira-Auth',   '').strip()

        if not domain:
            self._json_error(400, 'X-Jira-Domain header missing')
            return

        url  = f'https://{domain}/{jira_path}'
        body = None
        if method == 'POST':
            length = int(self.headers.get('Content-Length', 0))
            body   = self.rfile.read(length) if length else None

        req = urllib.request.Request(url, data=body, method=method)
        req.add_header('Authorization', auth)
        req.add_header('Content-Type',  'application/json')
        req.add_header('Accept',        'application/json')

        try:
            with urllib.request.urlopen(req) as resp:
                self._relay(resp.status, resp.read())
        except urllib.error.HTTPError as e:
            self._relay(e.code, e.read())
        except Exception as e:
            self._json_error(502, str(e))

    # ── Helpers ──────────────────────────────────────────────────
    def _relay(self, status, body):
        self._cors(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(body)

    def _json_error(self, status, msg):
        self._cors(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'error': msg}).encode())

    def _cors(self, status):
        self.send_response(status)
        self.send_header('Access-Control-Allow-Origin',  '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers',
                         'Content-Type, Authorization, X-Jira-Domain, X-Jira-Auth')

    def log_message(self, fmt, *args):
        print(f'  {self.address_string()} -- {fmt % args}')


if __name__ == '__main__':
    prod = '--prod' in sys.argv
    port = 80 if prod else 9000
    server = HTTPServer(('', port), TallyHandler)
    print(f'\n  Tally — The Controls App')
    print(f'  Running at http://0.0.0.0:{port}')
    print(f'  Mode: {"Production (GCP VM)" if prod else "Development"}\n')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n  Server stopped.')
