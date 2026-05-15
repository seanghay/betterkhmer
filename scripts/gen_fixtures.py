#!/usr/bin/env python3
"""Generate test fixtures for betterkhmer from real Khmer text."""

import random
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'resources'))
from khnormal import khnormal

ROOT = os.path.join(os.path.dirname(__file__), '..')
KHMER_TEXT = os.path.join(ROOT, 'resources', 'khmer-text.txt')
BAD_TXT = os.path.join(ROOT, 'resources', 'khmer-normalizer', 'test', 'fixtures', 'bad.txt')
GOOD_TXT = os.path.join(ROOT, 'resources', 'khmer-normalizer', 'test', 'fixtures', 'good.txt')
OUT_INPUT = os.path.join(ROOT, 'fixtures', 'input.txt')
OUT_EXPECTED = os.path.join(ROOT, 'fixtures', 'expected.txt')

SAMPLE_SIZE = 10_000
SEED = 42

def main():
    # Load existing test pairs from bad/good fixtures
    with open(BAD_TXT, encoding='utf-8') as f:
        bad_lines = [l.rstrip('\n') for l in f if l.strip()]

    # good.txt is one line (no newlines); split by running khnormal on each bad line
    # The good.txt in the reference is actually one concatenated line, so we derive
    # expected output by running khnormal on each bad line directly.
    existing_inputs = bad_lines
    existing_expected = [khnormal(line) for line in bad_lines]

    # Sample from real khmer text
    print(f"Reading {KHMER_TEXT}...")
    with open(KHMER_TEXT, encoding='utf-8') as f:
        all_lines = [l.rstrip('\n') for l in f if l.strip()]

    print(f"Total lines: {len(all_lines)}, sampling {SAMPLE_SIZE}...")
    random.seed(SEED)
    sampled = random.sample(all_lines, min(SAMPLE_SIZE, len(all_lines)))

    sampled_expected = [khnormal(line) for line in sampled]

    # Combine: existing pairs first, then sampled
    all_inputs = existing_inputs + sampled
    all_outputs = existing_expected + sampled_expected

    os.makedirs(os.path.join(ROOT, 'fixtures'), exist_ok=True)
    with open(OUT_INPUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(all_inputs) + '\n')
    with open(OUT_EXPECTED, 'w', encoding='utf-8') as f:
        f.write('\n'.join(all_outputs) + '\n')

    print(f"Written {len(all_inputs)} fixture pairs to fixtures/")

if __name__ == '__main__':
    main()
