"""Loopback-only routing service for the local ShipX demo."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
import threading

from valhalla import Actor

WORK = Path(__file__).resolve().parents[2] / 'backend' / 'work' / 'routing-demo'
AREA = json.loads((WORK / 'ready.json').read_text(encoding='utf-8'))
ACTOR = Actor(str(WORK / 'valhalla.json'))
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, data):
        content = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path != '/health':
            self.reply(404, {'message': 'Not found'})
            return
        self.reply(200, {'provider': 'valhalla-local', 'status': 'ok', 'bbox': AREA['bbox']})

    def do_POST(self):
        if self.path != '/route':
            self.reply(404, {'message': 'Not found'})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 16384:
                raise ValueError('Invalid request size')
            request = json.loads(self.rfile.read(size))
            points = request['locations']
            if len(points) != 2 or request['costing'] not in ('auto', 'motorcycle'):
                raise ValueError('Invalid route')
            south, west, north, east = AREA['bbox']
            for point in points:
                lat, lon = float(point['lat']), float(point['lon'])
                if not (math.isfinite(lat) and math.isfinite(lon) and south <= lat <= north and west <= lon <= east):
                    self.reply(422, {'message': 'Location outside demo area'})
                    return
            request['directions_options'] = {'units': 'kilometers', 'language': 'id-ID'}
            with LOCK:
                result = ACTOR.route(request)
            if isinstance(result, str):
                result = json.loads(result)
            self.reply(200, result)
        except (ValueError, KeyError, TypeError):
            self.reply(400, {'message': 'Invalid request'})
        except RuntimeError:
            self.reply(422, {'message': 'Route not found in demo road graph'})

    def log_message(self, format, *args):
        # Coordinates are only used for the current request.
        print(f'{self.command} {self.path}', flush=True)


if __name__ == '__main__':
    print('ShipX local routing listening on 127.0.0.1:8002', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8002), Handler).serve_forever()
