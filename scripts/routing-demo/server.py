"""Loopback-only routing service for the local ShipX demo."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import hashlib
import math
from pathlib import Path
import threading

from valhalla import Actor

WORK = Path(__file__).resolve().parents[2] / 'backend' / 'work' / 'routing-demo'
ACTIVE = WORK / 'active.json'
GRAPH = (WORK / json.loads(ACTIVE.read_text(encoding='utf-8'))['directory']).resolve() if ACTIVE.exists() else WORK
if not GRAPH.is_relative_to(WORK.resolve()):
    raise RuntimeError('Routing graph must stay inside the demo workspace')
AREA = json.loads((GRAPH / 'ready.json').read_text(encoding='utf-8'))
ROAD_HASH = hashlib.sha256((GRAPH / 'roads.osm.pbf').read_bytes()).hexdigest()
SERVER_HASH = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
DATASET = hashlib.sha256((ROAD_HASH + SERVER_HASH).encode()).hexdigest()
CONFIG = json.loads((GRAPH / 'valhalla.json').read_text(encoding='utf-8'))
# Match route searches for endpoints on destination-only roads and semi-islands.
CONFIG['thor']['costmatrix']['allow_second_pass'] = True
ACTOR = Actor(CONFIG)
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
        self.reply(200, {'provider': 'valhalla-local', 'status': 'ok', 'bbox': AREA['bbox'], 'dataset_id': DATASET})

    def do_POST(self):
        if self.path not in ('/route', '/matrix'):
            self.reply(404, {'message': 'Not found'})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 16384:
                raise ValueError('Invalid request size')
            request = json.loads(self.rfile.read(size))
            points = request['sources'] if self.path == '/matrix' else request['locations']
            maximum = 21 if self.path == '/matrix' else 22
            if not 2 <= len(points) <= maximum or request['costing'] not in ('auto', 'motorcycle'):
                raise ValueError('Invalid route')
            if self.path == '/matrix' and request['targets'] != points:
                raise ValueError('Matrix targets must match sources')
            south, west, north, east = AREA['bbox']
            for point in points:
                lat, lon = float(point['lat']), float(point['lon'])
                if not (math.isfinite(lat) and math.isfinite(lon) and south <= lat <= north and west <= lon <= east):
                    self.reply(422, {'message': 'Location outside demo area'})
                    return
            request['directions_options'] = {'units': 'kilometers', 'language': 'id-ID'}
            with LOCK:
                result = ACTOR.matrix(request) if self.path == '/matrix' else ACTOR.route(request)
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
