// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to C# — BetterKhmer package.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace BetterKhmer;

public static class Khnormal
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

    static Khnormal()
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

    private static int Charcat(int cp)
    {
        if (cp >= 0x1780 && cp <= 0x17DD) return Categories[cp - 0x1780];
        if (cp == 0x200C) return CatZ;
        if (cp == 0x200D) return CatZFCoeng;
        return CatOther;
    }

    private const string S1    = @"[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]";
    private const string NonBA = @"[ក-នផ-អឥ-ឳ]";
    private const string S2    = @"[ងកណនបម-ឝឡឣ-ឳ]";
    private const string NonRo = @"[ក-យល-អឥ-ឳ]";
    private const string B     = @"[ក-អឥ-ឳ◌]";
    private const string VA    = @"(?:[ិ-ឺើឿ៝]|ាំ)";
    private const string COENG = @"(?:(?:្" + NonRo + @")?្" + B + @")";

    private static readonly string Strong =
        S1 + @"៌?(?:្" + NonBA + @"(?:្" + NonBA + @")?)?" +
        "|" + NonBA + @"៌?(?:្" + S1 + @"(?:្" + NonBA + @")?|្" + NonBA + @"្" + S1 + @")";

    private static readonly string NStrong =
        @"(?:" + S2 + @"៌?(?:្" + S2 + @"(?:្" + S2 + @")?)?" +
        @"|ប៌?(?:" + COENG + @"(?:" + COENG + @")?)?" +
        @"|" + B + @"៌?(?:្" + NonRo + @"្ប|្ប(?:្" + B + @")))";

    private static readonly Regex ReInvis   = new(@"(‍?្)[្‌‍]+", RegexOptions.Compiled);
    private static readonly Regex ReVBE     = new(@"ើា", RegexOptions.Compiled);
    private static readonly Regex ReV1      = new(@"េ([ុ-ួ]?)ី", RegexOptions.Compiled);
    private static readonly Regex ReV2      = new(@"េ([ុ-ួ]?)ា", RegexOptions.Compiled);
    private static readonly Regex ReV3      = new(@"(ើ)(ុ)", RegexOptions.Compiled);
    private static readonly Regex ReStrong  = new(@"(?:" + Strong  + @")[េ-ៅ]?ុ(?=" + VA + @"|័)", RegexOptions.Compiled);
    private static readonly Regex ReNStrong = new(@"(?:" + NStrong + @")[េ-ៅ]?ុ(?=" + VA + @"|័)", RegexOptions.Compiled);
    private static readonly Regex ReCoengRo = new(@"(្រ)(្[ក-ឳ])", RegexOptions.Compiled);
    private static readonly Regex ReCoengDa = new(@"្ដ", RegexOptions.Compiled);
    private static readonly Regex ReLunar1  = new(@"(១?)([០-៩])្។", RegexOptions.Compiled);
    private static readonly Regex ReLunar2  = new(@"។្(១?)([០-៩])", RegexOptions.Compiled);

    private static string LunarReplace(Match m, int baseVal)
    {
        string d1 = m.Groups[1].Value;
        string d2 = m.Groups[2].Value;
        int v1 = d1.Length == 0 ? 0 : char.ConvertToUtf32(d1, 0) - 0x17E0;
        int v = v1 * 10 + char.ConvertToUtf32(d2, 0) - 0x17E0;
        if (v > 15) return m.Value;
        return char.ConvertFromUtf32(baseVal + v);
    }

    /// <summary>Returns the Khmer-normalized form of txt.</summary>
    public static string Normalize(string txt, string lang = "km")
    {
        if (lang == "xhm")
            txt = Regex.Replace(txt, @"[ិ-ៅ]្", "‍$0");

        // Enumerate Unicode codepoints
        var cps = new List<int>();
        for (int ci = 0; ci < txt.Length; )
        {
            int cp = char.ConvertToUtf32(txt, ci);
            cps.Add(cp);
            ci += cp > 0xFFFF ? 2 : 1;
        }
        int n = cps.Count;
        int[] cats = new int[n];
        for (int i = 0; i < n; i++) cats[i] = Charcat(cps[i]);

        for (int i = 1; i < n; i++)
        {
            if (cps[i - 1] == 0x200D || cps[i - 1] == 0x17D2)
            {
                if (cats[i] == CatBase || cats[i] == CatCoeng)
                    cats[i] = cats[i - 1];
            }
        }

        var res = new StringBuilder();
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

            var sylBuf = new StringBuilder();
            foreach (int k in indices) sylBuf.Append(char.ConvertFromUtf32(cps[k]));
            string syl = sylBuf.ToString();

            syl = ReInvis.Replace(syl, "$1");
            syl = ReVBE.Replace(syl, "ោី");
            syl = ReV1.Replace(syl, "ើ$1");
            syl = ReV2.Replace(syl, "ោ$1");
            syl = ReV3.Replace(syl, "$2$1");
            syl = ReStrong.Replace(syl, m =>
            {
                string s = m.Value;
                return s[..^"ុ".Length] + "៊";
            });
            syl = ReNStrong.Replace(syl, m =>
            {
                string s = m.Value;
                return s[..^"ុ".Length] + "៉";
            });
            syl = ReCoengRo.Replace(syl, "$2$1");
            syl = ReCoengDa.Replace(syl, "្ត");
            syl = ReLunar1.Replace(syl, m => LunarReplace(m, 0x19E0));
            syl = ReLunar2.Replace(syl, m => LunarReplace(m, 0x19F0));
            syl = syl.Replace("។្។", "᧰");
            res.Append(syl);
            idx = j;
        }
        return res.ToString();
    }
}
