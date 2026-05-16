// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C++ — betterkhmer package. Regex-free; 1:1 with the Go reference.

#include "betterkhmer.hpp"
#include <array>
#include <vector>
#include <string>
#include <algorithm>
#include <numeric>
#include <cstdint>
#include <cstddef>

namespace betterkhmer {
namespace {

/* ---- Character categories ---- */

enum Cat {
    CatOther = 0, CatBase = 1, CatRobat = 2, CatCoeng = 3,
    CatShift = 4, CatZ = 5, CatVPre = 6, CatVB = 7, CatVA = 8,
    CatVPost = 9, CatMS = 10, CatMF = 11, CatZFCoeng = 12
};

static const std::array<uint8_t, 0x17DE - 0x1780> CATEGORIES = [](){
    std::array<uint8_t, 0x17DE - 0x1780> c{};
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
    c[0x17DD - 0x1780] = CatMS;
    return c;
}();

Cat charcat(uint32_t cp) {
    if (cp >= 0x1780 && cp <= 0x17DD) return static_cast<Cat>(CATEGORIES[cp - 0x1780]);
    if (cp == 0x200C) return CatZ;
    if (cp == 0x200D) return CatZFCoeng;
    return CatOther;
}

/* ---- Khmer consonant classes (from the SIL reference khres) ---- */

constexpr uint32_t ZWNJ = 0x200C, ZWJ = 0x200D, COENG = 0x17D2,
                   ROBAT = 0x17CC, BA = 0x1794;

bool isBase(uint32_t r) {
    return (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC;
}
bool isNonRo(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) ||
           (r >= 0x17A5 && r <= 0x17B3);
}
bool isNonBA(uint32_t r) {
    return (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) ||
           (r >= 0x17A5 && r <= 0x17B3);
}
bool isS1(uint32_t r) {
    if (r >= 0x1780 && r <= 0x1783) return true;
    if (r >= 0x1785 && r <= 0x1788) return true;
    if (r >= 0x178A && r <= 0x178D) return true;
    if (r >= 0x178F && r <= 0x1792) return true;
    if (r >= 0x1795 && r <= 0x1797) return true;
    if (r >= 0x179E && r <= 0x17A0) return true;
    if (r == 0x17A2) return true;
    return false;
}
bool isS2(uint32_t r) {
    if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 ||
        r == 0x1794 || r == 0x17A1) return true;
    if (r >= 0x1798 && r <= 0x179D) return true;
    if (r >= 0x17A3 && r <= 0x17B3) return true;
    return false;
}
bool isVPre(uint32_t r) { return r >= 0x17C1 && r <= 0x17C5; }
bool isDigit(uint32_t r) { return r >= 0x17E0 && r <= 0x17E9; }

/* ---- UTF-8 encode/decode ---- */

int u8dec(const uint8_t* s, uint32_t& out) {
    uint8_t b = s[0];
    if (b < 0x80) { out = b; return 1; }
    if (b < 0xE0) { out = ((b&0x1F)<<6)|(s[1]&0x3F); return 2; }
    if (b < 0xF0) { out = ((b&0x0F)<<12)|((s[1]&0x3F)<<6)|(s[2]&0x3F); return 3; }
    out = ((b&0x07)<<18)|((s[1]&0x3F)<<12)|((s[2]&0x3F)<<6)|(s[3]&0x3F); return 4;
}

int u8enc(uint32_t cp, uint8_t* out) {
    if (cp < 0x80) { out[0]=cp; return 1; }
    if (cp < 0x800) { out[0]=0xC0|(cp>>6); out[1]=0x80|(cp&0x3F); return 2; }
    if (cp < 0x10000) { out[0]=0xE0|(cp>>12); out[1]=0x80|((cp>>6)&0x3F); out[2]=0x80|(cp&0x3F); return 3; }
    out[0]=0xF0|(cp>>18); out[1]=0x80|((cp>>12)&0x3F); out[2]=0x80|((cp>>6)&0x3F); out[3]=0x80|(cp&0x3F); return 4;
}

void appendCP(std::string& out, uint32_t cp) {
    uint8_t buf[4]; int n = u8enc(cp, buf);
    out.append(reinterpret_cast<char*>(buf), static_cast<size_t>(n));
}

using Vec = std::vector<uint32_t>;

/* ---- optRobat: positions after an optional Robat at p ---- */

std::vector<int> optRobat(const Vec& r, int p) {
    if (p < (int)r.size() && r[p] == ROBAT) return { p, p + 1 };
    return { p };
}

/* ---- coengEnds: end indices of one COENG: (?:(?:្ NonRo)? ្ B) ---- */

std::vector<int> coengEnds(const Vec& r, int s) {
    int n = (int)r.size();
    std::vector<int> res;
    if (s + 1 < n && r[s] == COENG && isBase(r[s + 1])) res.push_back(s + 2);
    if (s + 3 < n && r[s] == COENG && isNonRo(r[s + 1]) &&
        r[s + 2] == COENG && isBase(r[s + 3])) res.push_back(s + 4);
    return res;
}

/* ---- strongEnds / nstrongEnds ---- */

template <typename Add>
void strongEnds(const Vec& r, int s, Add add) {
    int n = (int)r.size();
    if (s >= n) return;
    if (isS1(r[s])) {
        for (int p : optRobat(r, s + 1)) {
            add(p);
            if (p + 1 < n && r[p] == COENG && isNonBA(r[p + 1])) {
                int q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add(q + 2);
            }
        }
    }
    if (isNonBA(r[s])) {
        for (int p : optRobat(r, s + 1)) {
            if (p + 1 < n && r[p] == COENG && isS1(r[p + 1])) {
                int q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add(q + 2);
            }
            if (p + 3 < n && r[p] == COENG && isNonBA(r[p + 1]) &&
                r[p + 2] == COENG && isS1(r[p + 3])) add(p + 4);
        }
    }
}

template <typename Add>
void nstrongEnds(const Vec& r, int s, Add add) {
    int n = (int)r.size();
    if (s >= n) return;
    if (isS2(r[s])) {
        for (int p : optRobat(r, s + 1)) {
            add(p);
            if (p + 1 < n && r[p] == COENG && isS2(r[p + 1])) {
                int q = p + 2;
                add(q);
                if (q + 1 < n && r[q] == COENG && isS2(r[q + 1])) add(q + 2);
            }
        }
    }
    if (r[s] == BA) {
        for (int p : optRobat(r, s + 1)) {
            add(p);
            for (int e1 : coengEnds(r, p)) {
                add(e1);
                for (int e2 : coengEnds(r, e1)) add(e2);
            }
        }
    }
    if (isBase(r[s])) {
        for (int p : optRobat(r, s + 1)) {
            if (p + 3 < n && r[p] == COENG && isNonRo(r[p + 1]) &&
                r[p + 2] == COENG && r[p + 3] == BA) add(p + 4);
            if (p + 3 < n && r[p] == COENG && r[p + 1] == BA &&
                r[p + 2] == COENG && isBase(r[p + 3])) add(p + 4);
        }
    }
}

/* ---- canEndAt ---- */

template <typename Ends>
bool canEndAt(const Vec& r, int target, Ends ends) {
    for (int s = 0; s < target; s++) {
        bool found = false;
        ends(r, s, [&](int e){ if (e == target) found = true; });
        if (found) return true;
    }
    return false;
}

/* ---- vaSamyokAt: lookahead (?:VA | ័) ---- */

bool vaSamyokAt(const Vec& r, int p) {
    int n = (int)r.size();
    if (p >= n) return false;
    uint32_t c = r[p];
    if (c == 0x17D0) return true;
    if (c >= 0x17B7 && c <= 0x17BA) return true;
    if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return true;
    if (c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6) return true;
    return false;
}

/* ---- applyShifter (mutates r in place) ---- */

template <typename Ends>
void applyShifter(Vec& r, Ends ends, uint32_t shifter) {
    for (int k = 0; k < (int)r.size(); k++) {
        if (r[k] != 0x17BB) continue;
        bool ctx = canEndAt(r, k, ends) ||
                   (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, k - 1, ends));
        if (ctx && vaSamyokAt(r, k + 1)) r[k] = shifter;
    }
}

/* ---- collapseInvis: (‍?្)[្‌‍]+ -> \1 ---- */

bool isInvis(uint32_t c) { return c == COENG || c == ZWNJ || c == ZWJ; }

Vec collapseInvis(const Vec& r) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    int i = 0;
    while (i < n) {
        int g1End = -1;
        if (r[i] == ZWJ && i + 1 < n && r[i + 1] == COENG) g1End = i + 2;
        else if (r[i] == COENG) g1End = i + 1;
        if (g1End >= 0) {
            int k = g1End;
            while (k < n && isInvis(r[k])) k++;
            if (k > g1End) {
                out.insert(out.end(), r.begin() + i, r.begin() + g1End);
                i = k;
                continue;
            }
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- pairReplace / pairReplace3 ---- */

Vec pairReplace(const Vec& r, uint32_t a, uint32_t b, std::initializer_list<uint32_t> repl) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (i + 1 < n && r[i] == a && r[i + 1] == b) {
            out.insert(out.end(), repl.begin(), repl.end());
            i += 2;
            continue;
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

Vec pairReplace3(const Vec& r, uint32_t a, uint32_t b, uint32_t c, uint32_t repl) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
            out.push_back(repl);
            i += 3;
            continue;
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- vowelSplit: េ([ុ-ួ]?)tail -> head + \1 ---- */

Vec vowelSplit(const Vec& r, uint32_t tail, uint32_t head) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17C1) {
            if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail) {
                out.push_back(head);
                out.push_back(r[i + 1]);
                i += 3;
                continue;
            }
            if (i + 1 < n && r[i + 1] == tail) {
                out.push_back(head);
                i += 2;
                continue;
            }
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- coengRo: (្រ)(្[ក-ឳ]) -> \2\1 ---- */

Vec coengRo(const Vec& r) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (i + 3 < n && r[i] == COENG && r[i + 1] == 0x179A &&
            r[i + 2] == COENG && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
            out.push_back(r[i + 2]);
            out.push_back(r[i + 3]);
            out.push_back(r[i]);
            out.push_back(r[i + 1]);
            i += 4;
            continue;
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- coengDa: (្)ដ -> \1ត ---- */

Vec coengDa(const Vec& r) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (i + 1 < n && r[i] == COENG && r[i + 1] == 0x178A) {
            out.push_back(COENG);
            out.push_back(0x178F);
            i += 2;
            continue;
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0) ---- */

Vec lunar1(const Vec& r) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17E1 && i + 3 < n && isDigit(r[i + 1]) &&
            r[i + 2] == COENG && r[i + 3] == 0x17D4) {
            int v = 10 + (int)(r[i + 1] - 0x17E0);
            if (v > 15) out.insert(out.end(), r.begin() + i, r.begin() + i + 4);
            else out.push_back((uint32_t)(0x19E0 + v));
            i += 4;
            continue;
        }
        if (i + 2 < n && isDigit(r[i]) && r[i + 1] == COENG && r[i + 2] == 0x17D4) {
            out.push_back((uint32_t)(0x19E0 + (int)(r[i] - 0x17E0)));
            i += 3;
            continue;
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0) ---- */

Vec lunar2(const Vec& r) {
    int n = (int)r.size();
    Vec out;
    out.reserve(n);
    for (int i = 0; i < n;) {
        if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == COENG) {
            if (i + 3 < n && r[i + 2] == 0x17E1 && isDigit(r[i + 3])) {
                int v = 10 + (int)(r[i + 3] - 0x17E0);
                if (v > 15) out.insert(out.end(), r.begin() + i, r.begin() + i + 4);
                else out.push_back((uint32_t)(0x19F0 + v));
                i += 4;
                continue;
            }
            if (i + 2 < n && isDigit(r[i + 2])) {
                out.push_back((uint32_t)(0x19F0 + (int)(r[i + 2] - 0x17E0)));
                i += 3;
                continue;
            }
        }
        out.push_back(r[i]);
        i++;
    }
    return out;
}

/* ---- hasByteE1: SWAR scan for byte 0xE1 ---- */

bool hasByteE1(const std::string& s) {
    const uint64_t lo = 0x0101010101010101ULL;
    const uint64_t hi = 0x8080808080808080ULL;
    const uint64_t mask = 0xE1E1E1E1E1E1E1E1ULL;
    const uint8_t* p = reinterpret_cast<const uint8_t*>(s.data());
    size_t len = s.size();
    size_t i = 0;
    for (; i + 8 <= len; i += 8) {
        uint64_t w = (uint64_t)p[i] | (uint64_t)p[i + 1] << 8 |
                     (uint64_t)p[i + 2] << 16 | (uint64_t)p[i + 3] << 24 |
                     (uint64_t)p[i + 4] << 32 | (uint64_t)p[i + 5] << 40 |
                     (uint64_t)p[i + 6] << 48 | (uint64_t)p[i + 7] << 56;
        uint64_t x = w ^ mask;
        if ((x - lo) & ~x & hi) return true;
    }
    for (; i < len; i++) if (p[i] == 0xE1) return true;
    return false;
}

} // anonymous namespace

std::string normalize(const std::string& txt, const std::string& lang) {
    /* SWAR skip/scan fast path: no Khmer byte => identity. */
    if (!hasByteE1(txt)) return txt;

    /* Decode UTF-8 to code points. */
    Vec raw;
    raw.reserve(txt.size());
    {
        const auto* p = reinterpret_cast<const uint8_t*>(txt.data());
        const auto* end = p + txt.size();
        while (p < end) {
            uint32_t cp; int nb = u8dec(p, cp); p += nb;
            raw.push_back(cp);
        }
    }

    /* XHM pre-step: insert U+200D before each [U+17B6-U+17C5] U+17D2 sequence. */
    Vec cps;
    if (lang == "xhm") {
        cps.reserve(raw.size() * 2);
        for (size_t k = 0; k < raw.size(); k++) {
            if (raw[k] >= 0x17B6 && raw[k] <= 0x17C5 &&
                k + 1 < raw.size() && raw[k + 1] == 0x17D2)
                cps.push_back(0x200D);
            cps.push_back(raw[k]);
        }
    } else {
        cps = std::move(raw);
    }

    int n = (int)cps.size();
    std::vector<Cat> cats(n);
    for (int k = 0; k < n; k++) cats[k] = charcat(cps[k]);

    /* Recategorise. */
    for (int i = 1; i < n; i++) {
        if (cps[i-1] == ZWJ || cps[i-1] == COENG) {
            if (cats[i] == CatBase || cats[i] == CatCoeng)
                cats[i] = cats[i-1];
        }
    }

    std::string res;
    res.reserve(txt.size());
    std::vector<int> indices;

    int i = 0;
    while (i < n) {
        if (cats[i] != CatBase) { appendCP(res, cps[i]); i++; continue; }
        int j = i + 1;
        while (j < n && cats[j] > CatBase) j++;

        int slen = j - i;
        indices.resize(slen);
        std::iota(indices.begin(), indices.end(), i);
        std::stable_sort(indices.begin(), indices.end(), [&](int a, int b){
            return cats[a] != cats[b] ? cats[a] < cats[b] : a < b;
        });

        Vec syl(slen);
        for (int k = 0; k < slen; k++) syl[k] = cps[indices[k]];

        syl = collapseInvis(syl);
        syl = pairReplace(syl, 0x17BE, 0x17B6, { 0x17C4, 0x17B8 });
        syl = vowelSplit(syl, 0x17B8, 0x17BE);
        syl = vowelSplit(syl, 0x17B6, 0x17C4);
        syl = pairReplace(syl, 0x17BE, 0x17BB, { 0x17BB, 0x17BE });
        applyShifter(syl, [](const Vec& r, int s, auto add){ strongEnds(r, s, add); }, 0x17CA);
        applyShifter(syl, [](const Vec& r, int s, auto add){ nstrongEnds(r, s, add); }, 0x17C9);
        syl = coengRo(syl);
        syl = coengDa(syl);
        syl = lunar1(syl);
        syl = lunar2(syl);
        syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0);

        for (uint32_t cp : syl) appendCP(res, cp);
        i = j;
    }
    return res;
}

} // namespace betterkhmer
