// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Java — betterkhmer.

package com.betterkhmer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class Khnormal {
    private static final int CAT_OTHER   = 0;
    private static final int CAT_BASE    = 1;
    private static final int CAT_ROBAT   = 2;
    private static final int CAT_COENG   = 3;
    private static final int CAT_SHIFT   = 4;
    private static final int CAT_Z       = 5;
    private static final int CAT_VPRE    = 6;
    private static final int CAT_VB      = 7;
    private static final int CAT_VA      = 8;
    private static final int CAT_VPOST   = 9;
    private static final int CAT_MS      = 10;
    private static final int CAT_MF      = 11;
    private static final int CAT_ZFCOENG = 12;

    private static final int[] CATEGORIES;
    static {
        int[] c = new int[0x17DE - 0x1780];
        Arrays.fill(c, CAT_OTHER);
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
        CATEGORIES = c;
    }

    private static final String S1    = "[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]";
    private static final String NON_BA = "[ក-នផ-អឥ-ឳ]";
    private static final String S2    = "[ងកណនបម-ឝឡឣ-ឳ]";
    private static final String NON_RO = "[ក-យល-អឥ-ឳ]";
    private static final String B     = "[ក-អឥ-ឳ◌]";
    private static final String VA    = "(?:[ិ-ឺើឿ៝]|ាំ)";
    private static final String COENG = "(?:(?:្" + NON_RO + ")?្" + B + ")";

    private static final String STRONG =
        S1 + "៌?(?:្" + NON_BA + "(?:្" + NON_BA + ")?)?" +
        "|" + NON_BA + "៌?(?:្" + S1 + "(?:្" + NON_BA + ")?|្" + NON_BA + "្" + S1 + ")";

    private static final String NSTRONG =
        "(?:" + S2 + "៌?(?:្" + S2 + "(?:្" + S2 + ")?)?" +
        "|ប៌?(?:" + COENG + "(?:" + COENG + ")?)?" +
        "|" + B + "៌?(?:្" + NON_RO + "្ប|្ប(?:្" + B + ")))";

    private static final Pattern RE_INVIS    = Pattern.compile("(‍?្)[្‌‍]+");
    private static final Pattern RE_VBE      = Pattern.compile("ើា");
    private static final Pattern RE_V1       = Pattern.compile("េ([ុ-ួ]?)ី");
    private static final Pattern RE_V2       = Pattern.compile("េ([ុ-ួ]?)ា");
    private static final Pattern RE_V3       = Pattern.compile("(ើ)(ុ)");
    private static final Pattern RE_STRONG   = Pattern.compile("(?:" + STRONG + ")[េ-ៅ]?ុ(?=" + VA + "|័)");
    private static final Pattern RE_NSTRONG  = Pattern.compile("(?:" + NSTRONG + ")[េ-ៅ]?ុ(?=" + VA + "|័)");
    private static final Pattern RE_COENG_RO = Pattern.compile("(្រ)(្[ក-ឳ])");
    private static final Pattern RE_COENG_DA = Pattern.compile("្ដ");
    private static final Pattern RE_LUNAR1   = Pattern.compile("(១?)([០-៩])្។");
    private static final Pattern RE_LUNAR2   = Pattern.compile("។្(១?)([០-៩])");

    private Khnormal() {}

    private static int charcat(int cp) {
        if (cp >= 0x1780 && cp <= 0x17DD) return CATEGORIES[cp - 0x1780];
        if (cp == 0x200C) return CAT_Z;
        if (cp == 0x200D) return CAT_ZFCOENG;
        return CAT_OTHER;
    }

    private static String lunarReplace(Matcher m, int base) {
        String d1 = m.group(1);
        String d2 = m.group(2);
        int v1 = (d1 == null || d1.isEmpty()) ? 0 : d1.codePointAt(0) - 0x17E0;
        int v = v1 * 10 + d2.codePointAt(0) - 0x17E0;
        if (v > 15) return m.group(0);
        return new String(Character.toChars(base + v));
    }

    private static String subFn(Pattern re, String s, java.util.function.Function<Matcher, String> fn) {
        Matcher m = re.matcher(s);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            m.appendReplacement(sb, Matcher.quoteReplacement(fn.apply(m)));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    /** Returns the Khmer-normalized form of txt. */
    public static String normalize(String txt) {
        return normalize(txt, "km");
    }

    /** Returns the Khmer-normalized form of txt (lang: "km" or "xhm"). */
    public static String normalize(String txt, String lang) {
        if ("xhm".equals(lang)) {
            txt = txt.replaceAll("[ិ-ៅ]្", "‍$0");
        }

        int[] cps = txt.codePoints().toArray();
        int n = cps.length;
        int[] cats = new int[n];
        for (int i = 0; i < n; i++) cats[i] = charcat(cps[i]);

        for (int i = 1; i < n; i++) {
            if (cps[i - 1] == 0x200D || cps[i - 1] == 0x17D2) {
                if (cats[i] == CAT_BASE || cats[i] == CAT_COENG) {
                    cats[i] = cats[i - 1];
                }
            }
        }

        StringBuilder res = new StringBuilder();
        int i = 0;
        while (i < n) {
            if (cats[i] != CAT_BASE) {
                res.appendCodePoint(cps[i]);
                i++;
                continue;
            }
            int j = i + 1;
            while (j < n && cats[j] > CAT_BASE) j++;

            Integer[] indices = new Integer[j - i];
            for (int k = 0; k < indices.length; k++) indices[k] = i + k;
            final int[] catsFinal = cats;
            Arrays.sort(indices, (a, b) -> catsFinal[a] != catsFinal[b] ? catsFinal[a] - catsFinal[b] : a - b);

            StringBuilder sylBuf = new StringBuilder();
            for (int idx : indices) sylBuf.appendCodePoint(cps[idx]);
            String syl = sylBuf.toString();

            syl = RE_INVIS.matcher(syl).replaceAll("$1");
            syl = RE_VBE.matcher(syl).replaceAll("ោី");
            syl = RE_V1.matcher(syl).replaceAll("ើ$1");
            syl = RE_V2.matcher(syl).replaceAll("ោ$1");
            syl = RE_V3.matcher(syl).replaceAll("$2$1");
            // STRONG/NSTRONG: lookahead match — remove ã (last char) and add shifter
            syl = subFn(RE_STRONG, syl, m -> {
                String s = m.group(0);
                return s.substring(0, s.length() - 1) + "៊";
            });
            syl = subFn(RE_NSTRONG, syl, m -> {
                String s = m.group(0);
                return s.substring(0, s.length() - 1) + "៉";
            });
            syl = RE_COENG_RO.matcher(syl).replaceAll("$2$1");
            syl = RE_COENG_DA.matcher(syl).replaceAll("្ត");
            syl = subFn(RE_LUNAR1, syl, m -> lunarReplace(m, 0x19E0));
            syl = subFn(RE_LUNAR2, syl, m -> lunarReplace(m, 0x19F0));
            syl = syl.replace("។្។", "᧰");
            res.append(syl);
            i = j;
        }
        return res.toString();
    }
}
