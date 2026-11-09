#!/usr/bin/env python3
"""Writes TestData/stress-data.json: far more data than Glance allows, with the longest and
nastiest text a person, a stuck key or a bot could enter. Load it with
    ./scripts/load-test-data.sh stress-data.json
The loader applies the app's own caps (100 lists x 100 steps, 500 foods; names 80, steps 200,
descriptions 300 characters), so the simulator shows exactly what a real user could end up with.

Usage: python3 scripts/make-stress-data.py [lists] [steps] [foods]   (default 300 150 2000)
The output is generated on demand and git-ignored (it's several MB).
"""
import json
import os
import random
import sys

random.seed(7)
LISTS, STEPS, FOODS = (int(a) for a in (sys.argv[1:] + ["300", "150", "2000"])[:3])

# Text that has broken apps before: very long, emoji sequences, right-to-left and
# direction overrides, zero-width characters, line breaks, markdown and format strings.
NASTY = [
    "A" * 500,
    "\U0001F468‍\U0001F469‍\U0001F467 family " * 20,
    "‮gnip sdeM",                    # right-to-left override
    "zero​width﻿join",
    "line one\nline two\r\nline three\ttab",
    "**bold** _it_ [link](https://example.com) %@ %d %n {0} \\(x)",
    "مرحبا بالعالم שלום עולם",           # Arabic + Hebrew
    "　全角スペース　漢字テスト",
    "<script>alert(1)</script>",
    "'; DROP TABLE Theme; --",
    "\u0000\u0007 control \u001B[31m",
    "Z̸̢̛͎a̴͕͝l̶̖̿g̸̙̈́ò̷͜ ̸̡̛t̴̹̋ȩ̷̛x̴̗̾t̸̰̓",
]
ICONS = ["meds", "leave", "morning", "night", "food", "work", "clean", "exercise", "water", "star", "nope"]
REPEATS = ["daily", "weekdays", "weekends", "weekly", "monthly", "everyNDays", "oneTime", "bogus"]
WHERE = ["fridge", "freezer", "pantry", "garage"]
KINDS = ["snack", "ingredient", "prepared", "drink", "thaw", "canned", "mystery"]
LABELS = ["Fruit", "Veggie", "Juice", "Bread", "Rice", "Chicken", "Eggs", "Fish"]


def text(i, size):
    """Ordinary text most of the time, nasty text every few items."""
    if i % 7 == 0:
        return NASTY[i % len(NASTY)]
    return (f"Item {i} " + "lorem ipsum dolor sit amet " * 20)[:size]


def lists():
    out = []
    for i in range(LISTS):
        out.append({
            "name": text(i, 120),
            "icon": ICONS[i % len(ICONS)],
            "repeat": REPEATS[i % len(REPEATS)],
            "weekdays": [random.randint(-3, 12)],   # includes impossible weekdays
            "dayOfMonth": random.randint(-5, 40),   # and impossible days
            "interval": random.randint(-2, 400),    # and zero / negative intervals
            "steps": [text(i * 1000 + s, 260) for s in range(STEPS)],
            "doneSteps": list(range(0, STEPS, 3)) + [99999, -1],
        })
    return out


def food():
    out = []
    for i in range(FOODS):
        out.append({
            "name": text(i, 120),
            "where": WHERE[i % len(WHERE)],
            "kinds": random.sample(KINDS, 3),
            "labels": random.sample(LABELS, 3) + [text(i, 60), "", "   "],
            "daysFromNow": random.randint(-400, 4000),
            "addedDaysAgo": random.randint(-5, 900),
            "details": text(i + 3, 900),
        })
    return out


root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "TestData")
path = os.path.join(root, "stress-data.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump({"about": "Generated stress data. Not for shipping.", "lists": lists(), "food": food()},
              f, ensure_ascii=False)
print(f"Wrote {os.path.relpath(path)}: {LISTS} lists x {STEPS} steps, {FOODS} foods, "
      f"{os.path.getsize(path) / 1_000_000:.1f} MB")
