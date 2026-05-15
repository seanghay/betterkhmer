# betterkhmer

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
