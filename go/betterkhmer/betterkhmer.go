// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Go — betterkhmer package. Regex-free.

package betterkhmer

import (
	"sort"
	"strings"
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
	for i := 0; i <= 0x17A2-0x1780; i++ {
		c[i] = catBase
	}
	for i := 0x17A5 - 0x1780; i <= 0x17B3-0x1780; i++ {
		c[i] = catBase
	}
	c[0x17B6-0x1780] = catVPost
	for i := 0x17B7 - 0x1780; i <= 0x17BA-0x1780; i++ {
		c[i] = catVA
	}
	for i := 0x17BB - 0x1780; i <= 0x17BD-0x1780; i++ {
		c[i] = catVB
	}
	for i := 0x17BE - 0x1780; i <= 0x17C5-0x1780; i++ {
		c[i] = catVPre
	}
	c[0x17C6-0x1780] = catMS
	c[0x17C7-0x1780] = catMF
	c[0x17C8-0x1780] = catMF
	c[0x17C9-0x1780] = catShift
	c[0x17CA-0x1780] = catShift
	c[0x17CB-0x1780] = catMS
	c[0x17CC-0x1780] = catRobat
	for i := 0x17CD - 0x1780; i <= 0x17D1-0x1780; i++ {
		c[i] = catMS
	}
	c[0x17D2-0x1780] = catCoeng
	c[0x17D3-0x1780] = catMS
	for i := 0x17D4 - 0x1780; i <= 0x17DC-0x1780; i++ {
		c[i] = catOther
	}
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

// --- Khmer consonant classes (from the SIL reference khres) ---

// B: all bases (incl. dotted circle).
func isBase(r rune) bool {
	return (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC
}

// NonRo: consonants excluding Ro (U+179A).
func isNonRo(r rune) bool {
	return (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3)
}

// NonBA: consonants excluding Ba (U+1794).
func isNonBA(r rune) bool {
	return (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3)
}

// S1: series-1 consonants.
func isS1(r rune) bool {
	switch {
	case r >= 0x1780 && r <= 0x1783:
		return true
	case r >= 0x1785 && r <= 0x1788:
		return true
	case r >= 0x178A && r <= 0x178D:
		return true
	case r >= 0x178F && r <= 0x1792:
		return true
	case r >= 0x1795 && r <= 0x1797:
		return true
	case r >= 0x179E && r <= 0x17A0:
		return true
	case r == 0x17A2:
		return true
	}
	return false
}

// S2: series-2 consonants.
func isS2(r rune) bool {
	switch {
	case r == 0x1780 || r == 0x1784 || r == 0x178E || r == 0x1793 || r == 0x1794 || r == 0x17A1:
		return true
	case r >= 0x1798 && r <= 0x179D:
		return true
	case r >= 0x17A3 && r <= 0x17B3:
		return true
	}
	return false
}

func isVPre(r rune) bool { return r >= 0x17C1 && r <= 0x17C5 }

const (
	zwnj  = 0x200C
	zwj   = 0x200D
	coeng = 0x17D2
	robat = 0x17CC
	ba    = 0x1794
)

// optRobat returns the position(s) after an optional Robat at p.
// Robat is greedy but the regex engine can also skip it, so when present
// both p (skipped) and p+1 (taken) are reachable.
func optRobat(r []rune, p int) []int {
	if p < len(r) && r[p] == robat {
		return []int{p, p + 1}
	}
	return []int{p}
}

// coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
func coengEnds(r []rune, s int) []int {
	n := len(r)
	var res []int
	if s+1 < n && r[s] == coeng && isBase(r[s+1]) {
		res = append(res, s+2)
	}
	if s+3 < n && r[s] == coeng && isNonRo(r[s+1]) && r[s+2] == coeng && isBase(r[s+3]) {
		res = append(res, s+4)
	}
	return res
}

// strongEnds enumerates all end indices of a STRONG match starting at s.
//
//	S1 ៌? (?:្ NonBA (?:្ NonBA)?)?
//	| NonBA ៌? (?:្ S1 (?:្ NonBA)? | ្ NonBA ្ S1)
func strongEnds(r []rune, s int, add func(int)) {
	n := len(r)
	if s >= n {
		return
	}
	if isS1(r[s]) {
		for _, p := range optRobat(r, s+1) {
			add(p)
			if p+1 < n && r[p] == coeng && isNonBA(r[p+1]) {
				q := p + 2
				add(q)
				if q+1 < n && r[q] == coeng && isNonBA(r[q+1]) {
					add(q + 2)
				}
			}
		}
	}
	if isNonBA(r[s]) {
		for _, p := range optRobat(r, s+1) {
			if p+1 < n && r[p] == coeng && isS1(r[p+1]) {
				q := p + 2
				add(q)
				if q+1 < n && r[q] == coeng && isNonBA(r[q+1]) {
					add(q + 2)
				}
			}
			if p+3 < n && r[p] == coeng && isNonBA(r[p+1]) && r[p+2] == coeng && isS1(r[p+3]) {
				add(p + 4)
			}
		}
	}
}

// nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
//
//	S2 ៌? (?:្ S2 (?:្ S2)?)?
//	| ប ៌? (?:COENG (?:COENG)?)?
//	| B ៌? (?:្ NonRo ្ ប | ្ ប ្ B)
func nstrongEnds(r []rune, s int, add func(int)) {
	n := len(r)
	if s >= n {
		return
	}
	if isS2(r[s]) {
		for _, p := range optRobat(r, s+1) {
			add(p)
			if p+1 < n && r[p] == coeng && isS2(r[p+1]) {
				q := p + 2
				add(q)
				if q+1 < n && r[q] == coeng && isS2(r[q+1]) {
					add(q + 2)
				}
			}
		}
	}
	if r[s] == ba {
		for _, p := range optRobat(r, s+1) {
			add(p)
			for _, e1 := range coengEnds(r, p) {
				add(e1)
				for _, e2 := range coengEnds(r, e1) {
					add(e2)
				}
			}
		}
	}
	if isBase(r[s]) {
		for _, p := range optRobat(r, s+1) {
			if p+3 < n && r[p] == coeng && isNonRo(r[p+1]) && r[p+2] == coeng && r[p+3] == ba {
				add(p + 4)
			}
			if p+3 < n && r[p] == coeng && r[p+1] == ba && r[p+2] == coeng && isBase(r[p+3]) {
				add(p + 4)
			}
		}
	}
}

// canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
func canEndAt(r []rune, target int, ends func([]rune, int, func(int))) bool {
	for s := 0; s < target; s++ {
		found := false
		ends(r, s, func(e int) {
			if e == target {
				found = true
			}
		})
		if found {
			return true
		}
	}
	return false
}

// vaSamyokAt is the lookahead (?:VA | ័):
// VA = (?:[ិ-ឺើឿ៝] | ាំ)
func vaSamyokAt(r []rune, p int) bool {
	n := len(r)
	if p >= n {
		return false
	}
	c := r[p]
	switch {
	case c == 0x17D0:
		return true
	case c >= 0x17B7 && c <= 0x17BA:
		return true
	case c == 0x17BE || c == 0x17BF || c == 0x17DD:
		return true
	case c == 0x17B6 && p+1 < n && r[p+1] == 0x17C6:
		return true
	}
	return false
}

// applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
// CLASS is STRONG (-> U+17CA) or NSTRONG (-> U+17C9). The class prefix and the
// optional pre-vowel are left untouched; only the -u (U+17BB) becomes the shifter.
func applyShifter(r []rune, ends func([]rune, int, func(int)), shifter rune) {
	for k := 0; k < len(r); k++ {
		if r[k] != 0x17BB {
			continue
		}
		ctx := canEndAt(r, k, ends) ||
			(k >= 1 && isVPre(r[k-1]) && canEndAt(r, k-1, ends))
		if ctx && vaSamyokAt(r, k+1) {
			r[k] = shifter
		}
	}
}

// collapseInvis: (‍?្)[្‌‍]+ -> \1
func collapseInvis(r []rune) []rune {
	n := len(r)
	isInvis := func(c rune) bool { return c == coeng || c == zwnj || c == zwj }
	out := make([]rune, 0, n)
	i := 0
	for i < n {
		g1End := -1
		if r[i] == zwj && i+1 < n && r[i+1] == coeng {
			g1End = i + 2
		} else if r[i] == coeng {
			g1End = i + 1
		}
		if g1End >= 0 {
			k := g1End
			for k < n && isInvis(r[k]) {
				k++
			}
			if k > g1End { // [្‌‍]+ matched at least one
				out = append(out, r[i:g1End]...)
				i = k
				continue
			}
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// pairReplace replaces every non-overlapping [a,b] with the runes in repl.
func pairReplace(r []rune, a, b rune, repl ...rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if i+1 < n && r[i] == a && r[i+1] == b {
			out = append(out, repl...)
			i += 2
			continue
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
func vowelSplit(r []rune, tail, head rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if r[i] == 0x17C1 {
			if i+2 < n && r[i+1] >= 0x17BB && r[i+1] <= 0x17BD && r[i+2] == tail {
				out = append(out, head, r[i+1])
				i += 3
				continue
			}
			if i+1 < n && r[i+1] == tail {
				out = append(out, head)
				i += 2
				continue
			}
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// coengRo: (្រ)(្[ក-ឳ]) -> \2\1
func coengRo(r []rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if i+3 < n && r[i] == coeng && r[i+1] == 0x179A &&
			r[i+2] == coeng && r[i+3] >= 0x1780 && r[i+3] <= 0x17B3 {
			out = append(out, r[i+2], r[i+3], r[i], r[i+1])
			i += 4
			continue
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// coengDa: (្)ដ -> \1ត
func coengDa(r []rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if i+1 < n && r[i] == coeng && r[i+1] == 0x178A {
			out = append(out, coeng, 0x178F)
			i += 2
			continue
		}
		out = append(out, r[i])
		i++
	}
	return out
}

func isDigit(r rune) bool { return r >= 0x17E0 && r <= 0x17E9 }

// lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
func lunar1(r []rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		// greedy ១? first
		if r[i] == 0x17E1 && i+3 < n && isDigit(r[i+1]) && r[i+2] == coeng && r[i+3] == 0x17D4 {
			v := 10 + int(r[i+1]-0x17E0)
			if v > 15 {
				out = append(out, r[i:i+4]...)
			} else {
				out = append(out, rune(0x19E0+v))
			}
			i += 4
			continue
		}
		if i+2 < n && isDigit(r[i]) && r[i+1] == coeng && r[i+2] == 0x17D4 {
			out = append(out, rune(0x19E0+int(r[i]-0x17E0)))
			i += 3
			continue
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
func lunar2(r []rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if r[i] == 0x17D4 && i+1 < n && r[i+1] == coeng {
			if i+3 < n && r[i+2] == 0x17E1 && isDigit(r[i+3]) {
				v := 10 + int(r[i+3]-0x17E0)
				if v > 15 {
					out = append(out, r[i:i+4]...)
				} else {
					out = append(out, rune(0x19F0+v))
				}
				i += 4
				continue
			}
			if i+2 < n && isDigit(r[i+2]) {
				out = append(out, rune(0x19F0+int(r[i+2]-0x17E0)))
				i += 3
				continue
			}
		}
		out = append(out, r[i])
		i++
	}
	return out
}

// hasByteE1 reports whether s contains byte 0xE1, scanned 8 bytes at a time
// (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte 0xE1,
// so no 0xE1 means no Khmer codepoint and the input is returned unchanged.
func hasByteE1(s string) bool {
	const (
		lo   = uint64(0x0101010101010101)
		hi   = uint64(0x8080808080808080)
		mask = uint64(0xE1E1E1E1E1E1E1E1)
	)
	i := 0
	for ; i+8 <= len(s); i += 8 {
		w := uint64(s[i]) | uint64(s[i+1])<<8 | uint64(s[i+2])<<16 | uint64(s[i+3])<<24 |
			uint64(s[i+4])<<32 | uint64(s[i+5])<<40 | uint64(s[i+6])<<48 | uint64(s[i+7])<<56
		x := w ^ mask
		if (x-lo)&^x&hi != 0 {
			return true
		}
	}
	for ; i < len(s); i++ {
		if s[i] == 0xE1 {
			return true
		}
	}
	return false
}

// Normalize returns the Khmer-normalized form of txt.
func Normalize(txt string) string {
	// SWAR skip/scan fast path: no Khmer byte => identity.
	if !hasByteE1(txt) {
		return txt
	}

	runes := []rune(txt)
	n := len(runes)
	cats := make([]cat, n)
	for i, r := range runes {
		cats[i] = charcat(r)
	}

	for i := 1; i < n; i++ {
		if runes[i-1] == zwj || runes[i-1] == coeng {
			if cats[i] == catBase || cats[i] == catCoeng {
				cats[i] = cats[i-1]
			}
		}
	}

	var res strings.Builder
	res.Grow(len(txt))
	i := 0
	for i < n {
		if cats[i] != catBase {
			res.WriteRune(runes[i])
			i++
			continue
		}
		j := i + 1
		for j < n && cats[j] > catBase {
			j++
		}

		indices := make([]int, j-i)
		for k := range indices {
			indices[k] = i + k
		}
		sort.SliceStable(indices, func(a, b int) bool {
			ca, cb := cats[indices[a]], cats[indices[b]]
			if ca != cb {
				return ca < cb
			}
			return indices[a] < indices[b]
		})

		syl := make([]rune, len(indices))
		for k, idx := range indices {
			syl[k] = runes[idx]
		}

		syl = collapseInvis(syl)
		syl = pairReplace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8) // ើា -> ោី
		syl = vowelSplit(syl, 0x17B8, 0x17BE)                  // េ(◌)ី -> ើ(◌)
		syl = vowelSplit(syl, 0x17B6, 0x17C4)                  // េ(◌)ា -> ោ(◌)
		syl = pairReplace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE) // ើុ -> ុើ
		applyShifter(syl, strongEnds, 0x17CA)                  // strong  -u -> ៊
		applyShifter(syl, nstrongEnds, 0x17C9)                 // weak    -u -> ៉
		syl = coengRo(syl)
		syl = coengDa(syl)
		syl = lunar1(syl)
		syl = lunar2(syl)
		syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0) // ។្។ -> ᧰

		for _, r := range syl {
			res.WriteRune(r)
		}
		i = j
	}
	return res.String()
}

// pairReplace3 replaces every non-overlapping [a,b,c] with repl.
func pairReplace3(r []rune, a, b, c, repl rune) []rune {
	n := len(r)
	out := make([]rune, 0, n)
	for i := 0; i < n; {
		if i+2 < n && r[i] == a && r[i+1] == b && r[i+2] == c {
			out = append(out, repl)
			i += 3
			continue
		}
		out = append(out, r[i])
		i++
	}
	return out
}
