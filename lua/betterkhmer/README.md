# betterkhmer · Lua

Khmer Unicode normalizer. Regex-free, Lua-pattern-free. Requires Lua 5.4 (uses
the built-in `utf8` library).

## Usage

```lua
local betterkhmer = dofile("betterkhmer.lua")

local result = betterkhmer.normalize("ខ្មែរ")
-- Middle Khmer:
local result_xhm = betterkhmer.normalize("ខ្មែរ", "xhm")
```

`normalize(txt[, lang])` takes a UTF-8 string and returns the normalized
UTF-8 string. `lang` defaults to `"km"`; pass `"xhm"` for Middle Khmer.

## Test

```bash
cd lua/betterkhmer
lua test/fixtures.lua ../../fixtures
```

The fixtures directory argument is optional (defaults to the repo `fixtures/`
relative to the test script). Prints `basic: ok` and `fixtures: 10085 ok`.
