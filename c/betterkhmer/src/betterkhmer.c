// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C — betterkhmer. Regex-free; 1:1 with the Go reference.

#include "betterkhmer.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ---- Character categories ---- */

enum {
    CAT_OTHER = 0, CAT_BASE = 1, CAT_ROBAT = 2, CAT_COENG = 3,
    CAT_SHIFT = 4, CAT_Z = 5, CAT_VPRE = 6, CAT_VB = 7, CAT_VA = 8,
    CAT_VPOST = 9, CAT_MS = 10, CAT_MF = 11, CAT_ZFCOENG = 12
};

static int s_cats[0x17DE - 0x1780];

static void init_cats(void) {
    int *c = s_cats;
    for (int i = 0; i < (int)(sizeof s_cats / sizeof *c); i++) c[i] = CAT_OTHER;
    for (int i = 0; i <= 0x17A2 - 0x1780; i++) c[i] = CAT_BASE;
    for (int i = 0x17A5 - 0x1780; i <= 0x17B3 - 0x1780; i++) c[i] = CAT_BASE;
    c[0x17B6 - 0x1780] = CAT_VPOST;
    for (int i = 0x17B7 - 0x1780; i <= 0x17BA - 0x1780; i++) c[i] = CAT_VA;
    for (int i = 0x17BB - 0x1780; i <= 0x17BD - 0x1780; i++) c[i] = CAT_VB;
    for (int i = 0x17BE - 0x1780; i <= 0x17C5 - 0x1780; i++) c[i] = CAT_VPRE;
    c[0x17C6 - 0x1780] = CAT_MS;
    c[0x17C7 - 0x1780] = CAT_MF; c[0x17C8 - 0x1780] = CAT_MF;
    c[0x17C9 - 0x1780] = CAT_SHIFT; c[0x17CA - 0x1780] = CAT_SHIFT;
    c[0x17CB - 0x1780] = CAT_MS; c[0x17CC - 0x1780] = CAT_ROBAT;
    for (int i = 0x17CD - 0x1780; i <= 0x17D1 - 0x1780; i++) c[i] = CAT_MS;
    c[0x17D2 - 0x1780] = CAT_COENG; c[0x17D3 - 0x1780] = CAT_MS;
    for (int i = 0x17D4 - 0x1780; i <= 0x17DC - 0x1780; i++) c[i] = CAT_OTHER;
    c[0x17DD - 0x1780] = CAT_MS;
}

static int charcat(uint32_t cp) {
    if (cp >= 0x1780 && cp <= 0x17DD) return s_cats[cp - 0x1780];
    if (cp == 0x200C) return CAT_Z;
    if (cp == 0x200D) return CAT_ZFCOENG;
    return CAT_OTHER;
}

/* ---- Khmer consonant classes (from the SIL reference khres) ---- */

#define ZWNJ  0x200Cu
#define ZWJ   0x200Du
#define COENG 0x17D2u
#define ROBAT 0x17CCu
#define BA    0x1794u

static int is_base(uint32_t r) {
    return (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC;
}

static int is_non_ro(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) ||
           (r >= 0x17A5 && r <= 0x17B3);
}

static int is_non_ba(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) ||
           (r >= 0x17A5 && r <= 0x17B3);
}

static int is_s1(uint32_t r) {
    if (r >= 0x1780 && r <= 0x1783) return 1;
    if (r >= 0x1785 && r <= 0x1788) return 1;
    if (r >= 0x178A && r <= 0x178D) return 1;
    if (r >= 0x178F && r <= 0x1792) return 1;
    if (r >= 0x1795 && r <= 0x1797) return 1;
    if (r >= 0x179E && r <= 0x17A0) return 1;
    if (r == 0x17A2) return 1;
    return 0;
}

static int is_s2(uint32_t r) {
    if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 ||
        r == 0x1794 || r == 0x17A1) return 1;
    if (r >= 0x1798 && r <= 0x179D) return 1;
    if (r >= 0x17A3 && r <= 0x17B3) return 1;
    return 0;
}

static int is_vpre(uint32_t r) { return r >= 0x17C1 && r <= 0x17C5; }

static int is_digit(uint32_t r) { return r >= 0x17E0 && r <= 0x17E9; }

/* ---- UTF-8 utilities ---- */

static int u8dec(const unsigned char *s, uint32_t *out) {
    uint8_t b = s[0];
    if (b < 0x80) { *out = b; return 1; }
    if (b < 0xE0) { *out = ((b & 0x1F) << 6) | (s[1] & 0x3F); return 2; }
    if (b < 0xF0) { *out = ((b & 0x0F) << 12) | ((s[1] & 0x3F) << 6) | (s[2] & 0x3F); return 3; }
    *out = ((b & 0x07) << 18) | ((s[1] & 0x3F) << 12) | ((s[2] & 0x3F) << 6) | (s[3] & 0x3F);
    return 4;
}

static int u8enc(uint32_t cp, unsigned char *out) {
    if (cp < 0x80) { out[0] = cp; return 1; }
    if (cp < 0x800) { out[0] = 0xC0 | (cp >> 6); out[1] = 0x80 | (cp & 0x3F); return 2; }
    if (cp < 0x10000) {
        out[0] = 0xE0 | (cp >> 12);
        out[1] = 0x80 | ((cp >> 6) & 0x3F);
        out[2] = 0x80 | (cp & 0x3F);
        return 3;
    }
    out[0] = 0xF0 | (cp >> 18); out[1] = 0x80 | ((cp >> 12) & 0x3F);
    out[2] = 0x80 | ((cp >> 6) & 0x3F); out[3] = 0x80 | (cp & 0x3F);
    return 4;
}

/* ---- Dynamic byte buffer ---- */

typedef struct { char *d; size_t n, cap; } Buf;

static void buf_push(Buf *b, const char *s, size_t n) {
    if (b->n + n + 1 > b->cap) {
        b->cap = (b->n + n + 1) * 2 + 64;
        b->d = realloc(b->d, b->cap);
    }
    memcpy(b->d + b->n, s, n);
    b->n += n;
    b->d[b->n] = '\0';
}

static void buf_push_cp(Buf *b, uint32_t cp) {
    unsigned char tmp[4];
    int n = u8enc(cp, tmp);
    buf_push(b, (char *)tmp, n);
}

/* ---- Code-point sequence helper ---- */

typedef struct { uint32_t *r; int n, cap; } Seq;

static Seq seq_new(int cap) {
    Seq s; s.r = malloc((size_t)(cap > 0 ? cap : 1) * sizeof(uint32_t));
    s.n = 0; s.cap = cap > 0 ? cap : 1;
    return s;
}

static void seq_push(Seq *s, uint32_t cp) {
    if (s->n >= s->cap) { s->cap = s->cap * 2 + 8; s->r = realloc(s->r, (size_t)s->cap * sizeof(uint32_t)); }
    s->r[s->n++] = cp;
}

static void seq_push_n(Seq *s, const uint32_t *src, int n) {
    for (int k = 0; k < n; k++) seq_push(s, src[k]);
}

/* ---- optRobat: positions after an optional Robat at p ---- */

/* Writes up to two end positions into pp; returns the count (1 or 2). */
static int opt_robat(const uint32_t *r, int n, int p, int pp[2]) {
    if (p < n && r[p] == ROBAT) { pp[0] = p; pp[1] = p + 1; return 2; }
    pp[0] = p; return 1;
}

/* ---- coengEnds: end indices of one COENG: (?:(?:្ NonRo)? ្ B) ---- */

static int coeng_ends(const uint32_t *r, int n, int s, int ee[2]) {
    int c = 0;
    if (s + 1 < n && r[s] == COENG && is_base(r[s + 1])) ee[c++] = s + 2;
    if (s + 3 < n && r[s] == COENG && is_non_ro(r[s + 1]) &&
        r[s + 2] == COENG && is_base(r[s + 3])) ee[c++] = s + 4;
    return c;
}

/* ---- strongEnds / nstrongEnds ---- */

typedef void (*AddFn)(int e, void *ctx);

static void strong_ends(const uint32_t *r, int n, int s, AddFn add, void *ctx) {
    if (s >= n) return;
    if (is_s1(r[s])) {
        int pp[2]; int np = opt_robat(r, n, s + 1, pp);
        for (int t = 0; t < np; t++) {
            int p = pp[t];
            add(p, ctx);
            if (p + 1 < n && r[p] == COENG && is_non_ba(r[p + 1])) {
                int q = p + 2;
                add(q, ctx);
                if (q + 1 < n && r[q] == COENG && is_non_ba(r[q + 1]))
                    add(q + 2, ctx);
            }
        }
    }
    if (is_non_ba(r[s])) {
        int pp[2]; int np = opt_robat(r, n, s + 1, pp);
        for (int t = 0; t < np; t++) {
            int p = pp[t];
            if (p + 1 < n && r[p] == COENG && is_s1(r[p + 1])) {
                int q = p + 2;
                add(q, ctx);
                if (q + 1 < n && r[q] == COENG && is_non_ba(r[q + 1]))
                    add(q + 2, ctx);
            }
            if (p + 3 < n && r[p] == COENG && is_non_ba(r[p + 1]) &&
                r[p + 2] == COENG && is_s1(r[p + 3]))
                add(p + 4, ctx);
        }
    }
}

static void nstrong_ends(const uint32_t *r, int n, int s, AddFn add, void *ctx) {
    if (s >= n) return;
    if (is_s2(r[s])) {
        int pp[2]; int np = opt_robat(r, n, s + 1, pp);
        for (int t = 0; t < np; t++) {
            int p = pp[t];
            add(p, ctx);
            if (p + 1 < n && r[p] == COENG && is_s2(r[p + 1])) {
                int q = p + 2;
                add(q, ctx);
                if (q + 1 < n && r[q] == COENG && is_s2(r[q + 1]))
                    add(q + 2, ctx);
            }
        }
    }
    if (r[s] == BA) {
        int pp[2]; int np = opt_robat(r, n, s + 1, pp);
        for (int t = 0; t < np; t++) {
            int p = pp[t];
            add(p, ctx);
            int e1[2]; int n1 = coeng_ends(r, n, p, e1);
            for (int a = 0; a < n1; a++) {
                add(e1[a], ctx);
                int e2[2]; int n2 = coeng_ends(r, n, e1[a], e2);
                for (int b = 0; b < n2; b++) add(e2[b], ctx);
            }
        }
    }
    if (is_base(r[s])) {
        int pp[2]; int np = opt_robat(r, n, s + 1, pp);
        for (int t = 0; t < np; t++) {
            int p = pp[t];
            if (p + 3 < n && r[p] == COENG && is_non_ro(r[p + 1]) &&
                r[p + 2] == COENG && r[p + 3] == BA)
                add(p + 4, ctx);
            if (p + 3 < n && r[p] == COENG && r[p + 1] == BA &&
                r[p + 2] == COENG && is_base(r[p + 3]))
                add(p + 4, ctx);
        }
    }
}

typedef void (*EndsFn)(const uint32_t *, int, int, AddFn, void *);

/* ---- canEndAt ---- */

typedef struct { int target; int found; } CanCtx;

static void can_add(int e, void *ctx) {
    CanCtx *c = ctx;
    if (e == c->target) c->found = 1;
}

static int can_end_at(const uint32_t *r, int n, int target, EndsFn ends) {
    for (int s = 0; s < target; s++) {
        CanCtx c = { target, 0 };
        ends(r, n, s, can_add, &c);
        if (c.found) return 1;
    }
    return 0;
}

/* ---- vaSamyokAt: lookahead (?:VA | ័) ---- */

static int va_samyok_at(const uint32_t *r, int n, int p) {
    if (p >= n) return 0;
    uint32_t c = r[p];
    if (c == 0x17D0) return 1;
    if (c >= 0x17B7 && c <= 0x17BA) return 1;
    if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return 1;
    if (c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6) return 1;
    return 0;
}

/* ---- applyShifter (mutates r in place) ---- */

static void apply_shifter(uint32_t *r, int n, EndsFn ends, uint32_t shifter) {
    for (int k = 0; k < n; k++) {
        if (r[k] != 0x17BB) continue;
        int ctx = can_end_at(r, n, k, ends) ||
                  (k >= 1 && is_vpre(r[k - 1]) && can_end_at(r, n, k - 1, ends));
        if (ctx && va_samyok_at(r, n, k + 1)) r[k] = shifter;
    }
}

/* ---- collapseInvis: (‍?្)[្‌‍]+ -> \1 ---- */

static int is_invis(uint32_t c) { return c == COENG || c == ZWNJ || c == ZWJ; }

static Seq collapse_invis(const uint32_t *r, int n) {
    Seq out = seq_new(n);
    int i = 0;
    while (i < n) {
        int g1_end = -1;
        if (r[i] == ZWJ && i + 1 < n && r[i + 1] == COENG) g1_end = i + 2;
        else if (r[i] == COENG) g1_end = i + 1;
        if (g1_end >= 0) {
            int k = g1_end;
            while (k < n && is_invis(r[k])) k++;
            if (k > g1_end) {
                seq_push_n(&out, r + i, g1_end - i);
                i = k;
                continue;
            }
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- pairReplace / pairReplace3 ---- */

static Seq pair_replace(const uint32_t *r, int n, uint32_t a, uint32_t b,
                        const uint32_t *repl, int rn) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (i + 1 < n && r[i] == a && r[i + 1] == b) {
            seq_push_n(&out, repl, rn);
            i += 2;
            continue;
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

static Seq pair_replace3(const uint32_t *r, int n, uint32_t a, uint32_t b,
                         uint32_t c, uint32_t repl) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
            seq_push(&out, repl);
            i += 3;
            continue;
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- vowelSplit: េ([ុ-ួ]?)tail -> head + \1 ---- */

static Seq vowel_split(const uint32_t *r, int n, uint32_t tail, uint32_t head) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17C1) {
            if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail) {
                seq_push(&out, head);
                seq_push(&out, r[i + 1]);
                i += 3;
                continue;
            }
            if (i + 1 < n && r[i + 1] == tail) {
                seq_push(&out, head);
                i += 2;
                continue;
            }
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- coengRo: (្រ)(្[ក-ឳ]) -> \2\1 ---- */

static Seq coeng_ro(const uint32_t *r, int n) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (i + 3 < n && r[i] == COENG && r[i + 1] == 0x179A &&
            r[i + 2] == COENG && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
            seq_push(&out, r[i + 2]);
            seq_push(&out, r[i + 3]);
            seq_push(&out, r[i]);
            seq_push(&out, r[i + 1]);
            i += 4;
            continue;
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- coengDa: (្)ដ -> \1ត ---- */

static Seq coeng_da(const uint32_t *r, int n) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (i + 1 < n && r[i] == COENG && r[i + 1] == 0x178A) {
            seq_push(&out, COENG);
            seq_push(&out, 0x178F);
            i += 2;
            continue;
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0) ---- */

static Seq lunar1(const uint32_t *r, int n) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17E1 && i + 3 < n && is_digit(r[i + 1]) &&
            r[i + 2] == COENG && r[i + 3] == 0x17D4) {
            int v = 10 + (int)(r[i + 1] - 0x17E0);
            if (v > 15) seq_push_n(&out, r + i, 4);
            else seq_push(&out, (uint32_t)(0x19E0 + v));
            i += 4;
            continue;
        }
        if (i + 2 < n && is_digit(r[i]) && r[i + 1] == COENG && r[i + 2] == 0x17D4) {
            seq_push(&out, (uint32_t)(0x19E0 + (int)(r[i] - 0x17E0)));
            i += 3;
            continue;
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0) ---- */

static Seq lunar2(const uint32_t *r, int n) {
    Seq out = seq_new(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == COENG) {
            if (i + 3 < n && r[i + 2] == 0x17E1 && is_digit(r[i + 3])) {
                int v = 10 + (int)(r[i + 3] - 0x17E0);
                if (v > 15) seq_push_n(&out, r + i, 4);
                else seq_push(&out, (uint32_t)(0x19F0 + v));
                i += 4;
                continue;
            }
            if (i + 2 < n && is_digit(r[i + 2])) {
                seq_push(&out, (uint32_t)(0x19F0 + (int)(r[i + 2] - 0x17E0)));
                i += 3;
                continue;
            }
        }
        seq_push(&out, r[i]);
        i++;
    }
    return out;
}

/* ---- hasByteE1: SWAR scan for byte 0xE1 ---- */

static int has_byte_e1(const char *s, size_t len) {
    const uint64_t lo = 0x0101010101010101ULL;
    const uint64_t hi = 0x8080808080808080ULL;
    const uint64_t mask = 0xE1E1E1E1E1E1E1E1ULL;
    const unsigned char *p = (const unsigned char *)s;
    size_t i = 0;
    for (; i + 8 <= len; i += 8) {
        uint64_t w = (uint64_t)p[i] | (uint64_t)p[i + 1] << 8 |
                     (uint64_t)p[i + 2] << 16 | (uint64_t)p[i + 3] << 24 |
                     (uint64_t)p[i + 4] << 32 | (uint64_t)p[i + 5] << 40 |
                     (uint64_t)p[i + 6] << 48 | (uint64_t)p[i + 7] << 56;
        uint64_t x = w ^ mask;
        if ((x - lo) & ~x & hi) return 1;
    }
    for (; i < len; i++) if (p[i] == 0xE1) return 1;
    return 0;
}

/* ---- Sort helper ---- */

static const int *g_sort_cats;
static int cmp_indices(const void *a, const void *b) {
    int ia = *(const int *)a, ib = *(const int *)b;
    if (g_sort_cats[ia] != g_sort_cats[ib]) return g_sort_cats[ia] - g_sort_cats[ib];
    return ia - ib;
}

/* ---- Public API ---- */

char *normalize(const char *txt, const char *lang) {
    static int initialised = 0;
    if (!initialised) { init_cats(); initialised = 1; }

    size_t txtlen = strlen(txt);

    /* SWAR skip/scan fast path: no Khmer byte => identity. */
    if (!has_byte_e1(txt, txtlen)) {
        char *copy = malloc(txtlen + 1);
        memcpy(copy, txt, txtlen + 1);
        return copy;
    }

    /* Decode UTF-8 to code points. */
    uint32_t *raw = malloc((txtlen + 1) * sizeof(uint32_t));
    int rawn = 0;
    {
        const unsigned char *p = (const unsigned char *)txt;
        const unsigned char *end = p + txtlen;
        while (p < end) {
            uint32_t cp; int nb = u8dec(p, &cp); p += nb;
            raw[rawn++] = cp;
        }
    }

    /* XHM pre-step: insert U+200D before each [U+17B6-U+17C5] U+17D2 sequence. */
    uint32_t *cps;
    int n;
    if (lang && strcmp(lang, "xhm") == 0) {
        cps = malloc((size_t)(rawn * 2 + 1) * sizeof(uint32_t));
        n = 0;
        for (int k = 0; k < rawn; k++) {
            if (raw[k] >= 0x17B6 && raw[k] <= 0x17C5 &&
                k + 1 < rawn && raw[k + 1] == 0x17D2) {
                cps[n++] = 0x200D;
            }
            cps[n++] = raw[k];
        }
        free(raw);
    } else {
        cps = raw;
        n = rawn;
    }

    int *cats = malloc((size_t)(n > 0 ? n : 1) * sizeof(int));
    for (int k = 0; k < n; k++) cats[k] = charcat(cps[k]);

    /* Recategorise. */
    for (int i = 1; i < n; i++) {
        if (cps[i - 1] == ZWJ || cps[i - 1] == COENG) {
            if (cats[i] == CAT_BASE || cats[i] == CAT_COENG)
                cats[i] = cats[i - 1];
        }
    }

    Buf res = {0};
    int *indices = malloc((size_t)(n > 0 ? n : 1) * sizeof(int));

    int i = 0;
    while (i < n) {
        if (cats[i] != CAT_BASE) { buf_push_cp(&res, cps[i]); i++; continue; }
        int j = i + 1;
        while (j < n && cats[j] > CAT_BASE) j++;

        int slen = j - i;
        for (int k = 0; k < slen; k++) indices[k] = i + k;
        g_sort_cats = cats;
        qsort(indices, (size_t)slen, sizeof(int), cmp_indices);

        Seq syl = seq_new(slen);
        for (int k = 0; k < slen; k++) seq_push(&syl, cps[indices[k]]);

        Seq t;
        t = collapse_invis(syl.r, syl.n); free(syl.r); syl = t;

        uint32_t r1[2] = { 0x17C4, 0x17B8 };
        t = pair_replace(syl.r, syl.n, 0x17BE, 0x17B6, r1, 2); free(syl.r); syl = t;
        t = vowel_split(syl.r, syl.n, 0x17B8, 0x17BE); free(syl.r); syl = t;
        t = vowel_split(syl.r, syl.n, 0x17B6, 0x17C4); free(syl.r); syl = t;
        uint32_t r2[2] = { 0x17BB, 0x17BE };
        t = pair_replace(syl.r, syl.n, 0x17BE, 0x17BB, r2, 2); free(syl.r); syl = t;

        apply_shifter(syl.r, syl.n, strong_ends, 0x17CA);
        apply_shifter(syl.r, syl.n, nstrong_ends, 0x17C9);

        t = coeng_ro(syl.r, syl.n); free(syl.r); syl = t;
        t = coeng_da(syl.r, syl.n); free(syl.r); syl = t;
        t = lunar1(syl.r, syl.n); free(syl.r); syl = t;
        t = lunar2(syl.r, syl.n); free(syl.r); syl = t;
        t = pair_replace3(syl.r, syl.n, 0x17D4, 0x17D2, 0x17D4, 0x19F0);
        free(syl.r); syl = t;

        for (int k = 0; k < syl.n; k++) buf_push_cp(&res, syl.r[k]);
        free(syl.r);
        i = j;
    }

    free(cps); free(cats); free(indices);
    if (!res.d) { res.d = malloc(1); res.d[0] = '\0'; }
    return res.d;
}
