// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Kotlin — betterkhmer.

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

    private val S1    = "[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]"
    private val NON_BA = "[ក-នផ-អឥ-ឳ]"
    private val S2    = "[ងកណនបម-ឝឡឣ-ឳ]"
    private val NON_RO = "[ក-យល-អឥ-ឳ]"
    private val B     = "[ក-អឥ-ឳ◌]"
    private val VA    = "(?:[ិ-ឺើឿ៝]|ាំ)"
    private val COENG = "(?:(?:្$NON_RO)?្$B)"

    private val STRONG = "$S1៌?(?:្$NON_BA(?:្$NON_BA)?)?|$NON_BA៌?(?:្$S1(?:្$NON_BA)?|្$NON_BA្$S1)"
    private val NSTRONG = "(?:$S2៌?(?:្$S2(?:្$S2)?)?|ប៌?(?:$COENG(?:$COENG)?)?|$B៌?(?:្$NON_RO្ប|្ប(?:្$B)))"

    private val RE_INVIS    = Regex("(‍?្)[្‌‍]+")
    private val RE_VBE      = Regex("ើា")
    private val RE_V1       = Regex("េ([ុ-ួ]?)ី")
    private val RE_V2       = Regex("េ([ុ-ួ]?)ា")
    private val RE_V3       = Regex("(ើ)(ុ)")
    private val RE_STRONG   = Regex("(?:$STRONG)[េ-ៅ]?ុ(?=$VA|័)")
    private val RE_NSTRONG  = Regex("(?:$NSTRONG)[េ-ៅ]?ុ(?=$VA|័)")
    private val RE_COENG_RO = Regex("(្រ)(្[ក-ឳ])")
    private val RE_COENG_DA = Regex("្ដ")
    private val RE_LUNAR1   = Regex("(១?)([០-៩])្។")
    private val RE_LUNAR2   = Regex("។្(១?)([០-៩])")

    private fun charcat(cp: Int): Int {
        if (cp in 0x1780..0x17DD) return CATEGORIES[cp - 0x1780]
        if (cp == 0x200C) return CAT_Z
        if (cp == 0x200D) return CAT_ZFCOENG
        return CAT_OTHER
    }

    private fun lunarReplace(d1: String, d2: String, base: Int): String? {
        val v1 = if (d1.isEmpty()) 0 else d1.codePointAt(0) - 0x17E0
        val v = v1 * 10 + d2.codePointAt(0) - 0x17E0
        if (v > 15) return null
        return String(Character.toChars(base + v))
    }

    /** Returns the Khmer-normalized form of txt. */
    fun normalize(txt: String, lang: String = "km"): String {
        var s = if (lang == "xhm") txt.replace(Regex("[ិ-ៅ]្"), "‍$0") else txt

        val cps = s.codePoints().toArray()
        val n = cps.size
        val cats = IntArray(n) { charcat(cps[it]) }

        for (i in 1 until n) {
            if (cps[i - 1] == 0x200D || cps[i - 1] == 0x17D2) {
                if (cats[i] == CAT_BASE || cats[i] == CAT_COENG) cats[i] = cats[i - 1]
            }
        }

        val res = StringBuilder()
        var i = 0
        while (i < n) {
            if (cats[i] != CAT_BASE) { res.appendCodePoint(cps[i]); i++; continue }
            var j = i + 1
            while (j < n && cats[j] > CAT_BASE) j++

            val indices = (i until j).sortedWith(compareBy({ cats[it] }, { it }))
            var syl = buildString { indices.forEach { appendCodePoint(cps[it]) } }

            syl = RE_INVIS.replace(syl, "$1")
            syl = RE_VBE.replace(syl, "ោី")
            syl = RE_V1.replace(syl, "ើ$1")
            syl = RE_V2.replace(syl, "ោ$1")
            syl = RE_V3.replace(syl, "$2$1")
            syl = RE_STRONG.replace(syl) { it.value.dropLast(1) + "៊" }
            syl = RE_NSTRONG.replace(syl) { it.value.dropLast(1) + "៉" }
            syl = RE_COENG_RO.replace(syl, "$2$1")
            syl = RE_COENG_DA.replace(syl, "្ត")
            syl = RE_LUNAR1.replace(syl) { m ->
                lunarReplace(m.groupValues[1], m.groupValues[2], 0x19E0) ?: m.value
            }
            syl = RE_LUNAR2.replace(syl) { m ->
                lunarReplace(m.groupValues[1], m.groupValues[2], 0x19F0) ?: m.value
            }
            syl = syl.replace("។្។", "᧰")
            res.append(syl)
            i = j
        }
        return res.toString()
    }
}
