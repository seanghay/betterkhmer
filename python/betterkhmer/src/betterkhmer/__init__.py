# Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
# Ported to betterkhmer Python package.

import enum
import re

class _Cats(enum.Enum):
    Other = 0; Base = 1; Robat = 2; Coeng = 3
    Shift = 4; Z = 5; VPre = 6; VB = 7; VA = 8
    VPost = 9; MS = 10; MF = 11; ZFCoeng = 12

_categories = (
    [_Cats.Base] * 35      # 1780-17A2
    + [_Cats.Other] * 2    # 17A3-17A4
    + [_Cats.Base] * 15    # 17A5-17B3
    + [_Cats.Other] * 2    # 17B4-17B5
    + [_Cats.VPost]         # 17B6
    + [_Cats.VA] * 4        # 17B7-17BA
    + [_Cats.VB] * 3        # 17BB-17BD
    + [_Cats.VPre] * 8      # 17BE-17C5
    + [_Cats.MS]             # 17C6
    + [_Cats.MF] * 2        # 17C7-17C8
    + [_Cats.Shift] * 2     # 17C9-17CA
    + [_Cats.MS]             # 17CB
    + [_Cats.Robat]          # 17CC
    + [_Cats.MS] * 5        # 17CD-17D1
    + [_Cats.Coeng]          # 17D2
    + [_Cats.MS]             # 17D3
    + [_Cats.Other] * 9     # 17D4-17DC
    + [_Cats.MS]             # 17DD
)

_khres: dict[str, str] = {
    "B":       "[ក-អឥ-ឳ◌]",
    "NonRo":   "[ក-យល-អឥ-ឳ]",
    "NonBA":   "[ក-នផ-អឥ-ឳ]",
    "S1":      ("[ក-ឃច-ឈដ-ឍត-ធ"
                "ផ-ភឞ-ហអ]"),
    "S2":      "[ងកណនបម-ឝឡឣ-ឳ]",
    "VA":      "(?:[ិ-ឺើឿ៝]|ាំ)",
    "COENG":   "(?:(?:្{NonRo})?្{B})",
    "STRONG":  ("  {S1}៌?                 # series 1 robat?\n"
                "    (?:្{NonBA}          # nonba coengs\n"
                "       (?:្{NonBA})?)?  \n"
                "  | {NonBA}៌?            # nonba robat?\n"
                "    (?:  ្{S1}           # series 1 coeng\n"
                "         (?:្{NonBA})?   #   + any nonba coeng\n"
                "       | ្{NonBA}្{S1})"),
    "NSTRONG": ("(?:{S2}៌?(?:្{S2}(?:្{S2})?)?"
                "|ប៌?(?:{COENG}(?:{COENG})?)?"
                "|{B}៌?(?:្{NonRo}្ប"
                "|្ប(?:្{B})))"),
}

for _ in range(3):
    _khres = {k: v.format(**_khres) for k, v in _khres.items()}

_re_invis   = re.compile("(‍?្)[្‌‍]+")
_re_vbe     = re.compile("ើា")
_re_v1      = re.compile("េ([ុ-ួ]?)ី")
_re_v2      = re.compile("េ([ុ-ួ]?)ា")
_re_v3      = re.compile("(ើ)(ុ)")
_re_strong  = re.compile(
    "((?:{STRONG})[េ-ៅ]?)ុ(?={VA}|័)".format(**_khres),
    re.X)
_re_nstrong = re.compile(
    "((?:{NSTRONG})[េ-ៅ]?)ុ(?={VA}|័)".format(**_khres),
    re.X)
_re_cro     = re.compile("(្រ)(្[ក-ឳ])")
_re_cda     = re.compile("(្)ដ")
_re_lunar1  = re.compile("(១?)([០-៩])្។")
_re_lunar2  = re.compile("។្(១?)([០-៩])")


def _charcat(c: str) -> _Cats:
    o = ord(c)
    if 0x1780 <= o <= 0x17DD:
        return _categories[o - 0x1780]
    if o == 0x200C:
        return _Cats.Z
    if o == 0x200D:
        return _Cats.ZFCoeng
    return _Cats.Other


def _lunar(m: re.Match, base: int) -> str:
    v = (ord(m.group(1) or "០") - 0x17E0) * 10 + ord(m.group(2)) - 0x17E0
    if v > 15:
        return m.group(0)
    return chr(v + base)


def normalize(txt: str, lang: str = "km") -> str:
    """Return the Khmer-normalized form of txt."""
    if lang == "xhm":
        txt = re.sub("([ិ-ៅ]្)", "‍\\1", txt)

    chars = list(txt)
    cats = [_charcat(c) for c in chars]

    for i in range(1, len(cats)):
        if txt[i - 1] in "‍្" and cats[i] in (_Cats.Base, _Cats.Coeng):
            cats[i] = cats[i - 1]

    i = 0
    res = []
    while i < len(cats):
        if cats[i] != _Cats.Base:
            res.append(chars[i])
            i += 1
            continue
        j = i + 1
        while j < len(cats) and cats[j].value > _Cats.Base.value:
            j += 1
        indices = sorted(range(i, j), key=lambda e: (cats[e].value, e))
        syl = "".join(chars[n] for n in indices)

        syl = _re_invis.sub(r"\1", syl)
        syl = _re_vbe.sub("ោី", syl)
        syl = _re_v1.sub("ើ\\1", syl)
        syl = _re_v2.sub("ោ\\1", syl)
        syl = _re_v3.sub(r"\2\1", syl)
        syl = _re_strong.sub("\\1៊", syl)
        syl = _re_nstrong.sub("\\1៉", syl)
        syl = _re_cro.sub(r"\2\1", syl)
        syl = _re_cda.sub("\\1ត", syl)
        syl = _re_lunar1.sub(lambda m: _lunar(m, 0x19E0), syl)
        syl = _re_lunar2.sub(lambda m: _lunar(m, 0x19F0), syl)
        syl = syl.replace("។្។", "᧰")
        res.append(syl)
        i = j

    return "".join(res)
