#!/usr/bin/env python3
"""Pack approved F artwork into runtime atlases (offline Pillow + NumPy).

Original RGBA drawings stay unchanged. Source and output must differ.
See doc/art/f_restyle.md for design, mapping and validation contracts.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from clean_mouse_frames import components

MICE = ['gray', 'runner', 'lid', 'gnawer', 'drummer', 'flour', 'elite', 'boss']


def subjects(path, columns, rows):
    image = Image.open(path).convert('RGBA')
    rgba = np.array(image)
    h, w = rgba.shape[:2]
    if np.all(rgba[:, :, 3] == 255):
        raise ValueError(f'{path}: missing genuine transparency')
    groups = [[] for _ in range(columns * rows)]
    # Work over the whole source, so tails crossing nominal cells are retained.
    for part in components(rgba[:, :, 3] > 8):
        if len(part) < 20:
            continue
        col = min(columns - 1, int(np.median(part % w) * columns / w))
        row = min(rows - 1, int(np.median(part // w) * rows / h))
        groups[row * columns + col].append(part)
    result = []
    boxes = []
    for index, group in enumerate(groups):
        major = [p for p in group if len(p) >= 1000]
        if len(major) != 1:
            raise ValueError(f'{path}: cell {index} has {len(major)} main subjects')
        mask = np.zeros(w * h, dtype=np.uint8)
        for part in group:
            mask[part] = 255
        # Restore original antialias fringe; never key out white food/eyes/hats.
        mask = Image.fromarray(mask.reshape(h, w)).filter(ImageFilter.MaxFilter(5))
        isolated = Image.new('RGBA', image.size)
        isolated.paste(image, (0, 0), mask)
        box = isolated.getbbox()
        boxes.append(box)
        result.append(isolated.crop(box))
    return result, {'source_size': [w, h], 'source_bounds': boxes}


def pack(items, columns, rows, cell=(256, 256), baseline=220, pad=16):
    scale = min(1.0, *[(cell[0] - pad * 2) / im.width for im in items],
                *[(baseline - pad) / im.height for im in items])
    atlas = Image.new('RGBA', (columns * cell[0], rows * cell[1]))
    for i, im in enumerate(items):
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        # Premultiplied resampling prevents hidden background RGB from bleeding.
        resized = im.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        xy = (i % columns * cell[0] + (cell[0] - size[0]) // 2,
              i // columns * cell[1] + baseline - size[1])
        atlas.paste(resized, xy)
    data = np.array(atlas)
    data[data[:, :, 3] == 0] = 0
    atlas = Image.fromarray(data)
    bounds = []
    for i in range(columns * rows):
        tile = atlas.crop((i % columns * cell[0], i // columns * cell[1],
                           (i % columns + 1) * cell[0], (i // columns + 1) * cell[1]))
        box = tile.getbbox()
        if not box or min(box[:2]) < pad or box[2] > cell[0] - pad or box[3] > baseline:
            raise ValueError(f'Unsafe cell {i}: {box}')
        bounds.append(box)
    return atlas, {'uniform_scale': scale, 'cell': cell, 'baseline': baseline, 'bounds': bounds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error('Source and output must differ')
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'mouse_frames').mkdir(exist_ok=True)
    (args.output / 'food_frames').mkdir(exist_ok=True)
    report = {}
    bun, source_info = subjects(args.source / 'bun.png', 6, 6)
    atlas, layout = pack(bun, 6, 6)
    atlas.save(args.output / 'food_frames/bun.png')
    report['bun'] = source_info | layout
    portraits = []
    for name in MICE:
        rows = 6 if name == 'gray' else 4
        frames, source_info = subjects(args.source / f'{name}.png', 6, rows)
        if name == 'gray':
            frames = [frames[row * 6 + col] for row in [2, 3, 4, 5] for col in range(6)]
        atlas, layout = pack(frames, 6, 4)
        atlas.save(args.output / f'mouse_frames/{name}.png')
        report[name] = source_info | layout
        portraits.append(frames[11])
    atlas, layout = pack(portraits, 4, 2, (384, 512), 440)
    atlas.save(args.output / 'mice.png')
    report['mice'] = layout
    foods, source_info = subjects(args.source / 'foods.png', 4, 2)
    # Same drawing as the animated bun, so its card and battlefield agree.
    foods[0] = bun[0]
    # Bun source is lower resolution; scale only its portrait to the atlas norm.
    target_width = np.median([im.width for im in foods[1:]])
    ratio = target_width / foods[0].width
    foods[0] = foods[0].convert('RGBa').resize(
        (round(foods[0].width * ratio), round(foods[0].height * ratio)),
        Image.Resampling.LANCZOS).convert('RGBA')
    atlas, layout = pack(foods, 4, 2, (384, 512), 440)
    atlas.save(args.output / 'foods.png')
    report['foods'] = source_info | layout
    (args.output / 'packing_report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Packed eight foods, eight mouse portraits, 192 mouse frames and 36 bun frames')


if __name__ == '__main__':
    main()
