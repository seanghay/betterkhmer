package BetterKhmer;
# Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
# Ported to Perl — betterkhmer package.

use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use Unicode::UCD;

our $VERSION = '0.1.0';

# ---- Character categories ----

use constant {
    CAT_OTHER   => 0, CAT_BASE    => 1, CAT_ROBAT   => 2,
    CAT_COENG   => 3, CAT_SHIFT   => 4, CAT_Z       => 5,
    CAT_VPRE    => 6, CAT_VB      => 7, CAT_VA      => 8,
    CAT_VPOST   => 9, CAT_MS      => 10, CAT_MF     => 11,
    CAT_ZFCOENG => 12,
};

my @CATEGORIES = (0) x (0x17DE - 0x1780);
for my $i (0 .. 0x17A2 - 0x1780) { $CATEGORIES[$i] = CAT_BASE; }
for my $i (0x17A5 - 0x1780 .. 0x17B3 - 0x1780) { $CATEGORIES[$i] = CAT_BASE; }
$CATEGORIES[0x17B6 - 0x1780] = CAT_VPOST;
for my $i (0x17B7 - 0x1780 .. 0x17BA - 0x1780) { $CATEGORIES[$i] = CAT_VA;  }
for my $i (0x17BB - 0x1780 .. 0x17BD - 0x1780) { $CATEGORIES[$i] = CAT_VB;  }
for my $i (0x17BE - 0x1780 .. 0x17C5 - 0x1780) { $CATEGORIES[$i] = CAT_VPRE; }
$CATEGORIES[0x17C6 - 0x1780] = CAT_MS;
$CATEGORIES[0x17C7 - 0x1780] = CAT_MF;
$CATEGORIES[0x17C8 - 0x1780] = CAT_MF;
$CATEGORIES[0x17C9 - 0x1780] = CAT_SHIFT;
$CATEGORIES[0x17CA - 0x1780] = CAT_SHIFT;
$CATEGORIES[0x17CB - 0x1780] = CAT_MS;
$CATEGORIES[0x17CC - 0x1780] = CAT_ROBAT;
for my $i (0x17CD - 0x1780 .. 0x17D1 - 0x1780) { $CATEGORIES[$i] = CAT_MS; }
$CATEGORIES[0x17D2 - 0x1780] = CAT_COENG;
$CATEGORIES[0x17D3 - 0x1780] = CAT_MS;
$CATEGORIES[0x17DD - 0x1780] = CAT_MS;

sub _charcat {
    my $cp = shift;
    return $CATEGORIES[$cp - 0x1780] if $cp >= 0x1780 && $cp <= 0x17DD;
    return CAT_Z       if $cp == 0x200C;
    return CAT_ZFCOENG if $cp == 0x200D;
    return CAT_OTHER;
}

# ---- Compiled patterns ----

my $S1     = qr/[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]/;
my $NonBA  = qr/[ក-នផ-អឥ-ឳ]/;
my $S2     = qr/[ងកណនបម-ឝឡឣ-ឳ]/;
my $NonRo  = qr/[ក-យល-អឥ-ឳ]/;
my $B      = qr/[ក-អឥ-ឳ◌]/;
my $VA     = qr/(?:[ិ-ឺើ-ៀ]|ាំ)/; # ិ U+17B7 .. ឺ U+17BA, ើ U+17BE, ៀ U+17BF, plus ◌ marks
my $COENG  = qr/(?:(?:្$NonRo)?្$B)/;

my $STRONG =
    qr/$S1\x{17CC}?(?:្$NonBA(?:្$NonBA)?)?|$NonBA\x{17CC}?(?:្$S1(?:្$NonBA)?|្$NonBA\x{17D2}$S1)/;

my $NSTRONG =
    qr/(?:$S2\x{17CC}?(?:្$S2(?:្$S2)?)?|ប\x{17CC}?(?:$COENG(?:$COENG)?)?|$B\x{17CC}?(?:្$NonRo\x{17D2}ប|្ប(?:្$B)))/;

my $re_invis   = qr/(\x{200D}?\x{17D2})[\x{17D2}\x{200C}\x{200D}]+/u;
my $re_vbe     = qr/\x{17BE}\x{17B6}/u;
my $re_v1      = qr/\x{17C1}([\x{17BB}-\x{17BD}]?)\x{17B8}/u;
my $re_v2      = qr/\x{17C1}([\x{17BB}-\x{17BD}]?)\x{17B6}/u;
my $re_v3      = qr/(\x{17BE})(\x{17BB})/u;
my $re_strong  = qr/(?:$STRONG)[\x{17C1}-\x{17C5}]?/u;
my $re_nstrong = qr/(?:$NSTRONG)[\x{17C1}-\x{17C5}]?/u;
my $re_coengRo = qr/(\x{17D2}\x{179A})(\x{17D2}[\x{1780}-\x{17B3}])/u;
my $re_coengDa = qr/\x{17D2}\x{178A}/u;
my $re_lunar1  = qr/(\x{17E1}?)([\x{17E0}-\x{17E9}])\x{17D2}\x{17D4}/u;
my $re_lunar2  = qr/\x{17D4}\x{17D2}(\x{17E1}?)([\x{17E0}-\x{17E9}])/u;

sub _lunar_replace {
    my ($d1, $d2, $base) = @_;
    my $v1 = $d1 ? (ord($d1) - 0x17E0) : 0;
    my $v  = $v1 * 10 + (ord($d2) - 0x17E0);
    return undef if $v > 15;
    return chr($base + $v);
}

# ---- Public API ----

sub normalize {
    my ($txt, $lang) = @_;
    $lang //= 'km';

    use feature 'unicode_strings';

    if ($lang eq 'xhm') {
        $txt =~ s/([\x{17B6}-\x{17C5}]\x{17D2})/\x{200D}$1/gu;
    }

    # Decode to codepoints
    my @cps  = map { ord($_) } split //, $txt;
    my $n    = scalar @cps;
    my @cats = map { _charcat($_) } @cps;

    # Recategorise
    for my $i (1 .. $n - 1) {
        my $prev = $cps[$i - 1];
        if ($prev == 0x200D || $prev == 0x17D2) {
            if ($cats[$i] == CAT_BASE || $cats[$i] == CAT_ZFCOENG) {
                $cats[$i] = $cats[$i - 1];
            }
        }
    }

    my $result = '';
    my $i = 0;
    while ($i < $n) {
        if ($cats[$i] != CAT_BASE) {
            $result .= chr($cps[$i]);
            $i++;
            next;
        }
        my $j = $i + 1;
        $j++ while $j < $n && $cats[$j] > CAT_BASE;

        my @idx = ($i .. $j - 1);
        @idx = sort { $cats[$a] != $cats[$b] ? $cats[$a] <=> $cats[$b] : $a <=> $b } @idx;

        my $syl = join('', map { chr($cps[$_]) } @idx);

        $syl =~ s/$re_invis/$1/g;
        $syl =~ s/$re_vbe/\x{17C4}\x{17B8}/g;
        $syl =~ s/$re_v1/\x{17BE}$1/g;
        $syl =~ s/$re_v2/\x{17C4}$1/g;
        $syl =~ s/$re_v3/$2$1/g;
        $syl =~ s/($re_strong)\x{17BB}(?=[\x{17B7}-\x{17BA}\x{17BE}\x{17BF}]|ាំ|\x{17D0})/$1\x{17CA}/g;
        $syl =~ s/($re_nstrong)\x{17BB}(?=[\x{17B7}-\x{17BA}\x{17BE}\x{17BF}]|ាំ|\x{17D0})/$1\x{17C9}/g;
        $syl =~ s/$re_coengRo/$2$1/g;
        $syl =~ s/$re_coengDa/\x{17D2}\x{178F}/g;
        $syl =~ s/$re_lunar1/do { my $r = _lunar_replace($1,$2,0x19E0); defined($r)?$r:$& }/ge;
        $syl =~ s/$re_lunar2/do { my $r = _lunar_replace($1,$2,0x19F0); defined($r)?$r:$& }/ge;
        $syl =~ s/\x{17D4}\x{17D2}\x{17D4}/\x{19F0}/g;

        $result .= $syl;
        $i = $j;
    }
    return $result;
}

1;
