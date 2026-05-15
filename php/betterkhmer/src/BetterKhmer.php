<?php
// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to PHP — betterkhmer package.

declare(strict_types=1);

namespace BetterKhmer;

final class Khnormal
{
    const CAT_OTHER   = 0;
    const CAT_BASE    = 1;
    const CAT_ROBAT   = 2;
    const CAT_COENG   = 3;
    const CAT_SHIFT   = 4;
    const CAT_Z       = 5;
    const CAT_VPRE    = 6;
    const CAT_VB      = 7;
    const CAT_VA      = 8;
    const CAT_VPOST   = 9;
    const CAT_MS      = 10;
    const CAT_MF      = 11;
    const CAT_ZFCOENG = 12;

    private static array $categories;
    private static string $reInvis;
    private static string $reV1;
    private static string $reV2;
    private static string $reV3;
    private static string $reStrong;
    private static string $reNStrong;
    private static string $reCoengRo;
    private static string $reCoengDa;
    private static string $reLunar1;
    private static string $reLunar2;
    private static bool $initialized = false;

    private static function init(): void
    {
        if (self::$initialized) return;
        self::$initialized = true;

        $cats = [];
        for ($i = 0; $i < 0x17DE - 0x1780; $i++) $cats[$i] = self::CAT_OTHER;
        for ($i = 0; $i <= 0x17A2 - 0x1780; $i++) $cats[$i] = self::CAT_BASE;
        for ($i = 0x17A5 - 0x1780; $i <= 0x17B3 - 0x1780; $i++) $cats[$i] = self::CAT_BASE;
        $cats[0x17B6 - 0x1780] = self::CAT_VPOST;
        for ($i = 0x17B7 - 0x1780; $i <= 0x17BA - 0x1780; $i++) $cats[$i] = self::CAT_VA;
        for ($i = 0x17BB - 0x1780; $i <= 0x17BD - 0x1780; $i++) $cats[$i] = self::CAT_VB;
        for ($i = 0x17BE - 0x1780; $i <= 0x17C5 - 0x1780; $i++) $cats[$i] = self::CAT_VPRE;
        $cats[0x17C6 - 0x1780] = self::CAT_MS;
        $cats[0x17C7 - 0x1780] = self::CAT_MF;
        $cats[0x17C8 - 0x1780] = self::CAT_MF;
        $cats[0x17C9 - 0x1780] = self::CAT_SHIFT;
        $cats[0x17CA - 0x1780] = self::CAT_SHIFT;
        $cats[0x17CB - 0x1780] = self::CAT_MS;
        $cats[0x17CC - 0x1780] = self::CAT_ROBAT;
        for ($i = 0x17CD - 0x1780; $i <= 0x17D1 - 0x1780; $i++) $cats[$i] = self::CAT_MS;
        $cats[0x17D2 - 0x1780] = self::CAT_COENG;
        $cats[0x17D3 - 0x1780] = self::CAT_MS;
        for ($i = 0x17D4 - 0x1780; $i <= 0x17DC - 0x1780; $i++) $cats[$i] = self::CAT_OTHER;
        $cats[0x17DD - 0x1780] = self::CAT_MS;
        self::$categories = $cats;

        $S1     = '[\x{1780}-\x{1783}\x{1785}-\x{1788}\x{178A}-\x{178D}\x{178F}-\x{1792}\x{1795}-\x{1797}\x{179E}-\x{17A0}\x{17A2}]';
        $NON_BA = '[\x{1780}-\x{1793}\x{1795}-\x{17A2}\x{17A5}-\x{17B3}]';
        $S2     = '[\x{1784}\x{1780}\x{178E}\x{1793}\x{1794}\x{1798}-\x{179D}\x{17A1}\x{17A3}-\x{17B3}]';
        $NON_RO = '[\x{1780}-\x{1799}\x{179B}-\x{17A2}\x{17A5}-\x{17B3}]';
        $B      = '[\x{1780}-\x{17A2}\x{17A5}-\x{17B3}\x{25CC}]';
        $VA     = '(?:[\x{17B7}-\x{17BA}\x{17BE}\x{17BF}\x{17DD}]|\x{17B6}\x{17C6})';
        $COENG  = "(?:(?:\\x{17D2}$NON_RO)?\\x{17D2}$B)";

        $STRONG = "$S1\\x{17CC}?(?:\\x{17D2}$NON_BA(?:\\x{17D2}$NON_BA)?)?|$NON_BA\\x{17CC}?(?:\\x{17D2}$S1(?:\\x{17D2}$NON_BA)?|\\x{17D2}$NON_BA\\x{17D2}$S1)";
        $NSTRONG = "(?:$S2\\x{17CC}?(?:\\x{17D2}$S2(?:\\x{17D2}$S2)?)?|\\x{1794}\\x{17CC}?(?:$COENG(?:$COENG)?)?|$B\\x{17CC}?(?:\\x{17D2}$NON_RO\\x{17D2}\\x{1794}|\\x{17D2}\\x{1794}(?:\\x{17D2}$B)))";

        self::$reInvis    = '/(\x{200D}?\x{17D2})[\x{17D2}\x{200C}\x{200D}]+/u';
        self::$reV1       = '/\x{17C1}([\x{17BB}-\x{17BD}]?)\x{17B8}/u';
        self::$reV2       = '/\x{17C1}([\x{17BB}-\x{17BD}]?)\x{17B6}/u';
        self::$reV3       = '/(\x{17BE})(\x{17BB})/u';
        self::$reStrong   = "/(?:$STRONG)[\x{17C1}-\x{17C5}]?\\x{17BB}(?=$VA|\\x{17D0})/u";
        self::$reNStrong  = "/(?:$NSTRONG)[\x{17C1}-\x{17C5}]?\\x{17BB}(?=$VA|\\x{17D0})/u";
        self::$reCoengRo  = '/(\x{17D2}\x{179A})(\x{17D2}[\x{1780}-\x{17B3}])/u';
        self::$reCoengDa  = '/\x{17D2}\x{178A}/u';
        self::$reLunar1   = '/(\x{17E1}?)([\x{17E0}-\x{17E9}])\x{17D2}\x{17D4}/u';
        self::$reLunar2   = '/\x{17D4}\x{17D2}(\x{17E1}?)([\x{17E0}-\x{17E9}])/u';
    }

    private static function charcat(int $cp): int
    {
        if ($cp >= 0x1780 && $cp <= 0x17DD) return self::$categories[$cp - 0x1780];
        if ($cp === 0x200C) return self::CAT_Z;
        if ($cp === 0x200D) return self::CAT_ZFCOENG;
        return self::CAT_OTHER;
    }

    private static function lunarReplace(array $m, int $base): string
    {
        $d1 = $m[1];
        $d2 = $m[2];
        $v1 = $d1 !== '' ? mb_ord($d1, 'UTF-8') - 0x17E0 : 0;
        $v = $v1 * 10 + mb_ord($d2, 'UTF-8') - 0x17E0;
        if ($v > 15) return $m[0];
        return mb_chr($base + $v, 'UTF-8');
    }

    public static function normalize(string $txt, string $lang = 'km'): string
    {
        self::init();

        if ($lang === 'xhm') {
            $txt = preg_replace('/[\x{17B7}-\x{17C5}]\x{17D2}/u', "\u{200D}$0", $txt);
        }

        // split into Unicode codepoint array
        preg_match_all('/./us', $txt, $charMatches);
        $chars = $charMatches[0];
        $n = count($chars);
        $cats = array_map(fn($c) => self::charcat(mb_ord($c, 'UTF-8')), $chars);

        for ($i = 1; $i < $n; $i++) {
            $cp = mb_ord($chars[$i - 1], 'UTF-8');
            if ($cp === 0x200D || $cp === 0x17D2) {
                if ($cats[$i] === self::CAT_BASE || $cats[$i] === self::CAT_COENG) {
                    $cats[$i] = $cats[$i - 1];
                }
            }
        }

        $res = '';
        $i = 0;
        while ($i < $n) {
            if ($cats[$i] !== self::CAT_BASE) {
                $res .= $chars[$i];
                $i++;
                continue;
            }
            $j = $i + 1;
            while ($j < $n && $cats[$j] > self::CAT_BASE) $j++;

            $indices = range($i, $j - 1);
            usort($indices, function ($a, $b) use ($cats) {
                return $cats[$a] !== $cats[$b] ? $cats[$a] - $cats[$b] : $a - $b;
            });
            $syl = implode('', array_map(fn($k) => $chars[$k], $indices));

            $syl = preg_replace(self::$reInvis, '$1', $syl);
            $syl = str_replace("\u{17BE}\u{17B6}", "\u{17C4}\u{17B8}", $syl);
            $syl = preg_replace(self::$reV1, "\u{17BE}$1", $syl);
            $syl = preg_replace(self::$reV2, "\u{17C4}$1", $syl);
            $syl = preg_replace(self::$reV3, '$2$1', $syl);
            $syl = preg_replace_callback(self::$reStrong, function ($m) {
                return mb_substr($m[0], 0, -1, 'UTF-8') . "\u{17CA}";
            }, $syl);
            $syl = preg_replace_callback(self::$reNStrong, function ($m) {
                return mb_substr($m[0], 0, -1, 'UTF-8') . "\u{17C9}";
            }, $syl);
            $syl = preg_replace(self::$reCoengRo, '$2$1', $syl);
            $syl = preg_replace(self::$reCoengDa, "\u{17D2}\u{178F}", $syl);
            $syl = preg_replace_callback(self::$reLunar1, fn($m) => self::lunarReplace($m, 0x19E0), $syl);
            $syl = preg_replace_callback(self::$reLunar2, fn($m) => self::lunarReplace($m, 0x19F0), $syl);
            $syl = str_replace("\u{17D4}\u{17D2}\u{17D4}", "\u{19F0}", $syl);
            $res .= $syl;
            $i = $j;
        }
        return $res;
    }
}
