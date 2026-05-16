// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Java — betterkhmer. Regex-free.

package com.betterkhmer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class BetterKhmer {
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

    private static final int ZWNJ  = 0x200C;
    private static final int ZWJ   = 0x200D;
    private static final int COENG = 0x17D2;
    private static final int ROBAT = 0x17CC;
    private static final int BA    = 0x1794;

    private BetterKhmer() {}

    private static int charcat(int cp) {
        if (cp >= 0x1780 && cp <= 0x17DD) return CATEGORIES[cp - 0x1780];
        if (cp == 0x200C) return CAT_Z;
        if (cp == 0x200D) return CAT_ZFCOENG;
        return CAT_OTHER;
    }

    // --- Khmer consonant classes (from the SIL reference khres) ---

    // B: all bases (incl. dotted circle).
    private static boolean isBase(int r) {
        return (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC;
    }

    // NonRo: consonants excluding Ro (U+179A).
    private static boolean isNonRo(int r) {
        return (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);
    }

    // NonBA: consonants excluding Ba (U+1794).
    private static boolean isNonBA(int r) {
        return (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3);
    }

    // S1: series-1 consonants.
    private static boolean isS1(int r) {
        if (r >= 0x1780 && r <= 0x1783) return true;
        if (r >= 0x1785 && r <= 0x1788) return true;
        if (r >= 0x178A && r <= 0x178D) return true;
        if (r >= 0x178F && r <= 0x1792) return true;
        if (r >= 0x1795 && r <= 0x1797) return true;
        if (r >= 0x179E && r <= 0x17A0) return true;
        return r == 0x17A2;
    }

    // S2: series-2 consonants.
    private static boolean isS2(int r) {
        if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 || r == 0x1794 || r == 0x17A1) return true;
        if (r >= 0x1798 && r <= 0x179D) return true;
        return r >= 0x17A3 && r <= 0x17B3;
    }

    private static boolean isVPre(int r) { return r >= 0x17C1 && r <= 0x17C5; }

    // optRobat returns the position(s) after an optional Robat at p.
    private static int[] optRobat(int[] r, int p) {
        if (p < r.length && r[p] == ROBAT) return new int[]{p, p + 1};
        return new int[]{p};
    }

    // coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
    private static void coengEnds(int[] r, int s, java.util.function.IntConsumer add) {
        int n = r.length;
        if (s + 1 < n && r[s] == COENG && isBase(r[s + 1])) add.accept(s + 2);
        if (s + 3 < n && r[s] == COENG && isNonRo(r[s + 1]) && r[s + 2] == COENG && isBase(r[s + 3]))
            add.accept(s + 4);
    }

    // strongEnds enumerates all end indices of a STRONG match starting at s.
    private static void strongEnds(int[] r, int s, java.util.function.IntConsumer add) {
        int n = r.length;
        if (s >= n) return;
        if (isS1(r[s])) {
            for (int p : optRobat(r, s + 1)) {
                add.accept(p);
                if (p + 1 < n && r[p] == COENG && isNonBA(r[p + 1])) {
                    int q = p + 2;
                    add.accept(q);
                    if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add.accept(q + 2);
                }
            }
        }
        if (isNonBA(r[s])) {
            for (int p : optRobat(r, s + 1)) {
                if (p + 1 < n && r[p] == COENG && isS1(r[p + 1])) {
                    int q = p + 2;
                    add.accept(q);
                    if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add.accept(q + 2);
                }
                if (p + 3 < n && r[p] == COENG && isNonBA(r[p + 1]) && r[p + 2] == COENG && isS1(r[p + 3]))
                    add.accept(p + 4);
            }
        }
    }

    // nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
    private static void nstrongEnds(int[] r, int s, java.util.function.IntConsumer add) {
        int n = r.length;
        if (s >= n) return;
        if (isS2(r[s])) {
            for (int p : optRobat(r, s + 1)) {
                add.accept(p);
                if (p + 1 < n && r[p] == COENG && isS2(r[p + 1])) {
                    int q = p + 2;
                    add.accept(q);
                    if (q + 1 < n && r[q] == COENG && isS2(r[q + 1])) add.accept(q + 2);
                }
            }
        }
        if (r[s] == BA) {
            for (int p : optRobat(r, s + 1)) {
                add.accept(p);
                coengEnds(r, p, e1 -> {
                    add.accept(e1);
                    coengEnds(r, e1, add::accept);
                });
            }
        }
        if (isBase(r[s])) {
            for (int p : optRobat(r, s + 1)) {
                if (p + 3 < n && r[p] == COENG && isNonRo(r[p + 1]) && r[p + 2] == COENG && r[p + 3] == BA)
                    add.accept(p + 4);
                if (p + 3 < n && r[p] == COENG && r[p + 1] == BA && r[p + 2] == COENG && isBase(r[p + 3]))
                    add.accept(p + 4);
            }
        }
    }

    private interface Ends { void ends(int[] r, int s, java.util.function.IntConsumer add); }

    // canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
    private static boolean canEndAt(int[] r, int target, Ends ends) {
        for (int s = 0; s < target; s++) {
            boolean[] found = {false};
            ends.ends(r, s, e -> { if (e == target) found[0] = true; });
            if (found[0]) return true;
        }
        return false;
    }

    // vaSamyokAt is the lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
    private static boolean vaSamyokAt(int[] r, int p) {
        int n = r.length;
        if (p >= n) return false;
        int c = r[p];
        if (c == 0x17D0) return true;
        if (c >= 0x17B7 && c <= 0x17BA) return true;
        if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return true;
        return c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6;
    }

    // applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
    private static void applyShifter(int[] r, Ends ends, int shifter) {
        for (int k = 0; k < r.length; k++) {
            if (r[k] != 0x17BB) continue;
            boolean ctx = canEndAt(r, k, ends)
                || (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, k - 1, ends));
            if (ctx && vaSamyokAt(r, k + 1)) r[k] = shifter;
        }
    }

    private static boolean isInvis(int c) { return c == COENG || c == ZWNJ || c == ZWJ; }

    // collapseInvis: (‍?្)[្‌‍]+ -> \1
    private static int[] collapseInvis(int[] r) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            int g1End = -1;
            if (r[i] == ZWJ && i + 1 < n && r[i + 1] == COENG) g1End = i + 2;
            else if (r[i] == COENG) g1End = i + 1;
            if (g1End >= 0) {
                int k = g1End;
                while (k < n && isInvis(r[k])) k++;
                if (k > g1End) {
                    for (int t = i; t < g1End; t++) out[o++] = r[t];
                    i = k;
                    continue;
                }
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // pairReplace replaces every non-overlapping [a,b] with the codepoints in repl.
    private static int[] pairReplace(int[] r, int a, int b, int r0, int r1) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (i + 1 < n && r[i] == a && r[i + 1] == b) {
                out[o++] = r0; out[o++] = r1;
                i += 2;
                continue;
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // pairReplace3 replaces every non-overlapping [a,b,c] with repl.
    private static int[] pairReplace3(int[] r, int a, int b, int c, int repl) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
                out[o++] = repl;
                i += 3;
                continue;
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
    private static int[] vowelSplit(int[] r, int tail, int head) {
        int n = r.length;
        ArrayList<Integer> buf = new ArrayList<>(n);
        int i = 0;
        while (i < n) {
            if (r[i] == 0x17C1) {
                if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail) {
                    buf.add(head); buf.add(r[i + 1]);
                    i += 3;
                    continue;
                }
                if (i + 1 < n && r[i + 1] == tail) {
                    buf.add(head);
                    i += 2;
                    continue;
                }
            }
            buf.add(r[i]);
            i++;
        }
        int[] res = new int[buf.size()];
        for (int k = 0; k < res.length; k++) res[k] = buf.get(k);
        return res;
    }

    // coengRo: (្រ)(្[ក-ឳ]) -> \2\1
    private static int[] coengRo(int[] r) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (i + 3 < n && r[i] == COENG && r[i + 1] == 0x179A
                && r[i + 2] == COENG && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
                out[o++] = r[i + 2]; out[o++] = r[i + 3]; out[o++] = r[i]; out[o++] = r[i + 1];
                i += 4;
                continue;
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // coengDa: (្)ដ -> \1ត
    private static int[] coengDa(int[] r) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (i + 1 < n && r[i] == COENG && r[i + 1] == 0x178A) {
                out[o++] = COENG; out[o++] = 0x178F;
                i += 2;
                continue;
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    private static boolean isDigit(int r) { return r >= 0x17E0 && r <= 0x17E9; }

    // lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
    private static int[] lunar1(int[] r) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (r[i] == 0x17E1 && i + 3 < n && isDigit(r[i + 1]) && r[i + 2] == COENG && r[i + 3] == 0x17D4) {
                int v = 10 + (r[i + 1] - 0x17E0);
                if (v > 15) {
                    for (int t = i; t < i + 4; t++) out[o++] = r[t];
                } else {
                    out[o++] = 0x19E0 + v;
                }
                i += 4;
                continue;
            }
            if (i + 2 < n && isDigit(r[i]) && r[i + 1] == COENG && r[i + 2] == 0x17D4) {
                out[o++] = 0x19E0 + (r[i] - 0x17E0);
                i += 3;
                continue;
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
    private static int[] lunar2(int[] r) {
        int n = r.length;
        int[] out = new int[n];
        int o = 0, i = 0;
        while (i < n) {
            if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == COENG) {
                if (i + 3 < n && r[i + 2] == 0x17E1 && isDigit(r[i + 3])) {
                    int v = 10 + (r[i + 3] - 0x17E0);
                    if (v > 15) {
                        for (int t = i; t < i + 4; t++) out[o++] = r[t];
                    } else {
                        out[o++] = 0x19F0 + v;
                    }
                    i += 4;
                    continue;
                }
                if (i + 2 < n && isDigit(r[i + 2])) {
                    out[o++] = 0x19F0 + (r[i + 2] - 0x17E0);
                    i += 3;
                    continue;
                }
            }
            out[o++] = r[i];
            i++;
        }
        return Arrays.copyOf(out, o);
    }

    // hasByteE1 reports whether s contains UTF-8 byte 0xE1, scanned 8 bytes at a
    // time (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte
    // 0xE1, so no 0xE1 means no Khmer codepoint and the input is unchanged.
    private static boolean hasByteE1(byte[] s) {
        final long lo   = 0x0101010101010101L;
        final long hi   = 0x8080808080808080L;
        final long mask = 0xE1E1E1E1E1E1E1E1L;
        int i = 0;
        for (; i + 8 <= s.length; i += 8) {
            long w = (s[i] & 0xFFL) | (s[i + 1] & 0xFFL) << 8 | (s[i + 2] & 0xFFL) << 16
                | (s[i + 3] & 0xFFL) << 24 | (s[i + 4] & 0xFFL) << 32 | (s[i + 5] & 0xFFL) << 40
                | (s[i + 6] & 0xFFL) << 48 | (s[i + 7] & 0xFFL) << 56;
            long x = w ^ mask;
            if (((x - lo) & ~x & hi) != 0) return true;
        }
        for (; i < s.length; i++) {
            if ((s[i] & 0xFF) == 0xE1) return true;
        }
        return false;
    }

    // xhmPrefix replaces [ិ-ៅ]្ with ‍$0 (prepend U+200D before the pair).
    private static int[] xhmPrefix(int[] cps) {
        int n = cps.length;
        ArrayList<Integer> out = new ArrayList<>(n + 8);
        for (int i = 0; i < n; i++) {
            if (i + 1 < n && cps[i] >= 0x17B7 && cps[i] <= 0x17C5 && cps[i + 1] == COENG) {
                out.add(ZWJ);
                out.add(cps[i]);
                out.add(cps[i + 1]);
                i++;
                continue;
            }
            out.add(cps[i]);
        }
        int[] res = new int[out.size()];
        for (int k = 0; k < res.length; k++) res[k] = out.get(k);
        return res;
    }

    /** Returns the Khmer-normalized form of txt. */
    public static String normalize(String txt) {
        return normalize(txt, "km");
    }

    /** Returns the Khmer-normalized form of txt (lang: "km" or "xhm"). */
    public static String normalize(String txt, String lang) {
        // SWAR skip/scan fast path: no Khmer byte => identity.
        if (!"xhm".equals(lang) && !hasByteE1(txt.getBytes(java.nio.charset.StandardCharsets.UTF_8))) {
            return txt;
        }

        int[] cps = txt.codePoints().toArray();
        if ("xhm".equals(lang)) cps = xhmPrefix(cps);
        int n = cps.length;
        int[] cats = new int[n];
        for (int i = 0; i < n; i++) cats[i] = charcat(cps[i]);

        for (int i = 1; i < n; i++) {
            if (cps[i - 1] == ZWJ || cps[i - 1] == COENG) {
                if (cats[i] == CAT_BASE || cats[i] == CAT_COENG) {
                    cats[i] = cats[i - 1];
                }
            }
        }

        StringBuilder res = new StringBuilder(txt.length());
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

            int[] syl = new int[indices.length];
            for (int k = 0; k < indices.length; k++) syl[k] = cps[indices[k]];

            syl = collapseInvis(syl);
            syl = pairReplace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8); // ើា -> ោី
            syl = vowelSplit(syl, 0x17B8, 0x17BE);                  // េ(◌)ី -> ើ(◌)
            syl = vowelSplit(syl, 0x17B6, 0x17C4);                  // េ(◌)ា -> ោ(◌)
            syl = pairReplace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE); // ើុ -> ុើ
            applyShifter(syl, BetterKhmer::strongEnds, 0x17CA);     // strong  -u -> ៊
            applyShifter(syl, BetterKhmer::nstrongEnds, 0x17C9);    // weak    -u -> ៉
            syl = coengRo(syl);
            syl = coengDa(syl);
            syl = lunar1(syl);
            syl = lunar2(syl);
            syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0); // ។្។ -> ᧰

            for (int r : syl) res.appendCodePoint(r);
            i = j;
        }
        return res.toString();
    }
}
