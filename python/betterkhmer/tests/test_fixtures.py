import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from betterkhmer import normalize

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'fixtures')

def load(path):
    with open(path, encoding='utf-8') as f:
        return [l.rstrip('\n') for l in f]

def test_basic():
    assert normalize('ខ្មែរ') == 'ខ្មែរ'

def test_fixtures():
    inputs   = load(os.path.join(ROOT, 'input.txt'))
    expected = load(os.path.join(ROOT, 'expected.txt'))
    assert len(inputs) == len(expected)
    failures = []
    for i, (inp, exp) in enumerate(zip(inputs, expected)):
        got = normalize(inp)
        if got != exp:
            failures.append((i, inp, exp, got))
    if failures:
        for i, inp, exp, got in failures[:10]:
            print(f"[{i}] {inp!r} => got {got!r}, want {exp!r}")
    assert not failures, f"{len(failures)} fixture failures"

if __name__ == '__main__':
    test_basic()
    print("basic: ok")
    test_fixtures()
    print("fixtures: ok")
