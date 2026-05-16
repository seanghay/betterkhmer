# BetterKhmer

Khmer Unicode normalizer ported to 18 languages. All implementations expose a single `normalize()` function and pass the same 10,085-line fixture suite.

Normalizes Khmer text according to the proposed normal encoding structure at https://www.unicode.org/L2/L2022/22290-khmer-encoding.pdf. It does not attempt to identify faulty text — it ensures two strings that would render the same are output as the same string.

Based on the original [khmer-normalizer](https://github.com/seanghay/khmer-normalizer) by [SIL Global](https://software.sil.org/), MIT license.

## Example

ខែ្មរ is corrected to ខ្មែរ:

- Input: ខ `U+1781` ែ `U+17C2` ្ `U+17D2` ម `U+1798` រ `U+179A`
- Output: ខ `U+1781` ្ `U+17D2` ម `U+1798` ែ `U+17C2` រ `U+179A`

## Languages

**This is not published to any package registry.** Each port is one
self-contained source file — copy it straight into your project.

| Language    | Source file (copy into your project) |
|-------------|--------------------------------------|
| Python      | `python/betterkhmer/src/betterkhmer/__init__.py` |
| Go          | `go/betterkhmer/betterkhmer.go` |
| Rust        | `rust/betterkhmer/src/lib.rs` |
| Swift       | `swift/betterkhmer/Sources/BetterKhmer/BetterKhmer.swift` |
| Dart        | `dart/betterkhmer/lib/betterkhmer.dart` |
| Ruby        | `ruby/betterkhmer/lib/betterkhmer.rb` |
| PHP         | `php/betterkhmer/src/BetterKhmer.php` |
| Java        | `java/betterkhmer/src/main/java/com/betterkhmer/BetterKhmer.java` |
| Kotlin      | `kotlin/betterkhmer/src/main/kotlin/com/betterkhmer/BetterKhmer.kt` |
| C#          | `csharp/betterkhmer/src/BetterKhmer.cs` |
| C           | `c/betterkhmer/src/betterkhmer.c` (+ `.h`) |
| C++         | `cpp/betterkhmer/src/betterkhmer.cpp` (+ `.hpp`) |
| TypeScript  | `typescript/betterkhmer/src/index.ts` |
| Zig         | `zig/betterkhmer/src/betterkhmer.zig` |
| Perl        | `perl/betterkhmer/lib/BetterKhmer.pm` |
| Elixir      | `elixir/betterkhmer/lib/betterkhmer.ex` |
| VB.NET      | `vbnet/betterkhmer/src/BetterKhmer.vb` |
| Objective-C | `objc/betterkhmer/src/BetterKhmer.m` (+ `.h`) |
| Lua         | `lua/betterkhmer/betterkhmer.lua` |

## API

Each language exposes one function: **`normalize(input, lang="km")`**.

- `lang = "km"` — Modern Khmer (default)
- `lang = "xhm"` — Middle Khmer

```python
# Python
from betterkhmer import normalize
result = normalize("ខ្មែរ")
```

```go
// Go
result := betterkhmer.Normalize("ខ្មែរ")
```

```typescript
// TypeScript / JavaScript
import { normalize } from 'betterkhmer';
const result = normalize('ខ្មែរ');
```

See the per-language `README.md` in each subdirectory for usage and test details.

## Why this exists

Khmer syllables are two-dimensional arrangements of marks surrounding a base consonant. Unicode does not mandate a single encoding order for these marks, so the same rendered word can be stored as multiple distinct byte sequences.

The word ស្ត្រី ("woman") can be encoded at least three ways that look identical on screen:

| Sequence | Codepoints | Sounds like |
|----------|------------|-------------|
| ស ្ត ្រ ី | U+179F U+17D2 U+178F U+17D2 U+179A U+17B8 | s-t-r-ī (correct) |
| ស ្រ ្ត ី | U+179F U+17D2 U+179A U+17D2 U+178F U+17B8 | s-r-t-ī |
| ស ្រ ី ្ត | U+179F U+17D2 U+179A U+17B8 U+17D2 U+178F | s-r-ī-t |

This disorder has real consequences:

- **Search breaks** — Google returns completely different results for visually identical queries typed in different apps.
- **Security spoofing** — `ស្ត្រី.com`, `ស្រ្តី.com`, and `ស្រី្ត.com` look the same in a browser bar but route to different servers.
- **Code review is unreliable** — variable names that appear identical may differ in encoding, making malicious substitutions invisible.
- **Rendering artifacts** — some browsers show dotted-circle error markers for out-of-order marks that others silently accept.

`normalize()` collapses all equivalent forms into one canonical byte sequence, so search, comparison, storage, and security checks behave correctly regardless of which keyboard or app produced the text.

Further reading: [Order and Disorder in Unicode](https://lontar.eu/en/notes/order-and-disorder-in-unicode/) · [Proposed Khmer encoding structure (Unicode L2/22-290)](https://www.unicode.org/L2/L2022/22290-khmer-encoding.pdf)

**Talk**: [S3T1 — Discrepancies in Khmer Unicode Character Ordering Rules and a Proposed Solution](https://www.youtube.com/watch?v=mD-nrfvWtgc) — the conference presentation behind the encoding proposal that this library implements.

## What it does

- Sorts character components within each Khmer syllable by Unicode category
- Canonicalizes compound vowel sequences (e.g. េ + ា → ោ)
- Applies consonant shifters (TRIISAP / MUUSIKATOAN) correctly
- Converts lunar date notation to dedicated Unicode symbols

## Fixtures

`fixtures/input.txt` and `fixtures/expected.txt` contain 10,085 test pairs sampled from real Khmer text. Regenerate with:

```sh
python3 scripts/gen_fixtures.py
```

## Benchmark

Throughput of the current implementation. One **op** = one `normalize()`
call on one line. Corpus: all 10,085 `fixtures/input.txt` lines held in
memory; 3 untimed warmup passes, then K timed full passes (timed region
≥ 5 s), best of two runs; **only the normalize loop is timed** (file IO,
process start and JIT/VM warmup excluded); release/optimized builds.

| Language    |        ops/sec |
|-------------|---------------:|
| Java        | 85,888 |
| Kotlin      | 55,406 |
| Go          | 53,802 |
| C#          | 49,693 |
| C           | 49,120 |
| VB.NET      | 48,352 |
| Rust        | 47,181 |
| TypeScript  | 44,230 |
| C++         | 43,540 |
| Objective-C | 42,880 |
| Dart        | 36,599 |
| Swift       | 19,749 |
| Elixir      | 13,613 |
| PHP         |  7,214 |
| Zig         |  6,412 |
| Ruby        |  4,940 |
| Python      |  4,013 |
| Perl        |  3,847 |
| Lua         |  3,591 |

All ports produce identical normalized output (verified by the 10,085-line
fixture suite). Absolute numbers are indicative only — they are not strictly
comparable across languages because runtimes, GC and per-call memory models
differ (e.g. C/C++/Objective-C and Zig allocate and free a result buffer on
every call, which dominates Zig's figure; Ruby/PHP/Perl still use the regex
implementation).

## License

MIT
