// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Zig — betterkhmer package. Regex-free; 1:1 with the Go reference.

const std = @import("std");
const mem = std.mem;

// ---- Character categories ----

const Cat = enum(u8) {
    other = 0, base = 1, robat = 2, coeng = 3, shift = 4, z = 5,
    vpre = 6, vb = 7, va = 8, vpost = 9, ms = 10, mf = 11, zfcoeng = 12,
};

const CAT_LEN = 0x17DE - 0x1780;
const CATEGORIES: [CAT_LEN]u8 = blk: {
    var a = [_]u8{0} ** CAT_LEN;
    var i: usize = 0;
    while (i <= 0x17A2 - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.base);
    i = 0x17A5 - 0x1780;
    while (i <= 0x17B3 - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.base);
    a[0x17B6 - 0x1780] = @intFromEnum(Cat.vpost);
    i = 0x17B7 - 0x1780;
    while (i <= 0x17BA - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.va);
    i = 0x17BB - 0x1780;
    while (i <= 0x17BD - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.vb);
    i = 0x17BE - 0x1780;
    while (i <= 0x17C5 - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.vpre);
    a[0x17C6 - 0x1780] = @intFromEnum(Cat.ms);
    a[0x17C7 - 0x1780] = @intFromEnum(Cat.mf);
    a[0x17C8 - 0x1780] = @intFromEnum(Cat.mf);
    a[0x17C9 - 0x1780] = @intFromEnum(Cat.shift);
    a[0x17CA - 0x1780] = @intFromEnum(Cat.shift);
    a[0x17CB - 0x1780] = @intFromEnum(Cat.ms);
    a[0x17CC - 0x1780] = @intFromEnum(Cat.robat);
    i = 0x17CD - 0x1780;
    while (i <= 0x17D1 - 0x1780) : (i += 1) a[i] = @intFromEnum(Cat.ms);
    a[0x17D2 - 0x1780] = @intFromEnum(Cat.coeng);
    a[0x17D3 - 0x1780] = @intFromEnum(Cat.ms);
    a[0x17DD - 0x1780] = @intFromEnum(Cat.ms);
    break :blk a;
};

fn charcat(cp: u21) Cat {
    if (cp >= 0x1780 and cp <= 0x17DD) return @enumFromInt(CATEGORIES[cp - 0x1780]);
    if (cp == 0x200C) return .z;
    if (cp == 0x200D) return .zfcoeng;
    return .other;
}

// ---- Khmer consonant classes (from the SIL reference khres) ----

const ZWNJ: u21 = 0x200C;
const ZWJ: u21 = 0x200D;
const COENG: u21 = 0x17D2;
const ROBAT: u21 = 0x17CC;
const BA: u21 = 0x1794;

fn isBase(r: u21) bool {
    return (r >= 0x1780 and r <= 0x17A2) or (r >= 0x17A5 and r <= 0x17B3) or r == 0x25CC;
}
fn isNonRo(r: u21) bool {
    return (r >= 0x1780 and r <= 0x1799) or (r >= 0x179B and r <= 0x17A2) or
        (r >= 0x17A5 and r <= 0x17B3);
}
fn isNonBA(r: u21) bool {
    return (r >= 0x1780 and r <= 0x1793) or (r >= 0x1795 and r <= 0x17A2) or
        (r >= 0x17A5 and r <= 0x17B3);
}
fn isS1(r: u21) bool {
    if (r >= 0x1780 and r <= 0x1783) return true;
    if (r >= 0x1785 and r <= 0x1788) return true;
    if (r >= 0x178A and r <= 0x178D) return true;
    if (r >= 0x178F and r <= 0x1792) return true;
    if (r >= 0x1795 and r <= 0x1797) return true;
    if (r >= 0x179E and r <= 0x17A0) return true;
    if (r == 0x17A2) return true;
    return false;
}
fn isS2(r: u21) bool {
    if (r == 0x1780 or r == 0x1784 or r == 0x178E or r == 0x1793 or
        r == 0x1794 or r == 0x17A1) return true;
    if (r >= 0x1798 and r <= 0x179D) return true;
    if (r >= 0x17A3 and r <= 0x17B3) return true;
    return false;
}
fn isVPre(r: u21) bool {
    return r >= 0x17C1 and r <= 0x17C5;
}
fn isDigit(r: u21) bool {
    return r >= 0x17E0 and r <= 0x17E9;
}

// ---- UTF-8 helpers ----

const Decoded = struct { cp: u21, len: u3 };

fn u8dec(s: []const u8) Decoded {
    const b = s[0];
    if (b < 0x80) return .{ .cp = b, .len = 1 };
    if (b < 0xE0) return .{ .cp = @as(u21, b & 0x1F) << 6 | (s[1] & 0x3F), .len = 2 };
    if (b < 0xF0) return .{
        .cp = @as(u21, b & 0x0F) << 12 | @as(u21, s[1] & 0x3F) << 6 | (s[2] & 0x3F),
        .len = 3,
    };
    return .{
        .cp = @as(u21, b & 0x07) << 18 | @as(u21, s[1] & 0x3F) << 12 |
            @as(u21, s[2] & 0x3F) << 6 | (s[3] & 0x3F),
        .len = 4,
    };
}

fn u8enc(cp: u21, buf: []u8) u3 {
    if (cp < 0x80) {
        buf[0] = @intCast(cp);
        return 1;
    }
    if (cp < 0x800) {
        buf[0] = @intCast(0xC0 | (cp >> 6));
        buf[1] = @intCast(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000) {
        buf[0] = @intCast(0xE0 | (cp >> 12));
        buf[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
        buf[2] = @intCast(0x80 | (cp & 0x3F));
        return 3;
    }
    buf[0] = @intCast(0xF0 | (cp >> 18));
    buf[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
    buf[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
    buf[3] = @intCast(0x80 | (cp & 0x3F));
    return 4;
}

fn appendCP(out: *std.ArrayList(u8), cp: u21) !void {
    var buf: [4]u8 = undefined;
    try out.appendSlice(buf[0..u8enc(cp, &buf)]);
}

// ---- optRobat: positions after an optional Robat at p ----

const RobatEnds = struct { p: [2]usize, n: u2 };

fn optRobat(r: []const u21, p: usize) RobatEnds {
    if (p < r.len and r[p] == ROBAT) return .{ .p = .{ p, p + 1 }, .n = 2 };
    return .{ .p = .{ p, 0 }, .n = 1 };
}

// ---- coengEnds: end indices of one COENG: (?:(?:្ NonRo)? ្ B) ----

const CoengEnds = struct { e: [2]usize, n: u2 };

fn coengEnds(r: []const u21, s: usize) CoengEnds {
    const n = r.len;
    var res = CoengEnds{ .e = .{ 0, 0 }, .n = 0 };
    if (s + 1 < n and r[s] == COENG and isBase(r[s + 1])) {
        res.e[res.n] = s + 2;
        res.n += 1;
    }
    if (s + 3 < n and r[s] == COENG and isNonRo(r[s + 1]) and
        r[s + 2] == COENG and isBase(r[s + 3]))
    {
        res.e[res.n] = s + 4;
        res.n += 1;
    }
    return res;
}

// ---- strongEnds / nstrongEnds ----

fn strongEnds(r: []const u21, s: usize, ctx: anytype, add: anytype) void {
    const n = r.len;
    if (s >= n) return;
    if (isS1(r[s])) {
        const pr = optRobat(r, s + 1);
        var t: usize = 0;
        while (t < pr.n) : (t += 1) {
            const p = pr.p[t];
            add(ctx, p);
            if (p + 1 < n and r[p] == COENG and isNonBA(r[p + 1])) {
                const q = p + 2;
                add(ctx, q);
                if (q + 1 < n and r[q] == COENG and isNonBA(r[q + 1])) add(ctx, q + 2);
            }
        }
    }
    if (isNonBA(r[s])) {
        const pr = optRobat(r, s + 1);
        var t: usize = 0;
        while (t < pr.n) : (t += 1) {
            const p = pr.p[t];
            if (p + 1 < n and r[p] == COENG and isS1(r[p + 1])) {
                const q = p + 2;
                add(ctx, q);
                if (q + 1 < n and r[q] == COENG and isNonBA(r[q + 1])) add(ctx, q + 2);
            }
            if (p + 3 < n and r[p] == COENG and isNonBA(r[p + 1]) and
                r[p + 2] == COENG and isS1(r[p + 3])) add(ctx, p + 4);
        }
    }
}

fn nstrongEnds(r: []const u21, s: usize, ctx: anytype, add: anytype) void {
    const n = r.len;
    if (s >= n) return;
    if (isS2(r[s])) {
        const pr = optRobat(r, s + 1);
        var t: usize = 0;
        while (t < pr.n) : (t += 1) {
            const p = pr.p[t];
            add(ctx, p);
            if (p + 1 < n and r[p] == COENG and isS2(r[p + 1])) {
                const q = p + 2;
                add(ctx, q);
                if (q + 1 < n and r[q] == COENG and isS2(r[q + 1])) add(ctx, q + 2);
            }
        }
    }
    if (r[s] == BA) {
        const pr = optRobat(r, s + 1);
        var t: usize = 0;
        while (t < pr.n) : (t += 1) {
            const p = pr.p[t];
            add(ctx, p);
            const c1 = coengEnds(r, p);
            var a: usize = 0;
            while (a < c1.n) : (a += 1) {
                add(ctx, c1.e[a]);
                const c2 = coengEnds(r, c1.e[a]);
                var b: usize = 0;
                while (b < c2.n) : (b += 1) add(ctx, c2.e[b]);
            }
        }
    }
    if (isBase(r[s])) {
        const pr = optRobat(r, s + 1);
        var t: usize = 0;
        while (t < pr.n) : (t += 1) {
            const p = pr.p[t];
            if (p + 3 < n and r[p] == COENG and isNonRo(r[p + 1]) and
                r[p + 2] == COENG and r[p + 3] == BA) add(ctx, p + 4);
            if (p + 3 < n and r[p] == COENG and r[p + 1] == BA and
                r[p + 2] == COENG and isBase(r[p + 3])) add(ctx, p + 4);
        }
    }
}

// ---- canEndAt ----

const CanCtx = struct { target: usize, found: bool };

fn canAdd(ctx: *CanCtx, e: usize) void {
    if (e == ctx.target) ctx.found = true;
}

fn canEndAt(r: []const u21, target: usize, comptime ends: anytype) bool {
    var s: usize = 0;
    while (s < target) : (s += 1) {
        var c = CanCtx{ .target = target, .found = false };
        ends(r, s, &c, canAdd);
        if (c.found) return true;
    }
    return false;
}

// ---- vaSamyokAt: lookahead (?:VA | ័) ----

fn vaSamyokAt(r: []const u21, p: usize) bool {
    const n = r.len;
    if (p >= n) return false;
    const c = r[p];
    if (c == 0x17D0) return true;
    if (c >= 0x17B7 and c <= 0x17BA) return true;
    if (c == 0x17BE or c == 0x17BF or c == 0x17DD) return true;
    if (c == 0x17B6 and p + 1 < n and r[p + 1] == 0x17C6) return true;
    return false;
}

// ---- applyShifter (mutates r in place) ----

fn applyShifter(r: []u21, comptime ends: anytype, shifter: u21) void {
    var k: usize = 0;
    while (k < r.len) : (k += 1) {
        if (r[k] != 0x17BB) continue;
        const ctx = canEndAt(r, k, ends) or
            (k >= 1 and isVPre(r[k - 1]) and canEndAt(r, k - 1, ends));
        if (ctx and vaSamyokAt(r, k + 1)) r[k] = shifter;
    }
}

// ---- collapseInvis: (‍?្)[្‌‍]+ -> \1 ----

fn isInvis(c: u21) bool {
    return c == COENG or c == ZWNJ or c == ZWJ;
}

fn collapseInvis(alloc: mem.Allocator, r: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        var g1_end: isize = -1;
        if (r[i] == ZWJ and i + 1 < n and r[i + 1] == COENG) {
            g1_end = @intCast(i + 2);
        } else if (r[i] == COENG) {
            g1_end = @intCast(i + 1);
        }
        if (g1_end >= 0) {
            const ge: usize = @intCast(g1_end);
            var k = ge;
            while (k < n and isInvis(r[k])) k += 1;
            if (k > ge) {
                try out.appendSlice(r[i..ge]);
                i = k;
                continue;
            }
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- pairReplace / pairReplace3 ----

fn pairReplace(alloc: mem.Allocator, r: []const u21, a: u21, b: u21, repl: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (i + 1 < n and r[i] == a and r[i + 1] == b) {
            try out.appendSlice(repl);
            i += 2;
            continue;
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

fn pairReplace3(alloc: mem.Allocator, r: []const u21, a: u21, b: u21, c: u21, repl: u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (i + 2 < n and r[i] == a and r[i + 1] == b and r[i + 2] == c) {
            try out.append(repl);
            i += 3;
            continue;
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- vowelSplit: េ([ុ-ួ]?)tail -> head + \1 ----

fn vowelSplit(alloc: mem.Allocator, r: []const u21, tail: u21, head: u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (r[i] == 0x17C1) {
            if (i + 2 < n and r[i + 1] >= 0x17BB and r[i + 1] <= 0x17BD and r[i + 2] == tail) {
                try out.append(head);
                try out.append(r[i + 1]);
                i += 3;
                continue;
            }
            if (i + 1 < n and r[i + 1] == tail) {
                try out.append(head);
                i += 2;
                continue;
            }
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- coengRo: (្រ)(្[ក-ឳ]) -> \2\1 ----

fn coengRo(alloc: mem.Allocator, r: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (i + 3 < n and r[i] == COENG and r[i + 1] == 0x179A and
            r[i + 2] == COENG and r[i + 3] >= 0x1780 and r[i + 3] <= 0x17B3)
        {
            try out.append(r[i + 2]);
            try out.append(r[i + 3]);
            try out.append(r[i]);
            try out.append(r[i + 1]);
            i += 4;
            continue;
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- coengDa: (្)ដ -> \1ត ----

fn coengDa(alloc: mem.Allocator, r: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (i + 1 < n and r[i] == COENG and r[i + 1] == 0x178A) {
            try out.append(COENG);
            try out.append(0x178F);
            i += 2;
            continue;
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0) ----

fn lunar1(alloc: mem.Allocator, r: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (r[i] == 0x17E1 and i + 3 < n and isDigit(r[i + 1]) and
            r[i + 2] == COENG and r[i + 3] == 0x17D4)
        {
            const v: u21 = 10 + (r[i + 1] - 0x17E0);
            if (v > 15) try out.appendSlice(r[i .. i + 4])
            else try out.append(0x19E0 + v);
            i += 4;
            continue;
        }
        if (i + 2 < n and isDigit(r[i]) and r[i + 1] == COENG and r[i + 2] == 0x17D4) {
            try out.append(0x19E0 + (r[i] - 0x17E0));
            i += 3;
            continue;
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0) ----

fn lunar2(alloc: mem.Allocator, r: []const u21) ![]u21 {
    const n = r.len;
    var out = std.ArrayList(u21).init(alloc);
    var i: usize = 0;
    while (i < n) {
        if (r[i] == 0x17D4 and i + 1 < n and r[i + 1] == COENG) {
            if (i + 3 < n and r[i + 2] == 0x17E1 and isDigit(r[i + 3])) {
                const v: u21 = 10 + (r[i + 3] - 0x17E0);
                if (v > 15) try out.appendSlice(r[i .. i + 4])
                else try out.append(0x19F0 + v);
                i += 4;
                continue;
            }
            if (i + 2 < n and isDigit(r[i + 2])) {
                try out.append(0x19F0 + (r[i + 2] - 0x17E0));
                i += 3;
                continue;
            }
        }
        try out.append(r[i]);
        i += 1;
    }
    return out.toOwnedSlice();
}

// ---- hasByteE1: SWAR scan for byte 0xE1 ----

fn hasByteE1(s: []const u8) bool {
    const lo: u64 = 0x0101010101010101;
    const hi: u64 = 0x8080808080808080;
    const mask: u64 = 0xE1E1E1E1E1E1E1E1;
    var i: usize = 0;
    while (i + 8 <= s.len) : (i += 8) {
        const w: u64 = @as(u64, s[i]) | @as(u64, s[i + 1]) << 8 |
            @as(u64, s[i + 2]) << 16 | @as(u64, s[i + 3]) << 24 |
            @as(u64, s[i + 4]) << 32 | @as(u64, s[i + 5]) << 40 |
            @as(u64, s[i + 6]) << 48 | @as(u64, s[i + 7]) << 56;
        const x = w ^ mask;
        if ((x -% lo) & ~x & hi != 0) return true;
    }
    while (i < s.len) : (i += 1) {
        if (s[i] == 0xE1) return true;
    }
    return false;
}

// ---- Sort context (insertionContext API: operates on index positions) ----

const SortCtx = struct {
    cats: []Cat,
    indices: []usize,

    pub fn lessThan(ctx: SortCtx, a: usize, b: usize) bool {
        const ia = ctx.indices[a];
        const ib = ctx.indices[b];
        const ca = @intFromEnum(ctx.cats[ia]);
        const cb = @intFromEnum(ctx.cats[ib]);
        return if (ca != cb) ca < cb else ia < ib;
    }

    pub fn swap(ctx: SortCtx, a: usize, b: usize) void {
        const tmp = ctx.indices[a];
        ctx.indices[a] = ctx.indices[b];
        ctx.indices[b] = tmp;
    }
};

// ---- Public API ----

/// Caller owns the returned slice; free with alloc.free().
pub fn normalize(alloc: mem.Allocator, txt: []const u8, lang: []const u8) ![]u8 {
    // SWAR skip/scan fast path: no Khmer byte => identity.
    if (!hasByteE1(txt)) return alloc.dupe(u8, txt);

    // Decode UTF-8 to code points.
    var raw = std.ArrayList(u21).init(alloc);
    defer raw.deinit();
    {
        var p: usize = 0;
        while (p < txt.len) {
            const r = u8dec(txt[p..]);
            try raw.append(r.cp);
            p += r.len;
        }
    }

    // XHM pre-step: insert U+200D before each [U+17B6-U+17C5] U+17D2 sequence.
    var cps = std.ArrayList(u21).init(alloc);
    defer cps.deinit();
    if (mem.eql(u8, lang, "xhm")) {
        var k: usize = 0;
        while (k < raw.items.len) : (k += 1) {
            if (raw.items[k] >= 0x17B6 and raw.items[k] <= 0x17C5 and
                k + 1 < raw.items.len and raw.items[k + 1] == 0x17D2)
                try cps.append(0x200D);
            try cps.append(raw.items[k]);
        }
    } else {
        try cps.appendSlice(raw.items);
    }

    const n = cps.items.len;
    var cats = std.ArrayList(Cat).init(alloc);
    defer cats.deinit();
    try cats.resize(n);
    for (0..n) |k| cats.items[k] = charcat(cps.items[k]);

    // Recategorise.
    for (1..n) |i| {
        const prev = cps.items[i - 1];
        if (prev == ZWJ or prev == COENG) {
            if (cats.items[i] == .base or cats.items[i] == .coeng)
                cats.items[i] = cats.items[i - 1];
        }
    }

    var out = std.ArrayList(u8).init(alloc);
    var indices = std.ArrayList(usize).init(alloc);
    defer indices.deinit();

    var i: usize = 0;
    while (i < n) {
        if (cats.items[i] != .base) {
            try appendCP(&out, cps.items[i]);
            i += 1;
            continue;
        }
        var j = i + 1;
        while (j < n and @intFromEnum(cats.items[j]) > @intFromEnum(Cat.base)) : (j += 1) {}

        const slen = j - i;
        try indices.resize(slen);
        for (0..slen) |k| indices.items[k] = i + k;
        std.sort.insertionContext(0, slen, SortCtx{
            .cats = cats.items,
            .indices = indices.items,
        });

        var syl = try alloc.alloc(u21, slen);
        for (0..slen) |k| syl[k] = cps.items[indices.items[k]];

        {
            const t = try collapseInvis(alloc, syl);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try pairReplace(alloc, syl, 0x17BE, 0x17B6, &[_]u21{ 0x17C4, 0x17B8 });
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try vowelSplit(alloc, syl, 0x17B8, 0x17BE);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try vowelSplit(alloc, syl, 0x17B6, 0x17C4);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try pairReplace(alloc, syl, 0x17BE, 0x17BB, &[_]u21{ 0x17BB, 0x17BE });
            alloc.free(syl);
            syl = t;
        }
        applyShifter(syl, strongEnds, 0x17CA);
        applyShifter(syl, nstrongEnds, 0x17C9);
        {
            const t = try coengRo(alloc, syl);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try coengDa(alloc, syl);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try lunar1(alloc, syl);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try lunar2(alloc, syl);
            alloc.free(syl);
            syl = t;
        }
        {
            const t = try pairReplace3(alloc, syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0);
            alloc.free(syl);
            syl = t;
        }

        for (syl) |cp| try appendCP(&out, cp);
        alloc.free(syl);
        i = j;
    }
    return out.toOwnedSlice();
}
