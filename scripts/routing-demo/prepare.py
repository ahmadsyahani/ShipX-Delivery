"""Prepare a project-local Valhalla runtime and a small OSM road extract."""
import argparse
import hashlib
import json
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


def build(bbox):
    import osmium
    import valhalla
    from valhalla import get_config

    box = ','.join(str(value) for value in bbox)
    osm = WORK / 'roads.osm'
    previous = WORK / 'area.json'
    if previous.exists() and json.loads(previous.read_text(encoding='utf-8'))['bbox'] != bbox:
        raise RuntimeError('Area differs from the existing road graph. Use a separate demo folder or keep the current area.')
    query = f'[out:xml][timeout:120];(way["highway"]({box});relation["type"="restriction"]({box}););(._;>;);out meta;'
    download('https://overpass-api.de/api/interpreter', osm,
             data=urllib.parse.urlencode({'data': query}).encode(), force=not previous.exists())
    content = osm.read_bytes()
    if b'<osm' not in content[:1000] or b'<remark>' in content:
        raise RuntimeError('The OSM response is invalid')
    previous.write_text(json.dumps({'bbox': bbox, 'source': 'OpenStreetMap / Overpass API'}), encoding='utf-8')
    pbf = WORK / 'roads.osm.pbf'
    if not pbf.exists():
        print('Converting road extract', flush=True)
        staging = WORK / 'roads.staging.osm.pbf'
        ways = 0
        with osmium.SimpleWriter(str(staging), overwrite=True) as writer:
            for item in osmium.FileProcessor(str(osm)):
                writer.add(item)
                if isinstance(item, osmium.osm.Way):
                    ways += 1
        if not ways:
            raise RuntimeError('The downloaded road extract is empty')
        staging.replace(pbf)
    tiles = WORK / 'tiles'
    tiles.mkdir(exist_ok=True)
    config = get_config(tile_dir=str(tiles), tile_extract='')
    config['mjolnir']['concurrency'] = 2
    config['mjolnir']['admin'] = str(WORK / 'admins.sqlite')
    config['mjolnir']['timezone'] = str(WORK / 'timezones.sqlite')
    config['mjolnir'].setdefault('logging', {})['type'] = 'std_out'
    config_path = WORK / 'valhalla.json'
    config_path.write_text(json.dumps(config, indent=2), encoding='utf-8')
    ready = WORK / 'ready.json'
    if not ready.exists():
        package = Path(valhalla.__file__).parent
        builder = package / 'bin' / ('valhalla_build_tiles.exe' if sys.platform == 'win32' else 'valhalla_build_tiles')
        build_environment = dict(os.environ)
        build_environment['PATH'] = str(package.parent / 'pyvalhalla.libs') + os.pathsep + os.environ.get('PATH', '')
        subprocess.run([str(builder), '-c', str(config_path), str(pbf)],
                       cwd=WORK, env=build_environment, check=True)
        ready.write_text(json.dumps({'bbox': bbox, 'provider': 'valhalla-3.9.1'}), encoding='utf-8')
    previous.write_text(json.dumps({'bbox': bbox, 'source': 'OpenStreetMap / Overpass API'}), encoding='utf-8')
    print(f'Routing graph ready in {WORK}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bbox', nargs=4, type=float, default=[-7.32, 112.75, -7.23, 112.84],
                        metavar=('SOUTH', 'WEST', 'NORTH', 'EAST'))
    parser.add_argument('--build', action='store_true')
    args = parser.parse_args()
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
