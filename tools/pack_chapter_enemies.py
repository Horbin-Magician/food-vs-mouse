#!/usr/bin/env python3
"""Pack generated chapter enemies using the established F sprite pipeline.

Requires explicit permission to perform offline image processing. Original
imagegen outputs are never modified. Drawings and poses are not synthesized:
every output frame is a source connected silhouette, uniformly scaled, placed
at y=220, and given a transparent gutter. See doc/art/chapter_enemy_assets.md.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pack_f_art import subjects


def pack_at_scale(frames, rows, scale):
    """Keep one scale per sheet, with neutral width shared across its variants."""
    atlas = Image.new('RGBA', (1536, rows * 256))
    bounds = []
    for index, frame in enumerate(frames):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        sprite = frame.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        x, y = (256 - size[0]) // 2, 220 - size[1]
        atlas.paste(sprite, (index % 6 * 256 + x, index // 6 * 256 + y))
        local = sprite.getbbox()
        box = (local[0] + x, local[1] + y, local[2] + x, local[3] + y)
        if min(box[:2]) < 16 or box[2] > 240 or box[3] > 220:
            raise ValueError(f'Unsafe cell {index}: {box}')
        bounds.append(box)
    data = np.array(atlas)
    data[data[:, :, 3] == 0] = 0
    return Image.fromarray(data), {'uniform_scale': scale, 'cell': [256, 256],
                                    'baseline': 220, 'bounds': bounds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('assets/art/source/chapter_enemies'))
    parser.add_argument('--output', type=Path, default=Path('assets/art'))
    parser.add_argument('--ids', nargs='*', help='Optional names; each selects its complete scale group')
    parser.add_argument('--authorized-offline-processing', action='store_true', required=True)
    args = parser.parse_args()
    report_path = args.output / 'chapter_enemy_packing_report.json'
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    sources = sorted(args.source.glob('*.png'))
    prepared = []
    shared_width = {}
    selected_groups = {name.removesuffix('_skill').removesuffix('_unarmored') for name in args.ids or []}
    for source in sources:
        is_skill = source.stem.endswith('_skill')
        rows = 3 if is_skill else 4
        name = source.stem.removesuffix('_skill')
        destination = args.output / ('enemy_skills' if is_skill else 'mouse_frames') / f'{name}.png'
        if source.resolve() == destination.resolve():
            raise ValueError('Source and output must differ')
        frames, source_info = subjects(source, 6, rows)
        group = name.removesuffix('_unarmored')
        neutral_width = frames[0].width
        # Reference frame zero is neutral in every sheet. Match its width across
        # basic, cast and unarmored states, then uniformly shrink the whole group
        # only as much as its widest/tallest actual pose requires for safe gutters.
        target_width = min(224 * neutral_width / frame.width for frame in frames)
        target_width = min(target_width, *(204 * neutral_width / frame.height for frame in frames))
        shared_width[group] = min(shared_width.get(group, 224), target_width)
        prepared.append((source, destination, frames, source_info, rows, group))
    for source, destination, frames, source_info, rows, group in prepared:
        if selected_groups and group not in selected_groups:
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        scale = shared_width[group] / frames[0].width
        atlas, layout = pack_at_scale(frames, rows, scale)
        atlas.save(destination)
        report[source.stem] = source_info | layout | {
            'source': str(source), 'output': str(destination), 'frame_count': len(frames),
            'scale_group': group, 'neutral_reference_width': shared_width[group],
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        }
        print(f'Packed {source.stem}: {len(frames)} distinct source frames')
    report_path.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
