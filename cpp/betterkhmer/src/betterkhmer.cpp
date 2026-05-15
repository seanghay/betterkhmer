// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C++ (PCRE2) — betterkhmer package.

#define PCRE2_CODE_UNIT_WIDTH 8
#include "betterkhmer.hpp"
#include <pcre2.h>
#include <array>
#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <numeric>
#include <stdexcept>
#include <cstdint>

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

std::string encodeCP(uint32_t cp) {
    uint8_t buf[4]; int n = u8enc(cp, buf);
    return {reinterpret_cast<char*>(buf), static_cast<size_t>(n)};
}

/* ---- PCRE2 wrapper ---- */

struct Re {
    pcre2_code* code = nullptr;
    Re() = default;
    Re(const char* pat) {
        int err; PCRE2_SIZE erroff;
        code = pcre2_compile((PCRE2_SPTR)pat, PCRE2_ZERO_TERMINATED,
                             PCRE2_UTF | PCRE2_UCP, &err, &erroff, nullptr);
        if (!code) throw std::runtime_error("bad regex");
    }
    ~Re() { if (code) pcre2_code_free(code); }
    Re(const Re&) = delete;
    Re& operator=(const Re&) = delete;
};

/* Global substitute with a fixed replacement template ($0/$1/$2 supported). */
std::string subStr(const Re& re, const std::string& s, const char* repl) {
    size_t inlen = s.size();
    size_t bufcap = inlen * 2 + 256;
    std::string buf(bufcap, '\0');
    PCRE2_SIZE outlen = bufcap;
    int rc = pcre2_substitute(re.code, (PCRE2_SPTR)s.data(), inlen, 0,
        PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED |
        PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
        nullptr, nullptr,
        (PCRE2_SPTR)repl, PCRE2_ZERO_TERMINATED,
        (PCRE2_UCHAR*)buf.data(), &outlen);
    if (rc == PCRE2_ERROR_NOMEMORY) {
        bufcap = outlen + 1;
        buf.resize(bufcap);
        outlen = bufcap;
        rc = pcre2_substitute(re.code, (PCRE2_SPTR)s.data(), inlen, 0,
            PCRE2_SUBSTITUTE_GLOBAL | PCRE2_SUBSTITUTE_EXTENDED,
            nullptr, nullptr,
            (PCRE2_SPTR)repl, PCRE2_ZERO_TERMINATED,
            (PCRE2_UCHAR*)buf.data(), &outlen);
    }
    if (rc < 0) return s;
    buf.resize(outlen);
    return buf;
}

/* Global substitute with callback. */
using SubFn = std::string(*)(const std::string& input, size_t ms, size_t me,
                              int ng, const PCRE2_SIZE* ov, void* ctx);

std::string subFn(const Re& re, const std::string& input, SubFn fn, void* ctx) {
    size_t inlen = input.size();
    pcre2_match_data* md = pcre2_match_data_create_from_pattern(re.code, nullptr);
    std::string out;
    out.reserve(inlen);
    size_t pos = 0;
    while (pos <= inlen) {
        int rc = pcre2_match(re.code, (PCRE2_SPTR)input.data(), inlen, pos, 0, md, nullptr);
        if (rc < 0) { out.append(input, pos); break; }
        const PCRE2_SIZE* ov = pcre2_get_ovector_pointer(md);
        size_t ms = ov[0], me = ov[1];
        out.append(input, pos, ms - pos);
        out += fn(input, ms, me, rc, ov, ctx);
        if (me == ms) { if (ms < inlen) out += input[ms]; pos = ms + 1; }
        else pos = me;
    }
    pcre2_match_data_free(md);
    return out;
}

std::string strReplaceAll(const std::string& src, const std::string& needle, const std::string& repl) {
    std::string out;
    size_t pos = 0, found;
    while ((found = src.find(needle, pos)) != std::string::npos) {
        out.append(src, pos, found - pos);
        out += repl;
        pos = found + needle.size();
    }
    out.append(src, pos);
    return out;
}

/* ---- Khmer patterns (raw UTF-8 bytes) ---- */

#define B      "[\xe1\x9e\x80-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3\xe2\x97\x8c]"
#define NON_RO "[\xe1\x9e\x80-\xe1\x9e\x99\xe1\x9e\x9b-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]"
#define NON_BA "[\xe1\x9e\x80-\xe1\x9e\x93\xe1\x9e\x95-\xe1\x9e\xa2\xe1\x9e\xa5-\xe1\x9e\xb3]"
#define S1     "[\xe1\x9e\x80-\xe1\x9e\x83\xe1\x9e\x85-\xe1\x9e\x88\xe1\x9e\x8a-\xe1\x9e\x8d\xe1\x9e\x8f-\xe1\x9e\x92\xe1\x9e\x95-\xe1\x9e\x97\xe1\x9e\x9e-\xe1\x9e\xa0\xe1\x9e\xa2]"
#define S2     "[\xe1\x9e\x84\xe1\x9e\x80\xe1\x9e\x8e\xe1\x9e\x93\xe1\x9e\x94\xe1\x9e\x98-\xe1\x9e\x9d\xe1\x9e\xa1\xe1\x9e\xa3-\xe1\x9e\xb3]"
#define VA     "(?:[\xe1\x9e\xb7-\xe1\x9e\xba\xe1\x9e\xbe\xe1\x9e\xbf\xe1\x9f\x9d]|\xe1\x9e\xb6\xe1\x9f\x86)"
#define COENG  "(?:(?:\xe1\x9f\x92" NON_RO ")?\xe1\x9f\x92" B ")"
#define STRONG \
    S1 "\xe1\x9f\x8c?(?:\xe1\x9f\x92" NON_BA "(?:\xe1\x9f\x92" NON_BA ")?)?" \
    "|" NON_BA "\xe1\x9f\x8c?(?:\xe1\x9f\x92" S1 "(?:\xe1\x9f\x92" NON_BA ")?" \
    "|\xe1\x9f\x92" NON_BA "\xe1\x9f\x92" S1 ")"
#define NSTRONG \
    "(?:" S2 "\xe1\x9f\x8c?(?:\xe1\x9f\x92" S2 "(?:\xe1\x9f\x92" S2 ")?)?" \
    "|\xe1\x9e\x94\xe1\x9f\x8c?(?:" COENG "(?:" COENG ")?)?" \
    "|" B "\xe1\x9f\x8c?(?:\xe1\x9f\x92" NON_RO "\xe1\x9f\x92\xe1\x9e\x94" \
    "|\xe1\x9f\x92\xe1\x9e\x94(?:\xe1\x9f\x92" B ")))"

/* Compiled regexes — initialised on first call via static local */
struct Regexes {
    Re invis, vbe, v1, v2, v3, strong, nstrong, coengRo, coengDa, lunar1, lunar2, xhm;
    Regexes() :
        invis   ("(\xe2\x80\x8d?\xe1\x9f\x92)[\xe1\x9f\x92\xe2\x80\x8c\xe2\x80\x8d]+"),
        vbe     ("\xe1\x9e\xbe\xe1\x9e\xb6"),
        v1      ("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb8"),
        v2      ("\xe1\x9f\x81([\xe1\x9e\xbb-\xe1\x9e\xbd]?)\xe1\x9e\xb6"),
        v3      ("(\xe1\x9e\xbe)(\xe1\x9e\xbb)"),
        strong  ("((?:" STRONG  ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb"
                 "(?=" VA "|\xe1\x9f\x90)"),
        nstrong ("((?:" NSTRONG ")[\xe1\x9f\x81-\xe1\x9f\x85]?)\xe1\x9e\xbb"
                 "(?=" VA "|\xe1\x9f\x90)"),
        coengRo ("(\xe1\x9f\x92\xe1\x9e\x9a)(\xe1\x9f\x92[\xe1\x9e\x80-\xe1\x9e\xb3])"),
        coengDa ("\xe1\x9f\x92\xe1\x9e\x8a"),
        lunar1  ("(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])\xe1\x9f\x92\xe1\x9f\x94"),
        lunar2  ("\xe1\x9f\x94\xe1\x9f\x92(\xe1\x9f\xa1?)([\xe1\x9f\xa0-\xe1\x9f\xa9])"),
        xhm     ("[\xe1\x9e\xb6-\xe1\x9f\x85]\xe1\x9f\x92")
    {}
};

const Regexes& re() {
    static const Regexes R;
    return R;
}

std::string lunarCb(const std::string& input, size_t ms, size_t me,
                    int ng, const PCRE2_SIZE* ov, void* ctx) {
    uint32_t base = *static_cast<uint32_t*>(ctx);
    int v1 = 0;
    if (ng >= 2 && ov[2] != PCRE2_UNSET && ov[3] > ov[2]) {
        uint32_t cp; u8dec(reinterpret_cast<const uint8_t*>(input.data()) + ov[2], cp);
        v1 = static_cast<int>(cp) - 0x17E0;
    }
    uint32_t d2; u8dec(reinterpret_cast<const uint8_t*>(input.data()) + ov[4], d2);
    int v = v1 * 10 + static_cast<int>(d2) - 0x17E0;
    if (v > 15) return input.substr(ms, me - ms);
    return encodeCP(base + static_cast<uint32_t>(v));
}

} // anonymous namespace

std::string normalize(const std::string& txt, const std::string& lang) {
    const Regexes& R = re();

    std::string s = txt;
    if (lang == "xhm")
        s = subStr(R.xhm, s, "\xe2\x80\x8d$0");

    /* Decode UTF-8 to codepoints */
    std::vector<uint32_t> cps;
    std::vector<Cat> cats;
    cps.reserve(s.size());
    cats.reserve(s.size());
    const auto* p = reinterpret_cast<const uint8_t*>(s.data());
    const auto* end = p + s.size();
    while (p < end) {
        uint32_t cp; int nb = u8dec(p, cp); p += nb;
        cps.push_back(cp);
        cats.push_back(charcat(cp));
    }
    int n = static_cast<int>(cps.size());

    /* Recategorise */
    for (int i = 1; i < n; i++) {
        if (cps[i-1] == 0x200D || cps[i-1] == 0x17D2) {
            if (cats[i] == CatBase || cats[i] == CatCoeng)
                cats[i] = cats[i-1];
        }
    }

    /* Process syllables */
    std::string res;
    res.reserve(s.size());
    std::vector<int> indices;

    int i = 0;
    while (i < n) {
        if (cats[i] != CatBase) { res += encodeCP(cps[i]); i++; continue; }
        int j = i + 1;
        while (j < n && cats[j] > CatBase) j++;

        int slen = j - i;
        indices.resize(slen);
        std::iota(indices.begin(), indices.end(), i);
        std::stable_sort(indices.begin(), indices.end(), [&](int a, int b){
            return cats[a] != cats[b] ? cats[a] < cats[b] : a < b;
        });

        std::string syl;
        syl.reserve(slen * 4);
        for (int k : indices) syl += encodeCP(cps[k]);

        syl = subStr(R.invis,   syl, "$1");
        syl = subStr(R.vbe,     syl, "\xe1\x9f\x84\xe1\x9e\xb8");
        syl = subStr(R.v1,      syl, "\xe1\x9e\xbe$1");
        syl = subStr(R.v2,      syl, "\xe1\x9f\x84$1");
        syl = subStr(R.v3,      syl, "$2$1");
        syl = subStr(R.strong,  syl, "$1\xe1\x9f\x8a");
        syl = subStr(R.nstrong, syl, "$1\xe1\x9f\x89");
        syl = subStr(R.coengRo, syl, "$2$1");
        syl = subStr(R.coengDa, syl, "\xe1\x9f\x92\xe1\x9e\x8f");

        uint32_t base1 = 0x19E0, base2 = 0x19F0;
        syl = subFn(R.lunar1, syl, lunarCb, &base1);
        syl = subFn(R.lunar2, syl, lunarCb, &base2);
        syl = strReplaceAll(syl,
            "\xe1\x9f\x94\xe1\x9f\x92\xe1\x9f\x94",
            "\xe1\xa7\xb0");

        res += syl;
        i = j;
    }
    return res;
}

} // namespace betterkhmer
