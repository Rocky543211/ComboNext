"""Verify packaged artwork, reproducibility, and skin contrast without LOTRO."""

import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_skin", ROOT / "build_skin.py")
skin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(skin)


class SkinTests(unittest.TestCase):
    def test_artwork_is_reproducible_and_self_contained(self):
        original_root = skin.ROOT
        try:
            with tempfile.TemporaryDirectory() as temporary:
                skin.ROOT = Path(temporary)
                skin.build()
                expected = {path.name for path in skin.ROOT.glob("*.tga")}
                packaged = {path.name for path in original_root.glob("*.tga")}
                self.assertEqual(expected, packaged)
                self.assertEqual(len(expected), 25)
                for name in expected:
                    with self.subTest(asset=name):
                        data = (original_root / name).read_bytes()
                        self.assertEqual(data, (skin.ROOT / name).read_bytes())
                        header = struct.unpack("<BBBHHBHHHHBB", data[:18])
                        self.assertEqual(header[2], 2)
                        self.assertEqual(header[-2], 24)
                        width, height = header[8:10]
                        self.assertEqual(len(data), 18 + width * height * 3)
                        if name.startswith("header_"):
                            self.assertEqual(width, int(name[7:-4]))
                            self.assertEqual(height, 34)
                        else:
                            self.assertEqual((width, height), (28, 28))
        finally:
            skin.ROOT = original_root

    def test_button_text_contrast(self):
        def luminance(rgb):
            linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
            return sum(value * weight for value, weight in zip(linear, (.2126, .7152, .0722)))

        text = luminance((.94, .91, .83))
        for background in ((.095, .12, .14), (.18, .22, .24), (.10, .13, .15)):
            self.assertGreaterEqual((text + .05) / (luminance(background) + .05), 4.5)
        disabled = luminance((.62, .64, .62))
        self.assertGreaterEqual((disabled + .05) / (luminance((.065, .075, .08)) + .05), 4.5)


if __name__ == "__main__":
    unittest.main()
