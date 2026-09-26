#!/usr/bin/env python3
"""Reproducible economy estimate; does not claim gameplay balance validation."""
import random
import re
import statistics
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / "resources/progression.tres").read_text()

def value(name):
    return float(re.search(rf"^{name} = ([0-9.]+)", source, re.MULTILINE).group(1))

base, decay = value("material_base"), value("material_decay")
cap, protection = int(value("max_level")), int(value("protected_target"))
rng = random.Random(713)

for policy in ("three_base", "three_trained_to_1", "one_matched"):
    samples = []
    for _ in range(10000):
        level = cost = 0
        while level < cap:
            count, material_level, each_cost = 3, 0, 1
            if policy == "three_trained_to_1":
                material_level, each_cost = 1, 3  # main + two base fodder: guaranteed
            elif policy == "one_matched":
                count, material_level = 1, level
                trained = 0
                while trained < material_level:
                    each_cost += 3
                    if rng.random() < min(1, 3 * base * decay ** trained):
                        trained += 1
                    elif trained >= protection:
                        trained -= 1
            cost += count * each_cost
            if rng.random() < min(1, count * base * decay ** max(level - material_level, 0)):
                level += 1
            elif level >= protection:
                level -= 1
        samples.append(cost)
    samples.sort()
    print(policy, "mean", round(statistics.mean(samples), 2), "median", statistics.median(samples),
          "p95", samples[9500], "p99", samples[9900])
