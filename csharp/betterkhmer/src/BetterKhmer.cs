// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C# — BetterKhmer package. Regex-free.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace BetterKhmer;

public static class BetterKhmer
{
    private const int CatOther   = 0;
    private const int CatBase    = 1;
    private const int CatRobat   = 2;
    private const int CatCoeng   = 3;
    private const int CatShift   = 4;
    private const int CatZ       = 5;
    private const int CatVPre    = 6;
    private const int CatVB      = 7;
    private const int CatVA      = 8;
    private const int CatVPost   = 9;
    private const int CatMS      = 10;
    private const int CatMF      = 11;
    private const int CatZFCoeng = 12;

    private static readonly int[] Categories;

    static BetterKhmer()
    {
        int[] c = new int[0x17DE - 0x1780];
        Array.Fill(c, CatOther);
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
        Categories = c;
    }

    private const int Zwnj  = 0x200C;
    private const int Zwj   = 0x200D;
    private const int Coeng = 0x17D2;
    private const int Robat = 0x17CC;
    private const int Ba    = 0x1794;

    private static int Charcat(int cp)
    {
        if (cp >= 0x1780 && cp <= 0x17DD) return Categories[cp - 0x1780];
        if (cp == 0x200C) return CatZ;
        if (cp == 0x200D) return CatZFCoeng;
        return CatOther;
    }

    // --- Khmer consonant classes (from the SIL reference khres) ---

    // B: all bases (incl. dotted circle).
    private static bool IsBase(int r) =>
        (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC;

    // NonRo: consonants excluding Ro (U+179A).
    private static bool IsNonRo(int r) =>
        (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);

    // NonBA: consonants excluding Ba (U+1794).
    private static bool IsNonBA(int r) =>
        (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);

    // S1: series-1 consonants.
    private static bool IsS1(int r)
    {
        if (r >= 0x1780 && r <= 0x1783) return true;
        if (r >= 0x1785 && r <= 0x1788) return true;
        if (r >= 0x178A && r <= 0x178D) return true;
        if (r >= 0x178F && r <= 0x1792) return true;
        if (r >= 0x1795 && r <= 0x1797) return true;
        if (r >= 0x179E && r <= 0x17A0) return true;
        return r == 0x17A2;
    }

    // S2: series-2 consonants.
    private static bool IsS2(int r)
    {
        if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 || r == 0x1794 || r == 0x17A1) return true;
        if (r >= 0x1798 && r <= 0x179D) return true;
        return r >= 0x17A3 && r <= 0x17B3;
    }

    private static bool IsVPre(int r) => r >= 0x17C1 && r <= 0x17C5;

    // OptRobat returns the position(s) after an optional Robat at p.
    private static int[] OptRobat(int[] r, int p) =>
        p < r.Length && r[p] == Robat ? new[] { p, p + 1 } : new[] { p };

    // CoengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
    private static void CoengEnds(int[] r, int s, Action<int> add)
    {
        int n = r.Length;
        if (s + 1 < n && r[s] == Coeng && IsBase(r[s + 1])) add(s + 2);
        if (s + 3 < n && r[s] == Coeng && IsNonRo(r[s + 1]) && r[s + 2] == Coeng && IsBase(r[s + 3]))
            add(s + 4);
    }

    // StrongEnds enumerates all end indices of a STRONG match starting at s.
    private static void StrongEnds(int[] r, int s, Action<int> add)
    {
        int n = r.Length;
        if (s >= n) return;
        if (IsS1(r[s]))
        {
            foreach (int p in OptRobat(r, s + 1))
            {
                add(p);
                if (p + 1 < n && r[p] == Coeng && IsNonBA(r[p + 1]))
                {
                    int q = p + 2;
                    add(q);
                    if (q + 1 < n && r[q] == Coeng && IsNonBA(r[q + 1])) add(q + 2);
                }
            }
        }
        if (IsNonBA(r[s]))
        {
            foreach (int p in OptRobat(r, s + 1))
            {
                if (p + 1 < n && r[p] == Coeng && IsS1(r[p + 1]))
                {
                    int q = p + 2;
                    add(q);
                    if (q + 1 < n && r[q] == Coeng && IsNonBA(r[q + 1])) add(q + 2);
                }
                if (p + 3 < n && r[p] == Coeng && IsNonBA(r[p + 1]) && r[p + 2] == Coeng && IsS1(r[p + 3]))
                    add(p + 4);
            }
        }
    }

    // NstrongEnds enumerates all end indices of an NSTRONG match starting at s.
    private static void NstrongEnds(int[] r, int s, Action<int> add)
    {
        int n = r.Length;
        if (s >= n) return;
        if (IsS2(r[s]))
        {
            foreach (int p in OptRobat(r, s + 1))
            {
                add(p);
                if (p + 1 < n && r[p] == Coeng && IsS2(r[p + 1]))
                {
                    int q = p + 2;
                    add(q);
                    if (q + 1 < n && r[q] == Coeng && IsS2(r[q + 1])) add(q + 2);
                }
            }
        }
        if (r[s] == Ba)
        {
            foreach (int p in OptRobat(r, s + 1))
            {
                add(p);
                CoengEnds(r, p, e1 =>
                {
                    add(e1);
                    CoengEnds(r, e1, add);
                });
            }
        }
        if (IsBase(r[s]))
        {
            foreach (int p in OptRobat(r, s + 1))
            {
                if (p + 3 < n && r[p] == Coeng && IsNonRo(r[p + 1]) && r[p + 2] == Coeng && r[p + 3] == Ba)
                    add(p + 4);
                if (p + 3 < n && r[p] == Coeng && r[p + 1] == Ba && r[p + 2] == Coeng && IsBase(r[p + 3]))
                    add(p + 4);
            }
        }
    }

    private delegate void Ends(int[] r, int s, Action<int> add);

    // CanEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
    private static bool CanEndAt(int[] r, int target, Ends ends)
    {
        for (int s = 0; s < target; s++)
        {
            bool found = false;
            ends(r, s, e => { if (e == target) found = true; });
            if (found) return true;
        }
        return false;
    }

    // VaSamyokAt is the lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
    private static bool VaSamyokAt(int[] r, int p)
    {
        int n = r.Length;
        if (p >= n) return false;
        int c = r[p];
        if (c == 0x17D0) return true;
        if (c >= 0x17B7 && c <= 0x17BA) return true;
        if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return true;
        return c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6;
    }

    // ApplyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
    private static void ApplyShifter(int[] r, Ends ends, int shifter)
    {
        for (int k = 0; k < r.Length; k++)
        {
            if (r[k] != 0x17BB) continue;
            bool ctx = CanEndAt(r, k, ends)
                || (k >= 1 && IsVPre(r[k - 1]) && CanEndAt(r, k - 1, ends));
            if (ctx && VaSamyokAt(r, k + 1)) r[k] = shifter;
        }
    }

    private static bool IsInvis(int c) => c == Coeng || c == Zwnj || c == Zwj;

    // CollapseInvis: (‍?្)[្‌‍]+ -> \1
    private static int[] CollapseInvis(int[] r)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            int g1End = -1;
            if (r[i] == Zwj && i + 1 < n && r[i + 1] == Coeng) g1End = i + 2;
            else if (r[i] == Coeng) g1End = i + 1;
            if (g1End >= 0)
            {
                int k = g1End;
                while (k < n && IsInvis(r[k])) k++;
                if (k > g1End)
                {
                    for (int t = i; t < g1End; t++) outp.Add(r[t]);
                    i = k;
                    continue;
                }
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // PairReplace replaces every non-overlapping [a,b] with [r0,r1].
    private static int[] PairReplace(int[] r, int a, int b, int r0, int r1)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (i + 1 < n && r[i] == a && r[i + 1] == b)
            {
                outp.Add(r0); outp.Add(r1);
                i += 2;
                continue;
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // PairReplace3 replaces every non-overlapping [a,b,c] with repl.
    private static int[] PairReplace3(int[] r, int a, int b, int c, int repl)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c)
            {
                outp.Add(repl);
                i += 3;
                continue;
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // VowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
    private static int[] VowelSplit(int[] r, int tail, int head)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (r[i] == 0x17C1)
            {
                if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail)
                {
                    outp.Add(head); outp.Add(r[i + 1]);
                    i += 3;
                    continue;
                }
                if (i + 1 < n && r[i + 1] == tail)
                {
                    outp.Add(head);
                    i += 2;
                    continue;
                }
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // CoengRo: (្រ)(្[ក-ឳ]) -> \2\1
    private static int[] CoengRo(int[] r)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (i + 3 < n && r[i] == Coeng && r[i + 1] == 0x179A
                && r[i + 2] == Coeng && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3)
            {
                outp.Add(r[i + 2]); outp.Add(r[i + 3]); outp.Add(r[i]); outp.Add(r[i + 1]);
                i += 4;
                continue;
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // CoengDa: (្)ដ -> \1ត
    private static int[] CoengDa(int[] r)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (i + 1 < n && r[i] == Coeng && r[i + 1] == 0x178A)
            {
                outp.Add(Coeng); outp.Add(0x178F);
                i += 2;
                continue;
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    private static bool IsDigit(int r) => r >= 0x17E0 && r <= 0x17E9;

    // Lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
    private static int[] Lunar1(int[] r)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (r[i] == 0x17E1 && i + 3 < n && IsDigit(r[i + 1]) && r[i + 2] == Coeng && r[i + 3] == 0x17D4)
            {
                int v = 10 + (r[i + 1] - 0x17E0);
                if (v > 15)
                {
                    for (int t = i; t < i + 4; t++) outp.Add(r[t]);
                }
                else
                {
                    outp.Add(0x19E0 + v);
                }
                i += 4;
                continue;
            }
            if (i + 2 < n && IsDigit(r[i]) && r[i + 1] == Coeng && r[i + 2] == 0x17D4)
            {
                outp.Add(0x19E0 + (r[i] - 0x17E0));
                i += 3;
                continue;
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // Lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
    private static int[] Lunar2(int[] r)
    {
        int n = r.Length;
        var outp = new List<int>(n);
        int i = 0;
        while (i < n)
        {
            if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == Coeng)
            {
                if (i + 3 < n && r[i + 2] == 0x17E1 && IsDigit(r[i + 3]))
                {
                    int v = 10 + (r[i + 3] - 0x17E0);
                    if (v > 15)
                    {
                        for (int t = i; t < i + 4; t++) outp.Add(r[t]);
                    }
                    else
                    {
                        outp.Add(0x19F0 + v);
                    }
                    i += 4;
                    continue;
                }
                if (i + 2 < n && IsDigit(r[i + 2]))
                {
                    outp.Add(0x19F0 + (r[i + 2] - 0x17E0));
                    i += 3;
                    continue;
                }
            }
            outp.Add(r[i]);
            i++;
        }
        return outp.ToArray();
    }

    // HasByteE1 reports whether s contains UTF-8 byte 0xE1, scanned 8 bytes at a
    // time (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte
    // 0xE1, so no 0xE1 means no Khmer codepoint and the input is unchanged.
    private static bool HasByteE1(byte[] s)
    {
        const ulong lo   = 0x0101010101010101UL;
        const ulong hi   = 0x8080808080808080UL;
        const ulong mask = 0xE1E1E1E1E1E1E1E1UL;
        int i = 0;
        for (; i + 8 <= s.Length; i += 8)
        {
            ulong w = s[i] | (ulong)s[i + 1] << 8 | (ulong)s[i + 2] << 16 | (ulong)s[i + 3] << 24
                | (ulong)s[i + 4] << 32 | (ulong)s[i + 5] << 40 | (ulong)s[i + 6] << 48 | (ulong)s[i + 7] << 56;
            ulong x = w ^ mask;
            if (((x - lo) & ~x & hi) != 0) return true;
        }
        for (; i < s.Length; i++)
        {
            if (s[i] == 0xE1) return true;
        }
        return false;
    }

    // CodePoints decodes txt into an array of Unicode code points.
    private static int[] CodePoints(string txt)
    {
        var cps = new List<int>(txt.Length);
        for (int ci = 0; ci < txt.Length;)
        {
            int cp = char.ConvertToUtf32(txt, ci);
            cps.Add(cp);
            ci += cp > 0xFFFF ? 2 : 1;
        }
        return cps.ToArray();
    }

    // XhmPrefix replaces [ិ-ៅ]្ with ‍$0 (prepend U+200D before the pair).
    private static int[] XhmPrefix(int[] cps)
    {
        int n = cps.Length;
        var outp = new List<int>(n + 8);
        for (int i = 0; i < n; i++)
        {
            if (i + 1 < n && cps[i] >= 0x17B7 && cps[i] <= 0x17C5 && cps[i + 1] == Coeng)
            {
                outp.Add(Zwj);
                outp.Add(cps[i]);
                outp.Add(cps[i + 1]);
                i++;
                continue;
            }
            outp.Add(cps[i]);
        }
        return outp.ToArray();
    }

    /// <summary>Returns the Khmer-normalized form of txt.</summary>
    public static string Normalize(string txt, string lang = "km")
    {
        // SWAR skip/scan fast path: no Khmer byte => identity.
        if (lang != "xhm" && !HasByteE1(Encoding.UTF8.GetBytes(txt)))
            return txt;

        int[] cps = CodePoints(txt);
        if (lang == "xhm") cps = XhmPrefix(cps);
        int n = cps.Length;
        int[] cats = new int[n];
        for (int i = 0; i < n; i++) cats[i] = Charcat(cps[i]);

        for (int i = 1; i < n; i++)
        {
            if (cps[i - 1] == Zwj || cps[i - 1] == Coeng)
            {
                if (cats[i] == CatBase || cats[i] == CatCoeng)
                    cats[i] = cats[i - 1];
            }
        }

        var res = new StringBuilder(txt.Length);
        int idx = 0;
        while (idx < n)
        {
            if (cats[idx] != CatBase) { res.Append(char.ConvertFromUtf32(cps[idx])); idx++; continue; }
            int j = idx + 1;
            while (j < n && cats[j] > CatBase) j++;

            var indices = Enumerable.Range(idx, j - idx)
                .OrderBy(k => cats[k])
                .ThenBy(k => k)
                .ToArray();

            int[] syl = new int[indices.Length];
            for (int k = 0; k < indices.Length; k++) syl[k] = cps[indices[k]];

            syl = CollapseInvis(syl);
            syl = PairReplace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8); // ើា -> ោី
            syl = VowelSplit(syl, 0x17B8, 0x17BE);                  // េ(◌)ី -> ើ(◌)
            syl = VowelSplit(syl, 0x17B6, 0x17C4);                  // េ(◌)ា -> ោ(◌)
            syl = PairReplace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE); // ើុ -> ុើ
            ApplyShifter(syl, StrongEnds, 0x17CA);                  // strong  -u -> ៊
            ApplyShifter(syl, NstrongEnds, 0x17C9);                 // weak    -u -> ៉
            syl = CoengRo(syl);
            syl = CoengDa(syl);
            syl = Lunar1(syl);
            syl = Lunar2(syl);
            syl = PairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0); // ។្។ -> ᧰

            foreach (int r in syl) res.Append(char.ConvertFromUtf32(r));
            idx = j;
        }
        return res.ToString();
    }
}
