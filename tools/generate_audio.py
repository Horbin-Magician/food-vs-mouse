#!/usr/bin/env python3
"""Compose the game's original score and kitchen SFX without downloaded samples.

Requires Python 3.10+, NumPy, and an FFmpeg build with the native Vorbis encoder.
Run with --verify to decode and check the checked-in assets without overwriting.
The score, timbres, and event recipes below are authored for food-vs-mouse.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
SR = 44100
SEED = 20260926
TAU = math.tau
SOURCE = "Original composition and procedural synthesis: tools/generate_audio.py"
MUSIC = {
    "menu": {"bpm": 88, "bars": 16, "key": "D major", "title": "打烊后的灯"},
    "shop": {"bpm": 104, "bars": 20, "key": "D major", "title": "小铺叮当"},
    "battle": {"bpm": 112, "bars": 24, "key": "D major", "title": "锅铲进行曲"},
    "elite": {"bpm": 116, "bars": 24, "key": "D minor", "title": "锅盖夜巡"},
    "boss": {"bpm": 124, "bars": 24, "key": "D minor", "title": "鼠大厨的晚宴"},
    "won": {"bpm": 108, "bars": 8, "key": "D major", "title": "守住这一盏灯"},
    "lost": {"bpm": 76, "bars": 8, "key": "B minor", "title": "明晚再开张"},
}
SFX_IDS = [
    "ui_click", "ui_cancel", "ui_error", "place", "remove", "heat_spawn",
    "heat_collect", "bun", "tea", "pepper", "popcorn", "noodles", "garlic",
    "hit", "armor", "bite", "enemy_down", "food_down", "flour", "summon",
    "rage", "danger", "wave_start", "clear", "purchase", "refresh",
    "upgrade_success", "upgrade_fail",
]


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def clock(duration: float) -> np.ndarray:
    return np.arange(max(1, round(duration * SR)), dtype=np.float64) / SR


def edge(signal: np.ndarray, attack: float = 0.003, release: float = 0.025) -> np.ndarray:
    signal = signal.copy()
    a = min(len(signal), max(1, round(attack * SR)))
    r = min(len(signal), max(1, round(release * SR)))
    signal[:a] *= np.sin(np.linspace(0, math.pi / 2, a)) ** 2
    signal[-r:] *= np.cos(np.linspace(0, math.pi / 2, r)) ** 2
    return signal


def noise(duration: float, seed: int, lo: float = 120, hi: float = 6500) -> np.ndarray:
    """Band-limited noise; a stable local seed cannot affect the music's score."""
    n = len(clock(duration))
    data = np.random.default_rng(seed).normal(size=n)
    f = np.fft.rfftfreq(n, 1 / SR)
    shape = (1 - np.exp(-(f / max(1, lo)) ** 4)) * np.exp(-(f / hi) ** 4)
    result = np.fft.irfft(np.fft.rfft(data) * shape, n=n)
    return result / max(0.001, float(np.std(result)))


def voice(kind: str, note: float, duration: float, velocity: float = 1) -> np.ndarray:
    """Damped additive/modal voices, with no rectangular oscillators."""
    t = clock(duration)
    f = hz(note)
    if kind == "mallet":
        y = (np.sin(TAU * f * t) * np.exp(-t / 0.38)
             + 0.28 * np.sin(TAU * f * 2.756 * t) * np.exp(-t / 0.062)
             + 0.075 * np.sin(TAU * f * 5.404 * t) * np.exp(-t / 0.032))
        return edge(y * velocity, 0.003, 0.05)
    if kind == "keys":
        y = np.zeros_like(t)
        for k, a in [(1, 1), (2, 0.34), (3, 0.15), (4, 0.065), (6, 0.018)]:
            y += a * np.sin(TAU * f * k * t + 0.12 * np.exp(-t * 7) * k) * np.exp(-t * (1.8 + k * 0.63))
        y += 0.12 * np.sin(TAU * f * 1.002 * t) * np.exp(-t * 3)
        return edge(y * velocity, 0.009, 0.09)
    if kind == "pluck":
        y = np.zeros_like(t)
        for k in range(1, 8):
            y += (1 / k**1.9) * np.sin(TAU * f * k * t) * np.exp(-t * (3.2 + k * 1.3))
        return edge(y * velocity, 0.004, 0.05)
    if kind == "bass":
        y = (np.sin(TAU * f * t) + 0.22 * np.sin(TAU * f * 2 * t)
             + 0.10 * np.sin(TAU * f * 3 * t)) * np.exp(-t * 2.1)
        return edge(y * velocity, 0.008, 0.05)
    if kind == "pad":
        y = (np.sin(TAU * f * t) + 0.4 * np.sin(TAU * f * 1.002 * t)
             + 0.13 * np.sin(TAU * f * 3 * t))
        return edge(y * velocity, min(0.3, duration / 3), min(0.5, duration / 3))
    if kind == "bell":
        y = sum(a * np.sin(TAU * f * k * t) * np.exp(-t * d)
                for k, a, d in [(1, 1, 5), (2.003, 0.23, 9), (3.99, 0.08, 16)])
        return edge(y * velocity, 0.002, 0.05)
    raise ValueError(kind)


def sweep(start: float, end: float, duration: float, decay: float = 5) -> np.ndarray:
    t = clock(duration)
    f = end + (start - end) * np.exp(-t * 14 / max(0.3, duration))
    phase = TAU * np.cumsum(f) / SR
    return edge(np.sin(phase) * np.exp(-t * decay), 0.002, 0.025)


def drum(kind: str, seed: int = SEED) -> np.ndarray:
    if kind == "kick":
        return sweep(150, 51, 0.24, 17) + noise(0.24, seed, 90, 800) * np.exp(-clock(0.24) * 150) * 0.09
    if kind == "snare":
        t = clock(0.18)
        return edge((0.42 * noise(0.18, seed, 700, 5300) + 0.3 * np.sin(TAU * 184 * t)) * np.exp(-t * 32), 0.003)
    if kind == "shaker":
        t = clock(0.10)
        return edge(noise(0.10, seed, 2800, 7300) * np.exp(-t * 46), 0.004, 0.028)
    if kind == "wood":
        t = clock(0.12)
        y = (np.sin(TAU * 740 * t) + 0.45 * np.sin(TAU * 1183 * t)) * np.exp(-t * 46)
        return edge(y, 0.0015, 0.025)
    if kind == "rim":
        t = clock(0.12)
        y = (np.sin(TAU * 1270 * t) + 0.4 * np.sin(TAU * 1790 * t)) * np.exp(-t * 62)
        return edge(y, 0.0018, 0.025)
    if kind == "tom":
        return sweep(200, 88, 0.25, 15)
    raise ValueError(kind)


class Mix:
    def __init__(self, duration: float, stereo: bool, loop: bool = False):
        self.data = np.zeros((round(duration * SR), 2 if stereo else 1), dtype=np.float64)
        self.loop = loop

    def add(self, sound: np.ndarray, at: float, gain: float = 1, pan: float = 0):
        start = round(at * SR)
        if self.data.shape[1] == 2:
            angle = (pan + 1) * math.pi / 4
            gains = np.array([math.cos(angle), math.sin(angle)]) * gain
        else:
            gains = np.array([gain])
        offset = 0
        while offset < len(sound):
            index = start % len(self.data) if self.loop else start
            if index >= len(self.data):
                break
            size = min(len(sound) - offset, len(self.data) - index)
            self.data[index:index + size] += sound[offset:offset + size, None] * gains
            offset += size
            start += size


# The four-bar kitchen motif is reharmonized and varied across sections.
MAJOR = [
    (38, [62, 66, 69, 73], [78, 81, 83, 81, 78, 76]),
    (35, [62, 66, 69, 71], [74, 78, 81, 78, 76, 74]),
    (31, [62, 66, 67, 71], [71, 74, 78, 74, 71, 69]),
    (33, [61, 64, 66, 69], [73, 76, 78, 76, 73, 69]),
    (35, [62, 66, 69, 71], [78, 76, 74, 71, 74, 78]),
    (28, [59, 62, 66, 67], [76, 78, 79, 78, 76, 74]),
    (33, [61, 64, 67, 69], [73, 74, 76, 79, 78, 73]),
    (38, [62, 66, 69, 71], [74, 78, 76, 74, 69, 73]),
]
MINOR = [
    (38, [62, 65, 69, 72], [77, 81, 82, 81, 77, 76]),
    (34, [62, 65, 69, 70], [74, 77, 81, 77, 76, 74]),
    (31, [62, 65, 67, 70], [70, 74, 77, 74, 70, 69]),
    (33, [61, 64, 67, 69], [73, 76, 77, 76, 73, 69]),
    (29, [60, 65, 69, 72], [77, 76, 74, 72, 74, 77]),
    (36, [60, 64, 67, 70], [76, 77, 79, 77, 76, 74]),
    (34, [62, 65, 69, 70], [77, 74, 70, 74, 77, 76]),
    (33, [61, 64, 67, 69], [73, 76, 77, 76, 73, 69]),
]


def compose(name: str) -> np.ndarray:
    spec = MUSIC[name]
    bars = spec["bars"]
    # Native Vorbis encodes full 64-sample granules. Fit whole musical bars to
    # this grid so its decoder adds no uncomposed padding at the loop point.
    frames = math.ceil(bars * 4 * 60 / spec["bpm"] * SR / 64) * 64
    beat = frames / SR / (bars * 4)
    mix = Mix(bars * 4 * beat, stereo=True, loop=True)
    active = name in ("battle", "elite", "boss")
    dark = name in ("elite", "boss")
    progression = MINOR if dark else MAJOR
    if name == "lost":
        progression = [MAJOR[i] for i in (1, 2, 0, 3, 1, 2, 5, 3)]
    swing = 0.055 if name in ("menu", "shop") else 0.012
    drum_bank = {k: drum(k) for k in ("kick", "snare", "shaker", "wood", "rim", "tom")}
    for bar in range(bars):
        root, chord, melody = progression[bar % 8]
        at = bar * 4 * beat
        # An eight-bar middle section answers the main motif with a lower pluck.
        bridge = 8 <= bar < 16 and bars >= 20
        phrase_end = bar % 4 == 3
        final = bar >= bars - 4
        mellow = name in ("menu", "lost")
        if name == "lost":
            melody = list(reversed(melody))
        key_gain = 0.105 if active else 0.13
        for b, g in [(0, 1), (1.5, 0.75), (3.0, 0.8)]:
            if name == "lost" and b == 1.5:
                continue
            for index, note in enumerate(chord):
                mix.add(voice("keys", note, 1.1, 1), at + (b + index * 0.017) * beat,
                        key_gain * g, (index - 1.5) * 0.12 - 0.25)
        # Quiet pad sustains harmonic warmth while short voices leave attack room.
        if bar % 2 == 0 or name == "lost":
            for index, note in enumerate(chord[:3]):
                mix.add(voice("pad", note - 12, beat * 3.8), at, 0.024,
                        -0.5 + index * 0.5)
        bass_events = [(0, root), (1.5, root + 7), (2.5, root + 12), (3.5, root + 7)]
        if mellow:
            bass_events = [(0, root), (2.0, root + 7)]
        if name == "boss":
            bass_events += [(0.75, root), (2.0, root)]
        for b, note in bass_events:
            mix.add(voice("bass", note, beat * 0.9), at + b * beat, 0.22 if active else 0.19)
        # A recognizable syncopated six-note phrase, with breathing room every 4th bar.
        starts = [0, 0.75, 1.25, 2, 2.75, 3.5]
        if name == "shop":
            starts = [0.25, 0.75, 1.5, 2, 2.5, 3.25]
        if name == "lost":
            starts = [0, 1, 1.5, 2.5, 3, 3.5]
        for j, (b, note) in enumerate(zip(starts, melody)):
            if phrase_end and j >= 4:
                continue
            if name == "menu" and bar % 8 >= 4 and j in (1, 4):
                continue
            if name == "lost" and j in (1, 4):
                continue
            tone = "pluck" if bridge else "mallet"
            if name == "lost":
                tone = "keys"
            pitch = note - (12 if bridge or name == "lost" else 0)
            if name == "won" and bar < 2:
                pitch += 0 if j < 3 else 12
            delay = swing if b % 1 == 0.5 else 0
            mix.add(voice(tone, pitch, 0.75), at + (b + delay) * beat,
                    (0.19 if active else 0.22) * (0.87 if j % 2 else 1), 0.16)
        # Soft answering pizzicato changes after the opening phrase.
        if bar % 4 in (1, 3) or final or name == "boss":
            for j, b in enumerate([2.25, 2.75, 3.25, 3.75]):
                note = chord[(j + bar) % 4] + (12 if bridge else 0)
                mix.add(voice("pluck", note, 0.36), at + b * beat,
                        0.09 if active else 0.07, -0.45)
        if name == "lost":
            if bar % 2 == 0:
                mix.add(drum_bank["wood"], at + 2 * beat, 0.04, -0.4)
            continue
        kick_beats = [0, 2.0] if not active else [0, 1.75, 2.5]
        if name == "boss":
            kick_beats = [0, 1.5, 2, 3.25]
        for b in kick_beats:
            mix.add(drum_bank["kick"], at + b * beat, 0.23 if active else 0.15)
        for b in [1, 3]:
            mix.add(drum_bank["snare" if active else "wood"], at + b * beat,
                    0.15 if active else 0.085, -0.12)
            if active:
                mix.add(drum_bank["rim"], at + b * beat, 0.05, 0.25)
        for j in range(8):
            if name == "menu" and j % 2 == 0:
                continue
            mix.add(drum_bank["shaker"], at + (j * 0.5 + (swing if j % 2 else 0)) * beat,
                    (0.026 if j % 2 else 0.04) * (0.8 if bridge else 1), 0.50)
        if phrase_end:
            # Small kitchen fill; less activity in the breathing middle section.
            for j, b in enumerate([3, 3.5, 3.75]):
                mix.add(drum_bank["tom" if active else "wood"], at + b * beat,
                        0.12 if active else 0.055, -0.3 + j * 0.3)
        if name == "won" and bar in (0, 4):
            for j, note in enumerate([74, 78, 81, 86]):
                mix.add(voice("bell", note, 1), at + j * 0.25 * beat, 0.12, -0.3 + j * 0.2)
    # A compact room folded around the loop retains its tail at the seam.
    dry = mix.data.copy()
    for delay, gain, flip in [(0.061, 0.075, True), (0.103, 0.055, False),
                              (0.173, 0.035, True), (0.257, 0.021, False)]:
        reflected = dry[:, ::-1] if flip else dry
        mix.data += np.roll(reflected, round(delay * SR), axis=0) * gain
    mix.data -= np.mean(mix.data, axis=0)
    return normalize(np.tanh(mix.data * 0.8), -6.8)


def normalize(data: np.ndarray, peak_db: float) -> np.ndarray:
    peak = float(np.max(np.abs(data)))
    return data * (10 ** (peak_db / 20) / max(peak, 1e-9))


def make_sfx(name: str) -> np.ndarray:
    durations = {"ui_click": .13, "ui_cancel": .22, "ui_error": .28,
                 "place": .32, "remove": .30, "heat_spawn": .42, "heat_collect": .44,
                 "bun": .22, "tea": .38, "pepper": .24, "popcorn": .30,
                 "noodles": .30, "garlic": .24, "hit": .15, "armor": .38,
                 "bite": .19, "enemy_down": .32, "food_down": .44, "flour": .52,
                 "summon": .78, "rage": .85, "danger": .70, "wave_start": .85,
                 "clear": 1.05, "purchase": .58, "refresh": .40,
                 "upgrade_success": 1.45, "upgrade_fail": .74}
    mix = Mix(durations[name], stereo=False)
    seed = SEED + SFX_IDS.index(name) * 101

    def put(sound, at=0, gain=1):
        mix.add(sound, at, gain)

    def pitched(kind, notes, step=.09, gain=.6, length=.5):
        for i, note in enumerate(notes):
            put(voice(kind, note, length), i * step, gain)

    if name == "ui_click":
        put(voice("mallet", 83, .13), gain=.8)
        put(drum("wood"), gain=.15)
    elif name == "ui_cancel":
        pitched("pluck", [78, 71], .065, .6, .17)
    elif name == "ui_error":
        pitched("keys", [54, 53], .1, .6, .18)
        put(drum("wood"), .01, .2)
    elif name == "place":
        put(sweep(200, 98, .21, 15), gain=.65)
        pitched("mallet", [69, 74], .07, .5, .25)
    elif name == "remove":
        t = clock(.25)
        put(noise(.25, seed, 180, 2600) * np.sin(np.pi * t / .25) ** 2 * .15)
        put(sweep(700, 280, .2, 14), .08, .35)
    elif name == "heat_spawn":
        put(sweep(340, 680, .18, 13), gain=.35)
        pitched("mallet", [78, 83], .12, .55, .30)
    elif name == "heat_collect":
        pitched("bell", [81, 86, 90], .07, .5, .27)
        put(sweep(220, 460, .22, 15), gain=.18)
    elif name == "bun":
        t = clock(.2)
        put(edge(noise(.2, seed, 300, 4000) * np.exp(-t * 23), .007), gain=.32)
        put(sweep(380, 170, .17, 24), gain=.7)
    elif name == "tea":
        pitched("bell", [90, 97], .035, .5, .33)
        put(drum("rim"), gain=.15)
    elif name == "pepper":
        t = clock(.2)
        put(edge(noise(.2, seed, 450, 3500) * np.sin(np.pi * t / .2)**2, .008), gain=.23)
        put(sweep(360, 105, .18, 19), .035, .4)
    elif name == "popcorn":
        for at, note, gain in [(0, 69, .65), (.05, 76, .32), (.11, 81, .20)]:
            put(voice("mallet", note, .15), at, gain)
            put(sweep(350, 110, .10, 36), at, gain * .65)
    elif name == "noodles":
        pitched("pluck", [62, 74], .025, .75, .24)
    elif name == "garlic":
        put(drum("wood"), gain=.65)
        put(voice("mallet", 57, .22), gain=.6)
    elif name == "hit":
        put(sweep(195, 88, .14, 29), gain=.7)
        put(edge(noise(.14, seed, 170, 2000) * np.exp(-clock(.14)*52)), gain=.22)
    elif name == "armor":
        t = clock(.36)
        y = sum(a * np.sin(TAU*f*t) * np.exp(-t*d) for f, a, d in
                [(650, .65, 18), (1037, .4, 22), (1441, .22, 30), (2197, .11, 40)])
        put(edge(y), gain=.65)
    elif name == "bite":
        for at in [0, .06]:
            put(edge(noise(.09, seed + round(at*100), 250, 3200) * np.exp(-clock(.09)*47)), at, .32)
            put(drum("wood"), at, .2)
    elif name == "enemy_down":
        put(sweep(570, 150, .3, 13), gain=.7)
        put(drum("wood"), .13, .2)
    elif name == "food_down":
        pitched("keys", [66, 62, 57], .065, .45, .28)
        put(sweep(170, 65, .30, 15), gain=.35)
    elif name == "flour":
        t = clock(.48)
        put(edge(noise(.48, seed, 120, 2500) * np.exp(-t*8), .016, .10), gain=.45)
        put(sweep(140, 70, .30, 17), gain=.35)
    elif name == "summon":
        pitched("mallet", [57, 60, 64, 69], .10, .5, .35)
        put(voice("pad", 45, .70), gain=.3)
        put(drum("tom"), .34, .3)
    elif name == "rage":
        put(sweep(105, 51, .68, 5), gain=.5)
        pitched("keys", [50, 53, 57], .085, .48, .55)
        put(edge(noise(.6, seed, 160, 1700) * np.sin(np.linspace(0,np.pi,len(clock(.6))))**2,
                 .02, .12), gain=.10)
    elif name == "danger":
        for at in [0, .27]:
            put(voice("keys", 62, .35), at, .45)
            put(voice("keys", 68, .35), at, .26)
            put(drum("wood"), at, .2)
    elif name == "wave_start":
        pitched("mallet", [62, 69, 74], .15, .55, .4)
        for at in [0, .15, .3]:
            put(drum("tom"), at, .25)
    elif name == "clear":
        pitched("bell", [74, 78, 81, 86], .11, .45, .65)
        for note in [62, 66, 69]:
            put(voice("keys", note, .70), .25, .17)
    elif name == "purchase":
        pitched("bell", [81, 86, 90], .07, .5, .40)
        put(drum("wood"), gain=.23)
    elif name == "refresh":
        pitched("pluck", [74, 78, 81, 78], .055, .6, .22)
        t = clock(.27)
        put(edge(noise(.27, seed, 700, 3600) * np.sin(np.pi*t/.27)**2), gain=.045)
    elif name == "upgrade_success":
        pitched("bell", [74, 78, 81, 86, 90], .11, .48, .75)
        for note in [62, 66, 69, 74]:
            put(voice("keys", note, .95), .34, .2)
    elif name == "upgrade_fail":
        pitched("mallet", [74, 71, 66], .12, .6, .43)
        put(voice("keys", 54, .55), .1, .25)
    result = mix.data[:, 0]
    result -= np.mean(result)
    return normalize(edge(result, .002, .035), -4.2)[:, None]


def write_wav(path: Path, data: np.ndarray):
    pcm = np.rint(np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(data.shape[1])
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())


def decode(path: Path, ffmpeg: str, channels: int) -> np.ndarray:
    result = subprocess.run([ffmpeg, "-v", "error", "-i", str(path), "-f", "f32le",
                             "-ar", str(SR), "-ac", str(channels), "pipe:1"],
                            check=True, capture_output=True)
    return np.frombuffer(result.stdout, dtype="<f4").reshape(-1, channels)


def stats(path: Path, data: np.ndarray, music: bool) -> dict:
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data.astype(np.float64)**2)))
    if not np.all(np.isfinite(data)) or not 0.001 < peak < 0.9 or rms < 0.0001:
        raise ValueError(f"Invalid/nonfinite/silent/clipped waveform: {path}")
    result = {
        "file": path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else path.name,
        "sample_rate": SR, "channels": data.shape[1], "samples": len(data),
        "duration_seconds": round(len(data) / SR, 6),
        "peak_dbfs": round(20 * math.log10(peak), 3),
        "rms_dbfs": round(20 * math.log10(rms), 3),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "source": SOURCE,
    }
    if music:
        # Compare the seam's step with normal adjacent sample steps near the seam.
        step = float(np.max(np.abs(data[0] - data[-1])))
        adjacent = np.concatenate([np.diff(data[:2048], axis=0), np.diff(data[-2048:], axis=0)])
        local_p99 = float(np.quantile(np.abs(adjacent), .99))
        result["loop_seam_step"] = round(step, 7)
        result["loop_local_step_p99"] = round(local_p99, 7)
        if step > max(0.025, local_p99 * 5):
            raise ValueError(f"Excessive loop seam discontinuity: {path} ({step})")
    else:
        if abs(float(data[0, 0])) > 0.0001 or abs(float(data[-1, 0])) > 0.0001:
            raise ValueError(f"Nonzero sound-effect edge: {path}")
    return result


def sync_music_imports(output: Path, manifest: dict):
    """Preserve Godot-generated UIDs/paths when refreshing editor loop metadata."""
    for name, spec in manifest["music"].items():
        path = output / "music" / f"{name}.ogg.import"
        if not path.exists():
            continue  # Godot owns initial importer/UID creation.
        settings = path.read_text()
        for key, value in {"loop": "true", "bpm": str(spec["effective_bpm"]),
                           "beat_count": str(spec["bars"] * 4), "bar_beats": "4"}.items():
            settings = re.sub(rf"^{key}=.*$", f"{key}={value}", settings, flags=re.MULTILINE)
        path.write_text(settings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/audio")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    manifest_path = args.output / "manifest.json"
    if args.verify:
        manifest = json.loads(manifest_path.read_text())
        for kind in ("music", "sfx"):
            for name, previous in manifest[kind].items():
                path = args.output / kind / (name + (".ogg" if kind == "music" else ".wav"))
                actual = stats(path, decode(path, args.ffmpeg, 2 if kind == "music" else 1), kind == "music")
                for key in ("sha256", "samples", "peak_dbfs", "rms_dbfs"):
                    if actual[key] != previous[key]:
                        raise ValueError(f"Manifest mismatch {name}.{key}")
        print(f"PASS: decoded and checked {len(manifest['music'])} music loops and {len(manifest['sfx'])} SFX.")
        return
    args.output.mkdir(parents=True, exist_ok=True)
    for kind in ("music", "sfx"):
        (args.output / kind).mkdir(exist_ok=True)
    version = subprocess.check_output([args.ffmpeg, "-version"], text=True).splitlines()[0]
    manifest = {"format_version": 1, "seed": SEED, "source": SOURCE,
                "tools": {"python": sys.version.split()[0], "numpy": np.__version__, "ffmpeg": version},
                "music": {}, "sfx": {}}
    with tempfile.TemporaryDirectory(prefix="food_audio_") as scratch:
        for name, spec in MUSIC.items():
            data = compose(name)
            raw = Path(scratch) / f"{name}.wav"
            write_wav(raw, data)
            destination = args.output / "music" / f"{name}.ogg"
            subprocess.run([args.ffmpeg, "-v", "error", "-y", "-i", str(raw),
                            "-map_metadata", "-1", "-c:a", "vorbis", "-strict", "-2", "-q:a", "5",
                            "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "0",
                            str(destination)], check=True)
            decoded = decode(destination, args.ffmpeg, 2)
            expected = len(data)
            if len(decoded) != expected:
                raise ValueError(f"Codec altered loop sample count: {name}: {len(decoded)} != {expected}")
            manifest["music"][name] = {
                **spec, "effective_bpm": round(spec["bars"] * 4 * 60 * SR / len(data), 6),
                "loop": True, **stats(destination, decoded, True),
            }
            print(f"music {name:7s} {len(decoded)/SR:6.2f}s peak={manifest['music'][name]['peak_dbfs']:.2f} dBFS", flush=True)
        for name in SFX_IDS:
            destination = args.output / "sfx" / f"{name}.wav"
            write_wav(destination, make_sfx(name))
            manifest["sfx"][name] = {"loop": False, **stats(destination, decode(destination, args.ffmpeg, 1), False)}
            print(f"sfx   {name}", flush=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    sync_music_imports(args.output, manifest)
    print(f"Wrote {len(MUSIC)} original music loops and {len(SFX_IDS)} original SFX to {args.output}.")


if __name__ == "__main__":
    main()
