#!/usr/bin/env python3
"""Repair the existing RGBA atlases offline; see doc/art/asset_pack.md.

Requires Pillow. Read original PNGs from --source and write to a different
--output directory. Never use a previously cleaned atlas as the source.
"""
import argparse
from collections import deque
import json
from pathlib import Path

from PIL import Image, ImageFilter

SHEETS = {"foods": 2, "mice": 2, "recipes": 3}
CORE_ALPHA = 8
MIN_AREA = 20
FRINGE = 2
PADDING = 16


def split_subjects(image, rows):
    width, height = image.size
    remaining = bytearray(a > CORE_ALPHA for a in image.getchannel("A").tobytes())
    masks = [bytearray(width * height) for _ in range(4 * rows)]
    major_counts = [0] * len(masks)
    kept_counts = [0] * len(masks)
    removed = 0
    for start in range(width * height):
        if not remaining[start]:
            continue
        remaining[start] = 0
        queue = deque([start])
        pixels = []
        left, top, right, bottom = width, height, 0, 0
        while queue:
            point = queue.popleft()
            y, x = divmod(point, width)
            pixels.append(point)
            left, top = min(left, x), min(top, y)
            right, bottom = max(right, x), max(bottom, y)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if remaining[neighbor]:
                        remaining[neighbor] = 0
                        queue.append(neighbor)
        if len(pixels) < MIN_AREA:
            removed += len(pixels)
            continue
        column = int(((left + right) / 2) * 4 / width)
        row = int(((top + bottom) / 2) * rows / height)
        owner = row * 4 + column
        kept_counts[owner] += 1
        major_counts[owner] += len(pixels) >= 10000
        for point in pixels:
            masks[owner][point] = 255
    if major_counts != [1] * len(masks):
        raise ValueError(f"Expected one main subject per cell, got {major_counts}")
    subjects = []
    for data in masks:
        mask = Image.frombytes("L", image.size, bytes(data))
        mask = mask.filter(ImageFilter.MaxFilter(FRINGE * 2 + 1))
        # Binary paste preserves the source alpha, including translucent edges.
        subject = Image.new("RGBA", image.size)
        subject.paste(image, (0, 0), mask)
        bounds = subject.getbbox()
        if bounds is None:
            raise ValueError("Empty subject")
        subjects.append(subject.crop(bounds))
    return subjects, kept_counts, removed


def validate(image, rows):
    width, height = image.size
    if image.mode != "RGBA":
        raise ValueError("Atlas must retain alpha")
    bounds = []
    for row in range(rows):
        top, bottom = round(row * height / rows), round((row + 1) * height / rows)
        for column in range(4):
            cell = image.crop((column * width // 4, top, (column + 1) * width // 4, bottom))
            box = cell.getbbox()
            if box is None:
                raise ValueError("Empty cell")
            left, upper, right, lower = box
            if min(left, upper, cell.width - right, cell.height - lower) < PADDING:
                raise ValueError(f"Insufficient transparent gutter: {box}")
            bounds.append(box)
    return bounds


def clean(path, rows, destination):
    with Image.open(path) as source:
        image = source.copy()
    if image.mode != "RGBA" or image.size != (1536, 1024):
        raise ValueError(f"Unexpected source format: {path}, {image.mode}, {image.size}")
    subjects, counts, removed = split_subjects(image, rows)
    cell_width = image.width // 4
    cell_height = image.height // rows
    scale = min(1.0, *(min((cell_width - 2 * PADDING) / s.width,
                           (cell_height - 2 * PADDING) / s.height) for s in subjects))
    result = Image.new("RGBA", image.size)
    for index, subject in enumerate(subjects):
        size = (int(subject.width * scale), int(subject.height * scale))
        # Resize premultiplied colors to avoid dark/colored transparent fringes.
        subject = subject.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
        row, column = divmod(index, 4)
        top, bottom = round(row * image.height / rows), round((row + 1) * image.height / rows)
        origin = (column * cell_width + (cell_width - subject.width) // 2,
                  top + (bottom - top - subject.height) // 2)
        result.paste(subject, origin)
    bounds = validate(result, rows)
    result.save(destination)
    return {"scale": scale, "components_per_cell": counts,
            "discarded_small_core_pixels": removed, "cell_alpha_bounds": bounds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error("Source and output must be different directories")
    args.output.mkdir(parents=True, exist_ok=True)
    report = {name: clean(args.source / f"{name}.png", rows, args.output / f"{name}.png")
              for name, rows in SHEETS.items()}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
