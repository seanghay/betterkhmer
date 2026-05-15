// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C (PCRE2) — betterkhmer.

#define PCRE2_CODE_UNIT_WIDTH 8
#include "betterkhmer.h"
#include <pcre2.h>
#include <stdint.h>
#include <stdio.h>
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

/* ---- Dynamic buffer ---- */

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

/* ---- PCRE2 helpers ---- */

static pcre2_code *mkre(const char *pat) {
    int err;
    PCRE2_SIZE erroff;
    pcre2_code *re = pcre2_compile(
        (PCRE2_SPTR)pat, PCRE2_ZERO_TERMINATED,
        PCRE2_UTF | PCRE2_UCP, &err, &erroff, NULL);
    if (!re) {
        PCRE2_UCHAR msg[256];
        pcre2_get_error_message(err, msg, sizeof msg);
        fprintf(stderr, "betterkhmer: bad pattern at offset %zu: %s\n", erroff, (char *)msg);
        abort();
    }
    return re;
}

/* Global substitute with a fixed replacement template (supports $0, $1, $2). */
static char *sub_str(pcre2_code *re, const char *s, const char *repl) {
    size_t inlen = strlen(s);
    size_t bufcap = inlen * 2 + 256;
    char *buf = malloc(bufcap);
    PCRE2_SIZE outlen = bufcap;
    int rc = pcre2_substitute(re, (PCRE2_SPTR)s, inlen, 0,
        PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED |
        PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
        NULL, NULL,
        (PCRE2_SPTR)repl, PCRE2_ZERO_TERMINATED,
        (PCRE2_UCHAR *)buf, &outlen);
    if (rc == PCRE2_ERROR_NOMEMORY) {
        free(buf);
        bufcap = outlen + 1;
        buf = malloc(bufcap);
        outlen = bufcap;
        rc = pcre2_substitute(re, (PCRE2_SPTR)s, inlen, 0,
            PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED,
            NULL, NULL,
            (PCRE2_SPTR)repl, PCRE2_ZERO_TERMINATED,
            (PCRE2_UCHAR *)buf, &outlen);
    }
    if (rc < 0) { free(buf); return strdup(s); }
    return buf;
}

/* Global substitute with a callback: fn returns a malloc'd replacement. */
typedef char *(*SubFn)(const char *input, size_t ms, size_t me,
                       int ng, const PCRE2_SIZE *ov, void *ctx);

static char *sub_fn(pcre2_code *re, const char *input, SubFn fn, void *ctx) {
    size_t inlen = strlen(input);
    pcre2_match_data *md = pcre2_match_data_create_from_pattern(re, NULL);
    Buf out = {0};
    size_t pos = 0;
    while (pos <= inlen) {
        int rc = pcre2_match(re, (PCRE2_SPTR)input, inlen, pos, 0, md, NULL);
        if (rc < 0) { buf_push(&out, input + pos, inlen - pos); break; }
        const PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
        size_t ms = ov[0], me = ov[1];
        buf_push(&out, input + pos, ms - pos);
        char *repl = fn(input, ms, me, rc, ov, ctx);
        buf_push(&out, repl, strlen(repl));
        free(repl);
        if (me == ms) { if (ms < inlen) buf_push(&out, input + ms, 1); pos = ms + 1; }
        else pos = me;
    }
    pcre2_match_data_free(md);
    return out.d ? out.d : strdup("");
}

/* Simple literal string replace (all occurrences). */
static char *str_replace_all(const char *src, const char *needle, const char *repl) {
    size_t nlen = strlen(needle), rlen = strlen(repl);
    Buf out = {0};
    const char *p = src;
    const char *found;
    while ((found = strstr(p, needle)) != NULL) {
        buf_push(&out, p, (size_t)(found - p));
        buf_push(&out, repl, rlen);
        p = found + nlen;
    }
    buf_push(&out, p, strlen(p));
    return out.d ? out.d : strdup(src);
}

/* ---- Khmer regex patterns (all chars as raw UTF-8 bytes) ---- */

/* Component definitions using raw UTF-8 byte sequences for Khmer code points:
   \xe1\x9e\x80 = U+1780, \xe1\x9e\xa2 = U+17A2, \xe1\x9e\xa5 = U+17A5,
   \xe1\x9e\xb3 = U+17B3, \xe2\x97\x8c = U+25CC (dotted circle).            */
#define B      "[\xe1\x9e\x80-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3\xe2\x97\x8c]"
#define NON_RO "[\xe1\x9e\x80-\xe1\x9e\x99\xe1\x9e\x9b-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]"
#define NON_BA "[\xe1\x9e\x80-\xe1\x9e\x93\xe1\x9e\x95-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]"
#define S1     "[\xe1\x9e\x80-\xe1\x9e\x83\xe1\x9e\x85-\xe1\x9e\x88\xe1\x9e\x8a-\xe1\x9e\x8d\xe1\x9e\x8f-\xe1\x9e\x92\xe1\x9e\x95-\xe1\x9e\x97\xe1\x9e\x9e-\xe1\x9e\xa0\xe1\x9e\xa2]"
#define S2     "[\xe1\x9e\x84\xe1\x9e\x80\xe1\x9e\x8e\xe1\x9e\x93\xe1\x9e\x94\xe1\x9e\x98-\xe1\x9e\x9d\xe1\x9e\xa1\xe1\x9e\xa3-\xe1\x9e\xb3]"
/* VA: [U+17B7-U+17BA, U+17BE, U+17BF, U+17DD] | U+17B6 U+17C6 */
#define VA     "(?:[\xe1\x9e\xb7-\xe1\x9e\xba\xe1\x9e\xbe\xe1\x9e\xbf\xe1\x9f\x9d]|\xe1\x9e\xb6\xe1\x9f\x86)"
/* U+17D2 = COENG \xe1\x9f\x92 */
#define COENG  "(?:(?:\xe1\x9f\x92" NON_RO ")?\xe1\x9f\x92" B ")"
/* U+17CC = ROBAT \xe1\x9f\x8c, U+1794 = BA \xe1\x9e\x94 */
#define STRONG \
    S1 "\xe1\x9f\x8c?(?:\xe1\x9f\x92" NON_BA "(?:\xe1\x9f\x92" NON_BA ")?)?" \
    "|" NON_BA "\xe1\x9f\x8c?(?:\xe1\x9f\x92" S1 "(?:\xe1\x9f\x92" NON_BA ")?" \
    "|\xe1\x9f\x92" NON_BA "\xe1\x9f\x92" S1 ")"
#define NSTRONG \
    "(?:" S2 "\xe1\x9f\x8c?(?:\xe1\x9f\x92" S2 "(?:\xe1\x9f\x92" S2 ")?)?" \
    "|\xe1\x9e\x94\xe1\x9f\x8c?(?:" COENG "(?:" COENG ")?)?" \
    "|" B "\xe1\x9f\x8c?(?:\xe1\x9f\x92" NON_RO "\xe1\x9f\x92\xe1\x9e\x94" \
    "|\xe1\x9f\x92\xe1\x9e\x94(?:\xe1\x9f\x92" B ")))"

/* Compiled patterns (initialised once) */
static pcre2_code *re_invis, *re_vbe, *re_v1, *re_v2, *re_v3;
static pcre2_code *re_strong, *re_nstrong;
static pcre2_code *re_coeng_ro, *re_coeng_da;
static pcre2_code *re_lunar1, *re_lunar2;
static pcre2_code *re_xhm;

static void init_re(void) {
    /* RE_INVIS: (U+200D? U+17D2) [U+17D2 U+200C U+200D]+ */
    re_invis = mkre("(\xe2\x80\x8d?\xe1\x9f\x92)[\xe1\x9f\x92\xe2\x80\x8c\xe2\x80\x8d]+");
    /* RE_VBE: U+17BE U+17B6 */
    re_vbe = mkre("\xe1\x9e\xbe\xe1\x9e\xb6");
    /* RE_V1: U+17C1 ([U+17BB-U+17BD]?) U+17B8 */
    re_v1 = mkre("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb8");
    /* RE_V2: U+17C1 ([U+17BB-U+17BD]?) U+17B6 */
    re_v2 = mkre("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb6");
    /* RE_V3: (U+17BE)(U+17BB) */
    re_v3 = mkre("(\xe1\x9e\xbe)(\xe1\x9e\xbb)");
    /* RE_STRONG / RE_NSTRONG: capture group 1 = STRONG+VPre?, then U+17BB,
       lookahead VA | U+17D0 */
    re_strong  = mkre("((?:" STRONG  ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb"
                      "(?=" VA "|\xe1\x9f\x90)");
    re_nstrong = mkre("((?:" NSTRONG ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb"
                      "(?=" VA "|\xe1\x9f\x90)");
    /* RE_COENG_RO: (U+17D2 U+179A)(U+17D2 [U+1780-U+17B3]) */
    re_coeng_ro = mkre("(\xe1\x9f\x92\xe1\x9e\x9a)(\xe1\x9f\x92[\xe1\x9e\x80-\xe1\x9e\xb3])");
    /* RE_COENG_DA: U+17D2 U+178A */
    re_coeng_da = mkre("\xe1\x9f\x92\xe1\x9e\x8a");
    /* RE_LUNAR1: (U+17E1?) ([U+17E0-U+17E9]) U+17D2 U+17D4 */
    re_lunar1 = mkre("(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])\xe1\x9f\x92\xe1\x9f\x94");
    /* RE_LUNAR2: U+17D4 U+17D2 (U+17E1?) ([U+17E0-U+17E9]) */
    re_lunar2 = mkre("\xe1\x9f\x94\xe1\x9f\x92(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])");
    /* XHM: [U+17B6-U+17C5] U+17D2 */
    re_xhm = mkre("[\xe1\x9e\xb6-\xe1\x9f\x85]\xe1\x9f\x92");
}

/* ---- Lunar date callback ---- */

static char *lunar_cb(const char *input, size_t ms, size_t me,
                      int ng, const PCRE2_SIZE *ov, void *ctx) {
    uint32_t base = *(const uint32_t *)ctx;
    int v1 = 0;
    if (ng >= 2 && ov[2] != PCRE2_UNSET && ov[3] > ov[2]) {
        uint32_t cp; u8dec((const unsigned char *)input + ov[2], &cp);
        v1 = (int)cp - 0x17E0;
    }
    uint32_t d2; u8dec((const unsigned char *)input + ov[4], &d2);
    int v = v1 * 10 + (int)d2 - 0x17E0;
    if (v > 15) {
        size_t mlen = me - ms;
        char *r = malloc(mlen + 1);
        memcpy(r, input + ms, mlen); r[mlen] = '\0';
        return r;
    }
    unsigned char tmp[4];
    int n = u8enc(base + (uint32_t)v, tmp);
    char *r = malloc(n + 1);
    memcpy(r, tmp, n); r[n] = '\0';
    return r;
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
    if (!initialised) { init_cats(); init_re(); initialised = 1; }

    /* XHM pre-step: insert U+200D before each [U+17B6-U+17C5] U+17D2 sequence */
    char *s;
    if (lang && strcmp(lang, "xhm") == 0)
        s = sub_str(re_xhm, txt, "\xe2\x80\x8d$0");
    else
        s = strdup(txt);

    /* Decode UTF-8 to codepoints */
    size_t slen = strlen(s);
    /* Upper bound: each byte could be a separate ASCII char */
    uint32_t *cps = malloc((slen + 1) * sizeof(uint32_t));
    int      *cats = malloc((slen + 1) * sizeof(int));
    int       n = 0;
    const unsigned char *p = (const unsigned char *)s;
    const unsigned char *end = p + slen;
    while (p < end) {
        uint32_t cp; int nb = u8dec(p, &cp); p += nb;
        cps[n] = cp; cats[n] = charcat(cp); n++;
    }
    free(s);

    /* Recategorise: char after U+17D2 or U+200D that is Base/Coeng → propagate */
    for (int i = 1; i < n; i++) {
        if (cps[i - 1] == 0x200D || cps[i - 1] == 0x17D2) {
            if (cats[i] == CAT_BASE || cats[i] == CAT_COENG)
                cats[i] = cats[i - 1];
        }
    }

    /* Find syllables, sort, and apply substitutions */
    Buf res = {0};
    int *indices = malloc((slen + 1) * sizeof(int));

    int i = 0;
    while (i < n) {
        if (cats[i] != CAT_BASE) {
            buf_push_cp(&res, cps[i]); i++; continue;
        }
        int j = i + 1;
        while (j < n && cats[j] > CAT_BASE) j++;

        int syl_len = j - i;
        for (int k = 0; k < syl_len; k++) indices[k] = i + k;
        g_sort_cats = cats;
        qsort(indices, (size_t)syl_len, sizeof(int), cmp_indices);

        /* Build syllable UTF-8 string */
        Buf sylbuf = {0};
        for (int k = 0; k < syl_len; k++) buf_push_cp(&sylbuf, cps[indices[k]]);
        char *syl = sylbuf.d ? sylbuf.d : strdup("");

        /* Apply substitutions */
        char *t;

        t = sub_str(re_invis,    syl, "$1");                  free(syl); syl = t;
        /* U+17C4 U+17B8 */
        t = sub_str(re_vbe,      syl, "\xe1\x9f\x84\xe1\x9e\xb8"); free(syl); syl = t;
        /* U+17BE + $1 */
        t = sub_str(re_v1,       syl, "\xe1\x9e\xbe$1");      free(syl); syl = t;
        /* U+17C4 + $1 */
        t = sub_str(re_v2,       syl, "\xe1\x9f\x84$1");      free(syl); syl = t;
        t = sub_str(re_v3,       syl, "$2$1");                 free(syl); syl = t;
        /* $1 + U+17CA (TRIISAP) */
        t = sub_str(re_strong,   syl, "$1\xe1\x9f\x8a");      free(syl); syl = t;
        /* $1 + U+17C9 (MUUSIKATOAN) */
        t = sub_str(re_nstrong,  syl, "$1\xe1\x9f\x89");      free(syl); syl = t;
        t = sub_str(re_coeng_ro, syl, "$2$1");                 free(syl); syl = t;
        /* U+17D2 U+178F */
        t = sub_str(re_coeng_da, syl, "\xe1\x9f\x92\xe1\x9e\x8f"); free(syl); syl = t;

        uint32_t base1 = 0x19E0, base2 = 0x19F0;
        t = sub_fn(re_lunar1, syl, lunar_cb, &base1);          free(syl); syl = t;
        t = sub_fn(re_lunar2, syl, lunar_cb, &base2);          free(syl); syl = t;

        /* U+17D4 U+17D2 U+17D4 → U+19F0 (᧰) */
        t = str_replace_all(syl,
                "\xe1\x9f\x94\xe1\x9f\x92\xe1\x9f\x94",
                "\xe1\xa7\xb0");
        free(syl); syl = t;

        buf_push(&res, syl, strlen(syl));
        free(syl);
        i = j;
    }

    free(cps); free(cats); free(indices);
    return res.d ? res.d : strdup("");
}
