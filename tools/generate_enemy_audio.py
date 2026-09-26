#!/usr/bin/env python3
"""Original kitchen enemy cues; deterministic standard-library synthesis."""
from __future__ import annotations

import argparse
import array
import hashlib
import io
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
CUES = {"enemy_whistle": .46, "enemy_iron": .62,
        "enemy_ferment": .60, "enemy_abacus": .40}


def synth(name: str) -> bytes:
    count = round(CUES[name] * SR)
    samples = [0.0] * count
    rng = random.Random(20260926 + list(CUES).index(name))
    for i in range(count):
        t = i / SR
        value = 0.0
        if name == "enemy_whistle":
            for at in (0.0, .19):
                u = t - at
                if 0 <= u < .18:
                    envelope = math.sin(math.pi * u / .18) ** 2
                    value += envelope * (math.sin(math.tau * (920*u + 120*u*u))
                                         + .12 * (rng.random() * 2 - 1))
        elif name == "enemy_iron":
            for frequency, gain, decay in ((260, 1.0, 11), (437, .45, 16),
                                           (703, .21, 22), (1061, .12, 30)):
                value += gain * math.sin(math.tau * frequency * t) * math.exp(-decay*t)
        elif name == "enemy_ferment":
            for at, frequency in ((0, 170), (.12, 220), (.28, 145), (.40, 260)):
                u = t-at
                if 0 <= u < .16:
                    value += math.sin(math.pi*u/.16)**2 * math.sin(
                        math.tau * (frequency*u + 380*u*u)) * math.exp(-7*u)
        else:
            for at, frequency in ((0, 690), (.09, 810), (.19, 600)):
                u = t-at
                if 0 <= u < .18:
                    value += math.exp(-45*u) * (math.sin(math.tau*frequency*u)
                                                + .28*math.sin(math.tau*frequency*2.71*u))
        fade = min(1.0, t/.006, (CUES[name]-t)/.04)
        samples[i] = value * max(0.0, fade)
    peak = max(abs(value) for value in samples)
    pcm = array.array("h", (round(value / peak * 10**(-8/20) * 32767) for value in samples))
    if sys.byteorder != "little": pcm.byteswap()
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setparams((1, 2, SR, count, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())
    return buffer.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    folder = ROOT / "assets/audio/sfx"
    results = {}
    for name, duration in CUES.items():
        blob = synth(name)
        path = folder / (name + ".wav")
        if args.verify:
            if path.read_bytes() != blob: raise ValueError(f"Mismatch: {path}")
        else:
            path.write_bytes(blob)
        with wave.open(str(path), "rb") as stream:
            assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) == (1, 2, SR)
            assert stream.getnframes() == round(duration * SR)
        results[name] = {"seconds": duration, "sha256": hashlib.sha256(blob).hexdigest(), "peak_dbfs": -8}
    report = ROOT / "assets/audio/enemy_manifest.json"
    contents = json.dumps({"source": "Original synthesis: tools/generate_enemy_audio.py", "sample_rate": SR, "cues": results}, ensure_ascii=False, indent=2) + "\n"
    if args.verify:
        assert report.read_text() == contents
    else:
        report.write_text(contents)
    print(f"PASS enemy audio: {len(results)} deterministic original cues, PCM format and manifest")


if __name__ == "__main__":
    main()
