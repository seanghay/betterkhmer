// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Zig (PCRE2 via extern) — betterkhmer package.

const std = @import("std");
const mem = std.mem;

// ---- PCRE2 extern declarations ----

const PCRE2_UTF                      : u32   = 0x00080000;
const PCRE2_UCP                      : u32   = 0x00020000;
const PCRE2_SUBSTITUTE_GLOBAL        : u32   = 0x00000100;
const PCRE2_SUBSTITUTE_EXTENDED      : u32   = 0x00000200;
const PCRE2_SUBSTITUTE_OVERFLOW_LENGTH: u32  = 0x00001000;
const PCRE2_ERROR_NOMEMORY           : i32   = -48;
const PCRE2_ZERO_TERMINATED          : usize = ~@as(usize, 0);
const PCRE2_UNSET                    : usize = ~@as(usize, 0);

const Code      = opaque {};
const MatchData = opaque {};

extern fn pcre2_compile_8(
    pattern: [*]const u8, length: usize, options: u32,
    errorcode: *i32, erroroffset: *usize, context: ?*anyopaque,
) ?*Code;
extern fn pcre2_code_free_8(code: *Code) void;
extern fn pcre2_match_data_create_from_pattern_8(code: *Code, ctx: ?*anyopaque) ?*MatchData;
extern fn pcre2_match_data_free_8(md: *MatchData) void;
extern fn pcre2_match_8(
    code: *Code, subject: [*]const u8, length: usize, startoffset: usize,
    options: u32, match_data: *MatchData, context: ?*anyopaque,
) i32;
extern fn pcre2_get_ovector_pointer_8(md: *MatchData) [*]usize;
extern fn pcre2_substitute_8(
    code: *Code, subject: [*]const u8, length: usize, startoffset: usize,
    options: u32, match_data: ?*MatchData, context: ?*anyopaque,
    replacement: [*]const u8, rlength: usize,
    outputbuffer: [*]u8, outlengthptr: *usize,
) i32;

// ---- PCRE2 wrapper ----

const Re = struct {
    code: *Code,

    fn init(pat: []const u8) Re {
        var err: i32 = undefined;
        var erroff: usize = undefined;
        const code = pcre2_compile_8(pat.ptr, pat.len, PCRE2_UTF | PCRE2_UCP,
                                     &err, &erroff, null) orelse @panic("bad regex");
        return .{ .code = code };
    }

    fn deinit(self: Re) void { pcre2_code_free_8(self.code); }
};

fn subStr(re: Re, alloc: mem.Allocator, s: []const u8, repl: []const u8) ![]u8 {
    var bufcap: usize = s.len * 2 + 256;
    var buf = try alloc.alloc(u8, bufcap);
    var outlen: usize = bufcap;

    var rc = pcre2_substitute_8(
        re.code, s.ptr, s.len, 0,
        PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
        null, null, repl.ptr, repl.len, buf.ptr, &outlen,
    );
    if (rc == PCRE2_ERROR_NOMEMORY) {
        alloc.free(buf);
        bufcap = outlen + 1;
        buf = try alloc.alloc(u8, bufcap);
        outlen = bufcap;
        rc = pcre2_substitute_8(
            re.code, s.ptr, s.len, 0,
            PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED,
            null, null, repl.ptr, repl.len, buf.ptr, &outlen,
        );
    }
    if (rc < 0) { alloc.free(buf); return try alloc.dupe(u8, s); }
    const result = try alloc.dupe(u8, buf[0..outlen]);
    alloc.free(buf);
    return result;
}

fn subLunar(re: Re, alloc: mem.Allocator, input: []const u8, base: u21) ![]u8 {
    const md = pcre2_match_data_create_from_pattern_8(re.code, null) orelse return error.OutOfMemory;
    defer pcre2_match_data_free_8(md);
    var out = std.ArrayList(u8).init(alloc);
    var pos: usize = 0;
    while (pos <= input.len) {
        const rc = pcre2_match_8(re.code, input.ptr, input.len, pos, 0, md, null);
        if (rc < 0) { try out.appendSlice(input[pos..]); break; }
        const ov = pcre2_get_ovector_pointer_8(md);
        const ms = ov[0]; const me = ov[1];
        try out.appendSlice(input[pos..ms]);
        var v1: u21 = 0;
        if (ov[2] != PCRE2_UNSET and ov[3] > ov[2]) {
            const r = u8dec(input[ov[2]..]);
            v1 = r.cp - 0x17E0;
        }
        const r2 = u8dec(input[ov[4]..]);
        const v = v1 * 10 + (r2.cp - 0x17E0);
        if (v <= 15) try appendCP(&out, base + v)
        else try out.appendSlice(input[ms..me]);
        if (me == ms) { if (ms < input.len) try out.append(input[ms]); pos = ms + 1; }
        else pos = me;
    }
    return out.toOwnedSlice();
}

// ---- Character categories ----

const Cat = enum(u8) {
    other=0, base=1, robat=2, coeng=3, shift=4, z=5,
    vpre=6, vb=7, va=8, vpost=9, ms=10, mf=11, zfcoeng=12,
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

// ---- UTF-8 helpers ----

const Decoded = struct { cp: u21, len: u3 };

fn u8dec(s: []const u8) Decoded {
    const b = s[0];
    if (b < 0x80) return .{ .cp = b, .len = 1 };
    if (b < 0xE0) return .{ .cp = @as(u21, b & 0x1F) << 6 | (s[1] & 0x3F), .len = 2 };
    if (b < 0xF0) return .{
        .cp = @as(u21, b & 0x0F) << 12 | @as(u21, s[1] & 0x3F) << 6 | (s[2] & 0x3F),
        .len = 3 };
    return .{
        .cp = @as(u21, b & 0x07) << 18 | @as(u21, s[1] & 0x3F) << 12 |
              @as(u21, s[2] & 0x3F) << 6 | (s[3] & 0x3F),
        .len = 4 };
}

fn u8enc(cp: u21, buf: []u8) u3 {
    if (cp < 0x80) { buf[0] = @intCast(cp); return 1; }
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

// ---- Khmer patterns (raw UTF-8) ----

const PAT_B       = "[\xe1\x9e\x80-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3\xe2\x97\x8c]";
const PAT_NON_RO  = "[\xe1\x9e\x80-\xe1\x9e\x99\xe1\x9e\x9b-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]";
const PAT_NON_BA  = "[\xe1\x9e\x80-\xe1\x9e\x93\xe1\x9e\x95-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]";
const PAT_S1      = "[\xe1\x9e\x80-\xe1\x9e\x83\xe1\x9e\x85-\xe1\x9e\x88\xe1\x9e\x8a-\xe1\x9e\x8d\xe1\x9e\x8f-\xe1\x9e\x92\xe1\x9e\x95-\xe1\x9e\x97\xe1\x9e\x9e-\xe1\x9e\xa0\xe1\x9e\xa2]";
const PAT_S2      = "[\xe1\x9e\x84\xe1\x9e\x80\xe1\x9e\x8e\xe1\x9e\x93\xe1\x9e\x94\xe1\x9e\x98-\xe1\x9e\x9d\xe1\x9e\xa1\xe1\x9e\xa3-\xe1\x9e\xb3]";
const PAT_VA      = "(?:[\xe1\x9e\xb7-\xe1\x9e\xba\xe1\x9e\xbe\xe1\x9e\xbf\xe1\x9f\x9d]|\xe1\x9e\xb6\xe1\x9f\x86)";
const PAT_COENG   = "(?:(?:\xe1\x9f\x92" ++ PAT_NON_RO ++ ")?\xe1\x9f\x92" ++ PAT_B ++ ")";
const PAT_STRONG  =
    PAT_S1 ++ "\xe1\x9f\x8c?(?:\xe1\x9f\x92" ++ PAT_NON_BA ++ "(?:\xe1\x9f\x92" ++ PAT_NON_BA ++ ")?)?" ++
    "|" ++ PAT_NON_BA ++ "\xe1\x9f\x8c?(?:\xe1\x9f\x92" ++ PAT_S1 ++ "(?:\xe1\x9f\x92" ++ PAT_NON_BA ++ ")?" ++
    "|\xe1\x9f\x92" ++ PAT_NON_BA ++ "\xe1\x9f\x92" ++ PAT_S1 ++ ")";
const PAT_NSTRONG =
    "(?:" ++ PAT_S2 ++ "\xe1\x9f\x8c?(?:\xe1\x9f\x92" ++ PAT_S2 ++ "(?:\xe1\x9f\x92" ++ PAT_S2 ++ ")?)?" ++
    "|\xe1\x9e\x94\xe1\x9f\x8c?(?:" ++ PAT_COENG ++ "(?:" ++ PAT_COENG ++ ")?)?" ++
    "|" ++ PAT_B ++ "\xe1\x9f\x8c?(?:\xe1\x9f\x92" ++ PAT_NON_RO ++ "\xe1\x9f\x92\xe1\x9e\x94" ++
    "|\xe1\x9f\x92\xe1\x9e\x94(?:\xe1\x9f\x92" ++ PAT_B ++ ")))";

// ---- Compiled patterns (lazy singleton) ----

const Patterns = struct {
    invis:   Re,
    vbe:     Re,
    v1:      Re,
    v2:      Re,
    v3:      Re,
    strong:  Re,
    nstrong: Re,
    coengRo: Re,
    coengDa: Re,
    lunar1:  Re,
    lunar2:  Re,
    xhm:     Re,
};

var g_patterns: Patterns = undefined;
var g_inited: bool = false;

fn ensureInit() void {
    if (g_inited) return;
    g_inited = true;
    g_patterns = Patterns{
        .invis   = Re.init("(\xe2\x80\x8d?\xe1\x9f\x92)[\xe1\x9f\x92\xe2\x80\x8c\xe2\x80\x8d]+"),
        .vbe     = Re.init("\xe1\x9e\xbe\xe1\x9e\xb6"),
        .v1      = Re.init("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb8"),
        .v2      = Re.init("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb6"),
        .v3      = Re.init("(\xe1\x9e\xbe)(\xe1\x9e\xbb)"),
        .strong  = Re.init("((?:" ++ PAT_STRONG  ++ ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb(?=" ++ PAT_VA ++ "|\xe1\x9f\x90)"),
        .nstrong = Re.init("((?:" ++ PAT_NSTRONG ++ ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb(?=" ++ PAT_VA ++ "|\xe1\x9f\x90)"),
        .coengRo = Re.init("(\xe1\x9f\x92\xe1\x9e\x9a)(\xe1\x9f\x92[\xe1\x9e\x80-\xe1\x9e\xb3])"),
        .coengDa = Re.init("\xe1\x9f\x92\xe1\x9e\x8a"),
        .lunar1  = Re.init("(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])\xe1\x9f\x92\xe1\x9f\x94"),
        .lunar2  = Re.init("\xe1\x9f\x94\xe1\x9f\x92(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])"),
        .xhm     = Re.init("[\xe1\x9e\xb6-\xe1\x9f\x85]\xe1\x9f\x92"),
    };
}

// ---- Sort context (insertionContext API: operates on index positions) ----

const SortCtx = struct {
    cats:    []Cat,
    indices: []usize,

    pub fn lessThan(ctx: SortCtx, a: usize, b: usize) bool {
        const ia = ctx.indices[a]; const ib = ctx.indices[b];
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
    ensureInit();
    const R = &g_patterns;

    var owned: ?[]u8 = null;
    var input: []const u8 = txt;
    if (mem.eql(u8, lang, "xhm")) {
        owned = try subStr(R.xhm, alloc, txt, "\xe2\x80\x8d$0");
        input = owned.?;
    }
    defer if (owned) |o| alloc.free(o);

    // Decode
    var cps  = std.ArrayList(u21).init(alloc); defer cps.deinit();
    var cats = std.ArrayList(Cat).init(alloc);  defer cats.deinit();
    var p: usize = 0;
    while (p < input.len) {
        const r = u8dec(input[p..]);
        try cps.append(r.cp);
        try cats.append(charcat(r.cp));
        p += r.len;
    }
    const n = cps.items.len;

    // Recategorise
    for (1..n) |i| {
        const prev = cps.items[i - 1];
        if (prev == 0x200D or prev == 0x17D2) {
            if (cats.items[i] == .base or cats.items[i] == .zfcoeng)
                cats.items[i] = cats.items[i - 1];
        }
    }

    // Process
    var out     = std.ArrayList(u8).init(alloc);
    var indices = std.ArrayList(usize).init(alloc); defer indices.deinit();

    var i: usize = 0;
    while (i < n) {
        if (cats.items[i] != .base) { try appendCP(&out, cps.items[i]); i += 1; continue; }
        var j = i + 1;
        while (j < n and @intFromEnum(cats.items[j]) > @intFromEnum(Cat.base)) : (j += 1) {}

        try indices.resize(j - i);
        for (0..j - i) |k| indices.items[k] = i + k;
        std.sort.insertionContext(0, indices.items.len, SortCtx{
            .cats = cats.items, .indices = indices.items,
        });

        var syl = std.ArrayList(u8).init(alloc);
        for (indices.items) |k| try appendCP(&syl, cps.items[k]);
        var s = try syl.toOwnedSlice();

        inline for (.{
            .{ R.invis,   "$1" },
            .{ R.vbe,     "\xe1\x9f\x84\xe1\x9e\xb8" },
            .{ R.v1,      "\xe1\x9e\xbe$1" },
            .{ R.v2,      "\xe1\x9f\x84$1" },
            .{ R.v3,      "$2$1" },
            .{ R.strong,  "$1\xe1\x9f\x8a" },
            .{ R.nstrong, "$1\xe1\x9f\x89" },
            .{ R.coengRo, "$2$1" },
            .{ R.coengDa, "\xe1\x9f\x92\xe1\x9e\x8f" },
        }) |pair| {
            const ns = try subStr(pair[0], alloc, s, pair[1]);
            alloc.free(s); s = ns;
        }

        const ns1 = try subLunar(R.lunar1, alloc, s, 0x19E0); alloc.free(s); s = ns1;
        const ns2 = try subLunar(R.lunar2, alloc, s, 0x19F0); alloc.free(s); s = ns2;

        const khan = "\xe1\x9f\x94\xe1\x9f\x92\xe1\x9f\x94";
        if (mem.indexOf(u8, s, khan) != null) {
            var rep = std.ArrayList(u8).init(alloc);
            var pos2: usize = 0;
            while (mem.indexOf(u8, s[pos2..], khan)) |idx| {
                try rep.appendSlice(s[pos2 .. pos2 + idx]);
                try rep.appendSlice("\xe1\xa7\xb0");
                pos2 += idx + khan.len;
            }
            try rep.appendSlice(s[pos2..]);
            alloc.free(s); s = try rep.toOwnedSlice();
        }

        try out.appendSlice(s);
        alloc.free(s);
        i = j;
    }
    return out.toOwnedSlice();
}
