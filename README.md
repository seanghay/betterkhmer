# BetterKhmer

Khmer Unicode normalizer ported to 14 languages. All implementations expose a single `normalize()` function and pass the same 10,085-line fixture suite.

Normalizes Khmer text according to the proposed normal encoding structure at https://www.unicode.org/L2/L2022/22290-khmer-encoding.pdf. It does not attempt to identify faulty text — it ensures two strings that would render the same are output as the same string.

Based on the original [khmer-normalizer](https://github.com/seanghay/khmer-normalizer) by [SIL Global](https://software.sil.org/), MIT license.

## Example

ខែ្មរ is corrected to ខ្មែរ:

- Input: ខ `U+1781` ែ `U+17C2` ្ `U+17D2` ម `U+1798` រ `U+179A`
- Output: ខ `U+1781` ្ `U+17D2` ម `U+1798` ែ `U+17C2` រ `U+179A`

## Languages

| Language   | Directory              | Install / Build |
|------------|------------------------|-----------------|
| Python     | `python/betterkhmer`   | `pip install betterkhmer` |
| Go         | `go/betterkhmer`       | `go get github.com/seanghay/betterkhmer` |
| Rust       | `rust/betterkhmer`     | `cargo add betterkhmer` |
| Swift      | `swift/betterkhmer`    | Swift Package Manager |
| Dart       | `dart/betterkhmer`     | `dart pub add betterkhmer` |
| Ruby       | `ruby/betterkhmer`     | `gem install betterkhmer` |
| PHP        | `php/betterkhmer`      | `composer require betterkhmer/betterkhmer` |
| Java       | `java/betterkhmer`     | Maven / Gradle |
| Kotlin     | `kotlin/betterkhmer`   | Gradle |
| C#         | `csharp/betterkhmer`   | `dotnet add package BetterKhmer` |
| C          | `c/betterkhmer`        | CMake + PCRE2 |
| C++        | `cpp/betterkhmer`      | CMake + PCRE2 |
| TypeScript | `typescript/betterkhmer` | `npm install betterkhmer` |
| Zig        | `zig/betterkhmer`      | `zig build` + PCRE2 |
| Perl       | `perl/betterkhmer`     | `perl -Ilib` |

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

See the per-language `README.md` in each subdirectory for install and usage details.

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

## License

MIT
