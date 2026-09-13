#!/usr/bin/env python3
"""Remove baked checkerboards and pack articulated frames; Pillow + NumPy.

Source must be the original RGB imagegen sheets in a different directory.
No runtime dependencies. See doc/art/animation.md for the packing contract.
"""
import argparse
from collections import deque
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

IDS = ['gray', 'runner', 'lid', 'gnawer', 'drummer', 'flour', 'elite', 'boss']
SIZE, PAD, BASELINE = 256, 12, 220


def components(mask):
    h, w = mask.shape
    remaining = bytearray(mask.astype(np.uint8).tobytes())
    for start in range(w*h):
        if not remaining[start]: continue
        remaining[start] = 0
        queue = deque([start])
        pixels = []
        while queue:
            p = queue.popleft()
            pixels.append(p)
            y, x = divmod(p, w)
            for n in ((p-1 if x else -1), (p+1 if x+1<w else -1),
                      (p-w if y else -1), (p+w if y+1<h else -1)):
                if n >= 0 and remaining[n]:
                    remaining[n] = 0
                    queue.append(n)
        yield np.array(pixels, dtype=np.int32)


def clean(source, destination):
    im = Image.open(source)
    if im.mode != 'RGB': raise ValueError('Use original RGB generation, not cleaned RGBA')
    if im.size != (1536, 1024): raise ValueError('Expected 1536x1024')
    rgb = np.array(im).astype(np.int16)
    lo, hi = rgb.min(2), rgb.max(2)
    neutral = (hi-lo <= 24) & (lo >= 155)
    # The dark ink contour protects light fur, eye whites and chef clothing.
    # Background includes enclosed checker regions between hands/tail/props.
    bg = np.zeros(neutral.size, dtype=bool)
    for comp in components(neutral):
        values = lo.ravel()[comp]
        edge = np.any(comp < 1536) or np.any(comp >= 1536*1023) or np.any(comp % 1536 == 0) or np.any(comp % 1536 == 1535)
        if edge or (len(comp) >= 200 and np.std(values) > 13):
            bg[comp] = True
    fg = ~bg.reshape(neutral.shape)
    parts = [[] for _ in range(24)]
    for comp in components(fg):
        if len(comp) < 22: continue
        yy, xx = comp//1536, comp%1536
        owner = min(3, int(np.median(yy)//256))*6 + min(5, int(np.median(xx)//256))
        parts[owner].append(comp)
    subjects=[]
    boxes=[]
    for index, group in enumerate(parts):
        if not group: raise ValueError(f'Empty frame {index}')
        major = [p for p in group if len(p)>3000]
        if not major: raise ValueError(f'{source.stem} frame {index}: missing body')
        mask=np.zeros(1536*1024,dtype=np.uint8)
        for p in group: mask[p]=255
        mask=Image.fromarray(mask.reshape(1024,1536))
        # Slightly soften the hard key at the outside only, keeping ink outlines.
        mask=mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
        rgba=im.convert('RGBA');rgba.putalpha(mask)
        box=rgba.getbbox()
        boxes.append(box)
        subjects.append(rgba.crop(box))
    scale=min(1.0, *[(SIZE-2*PAD)/s.width for s in subjects],
              *[(BASELINE-PAD)/s.height for s in subjects])
    out=Image.new('RGBA', im.size)
    bounds=[]
    for index, subject in enumerate(subjects):
        size=(round(subject.width*scale),round(subject.height*scale))
        subject=subject.convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA')
        x=(SIZE-size[0])//2
        y=BASELINE-size[1]
        col,row=index%6,index//6
        out.paste(subject,(col*SIZE+x,row*SIZE+y))
        bounds.append([x,y,x+size[0],BASELINE])
    out.save(destination)
    return {'scale':scale,'source_bounds':boxes,'frame_bounds':bounds}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.source.resolve()==args.output.resolve(): parser.error('Separate source/output required')
    args.output.mkdir(parents=True,exist_ok=True)
    report={id:clean(args.source/f'{id}.png',args.output/f'{id}.png') for id in IDS}
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
