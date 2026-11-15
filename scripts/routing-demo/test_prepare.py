"""Regression checks for depot-sized, versioned routing graphs."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('routing_prepare', Path(__file__).with_name('prepare.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PrepareTest(unittest.TestCase):
    def test_new_area_keeps_legacy_graph_and_uses_separate_directory(self):
        old_bbox = [-7.32, 112.75, -7.23, 112.84]
        new_bbox = [-7.394, 112.674, -7.160, 112.910]
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / 'area.json').write_text(json.dumps({'bbox': old_bbox}))
            with patch.object(prepare, 'WORK', work):
                self.assertEqual(work, prepare.graph_directory(old_bbox))
                target = prepare.graph_directory(new_bbox)
                self.assertEqual(work / 'datasets', target.parent)
                self.assertEqual(target, prepare.graph_directory(new_bbox))
                self.assertEqual(old_bbox, json.loads((work / 'area.json').read_text())['bbox'])

    def test_depot_area_covers_ten_kilometre_radius_with_extra_roads(self):
        result = type('Result', (), {'stdout': json.dumps({
            'latitude': -7.2771739, 'longitude': 112.7921963, 'service_radius_m': 10000,
        })})()
        with patch.object(prepare.subprocess, 'run', return_value=result):
            south, west, north, east = prepare.depot_bbox()
        self.assertLess(south, -7.2771739 - 10000 / 111320)
        self.assertGreater(north, -7.2771739 + 10000 / 111320)
        self.assertLess(west, 112.7921963 - 0.091)
        self.assertGreater(east, 112.7921963 + 0.091)
        self.assertLess((north - south) * (east - west), 0.15)

    def test_unconfigured_depot_does_not_build_an_area(self):
        result = type('Result', (), {'stdout': json.dumps({
            'latitude': None, 'longitude': None, 'service_radius_m': 10000,
        })})()
        with patch.object(prepare.subprocess, 'run', return_value=result):
            with self.assertRaisesRegex(RuntimeError, 'Configure the depot'):
                prepare.depot_bbox()


if __name__ == '__main__':
    unittest.main()
