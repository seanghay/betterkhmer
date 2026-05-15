# frozen_string_literal: true
# Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
# Ported to Ruby — betterkhmer gem.

module BetterKhmer
  CAT_OTHER   = 0; CAT_BASE  = 1; CAT_ROBAT   = 2; CAT_COENG  = 3
  CAT_SHIFT   = 4; CAT_Z     = 5; CAT_VPRE    = 6; CAT_VB     = 7
  CAT_VA      = 8; CAT_VPOST = 9; CAT_MS      = 10; CAT_MF    = 11
  CAT_ZFCOENG = 12

  CATEGORIES = (
    [CAT_BASE] * 35  + [CAT_OTHER] * 2  + [CAT_BASE] * 15  + [CAT_OTHER] * 2 +
    [CAT_VPOST]      + [CAT_VA] * 4     + [CAT_VB] * 3     + [CAT_VPRE] * 8  +
    [CAT_MS]         + [CAT_MF] * 2     + [CAT_SHIFT] * 2  + [CAT_MS]        +
    [CAT_ROBAT]      + [CAT_MS] * 5     + [CAT_COENG]       + [CAT_MS]        +
    [CAT_OTHER] * 9  + [CAT_MS]
  ).freeze

  S1      = '[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]'
  NON_BA  = '[ក-នផ-អឥ-ឳ]'
  S2      = '[ងកណនបម-ឝឡឣ-ឳ]'
  NON_RO  = '[ក-យល-អឥ-ឳ]'
  B       = '[ក-អឥ-ឳ◌]'
  VA      = '(?:[ិ-ឺើឿ៝]|ាំ)'

  STRONG_CLEAN =
    "#{S1}\u{17CC}?(?:\u{17D2}#{NON_BA}(?:\u{17D2}#{NON_BA})?)?|" \
    "#{NON_BA}\u{17CC}?(?:\u{17D2}#{S1}(?:\u{17D2}#{NON_BA})?|\u{17D2}#{NON_BA}\u{17D2}#{S1})"

  NSTRONG =
    "(?:#{S2}\u{17CC}?(?:\u{17D2}#{S2}(?:\u{17D2}#{S2})?)?|\u{1794}\u{17CC}?" \
    "(?:(?:(?:\u{17D2}#{NON_RO})?\u{17D2}#{B})(?:(?:(?:\u{17D2}#{NON_RO})?\u{17D2}#{B}))?)?|" \
    "#{B}\u{17CC}?(?:\u{17D2}#{NON_RO}\u{17D2}\u{1794}|\u{17D2}\u{1794}(?:\u{17D2}#{B})))"

  RE_INVIS    = /([‍]?្)[្‌‍]+/u
  RE_V1       = /េ([ុ-ួ]?)ី/u
  RE_V2       = /េ([ុ-ួ]?)ា/u
  RE_V3       = /(ើ)(ុ)/u
  RE_STRONG   = Regexp.new("(?:#{STRONG_CLEAN})[េ-ៅ]?ុ(?=#{VA}|័)", Regexp::MULTILINE)
  RE_NSTRONG  = Regexp.new("#{NSTRONG}[េ-ៅ]?ុ(?=#{VA}|័)", Regexp::MULTILINE)
  RE_COENG_RO = /(្រ)(្[ក-ឳ])/u
  RE_COENG_DA = /្ដ/u
  RE_LUNAR1   = /(១?)([០-៩])្។/u
  RE_LUNAR2   = /។្(១?)([០-៩])/u

  def self.charcat(cp)
    return CATEGORIES[cp - 0x1780] if cp >= 0x1780 && cp <= 0x17DD
    return CAT_Z       if cp == 0x200C
    return CAT_ZFCOENG if cp == 0x200D
    CAT_OTHER
  end

  def self.lunar(g1, g2, base)
    v = (g1.empty? ? 0 : g1.ord - 0x17E0) * 10 + g2.ord - 0x17E0
    return nil if v > 15
    (base + v).chr(Encoding::UTF_8)
  end

  def self.normalize(txt, lang: 'km')
    if lang == 'xhm'
      txt = txt.gsub(/([ិ-ៅ]្)/u, "‍\\1")
    end

    chars = txt.chars
    n = chars.size
    cats = chars.map { |c| charcat(c.ord) }

    (1...n).each do |i|
      cp = chars[i - 1].ord
      if cp == 0x200D || cp == 0x17D2
        cats[i] = cats[i - 1] if cats[i] == CAT_BASE || cats[i] == CAT_COENG
      end
    end

    res = +''.encode('UTF-8')
    i = 0
    while i < n
      if cats[i] != CAT_BASE
        res << chars[i]
        i += 1
        next
      end
      j = i + 1
      j += 1 while j < n && cats[j] > CAT_BASE

      sorted = (i...j).sort_by { |k| [cats[k], k] }
      syl = sorted.map { |k| chars[k] }.join

      syl.gsub!(RE_INVIS, '\1')
      syl.gsub!("ើា", "ោី")
      syl.gsub!(RE_V1) { "ើ#{$~[1]}" }
      syl.gsub!(RE_V2) { "ោ#{$~[1]}" }
      syl.gsub!(RE_V3, '\2\1')
      syl.gsub!(RE_STRONG)  { |m| m[0..-2] + "៊" }
      syl.gsub!(RE_NSTRONG) { |m| m[0..-2] + "៉" }
      syl.gsub!(RE_COENG_RO, '\2\1')
      syl.gsub!(RE_COENG_DA, "្ត")
      syl.gsub!(RE_LUNAR1) do
        result = lunar($~[1], $~[2], 0x19E0)
        result.nil? ? $~[0] : result
      end
      syl.gsub!(RE_LUNAR2) do
        result = lunar($~[1], $~[2], 0x19F0)
        result.nil? ? $~[0] : result
      end
      syl.gsub!("។្។", "᧰")
      res << syl
      i = j
    end
    res
  end
end
