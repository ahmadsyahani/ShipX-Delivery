"""Prepare a project-local Valhalla runtime and a small OSM road extract."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'backend' / 'work' / 'routing-demo'
PYTHON = WORK / 'python' / 'python.exe'
PYTHON_URL = 'https://www.python.org/ftp/python/3.14.10/python-3.14.10-embed-amd64.zip'
PYTHON_SHA256 = '90905e64a840557d8c1bc4f5b74db3d7ee85e3ffb217611cac1c7813acea4159'


def download(url, path, checksum=None, data=None, force=False):
    if not force and path.exists() and (not checksum or hashlib.sha256(path.read_bytes()).hexdigest() == checksum):
        return
    request = urllib.request.Request(url, data=data, headers={'User-Agent': 'ShipX-local-routing-demo/1.0'})
    print(f'Downloading {path.name}', flush=True)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                content = response.read()
            break
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            print('Download interrupted, retrying shortly', flush=True)
            time.sleep(5 * (attempt + 1))
    if checksum and hashlib.sha256(content).hexdigest() != checksum:
        raise RuntimeError(f'Checksum mismatch for {path.name}')
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_bytes(content)
    temporary.replace(path)


def bootstrap():
    WORK.mkdir(parents=True, exist_ok=True)
    if not PYTHON.exists():
        archive = WORK / 'python.zip'
        download(PYTHON_URL, archive, PYTHON_SHA256)
        with zipfile.ZipFile(archive) as source:
            source.extractall(PYTHON.parent)
        (PYTHON.parent / 'python314._pth').write_text(
            'python314.zip\n.\nLib/site-packages\nimport site\n', encoding='utf-8')
    site = PYTHON.parent / 'Lib' / 'site-packages'
    site.mkdir(parents=True, exist_ok=True)
    if not (site / 'pip').exists():
        with urllib.request.urlopen('https://pypi.org/pypi/pip/25.3/json', timeout=30) as response:
            metadata = json.load(response)
        wheel = next(item for item in metadata['urls'] if item['filename'].endswith('.whl'))
        archive = WORK / wheel['filename']
        download(wheel['url'], archive, wheel['digests']['sha256'])
        with zipfile.ZipFile(archive) as source:
            source.extractall(site)
    subprocess.run([str(PYTHON), '-m', 'pip', 'install', '--disable-pip-version-check',
                    '--only-binary=:all:', 'pyvalhalla==3.9.1', 'osmium==4.3.2'], check=True)


def depot_bbox():
    code = '''require "backend/vendor/autoload.php";
$app = require "backend/bootstrap/app.php";
$app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
echo json_encode(App\\Models\\Depot::findOrFail(1)->only(["latitude", "longitude", "service_radius_m"]));'''
    result = subprocess.run(['php', '-r', code], cwd=ROOT, check=True, capture_output=True, text=True)
    depot = json.loads(result.stdout)
    if depot['latitude'] is None or depot['longitude'] is None or not depot['service_radius_m']:
        raise RuntimeError('Configure the depot location and delivery radius first.')
    latitude, longitude = float(depot['latitude']), float(depot['longitude'])
    # Keep extra roads around the delivery circle for detours and edge snapping.
    latitude_delta = (float(depot['service_radius_m']) + 3000) / 111320
    longitude_delta = latitude_delta / max(0.01, math.cos(math.radians(latitude)))
    return [math.floor((latitude - latitude_delta) * 1000) / 1000,
            math.floor((longitude - longitude_delta) * 1000) / 1000,
            math.ceil((latitude + latitude_delta) * 1000) / 1000,
            math.ceil((longitude + longitude_delta) * 1000) / 1000]


def graph_directory(bbox):
    legacy = WORK / 'area.json'
    if legacy.exists() and json.loads(legacy.read_text(encoding='utf-8'))['bbox'] == bbox:
        return WORK
    version = hashlib.sha256(json.dumps(bbox).encode()).hexdigest()[:16]
    return WORK / 'datasets' / version


def build(bbox):
    import osmium
    import valhalla
    from valhalla import get_config

    graph = graph_directory(bbox)
    graph.mkdir(parents=True, exist_ok=True)
    box = ','.join(str(value) for value in bbox)
    osm = graph / 'roads.osm'
    previous = graph / 'area.json'
    query = f'[out:xml][timeout:120];(way["highway"]({box});relation["type"="restriction"]({box}););(._;>;);out meta;'
    download('https://overpass-api.de/api/interpreter', osm,
             data=urllib.parse.urlencode({'data': query}).encode(), force=not previous.exists())
    content = osm.read_bytes()
    if b'<osm' not in content[:1000] or b'<remark>' in content:
        raise RuntimeError('The OSM response is invalid')
    previous.write_text(json.dumps({'bbox': bbox, 'source': 'OpenStreetMap / Overpass API'}), encoding='utf-8')
    pbf = graph / 'roads.osm.pbf'
    if not pbf.exists():
        print('Converting road extract', flush=True)
        staging = graph / 'roads.staging.osm.pbf'
        ways = 0
        with osmium.SimpleWriter(str(staging), overwrite=True) as writer:
            for item in osmium.FileProcessor(str(osm)):
                writer.add(item)
                if isinstance(item, osmium.osm.Way):
                    ways += 1
        if not ways:
            raise RuntimeError('The downloaded road extract is empty')
        staging.replace(pbf)
    tiles = graph / 'tiles'
    tiles.mkdir(exist_ok=True)
    config = get_config(tile_dir=str(tiles), tile_extract='')
    config['mjolnir']['concurrency'] = 2
    config['thor']['costmatrix']['allow_second_pass'] = True
    config['mjolnir']['admin'] = str(graph / 'admins.sqlite')
    config['mjolnir']['timezone'] = str(graph / 'timezones.sqlite')
    config['mjolnir'].setdefault('logging', {})['type'] = 'std_out'
    config_path = graph / 'valhalla.json'
    config_path.write_text(json.dumps(config, indent=2), encoding='utf-8')
    ready = graph / 'ready.json'
    if not ready.exists():
        package = Path(valhalla.__file__).parent
        builder = package / 'bin' / ('valhalla_build_tiles.exe' if sys.platform == 'win32' else 'valhalla_build_tiles')
        build_environment = dict(os.environ)
        build_environment['PATH'] = str(package.parent / 'pyvalhalla.libs') + os.pathsep + os.environ.get('PATH', '')
        subprocess.run([str(builder), '-c', str(config_path), str(pbf)],
                       cwd=graph, env=build_environment, check=True)
        ready.write_text(json.dumps({'bbox': bbox, 'provider': 'valhalla-3.9.1'}), encoding='utf-8')
    previous.write_text(json.dumps({'bbox': bbox, 'source': 'OpenStreetMap / Overpass API'}), encoding='utf-8')
    # Switch only after a successful build. Existing running graphs remain intact.
    active = WORK / 'active.json'
    temporary = WORK / 'active.json.tmp'
    temporary.write_text(json.dumps({'directory': graph.relative_to(WORK).as_posix()}), encoding='utf-8')
    temporary.replace(active)
    print(f'Routing graph ready in {graph}. Run scripts/routing-demo/start.ps1 to activate it.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bbox', nargs=4, type=float, default=[-7.32, 112.75, -7.23, 112.84],
                        metavar=('SOUTH', 'WEST', 'NORTH', 'EAST'))
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--depot', action='store_true', help='Cover the configured depot radius with a 3 km road buffer')
    args = parser.parse_args()
    if args.depot:
        args.bbox = depot_bbox()
    south, west, north, east = args.bbox
    if not (-90 <= south < north <= 90 and -180 <= west < east <= 180):
        parser.error('Invalid bounding box')
    if (north - south) * (east - west) > 0.15:
        parser.error('Choose a city-sized area for this local demo')
    if args.build:
        build(args.bbox)
    else:
        bootstrap()
        subprocess.run([str(PYTHON), str(Path(__file__).resolve()), '--build', '--bbox',
                        *[str(value) for value in args.bbox]], check=True)
