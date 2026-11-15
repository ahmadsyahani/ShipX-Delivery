"""Integration checks against the prepared local Valhalla service."""
import json
import unittest
import urllib.error
import urllib.request


class RoutingServerTest(unittest.TestCase):
    def post(self, path, body):
        request = urllib.request.Request('http://127.0.0.1:8002' + path,
                                         data=json.dumps(body).encode(),
                                         headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.load(response)

    def test_matrix_reaches_depot_in_both_directions(self):
        # This depot endpoint failed in CostMatrix while the route API succeeded.
        points = [{'lat': -7.2771739, 'lon': 112.7921963},
                  {'lat': -7.282, 'lon': 112.760},
                  {'lat': -7.264, 'lon': 112.810}]
        for mode in ['motorcycle', 'auto']:
            with self.subTest(mode=mode):
                result = self.post('/matrix', {'costing': mode, 'sources': points, 'targets': points})
                for index, row in enumerate(result['sources_to_targets']):
                    for target, cell in enumerate(row):
                        self.assertIsNotNone(cell['time'])
                        self.assertGreaterEqual(cell['time'], 0)
                        if index == target:
                            self.assertEqual(0, cell['time'])

    def test_outside_area_remains_rejected(self):
        points = [{'lat': 0, 'lon': 0}, {'lat': -7.2771739, 'lon': 112.7921963}]
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.post('/matrix', {'costing': 'motorcycle', 'sources': points, 'targets': points})
        self.assertEqual(422, error.exception.code)


if __name__ == '__main__':
    unittest.main()
