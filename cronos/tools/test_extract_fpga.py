import importlib.util
import unittest
from pathlib import Path


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


fpga = load('extract-fpga-fw')


class ExtractTests(unittest.TestCase):
    def test_invalid_vendor_image_fails_extraction(self):
        for data in (b'', b'ANDROID!', b'ANDROID!' + bytes(6136)):
            with self.assertRaises(ValueError):
                fpga.extract(data)


if __name__ == '__main__':
    unittest.main()
