// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Kotlin — betterkhmer. Regex-free.

package com.betterkhmer

import java.util.Arrays

object BetterKhmer {
    private const val CAT_OTHER   = 0
    private const val CAT_BASE    = 1
    private const val CAT_ROBAT   = 2
    private const val CAT_COENG   = 3
    private const val CAT_SHIFT   = 4
    private const val CAT_Z       = 5
    private const val CAT_VPRE    = 6
    private const val CAT_VB      = 7
    private const val CAT_VA      = 8
    private const val CAT_VPOST   = 9
    private const val CAT_MS      = 10
    private const val CAT_MF      = 11
    private const val CAT_ZFCOENG = 12

    private val CATEGORIES: IntArray = IntArray(0x17DE - 0x1780).also { c ->
        Arrays.fill(c, CAT_OTHER)
        for (i in 0..(0x17A2 - 0x1780)) c[i] = CAT_BASE
        for (i in (0x17A5 - 0x1780)..(0x17B3 - 0x1780)) c[i] = CAT_BASE
        c[0x17B6 - 0x1780] = CAT_VPOST
        for (i in (0x17B7 - 0x1780)..(0x17BA - 0x1780)) c[i] = CAT_VA
        for (i in (0x17BB - 0x1780)..(0x17BD - 0x1780)) c[i] = CAT_VB
        for (i in (0x17BE - 0x1780)..(0x17C5 - 0x1780)) c[i] = CAT_VPRE
        c[0x17C6 - 0x1780] = CAT_MS; c[0x17C7 - 0x1780] = CAT_MF; c[0x17C8 - 0x1780] = CAT_MF
        c[0x17C9 - 0x1780] = CAT_SHIFT; c[0x17CA - 0x1780] = CAT_SHIFT
        c[0x17CB - 0x1780] = CAT_MS; c[0x17CC - 0x1780] = CAT_ROBAT
        for (i in (0x17CD - 0x1780)..(0x17D1 - 0x1780)) c[i] = CAT_MS
        c[0x17D2 - 0x1780] = CAT_COENG; c[0x17D3 - 0x1780] = CAT_MS
        for (i in (0x17D4 - 0x1780)..(0x17DC - 0x1780)) c[i] = CAT_OTHER
        c[0x17DD - 0x1780] = CAT_MS
    }

    private const val ZWNJ  = 0x200C
    private const val ZWJ   = 0x200D
    private const val COENG = 0x17D2
    private const val ROBAT = 0x17CC
    private const val BA    = 0x1794

    private fun charcat(cp: Int): Int {
        if (cp in 0x1780..0x17DD) return CATEGORIES[cp - 0x1780]
        if (cp == 0x200C) return CAT_Z
        if (cp == 0x200D) return CAT_ZFCOENG
        return CAT_OTHER
    }

    // --- Khmer consonant classes (from the SIL reference khres) ---

    // B: all bases (incl. dotted circle).
    private fun isBase(r: Int): Boolean =
        (r in 0x1780..0x17A2) || (r in 0x17A5..0x17B3) || r == 0x25CC

    // NonRo: consonants excluding Ro (U+179A).
    private fun isNonRo(r: Int): Boolean =
        (r in 0x1780..0x1799) || (r in 0x179B..0x17A2) || (r in 0x17A5..0x17B3)

    // NonBA: consonants excluding Ba (U+1794).
    private fun isNonBA(r: Int): Boolean =
        (r in 0x1780..0x1793) || (r in 0x1795..0x17A2) || (r in 0x17A5..0x17B3)

    // S1: series-1 consonants.
    private fun isS1(r: Int): Boolean {
        if (r in 0x1780..0x1783) return true
        if (r in 0x1785..0x1788) return true
        if (r in 0x178A..0x178D) return true
        if (r in 0x178F..0x1792) return true
        if (r in 0x1795..0x1797) return true
        if (r in 0x179E..0x17A0) return true
        return r == 0x17A2
    }

    // S2: series-2 consonants.
    private fun isS2(r: Int): Boolean {
        if (r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 || r == 0x1794 || r == 0x17A1) return true
        if (r in 0x1798..0x179D) return true
        return r in 0x17A3..0x17B3
    }

    private fun isVPre(r: Int): Boolean = r in 0x17C1..0x17C5

    // optRobat returns the position(s) after an optional Robat at p.
    private fun optRobat(r: IntArray, p: Int): IntArray =
        if (p < r.size && r[p] == ROBAT) intArrayOf(p, p + 1) else intArrayOf(p)

    // coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
    private inline fun coengEnds(r: IntArray, s: Int, add: (Int) -> Unit) {
        val n = r.size
        if (s + 1 < n && r[s] == COENG && isBase(r[s + 1])) add(s + 2)
        if (s + 3 < n && r[s] == COENG && isNonRo(r[s + 1]) && r[s + 2] == COENG && isBase(r[s + 3])) add(s + 4)
    }

    // strongEnds enumerates all end indices of a STRONG match starting at s.
    private fun strongEnds(r: IntArray, s: Int, add: (Int) -> Unit) {
        val n = r.size
        if (s >= n) return
        if (isS1(r[s])) {
            for (p in optRobat(r, s + 1)) {
                add(p)
                if (p + 1 < n && r[p] == COENG && isNonBA(r[p + 1])) {
                    val q = p + 2
                    add(q)
                    if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add(q + 2)
                }
            }
        }
        if (isNonBA(r[s])) {
            for (p in optRobat(r, s + 1)) {
                if (p + 1 < n && r[p] == COENG && isS1(r[p + 1])) {
                    val q = p + 2
                    add(q)
                    if (q + 1 < n && r[q] == COENG && isNonBA(r[q + 1])) add(q + 2)
                }
                if (p + 3 < n && r[p] == COENG && isNonBA(r[p + 1]) && r[p + 2] == COENG && isS1(r[p + 3]))
                    add(p + 4)
            }
        }
    }

    // nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
    private fun nstrongEnds(r: IntArray, s: Int, add: (Int) -> Unit) {
        val n = r.size
        if (s >= n) return
        if (isS2(r[s])) {
            for (p in optRobat(r, s + 1)) {
                add(p)
                if (p + 1 < n && r[p] == COENG && isS2(r[p + 1])) {
                    val q = p + 2
                    add(q)
                    if (q + 1 < n && r[q] == COENG && isS2(r[q + 1])) add(q + 2)
                }
            }
        }
        if (r[s] == BA) {
            for (p in optRobat(r, s + 1)) {
                add(p)
                coengEnds(r, p) { e1 ->
                    add(e1)
                    coengEnds(r, e1) { e2 -> add(e2) }
                }
            }
        }
        if (isBase(r[s])) {
            for (p in optRobat(r, s + 1)) {
                if (p + 3 < n && r[p] == COENG && isNonRo(r[p + 1]) && r[p + 2] == COENG && r[p + 3] == BA)
                    add(p + 4)
                if (p + 3 < n && r[p] == COENG && r[p + 1] == BA && r[p + 2] == COENG && isBase(r[p + 3]))
                    add(p + 4)
            }
        }
    }

    // canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
    private fun canEndAt(r: IntArray, target: Int, ends: (IntArray, Int, (Int) -> Unit) -> Unit): Boolean {
        for (s in 0 until target) {
            var found = false
            ends(r, s) { e -> if (e == target) found = true }
            if (found) return true
        }
        return false
    }

    // vaSamyokAt is the lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
    private fun vaSamyokAt(r: IntArray, p: Int): Boolean {
        val n = r.size
        if (p >= n) return false
        val c = r[p]
        if (c == 0x17D0) return true
        if (c in 0x17B7..0x17BA) return true
        if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return true
        return c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6
    }

    // applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
    private fun applyShifter(r: IntArray, ends: (IntArray, Int, (Int) -> Unit) -> Unit, shifter: Int) {
        for (k in r.indices) {
            if (r[k] != 0x17BB) continue
            val ctx = canEndAt(r, k, ends) ||
                (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, k - 1, ends))
            if (ctx && vaSamyokAt(r, k + 1)) r[k] = shifter
        }
    }

    private fun isInvis(c: Int): Boolean = c == COENG || c == ZWNJ || c == ZWJ

    // collapseInvis: (‍?្)[្‌‍]+ -> \1
    private fun collapseInvis(r: IntArray): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            var g1End = -1
            if (r[i] == ZWJ && i + 1 < n && r[i + 1] == COENG) g1End = i + 2
            else if (r[i] == COENG) g1End = i + 1
            if (g1End >= 0) {
                var k = g1End
                while (k < n && isInvis(r[k])) k++
                if (k > g1End) {
                    for (t in i until g1End) out.add(r[t])
                    i = k
                    continue
                }
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // pairReplace replaces every non-overlapping [a,b] with [r0,r1].
    private fun pairReplace(r: IntArray, a: Int, b: Int, r0: Int, r1: Int): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (i + 1 < n && r[i] == a && r[i + 1] == b) {
                out.add(r0); out.add(r1)
                i += 2
                continue
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // pairReplace3 replaces every non-overlapping [a,b,c] with repl.
    private fun pairReplace3(r: IntArray, a: Int, b: Int, c: Int, repl: Int): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
                out.add(repl)
                i += 3
                continue
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
    private fun vowelSplit(r: IntArray, tail: Int, head: Int): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (r[i] == 0x17C1) {
                if (i + 2 < n && r[i + 1] in 0x17BB..0x17BD && r[i + 2] == tail) {
                    out.add(head); out.add(r[i + 1])
                    i += 3
                    continue
                }
                if (i + 1 < n && r[i + 1] == tail) {
                    out.add(head)
                    i += 2
                    continue
                }
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // coengRo: (្រ)(្[ក-ឳ]) -> \2\1
    private fun coengRo(r: IntArray): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (i + 3 < n && r[i] == COENG && r[i + 1] == 0x179A &&
                r[i + 2] == COENG && r[i + 3] in 0x1780..0x17B3) {
                out.add(r[i + 2]); out.add(r[i + 3]); out.add(r[i]); out.add(r[i + 1])
                i += 4
                continue
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // coengDa: (្)ដ -> \1ត
    private fun coengDa(r: IntArray): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (i + 1 < n && r[i] == COENG && r[i + 1] == 0x178A) {
                out.add(COENG); out.add(0x178F)
                i += 2
                continue
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    private fun isDigit(r: Int): Boolean = r in 0x17E0..0x17E9

    // lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
    private fun lunar1(r: IntArray): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (r[i] == 0x17E1 && i + 3 < n && isDigit(r[i + 1]) && r[i + 2] == COENG && r[i + 3] == 0x17D4) {
                val v = 10 + (r[i + 1] - 0x17E0)
                if (v > 15) {
                    for (t in i until i + 4) out.add(r[t])
                } else {
                    out.add(0x19E0 + v)
                }
                i += 4
                continue
            }
            if (i + 2 < n && isDigit(r[i]) && r[i + 1] == COENG && r[i + 2] == 0x17D4) {
                out.add(0x19E0 + (r[i] - 0x17E0))
                i += 3
                continue
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
    private fun lunar2(r: IntArray): IntArray {
        val n = r.size
        val out = ArrayList<Int>(n)
        var i = 0
        while (i < n) {
            if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == COENG) {
                if (i + 3 < n && r[i + 2] == 0x17E1 && isDigit(r[i + 3])) {
                    val v = 10 + (r[i + 3] - 0x17E0)
                    if (v > 15) {
                        for (t in i until i + 4) out.add(r[t])
                    } else {
                        out.add(0x19F0 + v)
                    }
                    i += 4
                    continue
                }
                if (i + 2 < n && isDigit(r[i + 2])) {
                    out.add(0x19F0 + (r[i + 2] - 0x17E0))
                    i += 3
                    continue
                }
            }
            out.add(r[i])
            i++
        }
        return out.toIntArray()
    }

    // hasByteE1 reports whether s contains UTF-8 byte 0xE1, scanned 8 bytes at a
    // time (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte
    // 0xE1, so no 0xE1 means no Khmer codepoint and the input is unchanged.
    private fun hasByteE1(s: ByteArray): Boolean {
        val lo   = 0x0101010101010101L
        val hi   = -0x7f7f7f7f7f7f7f80L // 0x8080808080808080
        val mask = -0x1e1e1e1e1e1e1e1fL // 0xE1E1E1E1E1E1E1E1
        var i = 0
        while (i + 8 <= s.size) {
            val w = (s[i].toLong() and 0xFF) or ((s[i + 1].toLong() and 0xFF) shl 8) or
                ((s[i + 2].toLong() and 0xFF) shl 16) or ((s[i + 3].toLong() and 0xFF) shl 24) or
                ((s[i + 4].toLong() and 0xFF) shl 32) or ((s[i + 5].toLong() and 0xFF) shl 40) or
                ((s[i + 6].toLong() and 0xFF) shl 48) or ((s[i + 7].toLong() and 0xFF) shl 56)
            val x = w xor mask
            if (((x - lo) and x.inv() and hi) != 0L) return true
            i += 8
        }
        while (i < s.size) {
            if ((s[i].toInt() and 0xFF) == 0xE1) return true
            i++
        }
        return false
    }

    // xhmPrefix replaces [ិ-ៅ]្ with ‍$0 (prepend U+200D before the pair).
    private fun xhmPrefix(cps: IntArray): IntArray {
        val n = cps.size
        val out = ArrayList<Int>(n + 8)
        var i = 0
        while (i < n) {
            if (i + 1 < n && cps[i] in 0x17B7..0x17C5 && cps[i + 1] == COENG) {
                out.add(ZWJ)
                out.add(cps[i])
                out.add(cps[i + 1])
                i += 2
                continue
            }
            out.add(cps[i])
            i++
        }
        return out.toIntArray()
    }

    /** Returns the Khmer-normalized form of txt. */
    fun normalize(txt: String, lang: String = "km"): String {
        // SWAR skip/scan fast path: no Khmer byte => identity.
        if (lang != "xhm" && !hasByteE1(txt.toByteArray(Charsets.UTF_8))) {
            return txt
        }

        var cps = txt.codePoints().toArray()
        if (lang == "xhm") cps = xhmPrefix(cps)
        val n = cps.size
        val cats = IntArray(n) { charcat(cps[it]) }

        for (i in 1 until n) {
            if (cps[i - 1] == ZWJ || cps[i - 1] == COENG) {
                if (cats[i] == CAT_BASE || cats[i] == CAT_COENG) cats[i] = cats[i - 1]
            }
        }

        val res = StringBuilder(txt.length)
        var i = 0
        while (i < n) {
            if (cats[i] != CAT_BASE) { res.appendCodePoint(cps[i]); i++; continue }
            var j = i + 1
            while (j < n && cats[j] > CAT_BASE) j++

            val indices = (i until j).sortedWith(compareBy({ cats[it] }, { it }))
            var syl = IntArray(indices.size) { cps[indices[it]] }

            syl = collapseInvis(syl)
            syl = pairReplace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8) // ើា -> ោី
            syl = vowelSplit(syl, 0x17B8, 0x17BE)                  // េ(◌)ី -> ើ(◌)
            syl = vowelSplit(syl, 0x17B6, 0x17C4)                  // េ(◌)ា -> ោ(◌)
            syl = pairReplace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE) // ើុ -> ុើ
            applyShifter(syl, ::strongEnds, 0x17CA)                // strong  -u -> ៊
            applyShifter(syl, ::nstrongEnds, 0x17C9)               // weak    -u -> ៉
            syl = coengRo(syl)
            syl = coengDa(syl)
            syl = lunar1(syl)
            syl = lunar2(syl)
            syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0) // ។្។ -> ᧰

            for (r in syl) res.appendCodePoint(r)
            i = j
        }
        return res.toString()
    }
}
