// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Objective-C — BetterKhmer package. Regex-free.

#import "BetterKhmer.h"

// --- Category constants ---
enum {
    CatOther   = 0,
    CatBase    = 1,
    CatRobat   = 2,
    CatCoeng   = 3,
    CatShift   = 4,
    CatZ       = 5,
    CatVPre    = 6,
    CatVB      = 7,
    CatVA      = 8,
    CatVPost   = 9,
    CatMS      = 10,
    CatMF      = 11,
    CatZFCoeng = 12,
};

enum {
    Zwnj  = 0x200C,
    Zwj   = 0x200D,
    Coeng = 0x17D2,
    Robat = 0x17CC,
    Ba    = 0x1794,
};

#define CAT_LEN (0x17DE - 0x1780)

static int gCategories[CAT_LEN];

static void initCategories(void) {
    int *c = gCategories;
    for (int i = 0; i < CAT_LEN; i++) c[i] = CatOther;
    for (int i = 0; i <= 0x17A2 - 0x1780; i++) c[i] = CatBase;
    for (int i = 0x17A5 - 0x1780; i <= 0x17B3 - 0x1780; i++) c[i] = CatBase;
    c[0x17B6 - 0x1780] = CatVPost;
    for (int i = 0x17B7 - 0x1780; i <= 0x17BA - 0x1780; i++) c[i] = CatVA;
    for (int i = 0x17BB - 0x1780; i <= 0x17BD - 0x1780; i++) c[i] = CatVB;
    for (int i = 0x17BE - 0x1780; i <= 0x17C5 - 0x1780; i++) c[i] = CatVPre;
    c[0x17C6 - 0x1780] = CatMS;
    c[0x17C7 - 0x1780] = CatMF; c[0x17C8 - 0x1780] = CatMF;
    c[0x17C9 - 0x1780] = CatShift; c[0x17CA - 0x1780] = CatShift;
    c[0x17CB - 0x1780] = CatMS; c[0x17CC - 0x1780] = CatRobat;
    for (int i = 0x17CD - 0x1780; i <= 0x17D1 - 0x1780; i++) c[i] = CatMS;
    c[0x17D2 - 0x1780] = CatCoeng; c[0x17D3 - 0x1780] = CatMS;
    for (int i = 0x17D4 - 0x1780; i <= 0x17DC - 0x1780; i++) c[i] = CatOther;
    c[0x17DD - 0x1780] = CatMS;
}

static int charcat(uint32_t cp) {
    if (cp >= 0x1780 && cp <= 0x17DD) return gCategories[cp - 0x1780];
    if (cp == 0x200C) return CatZ;
    if (cp == 0x200D) return CatZFCoeng;
    return CatOther;
}

// --- Khmer consonant classes (from the SIL reference khres) ---

// B: all bases (incl. dotted circle).
static BOOL isBase(uint32_t r) {
    return (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC;
}

// NonRo: consonants excluding Ro (U+179A).
static BOOL isNonRo(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);
}

// NonBA: consonants excluding Ba (U+1794).
static BOOL isNonBA(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);
}

// S1: series-1 consonants.
static BOOL isS1(uint32_t r) {
    if (r >= 0x1780 && r <= 0x1783) return YES;
    if (r >= 0x1785 && r <= 0x1788) return YES;
    if (r >= 0x178A && r <= 0x178D) return YES;
    if (r >= 0x178F && r <= 0x1792) return YES;
    if (r >= 0x1795 && r <= 0x1797) return YES;
    if (r >= 0x179E && r <= 0x17A0) return YES;
    return r == 0x17A2;
}

// S2: series-2 consonants.
static BOOL isS2(uint32_t r) {
    if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 || r == 0x1794 || r == 0x17A1) return YES;
    if (r >= 0x1798 && r <= 0x179D) return YES;
    return r >= 0x17A3 && r <= 0x17B3;
}

static BOOL isVPre(uint32_t r) { return r >= 0x17C1 && r <= 0x17C5; }

// --- Codepoint buffer: a simple growable uint32_t array ---

typedef struct {
    uint32_t *data;
    NSUInteger len;
    NSUInteger cap;
} CpBuf;

static void cpInit(CpBuf *b, NSUInteger cap) {
    if (cap == 0) cap = 16;
    b->data = (uint32_t *)malloc(cap * sizeof(uint32_t));
    b->len = 0;
    b->cap = cap;
}

static void cpFree(CpBuf *b) {
    free(b->data);
    b->data = NULL;
    b->len = 0;
    b->cap = 0;
}

static void cpAdd(CpBuf *b, uint32_t v) {
    if (b->len == b->cap) {
        b->cap = b->cap * 2;
        b->data = (uint32_t *)realloc(b->data, b->cap * sizeof(uint32_t));
    }
    b->data[b->len++] = v;
}

// OptRobat returns the position(s) after an optional Robat at p.
// Writes 1 or 2 positions into out, returns the count.
static int optRobat(const uint32_t *r, NSUInteger n, NSUInteger p, NSUInteger out[2]) {
    if (p < n && r[p] == Robat) {
        out[0] = p;
        out[1] = p + 1;
        return 2;
    }
    out[0] = p;
    return 1;
}

// Ends callback signature: collects end indices.
typedef void (^AddBlock)(NSUInteger);

// CoengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
static void coengEnds(const uint32_t *r, NSUInteger n, NSUInteger s, AddBlock add) {
    if (s + 1 < n && r[s] == Coeng && isBase(r[s + 1])) add(s + 2);
    if (s + 3 < n && r[s] == Coeng && isNonRo(r[s + 1]) && r[s + 2] == Coeng && isBase(r[s + 3]))
        add(s + 4);
}

// StrongEnds enumerates all end indices of a STRONG match starting at s.
static void strongEnds(const uint32_t *r, NSUInteger n, NSUInteger s, AddBlock add) {
    if (s >= n) return;
    if (isS1(r[s])) {
        NSUInteger ps[2];
        int pc = optRobat(r, n, s + 1, ps);
        for (int pi = 0; pi < pc; pi++) {
            NSUInteger p = ps[pi];
            add(p);
            if (p + 1 < n && r[p] == Coeng && isNonBA(r[p + 1])) {
                NSUInteger q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == Coeng && isNonBA(r[q + 1])) add(q + 2);
            }
        }
    }
    if (isNonBA(r[s])) {
        NSUInteger ps[2];
        int pc = optRobat(r, n, s + 1, ps);
        for (int pi = 0; pi < pc; pi++) {
            NSUInteger p = ps[pi];
            if (p + 1 < n && r[p] == Coeng && isS1(r[p + 1])) {
                NSUInteger q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == Coeng && isNonBA(r[q + 1])) add(q + 2);
            }
            if (p + 3 < n && r[p] == Coeng && isNonBA(r[p + 1]) && r[p + 2] == Coeng && isS1(r[p + 3]))
                add(p + 4);
        }
    }
}

// NstrongEnds enumerates all end indices of an NSTRONG match starting at s.
static void nstrongEnds(const uint32_t *r, NSUInteger n, NSUInteger s, AddBlock add) {
    if (s >= n) return;
    if (isS2(r[s])) {
        NSUInteger ps[2];
        int pc = optRobat(r, n, s + 1, ps);
        for (int pi = 0; pi < pc; pi++) {
            NSUInteger p = ps[pi];
            add(p);
            if (p + 1 < n && r[p] == Coeng && isS2(r[p + 1])) {
                NSUInteger q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == Coeng && isS2(r[q + 1])) add(q + 2);
            }
        }
    }
    if (r[s] == Ba) {
        NSUInteger ps[2];
        int pc = optRobat(r, n, s + 1, ps);
        for (int pi = 0; pi < pc; pi++) {
            NSUInteger p = ps[pi];
            add(p);
            coengEnds(r, n, p, ^(NSUInteger e1) {
                add(e1);
                coengEnds(r, n, e1, add);
            });
        }
    }
    if (isBase(r[s])) {
        NSUInteger ps[2];
        int pc = optRobat(r, n, s + 1, ps);
        for (int pi = 0; pi < pc; pi++) {
            NSUInteger p = ps[pi];
            if (p + 3 < n && r[p] == Coeng && isNonRo(r[p + 1]) && r[p + 2] == Coeng && r[p + 3] == Ba)
                add(p + 4);
            if (p + 3 < n && r[p] == Coeng && r[p + 1] == Ba && r[p + 2] == Coeng && isBase(r[p + 3]))
                add(p + 4);
        }
    }
}

typedef void (*EndsFn)(const uint32_t *, NSUInteger, NSUInteger, AddBlock);

// CanEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
static BOOL canEndAt(const uint32_t *r, NSUInteger n, NSUInteger target, EndsFn ends) {
    for (NSUInteger s = 0; s < target; s++) {
        __block BOOL found = NO;
        ends(r, n, s, ^(NSUInteger e) { if (e == target) found = YES; });
        if (found) return YES;
    }
    return NO;
}

// VaSamyokAt is the lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
static BOOL vaSamyokAt(const uint32_t *r, NSUInteger n, NSUInteger p) {
    if (p >= n) return NO;
    uint32_t c = r[p];
    if (c == 0x17D0) return YES;
    if (c >= 0x17B7 && c <= 0x17BA) return YES;
    if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return YES;
    return c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6;
}

// ApplyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
static void applyShifter(uint32_t *r, NSUInteger n, EndsFn ends, uint32_t shifter) {
    for (NSUInteger k = 0; k < n; k++) {
        if (r[k] != 0x17BB) continue;
        BOOL ctx = canEndAt(r, n, k, ends)
            || (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, n, k - 1, ends));
        if (ctx && vaSamyokAt(r, n, k + 1)) r[k] = shifter;
    }
}

static BOOL isInvis(uint32_t c) { return c == Coeng || c == Zwnj || c == Zwj; }

// CollapseInvis: (‍?្)[្‌‍]+ -> \1
static void collapseInvis(CpBuf *src, CpBuf *dst) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        NSInteger g1End = -1;
        if (r[i] == Zwj && i + 1 < n && r[i + 1] == Coeng) g1End = (NSInteger)(i + 2);
        else if (r[i] == Coeng) g1End = (NSInteger)(i + 1);
        if (g1End >= 0) {
            NSUInteger k = (NSUInteger)g1End;
            while (k < n && isInvis(r[k])) k++;
            if (k > (NSUInteger)g1End) {
                for (NSUInteger t = i; t < (NSUInteger)g1End; t++) cpAdd(dst, r[t]);
                i = k;
                continue;
            }
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// PairReplace replaces every non-overlapping [a,b] with [r0,r1].
static void pairReplace(CpBuf *src, CpBuf *dst, uint32_t a, uint32_t b, uint32_t r0, uint32_t r1) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (i + 1 < n && r[i] == a && r[i + 1] == b) {
            cpAdd(dst, r0); cpAdd(dst, r1);
            i += 2;
            continue;
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// PairReplace3 replaces every non-overlapping [a,b,c] with repl.
static void pairReplace3(CpBuf *src, CpBuf *dst, uint32_t a, uint32_t b, uint32_t c, uint32_t repl) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
            cpAdd(dst, repl);
            i += 3;
            continue;
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// VowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
static void vowelSplit(CpBuf *src, CpBuf *dst, uint32_t tail, uint32_t head) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (r[i] == 0x17C1) {
            if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail) {
                cpAdd(dst, head); cpAdd(dst, r[i + 1]);
                i += 3;
                continue;
            }
            if (i + 1 < n && r[i + 1] == tail) {
                cpAdd(dst, head);
                i += 2;
                continue;
            }
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// CoengRo: (្រ)(្[ក-ឳ]) -> \2\1
static void coengRo(CpBuf *src, CpBuf *dst) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (i + 3 < n && r[i] == Coeng && r[i + 1] == 0x179A
            && r[i + 2] == Coeng && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
            cpAdd(dst, r[i + 2]); cpAdd(dst, r[i + 3]); cpAdd(dst, r[i]); cpAdd(dst, r[i + 1]);
            i += 4;
            continue;
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// CoengDa: (្)ដ -> \1ត
static void coengDa(CpBuf *src, CpBuf *dst) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (i + 1 < n && r[i] == Coeng && r[i + 1] == 0x178A) {
            cpAdd(dst, Coeng); cpAdd(dst, 0x178F);
            i += 2;
            continue;
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

static BOOL isDigit(uint32_t r) { return r >= 0x17E0 && r <= 0x17E9; }

// Lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
static void lunar1(CpBuf *src, CpBuf *dst) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (r[i] == 0x17E1 && i + 3 < n && isDigit(r[i + 1]) && r[i + 2] == Coeng && r[i + 3] == 0x17D4) {
            uint32_t v = 10 + (r[i + 1] - 0x17E0);
            if (v > 15) {
                for (NSUInteger t = i; t < i + 4; t++) cpAdd(dst, r[t]);
            } else {
                cpAdd(dst, 0x19E0 + v);
            }
            i += 4;
            continue;
        }
        if (i + 2 < n && isDigit(r[i]) && r[i + 1] == Coeng && r[i + 2] == 0x17D4) {
            cpAdd(dst, 0x19E0 + (r[i] - 0x17E0));
            i += 3;
            continue;
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// Lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
static void lunar2(CpBuf *src, CpBuf *dst) {
    const uint32_t *r = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 1);
    NSUInteger i = 0;
    while (i < n) {
        if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == Coeng) {
            if (i + 3 < n && r[i + 2] == 0x17E1 && isDigit(r[i + 3])) {
                uint32_t v = 10 + (r[i + 3] - 0x17E0);
                if (v > 15) {
                    for (NSUInteger t = i; t < i + 4; t++) cpAdd(dst, r[t]);
                } else {
                    cpAdd(dst, 0x19F0 + v);
                }
                i += 4;
                continue;
            }
            if (i + 2 < n && isDigit(r[i + 2])) {
                cpAdd(dst, 0x19F0 + (r[i + 2] - 0x17E0));
                i += 3;
                continue;
            }
        }
        cpAdd(dst, r[i]);
        i++;
    }
}

// HasByteE1 reports whether s contains UTF-8 byte 0xE1, scanned 8 bytes at a
// time (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte
// 0xE1, so no 0xE1 means no Khmer codepoint and the input is unchanged.
static BOOL hasByteE1(const uint8_t *s, NSUInteger len) {
    const uint64_t lo   = 0x0101010101010101ULL;
    const uint64_t hi   = 0x8080808080808080ULL;
    const uint64_t mask = 0xE1E1E1E1E1E1E1E1ULL;
    NSUInteger i = 0;
    for (; i + 8 <= len; i += 8) {
        uint64_t w = (uint64_t)s[i] | (uint64_t)s[i + 1] << 8 | (uint64_t)s[i + 2] << 16 | (uint64_t)s[i + 3] << 24
            | (uint64_t)s[i + 4] << 32 | (uint64_t)s[i + 5] << 40 | (uint64_t)s[i + 6] << 48 | (uint64_t)s[i + 7] << 56;
        uint64_t x = w ^ mask;
        if (((x - lo) & ~x & hi) != 0) return YES;
    }
    for (; i < len; i++) {
        if (s[i] == 0xE1) return YES;
    }
    return NO;
}

// CodePoints decodes txt (a UTF-16 NSString) into an array of Unicode code points.
static void codePoints(NSString *txt, CpBuf *out) {
    NSUInteger u16len = txt.length;
    cpInit(out, u16len + 1);
    if (u16len == 0) return;
    unichar *u = (unichar *)malloc(u16len * sizeof(unichar));
    [txt getCharacters:u range:NSMakeRange(0, u16len)];
    NSUInteger i = 0;
    while (i < u16len) {
        unichar c = u[i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < u16len) {
            unichar lo = u[i + 1];
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                uint32_t cp = 0x10000 + (((uint32_t)(c - 0xD800)) << 10) + (uint32_t)(lo - 0xDC00);
                cpAdd(out, cp);
                i += 2;
                continue;
            }
        }
        cpAdd(out, (uint32_t)c);
        i += 1;
    }
    free(u);
}

// Encodes a codepoint array back into an NSString.
static NSString *fromCodePoints(const uint32_t *cps, NSUInteger n) {
    // Worst case: every codepoint is astral (2 UTF-16 units).
    unichar *u = (unichar *)malloc((n * 2 + 1) * sizeof(unichar));
    NSUInteger w = 0;
    for (NSUInteger i = 0; i < n; i++) {
        uint32_t cp = cps[i];
        if (cp > 0xFFFF) {
            cp -= 0x10000;
            u[w++] = (unichar)(0xD800 + (cp >> 10));
            u[w++] = (unichar)(0xDC00 + (cp & 0x3FF));
        } else {
            u[w++] = (unichar)cp;
        }
    }
    NSString *s = [[NSString alloc] initWithCharacters:u length:w];
    free(u);
    return s;
}

// XhmPrefix replaces [ិ-ៅ]្ with ‍$0 (prepend U+200D before the pair).
static void xhmPrefix(CpBuf *src, CpBuf *dst) {
    const uint32_t *cps = src->data;
    NSUInteger n = src->len;
    cpInit(dst, n + 8);
    for (NSUInteger i = 0; i < n; i++) {
        if (i + 1 < n && cps[i] >= 0x17B7 && cps[i] <= 0x17C5 && cps[i + 1] == Coeng) {
            cpAdd(dst, Zwj);
            cpAdd(dst, cps[i]);
            cpAdd(dst, cps[i + 1]);
            i++;
            continue;
        }
        cpAdd(dst, cps[i]);
    }
}

@implementation BetterKhmer

+ (void)initialize {
    if (self == [BetterKhmer class]) {
        initCategories();
    }
}

+ (NSString *)normalize:(NSString *)txt {
    return [self normalize:txt lang:@"km"];
}

+ (NSString *)normalize:(NSString *)txt lang:(NSString *)lang {
    BOOL isXhm = [lang isEqualToString:@"xhm"];

    // SWAR skip/scan fast path: no Khmer byte => identity.
    if (!isXhm) {
        const char *utf8 = [txt UTF8String];
        NSUInteger blen = [txt lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (!hasByteE1((const uint8_t *)utf8, blen)) {
            return txt;
        }
    }

    CpBuf cpsBuf;
    codePoints(txt, &cpsBuf);

    if (isXhm) {
        CpBuf tmp;
        xhmPrefix(&cpsBuf, &tmp);
        cpFree(&cpsBuf);
        cpsBuf = tmp;
    }

    uint32_t *cps = cpsBuf.data;
    NSUInteger n = cpsBuf.len;

    int *cats = (int *)malloc((n == 0 ? 1 : n) * sizeof(int));
    for (NSUInteger i = 0; i < n; i++) cats[i] = charcat(cps[i]);

    for (NSUInteger i = 1; i < n; i++) {
        if (cps[i - 1] == Zwj || cps[i - 1] == Coeng) {
            if (cats[i] == CatBase || cats[i] == CatCoeng)
                cats[i] = cats[i - 1];
        }
    }

    CpBuf res;
    cpInit(&res, n + 8);

    NSUInteger idx = 0;
    while (idx < n) {
        if (cats[idx] != CatBase) {
            cpAdd(&res, cps[idx]);
            idx++;
            continue;
        }
        NSUInteger j = idx + 1;
        while (j < n && cats[j] > CatBase) j++;

        NSUInteger count = j - idx;

        // Stable sort indices [idx, j) by (cats[k], k). Original order is already
        // ascending by k, so a stable sort on cats preserves the tie-break by k.
        NSUInteger *indices = (NSUInteger *)malloc(count * sizeof(NSUInteger));
        for (NSUInteger k = 0; k < count; k++) indices[k] = idx + k;
        // Insertion sort (stable) keyed on cats.
        for (NSUInteger a = 1; a < count; a++) {
            NSUInteger key = indices[a];
            int keyCat = cats[key];
            NSInteger b = (NSInteger)a - 1;
            while (b >= 0 && cats[indices[b]] > keyCat) {
                indices[b + 1] = indices[b];
                b--;
            }
            indices[b + 1] = key;
        }

        CpBuf syl;
        cpInit(&syl, count + 1);
        for (NSUInteger k = 0; k < count; k++) cpAdd(&syl, cps[indices[k]]);
        free(indices);

        CpBuf a, b;

        collapseInvis(&syl, &a);                                         cpFree(&syl);
        pairReplace(&a, &b, 0x17BE, 0x17B6, 0x17C4, 0x17B8);             cpFree(&a); // ើា -> ោី
        vowelSplit(&b, &a, 0x17B8, 0x17BE);                               cpFree(&b); // េ(◌)ី -> ើ(◌)
        vowelSplit(&a, &b, 0x17B6, 0x17C4);                               cpFree(&a); // េ(◌)ា -> ោ(◌)
        pairReplace(&b, &a, 0x17BE, 0x17BB, 0x17BB, 0x17BE);             cpFree(&b); // ើុ -> ុើ
        applyShifter(a.data, a.len, strongEnds, 0x17CA);                              // strong  -u -> ៊
        applyShifter(a.data, a.len, nstrongEnds, 0x17C9);                             // weak    -u -> ៉
        coengRo(&a, &b);                                                  cpFree(&a);
        coengDa(&b, &a);                                                  cpFree(&b);
        lunar1(&a, &b);                                                   cpFree(&a);
        lunar2(&b, &a);                                                   cpFree(&b);
        pairReplace3(&a, &b, 0x17D4, 0x17D2, 0x17D4, 0x19F0);            cpFree(&a); // ។្។ -> ᧰

        for (NSUInteger k = 0; k < b.len; k++) cpAdd(&res, b.data[k]);
        cpFree(&b);

        idx = j;
    }

    free(cats);
    cpFree(&cpsBuf);

    NSString *out = fromCodePoints(res.data, res.len);
    cpFree(&res);
    return out;
}

@end
