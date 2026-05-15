# betterkhmer

Khmer Unicode normalizer ported to 11 languages. All implementations expose a single `normalize()` function and pass the same 10,085-line fixture suite.

Based on the original work by [SIL Global](https://software.sil.org/), MIT license.

## Languages

| Language | Directory | Install |
|----------|-----------|---------|
| Python   | `python/betterkhmer` | `pip install betterkhmer` |
| Go       | `go/betterkhmer` | `go get github.com/seanghay/betterkhmer` |
| Rust     | `rust/betterkhmer` | `cargo add betterkhmer` |
| Swift    | `swift/betterkhmer` | Swift Package Manager |
| Dart     | `dart/betterkhmer` | `dart pub add betterkhmer` |
| Ruby     | `ruby/betterkhmer` | `gem install betterkhmer` |
| PHP      | `php/betterkhmer` | `composer require betterkhmer/betterkhmer` |
| Java     | `java/betterkhmer` | Maven / Gradle |
| Kotlin   | `kotlin/betterkhmer` | Gradle |
| C#       | `csharp/betterkhmer` | `dotnet add package BetterKhmer` |
| C        | `c/betterkhmer` | CMake + PCRE2 |

## Usage

Each language exposes one function: **`normalize(input)`**. See the per-language README for details.

## What it does

`normalize` reorders and canonicalizes Khmer Unicode syllables:

- Sorts character components within each syllable by Unicode category
- Canonicalizes compound vowel sequences
- Applies consonant shifters (TRIISAP / MUUSIKATOAN) correctly
- Converts lunar date notation to dedicated Unicode symbols

## Fixtures

`fixtures/input.txt` and `fixtures/expected.txt` contain 10,085 test pairs sampled from real Khmer text. Run `python3 scripts/gen_fixtures.py` to regenerate them.

## License

MIT
