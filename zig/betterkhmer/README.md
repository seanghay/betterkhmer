# betterkhmer — Zig

Khmer Unicode normalizer for Zig.

## Requirements

- Zig 0.14+
- PCRE2 (`brew install pcre2` / `apt install libpcre2-dev`)

## Usage

```zig
const std = @import("std");
const betterkhmer = @import("betterkhmer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const result = try betterkhmer.normalize(alloc, "ខ្មែរ", "km");
    defer alloc.free(result);
    std.debug.print("{s}\n", .{result});
}
```

## Build & Test

```sh
zig build -Doptimize=ReleaseFast
zig build test -Doptimize=ReleaseFast -- ../../fixtures
```
