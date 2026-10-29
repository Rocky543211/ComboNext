"""Build ComboNext's original decorative TGA skin; standard library only."""

import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent / "Resources"


class Canvas:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = [
            (18 + (x * 7 + y * 11) % 3, 25 + y % 3, 31 + y % 3)
            for y in range(height) for x in range(width)
        ]

    def dot(self, x, y, colour):
        x, y = round(x), round(y)
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y * self.width + x] = colour

    def path(self, points, colour):
        for (x1, y1), (x2, y2) in zip(points, points[1:]):
            steps = max(1, math.ceil(max(abs(x2 - x1), abs(y2 - y1))))
            for step in range(steps + 1):
                t = step / steps
                self.dot(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, colour)

    def save(self, name):
        data = bytes(
            channel
            for y in range(self.height - 1, -1, -1)
            for x in range(self.width)
            for channel in reversed(self.pixels[y * self.width + x])
        )
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                             self.width, self.height, 24, 0)
        ROOT.mkdir(exist_ok=True)
        (ROOT / (name + ".tga")).write_bytes(header + data)

    def png(self, path):
        def chunk(name, data):
            return (struct.pack(">I", len(data)) + name + data
                    + struct.pack(">I", zlib.crc32(name + data)))
        rows = b"".join(
            b"\0" + bytes(channel for pixel in self.pixels[y * self.width:(y + 1) * self.width]
                           for channel in pixel)
            for y in range(self.height)
        )
        Path(path).write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
        )


RACES = {
    "Gondorian": (199, 166, 102), "Man": (209, 176, 112),
    "Elf": (158, 201, 166), "Dwarf": (212, 156, 92),
    "Hobbit": (199, 178, 110), "Beorning": (207, 163, 110),
    "HighElf": (191, 199, 240), "StoutAxe": (219, 140, 92),
    "RiverHobbit": (138, 201, 194),
}
CLASSES = {
    "Beorning": (224, 176, 110), "Brawler": (219, 178, 128),
    "Burglar": (204, 176, 224), "Captain": (224, 204, 125),
    "Champion": (235, 153, 120), "Guardian": (178, 209, 235),
    "Hunter": (166, 212, 138), "LoreMaster": (153, 209, 199),
    "Mariner": (138, 204, 227), "Minstrel": (230, 189, 219),
    "RuneKeeper": (181, 186, 247), "Warden": (217, 186, 130),
}

# Original small line emblems, not copied from the game's artwork.
SHAPES = {
    "Gondorian": [[(14, 24), (14, 5)], [(14, 12), (7, 7), (7, 3)],
                  [(14, 12), (21, 7), (21, 3)], [(14, 19), (4, 13)], [(14, 19), (24, 13)]],
    "Man": [[(5, 5), (23, 5), (22, 16), (14, 25), (6, 16), (5, 5)],
            [(14, 8), (14, 20)], [(9, 14), (19, 14)]],
    "Elf": [[(14, 25), (5, 14), (14, 3), (23, 14), (14, 25)],
            [(14, 23), (14, 5)], [(14, 17), (8, 12)], [(14, 13), (19, 9)]],
    "Dwarf": [[(3, 7), (8, 3), (14, 8), (20, 3), (25, 7), (25, 19),
               (14, 25), (3, 19), (3, 7)], [(7, 12), (14, 18), (21, 12)]],
    "Hobbit": [[(4, 23), (4, 12), (8, 6), (14, 4), (20, 6), (24, 12), (24, 23), (4, 23)],
               [(14, 5), (14, 23)], [(5, 14), (23, 14)]],
    "Beorning": [[(6, 24), (4, 14), (9, 9), (19, 9), (24, 14), (22, 24), (6, 24)],
                 [(5, 8), (4, 3)], [(11, 6), (10, 1)], [(17, 6), (18, 1)], [(23, 8), (24, 3)]],
    "HighElf": [[(14, 25), (4, 16), (14, 6), (24, 16), (14, 25)],
                [(14, 6), (14, 24)], [(10, 3), (18, 3)], [(14, 0), (14, 6)]],
    "StoutAxe": [[(6, 24), (21, 4)], [(8, 3), (20, 9), (25, 18), (15, 14), (8, 3)]],
    "RiverHobbit": [[(2, 20), (8, 16), (14, 20), (20, 16), (26, 20)],
                    [(2, 25), (8, 21), (14, 25), (20, 21), (26, 25)],
                    [(14, 17), (14, 2), (23, 9), (14, 9)]],
    "Brawler": [[(6, 23), (3, 13), (6, 6), (10, 9), (12, 4), (16, 8),
                 (20, 5), (23, 11), (24, 18), (20, 24), (6, 23)]],
    "Burglar": [[(4, 3), (19, 17), (15, 21), (4, 3)], [(12, 19), (22, 10)], [(17, 21), (23, 26)]],
    "Captain": [[(6, 26), (6, 2), (23, 5), (17, 10), (23, 15), (6, 13)]],
    "Champion": [[(4, 3), (24, 25)], [(24, 3), (4, 25)],
                  [(3, 19), (9, 25)], [(19, 25), (25, 19)]],
    "Guardian": [[(4, 4), (24, 4), (23, 17), (14, 25), (5, 17), (4, 4)],
                  [(14, 8), (14, 21)], [(8, 13), (20, 13)]],
    "Hunter": [[(6, 3), (17, 8), (20, 14), (17, 20), (6, 25), (6, 3)],
                [(2, 14), (26, 14), (21, 9)], [(26, 14), (21, 19)]],
    "LoreMaster": [[(2, 6), (10, 4), (14, 8), (18, 4), (26, 6), (26, 23),
                    (18, 21), (14, 25), (10, 21), (2, 23), (2, 6)], [(14, 8), (14, 25)]],
    "Mariner": [[(14, 2), (14, 24)], [(4, 14), (7, 21), (14, 25), (21, 21), (24, 14)],
                 [(8, 10), (20, 10)], [(10, 5), (14, 1), (18, 5), (14, 9), (10, 5)]],
    "Minstrel": [[(3, 3), (7, 22), (14, 26), (21, 22), (25, 3)],
                  [(4, 7), (24, 7)], [(9, 7), (11, 21)], [(14, 7), (14, 23)], [(19, 7), (17, 21)]],
    "RuneKeeper": [[(5, 3), (23, 3), (23, 25), (5, 25), (5, 3)],
                    [(14, 21), (14, 7), (20, 12), (14, 16), (8, 12)]],
    "Warden": [[(18, 1), (14, 8), (18, 11), (22, 8), (18, 1)], [(18, 11), (18, 27)],
                [(3, 9), (11, 9), (11, 21), (7, 25), (3, 21), (3, 9)]],
}


def build():
    assets = []
    for width in (390, 430, 460, 500):
        art = Canvas(width, 34)
        for y in (0, 32):
            art.path([(0, y), (width - 1, y)], (64, 73, 78))
        for x, direction in ((1, 1), (width - 2, -1)):
            art.path([(x, 13), (x + 8 * direction, 4), (x + 31 * direction, 4)], (118, 112, 90))
            art.path([(x, 21), (x + 8 * direction, 29), (x + 31 * direction, 29)], (118, 112, 90))
        for x in range(44, width - 70, 30):
            art.path([(x, 28), (x + 4, 25), (x + 8, 28)], (58, 68, 74))
        art.save("header_" + str(width))
        assets.append(art)
    for kind, palette in (("race", RACES), ("class", CLASSES)):
        for name, colour in palette.items():
            art = Canvas(28, 28)
            for path in SHAPES[name]:
                art.path(path, colour)
            art.save(kind + "_" + name)
            assets.append(art)
    return assets


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="Optional artwork contact sheet PNG")
    args = parser.parse_args()
    assets = build()
    if args.preview:
        sheet = Canvas(500, 220)
        for i, art in enumerate(assets):
            x, y = (0, i * 36) if i < 4 else (8 + ((i - 4) % 12) * 40, 148 + ((i - 4) // 12) * 34)
            for row in range(art.height):
                for col in range(art.width):
                    sheet.dot(x + col, y + row, art.pixels[row * art.width + col])
        sheet.png(args.preview)
