#!/usr/bin/env python3
"""Print a public/reference Gen III map layout's metatile IDs with coordinates.

This diagnostic is intentionally local-only. It reads no player-provided ROM and
writes no image assets. Its job is to inspect known layout block-data references
while authoring semantic profile metadata.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--x0", type=int, default=0)
    parser.add_argument("--y0", type=int, default=0)
    parser.add_argument("--x1", type=int)
    parser.add_argument("--y1", type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    raw = args.layout.read_bytes()
    expected = args.width * args.height * 2
    if len(raw) != expected:
        raise SystemExit(
            f"{args.layout}: {len(raw)} bytes, expected {expected} for "
            f"{args.width}x{args.height} u16 layout"
        )
    cells = [int.from_bytes(raw[offset : offset + 2], "little") for offset in range(0, len(raw), 2)]
    x1 = args.x1 if args.x1 is not None else args.width
    y1 = args.y1 if args.y1 is not None else args.height
    if not (0 <= args.x0 <= x1 <= args.width and 0 <= args.y0 <= y1 <= args.height):
        raise SystemExit("requested region is outside the layout")

    print(f"layout={args.layout} size={args.width}x{args.height} region={args.x0},{args.y0}..{x1 - 1},{y1 - 1}")
    print("     " + " ".join(f"{x:04X}" for x in range(args.x0, x1)))
    for y in range(args.y0, y1):
        values = []
        for x in range(args.x0, x1):
            raw_id = cells[y * args.width + x]
            metatile = raw_id & 0x03FF
            tileset = "P" if metatile < 640 else "S"
            values.append(f"{tileset}{metatile:03X}")
        print(f"{y:04X} " + " ".join(values))


if __name__ == "__main__":
    main()
