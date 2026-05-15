// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Go — betterkhmer package.

package betterkhmer

import (
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"
)

type cat int

const (
	catOther   cat = 0
	catBase    cat = 1
	catRobat   cat = 2
	catCoeng   cat = 3
	catShift   cat = 4
	catZ       cat = 5
	catVPre    cat = 6
	catVB      cat = 7
	catVA      cat = 8
	catVPost   cat = 9
	catMS      cat = 10
	catMF      cat = 11
	catZFCoeng cat = 12
)

var categories = func() []cat {
	c := make([]cat, 0x17DE-0x1780)
	for i := range c {
		c[i] = catOther
	}
	for i := 0; i <= 0x17A2-0x1780; i++ { c[i] = catBase }
	for i := 0x17A5 - 0x1780; i <= 0x17B3-0x1780; i++ { c[i] = catBase }
	c[0x17B6-0x1780] = catVPost
	for i := 0x17B7 - 0x1780; i <= 0x17BA-0x1780; i++ { c[i] = catVA }
	for i := 0x17BB - 0x1780; i <= 0x17BD-0x1780; i++ { c[i] = catVB }
	for i := 0x17BE - 0x1780; i <= 0x17C5-0x1780; i++ { c[i] = catVPre }
	c[0x17C6-0x1780] = catMS
	c[0x17C7-0x1780] = catMF
	c[0x17C8-0x1780] = catMF
	c[0x17C9-0x1780] = catShift
	c[0x17CA-0x1780] = catShift
	c[0x17CB-0x1780] = catMS
	c[0x17CC-0x1780] = catRobat
	for i := 0x17CD - 0x1780; i <= 0x17D1-0x1780; i++ { c[i] = catMS }
	c[0x17D2-0x1780] = catCoeng
	c[0x17D3-0x1780] = catMS
	for i := 0x17D4 - 0x1780; i <= 0x17DC-0x1780; i++ { c[i] = catOther }
	c[0x17DD-0x1780] = catMS
	return c
}()

func charcat(r rune) cat {
	if r >= 0x1780 && r <= 0x17DD {
		return categories[r-0x1780]
	}
	if r == 0x200C {
		return catZ
	}
	if r == 0x200D {
		return catZFCoeng
	}
	return catOther
}

const (
	// pre-expanded patterns (no verbose whitespace)
	patS1 = `[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]`
	patNonBA = `[ក-នផ-អឥ-ឳ]`
	patS2 = `[ងកណនបម-ឝឡឣ-ឳ]`
	patNonRo = `[ក-យល-អឥ-ឳ]`
	patB = `[ក-អឥ-ឳ◌]`
	patVA = `(?:[ិ-ឺើឿ៝]|ាំ)`

	patSTRONG = patS1 + `៌?(?:្` + patNonBA + `(?:្` + patNonBA + `)?)?|` +
		patNonBA + `៌?(?:្` + patS1 + `(?:្` + patNonBA + `)?|` +
		`្` + patNonBA + `្` + patS1 + `)`

	patNSTRONG = `(?:` + patS2 + `៌?(?:្` + patS2 + `(?:្` + patS2 + `)?)?|ប៌?` +
		`(?:(?:(?:្` + patNonRo + `)?` + `្` + patB + `)(?:(?:(?:្` + patNonRo + `)?` + `្` + patB + `))?)?|` +
		patB + `៌?(?:្` + patNonRo + `្ប|្ប(?:្` + patB + `)))`
)

var (
	reInvis   = regexp.MustCompile(`(‍?្)[្‌‍]+`)
	reV1      = regexp.MustCompile(`េ([ុ-ួ]?)ី`)
	reV2      = regexp.MustCompile(`េ([ុ-ួ]?)ា`)
	reV3      = regexp.MustCompile(`(ើ)(ុ)`)
	reStrong  = regexp.MustCompile(`((?:` + patSTRONG + `)[េ-ៅ]?)ុ(` + patVA + `|័)`)
	reNStrong = regexp.MustCompile(`((?:` + patNSTRONG + `)[េ-ៅ]?)ុ(` + patVA + `|័)`)
	reCoengRo = regexp.MustCompile(`(្រ)(្[ក-ឳ])`)
	reCoengDa = regexp.MustCompile(`(្)ដ`)
	reLunar1  = regexp.MustCompile(`(១?)([០-៩])្។`)
	reLunar2  = regexp.MustCompile(`។្(១?)([០-៩])`)
)

func lunarReplace(match string, base rune, re *regexp.Regexp) string {
	m := re.FindStringSubmatch(match)
	var v int
	if m[1] != "" {
		r, _ := utf8.DecodeRuneInString(m[1])
		v = int(r-0x17E0) * 10
	}
	r2, _ := utf8.DecodeRuneInString(m[2])
	v += int(r2 - 0x17E0)
	if v > 15 {
		return match
	}
	return string(rune(v) + base)
}

// Normalize returns the Khmer-normalized form of txt.
func Normalize(txt string) string {
	runes := []rune(txt)
	n := len(runes)
	cats := make([]cat, n)
	for i, r := range runes {
		cats[i] = charcat(r)
	}

	for i := 1; i < n; i++ {
		if runes[i-1] == 0x200D || runes[i-1] == 0x17D2 {
			if cats[i] == catBase || cats[i] == catCoeng {
				cats[i] = cats[i-1]
			}
		}
	}

	var res strings.Builder
	i := 0
	for i < n {
		if cats[i] != catBase {
			res.WriteRune(runes[i])
			i++
			continue
		}
		j := i + 1
		for j < n && int(cats[j]) > int(catBase) {
			j++
		}

		indices := make([]int, j-i)
		for k := range indices {
			indices[k] = i + k
		}
		sort.SliceStable(indices, func(a, b int) bool {
			ca, cb := int(cats[indices[a]]), int(cats[indices[b]])
			if ca != cb {
				return ca < cb
			}
			return indices[a] < indices[b]
		})

		var syl strings.Builder
		for _, idx := range indices {
			syl.WriteRune(runes[idx])
		}
		s := syl.String()

		s = reInvis.ReplaceAllString(s, "$1")
		s = strings.ReplaceAll(s, "ើា", "ោី")
		s = reV1.ReplaceAllString(s, "ើ$1")
		s = reV2.ReplaceAllString(s, "ោ$1")
		s = reV3.ReplaceAllString(s, "$2$1")
		s = reStrong.ReplaceAllString(s, "${1}៊${2}")
		s = reNStrong.ReplaceAllString(s, "${1}៉${2}")
		s = reCoengRo.ReplaceAllString(s, "$2$1")
		s = reCoengDa.ReplaceAllString(s, "${1}ត")
		s = reLunar1.ReplaceAllStringFunc(s, func(m string) string {
			return lunarReplace(m, 0x19E0, reLunar1)
		})
		s = reLunar2.ReplaceAllStringFunc(s, func(m string) string {
			return lunarReplace(m, 0x19F0, reLunar2)
		})
		s = strings.ReplaceAll(s, "។្។", "᧰")
		res.WriteString(s)
		i = j
	}
	return res.String()
}
