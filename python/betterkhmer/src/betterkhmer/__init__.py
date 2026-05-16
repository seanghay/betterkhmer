# Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
# Ported to betterkhmer Python package. Regex-free.

import enum


class _Cats(enum.IntEnum):
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

_ZWNJ = 0x200C
_ZWJ = 0x200D
_COENG = 0x17D2
_ROBAT = 0x17CC
_BA = 0x1794


def _charcat(o):
    if 0x1780 <= o <= 0x17DD:
        return _categories[o - 0x1780]
    if o == _ZWNJ:
        return _Cats.Z
    if o == _ZWJ:
        return _Cats.ZFCoeng
    return _Cats.Other


# --- Khmer consonant classes (from the SIL reference khres) ---

def _is_base(r):
    return (0x1780 <= r <= 0x17A2) or (0x17A5 <= r <= 0x17B3) or r == 0x25CC


def _is_non_ro(r):
    return (0x1780 <= r <= 0x1799) or (0x179B <= r <= 0x17A2) or (0x17A5 <= r <= 0x17B3)


def _is_non_ba(r):
    return (0x1780 <= r <= 0x1793) or (0x1795 <= r <= 0x17A2) or (0x17A5 <= r <= 0x17B3)


def _is_s1(r):
    return ((0x1780 <= r <= 0x1783) or (0x1785 <= r <= 0x1788)
            or (0x178A <= r <= 0x178D) or (0x178F <= r <= 0x1792)
            or (0x1795 <= r <= 0x1797) or (0x179E <= r <= 0x17A0)
            or r == 0x17A2)


def _is_s2(r):
    return (r in (0x1780, 0x1784, 0x178E, 0x1793, 0x1794, 0x17A1)
            or (0x1798 <= r <= 0x179D) or (0x17A3 <= r <= 0x17B3))


def _is_vpre(r):
    return 0x17C1 <= r <= 0x17C5


def _is_digit(r):
    return 0x17E0 <= r <= 0x17E9


def _opt_robat(r, p):
    if p < len(r) and r[p] == _ROBAT:
        return (p, p + 1)
    return (p,)


def _coeng_ends(r, s):
    n = len(r)
    res = []
    if s + 1 < n and r[s] == _COENG and _is_base(r[s + 1]):
        res.append(s + 2)
    if (s + 3 < n and r[s] == _COENG and _is_non_ro(r[s + 1])
            and r[s + 2] == _COENG and _is_base(r[s + 3])):
        res.append(s + 4)
    return res


def _strong_ends(r, s, add):
    n = len(r)
    if s >= n:
        return
    if _is_s1(r[s]):
        for p in _opt_robat(r, s + 1):
            add(p)
            if p + 1 < n and r[p] == _COENG and _is_non_ba(r[p + 1]):
                q = p + 2
                add(q)
                if q + 1 < n and r[q] == _COENG and _is_non_ba(r[q + 1]):
                    add(q + 2)
    if _is_non_ba(r[s]):
        for p in _opt_robat(r, s + 1):
            if p + 1 < n and r[p] == _COENG and _is_s1(r[p + 1]):
                q = p + 2
                add(q)
                if q + 1 < n and r[q] == _COENG and _is_non_ba(r[q + 1]):
                    add(q + 2)
            if (p + 3 < n and r[p] == _COENG and _is_non_ba(r[p + 1])
                    and r[p + 2] == _COENG and _is_s1(r[p + 3])):
                add(p + 4)


def _nstrong_ends(r, s, add):
    n = len(r)
    if s >= n:
        return
    if _is_s2(r[s]):
        for p in _opt_robat(r, s + 1):
            add(p)
            if p + 1 < n and r[p] == _COENG and _is_s2(r[p + 1]):
                q = p + 2
                add(q)
                if q + 1 < n and r[q] == _COENG and _is_s2(r[q + 1]):
                    add(q + 2)
    if r[s] == _BA:
        for p in _opt_robat(r, s + 1):
            add(p)
            for e1 in _coeng_ends(r, p):
                add(e1)
                for e2 in _coeng_ends(r, e1):
                    add(e2)
    if _is_base(r[s]):
        for p in _opt_robat(r, s + 1):
            if (p + 3 < n and r[p] == _COENG and _is_non_ro(r[p + 1])
                    and r[p + 2] == _COENG and r[p + 3] == _BA):
                add(p + 4)
            if (p + 3 < n and r[p] == _COENG and r[p + 1] == _BA
                    and r[p + 2] == _COENG and _is_base(r[p + 3])):
                add(p + 4)


def _can_end_at(r, target, ends):
    for s in range(target):
        found = [False]

        def _mark(e):
            if e == target:
                found[0] = True

        ends(r, s, _mark)
        if found[0]:
            return True
    return False


def _va_samyok_at(r, p):
    n = len(r)
    if p >= n:
        return False
    c = r[p]
    if c == 0x17D0:
        return True
    if 0x17B7 <= c <= 0x17BA:
        return True
    if c in (0x17BE, 0x17BF, 0x17DD):
        return True
    if c == 0x17B6 and p + 1 < n and r[p + 1] == 0x17C6:
        return True
    return False


def _apply_shifter(r, ends, shifter):
    for k in range(len(r)):
        if r[k] != 0x17BB:
            continue
        ctx = _can_end_at(r, k, ends) or (
            k >= 1 and _is_vpre(r[k - 1]) and _can_end_at(r, k - 1, ends))
        if ctx and _va_samyok_at(r, k + 1):
            r[k] = shifter


def _collapse_invis(r):
    n = len(r)
    out = []
    i = 0
    while i < n:
        g1_end = -1
        if r[i] == _ZWJ and i + 1 < n and r[i + 1] == _COENG:
            g1_end = i + 2
        elif r[i] == _COENG:
            g1_end = i + 1
        if g1_end >= 0:
            k = g1_end
            while k < n and r[k] in (_COENG, _ZWNJ, _ZWJ):
                k += 1
            if k > g1_end:
                out.extend(r[i:g1_end])
                i = k
                continue
        out.append(r[i])
        i += 1
    return out


def _pair_replace(r, a, b, *repl):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if i + 1 < n and r[i] == a and r[i + 1] == b:
            out.extend(repl)
            i += 2
            continue
        out.append(r[i])
        i += 1
    return out


def _pair_replace3(r, a, b, c, repl):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if i + 2 < n and r[i] == a and r[i + 1] == b and r[i + 2] == c:
            out.append(repl)
            i += 3
            continue
        out.append(r[i])
        i += 1
    return out


def _vowel_split(r, tail, head):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if r[i] == 0x17C1:
            if i + 2 < n and 0x17BB <= r[i + 1] <= 0x17BD and r[i + 2] == tail:
                out.append(head)
                out.append(r[i + 1])
                i += 3
                continue
            if i + 1 < n and r[i + 1] == tail:
                out.append(head)
                i += 2
                continue
        out.append(r[i])
        i += 1
    return out


def _coeng_ro(r):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if (i + 3 < n and r[i] == _COENG and r[i + 1] == 0x179A
                and r[i + 2] == _COENG and 0x1780 <= r[i + 3] <= 0x17B3):
            out.append(r[i + 2])
            out.append(r[i + 3])
            out.append(r[i])
            out.append(r[i + 1])
            i += 4
            continue
        out.append(r[i])
        i += 1
    return out


def _coeng_da(r):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if i + 1 < n and r[i] == _COENG and r[i + 1] == 0x178A:
            out.append(_COENG)
            out.append(0x178F)
            i += 2
            continue
        out.append(r[i])
        i += 1
    return out


def _lunar1(r):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if (r[i] == 0x17E1 and i + 3 < n and _is_digit(r[i + 1])
                and r[i + 2] == _COENG and r[i + 3] == 0x17D4):
            v = 10 + (r[i + 1] - 0x17E0)
            if v > 15:
                out.extend(r[i:i + 4])
            else:
                out.append(0x19E0 + v)
            i += 4
            continue
        if (i + 2 < n and _is_digit(r[i]) and r[i + 1] == _COENG
                and r[i + 2] == 0x17D4):
            out.append(0x19E0 + (r[i] - 0x17E0))
            i += 3
            continue
        out.append(r[i])
        i += 1
    return out


def _lunar2(r):
    n = len(r)
    out = []
    i = 0
    while i < n:
        if r[i] == 0x17D4 and i + 1 < n and r[i + 1] == _COENG:
            if i + 3 < n and r[i + 2] == 0x17E1 and _is_digit(r[i + 3]):
                v = 10 + (r[i + 3] - 0x17E0)
                if v > 15:
                    out.extend(r[i:i + 4])
                else:
                    out.append(0x19F0 + v)
                i += 4
                continue
            if i + 2 < n and _is_digit(r[i + 2]):
                out.append(0x19F0 + (r[i + 2] - 0x17E0))
                i += 3
                continue
        out.append(r[i])
        i += 1
    return out


def _has_khmer(cps):
    for o in cps:
        if 0x1780 <= o <= 0x17FF:
            return True
    return False


def normalize(txt, lang="km"):
    """Return the Khmer-normalized form of txt."""
    cps = [ord(c) for c in txt]

    if lang == "xhm":
        # ([ិ-ៅ]្) -> ‍\1  (U+17B7..U+17C5 followed by U+17D2, prepend U+200D)
        out = []
        n = len(cps)
        for i, o in enumerate(cps):
            if (0x17B7 <= o <= 0x17C5 and i + 1 < n and cps[i + 1] == _COENG):
                out.append(_ZWJ)
            out.append(o)
        cps = out

    if not _has_khmer(cps):
        return "".join(chr(o) for o in cps)

    n = len(cps)
    cats = [_charcat(o) for o in cps]

    for i in range(1, n):
        if cps[i - 1] == _ZWJ or cps[i - 1] == _COENG:
            if cats[i] == _Cats.Base or cats[i] == _Cats.Coeng:
                cats[i] = cats[i - 1]

    i = 0
    res = []
    while i < n:
        if cats[i] != _Cats.Base:
            res.append(cps[i])
            i += 1
            continue
        j = i + 1
        while j < n and cats[j] > _Cats.Base:
            j += 1

        indices = sorted(range(i, j), key=lambda e: (cats[e], e))
        syl = [cps[k] for k in indices]

        syl = _collapse_invis(syl)
        syl = _pair_replace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8)  # ើា -> ោី
        syl = _vowel_split(syl, 0x17B8, 0x17BE)                   # េ(◌)ី -> ើ(◌)
        syl = _vowel_split(syl, 0x17B6, 0x17C4)                   # េ(◌)ា -> ោ(◌)
        syl = _pair_replace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE)  # ើុ -> ុើ
        _apply_shifter(syl, _strong_ends, 0x17CA)                 # strong -u -> ៊
        _apply_shifter(syl, _nstrong_ends, 0x17C9)                # weak   -u -> ៉
        syl = _coeng_ro(syl)
        syl = _coeng_da(syl)
        syl = _lunar1(syl)
        syl = _lunar2(syl)
        syl = _pair_replace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0)  # ។្។ -> ᧰

        res.extend(syl)
        i = j

    return "".join(chr(o) for o in res)
