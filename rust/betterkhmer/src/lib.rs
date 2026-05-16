// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Rust — betterkhmer crate. Regex-free.

use std::sync::OnceLock;

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
enum Cat {
    Other = 0,
    Base = 1,
    Robat = 2,
    Coeng = 3,
    Shift = 4,
    Z = 5,
    VPre = 6,
    VB = 7,
    VA = 8,
    VPost = 9,
    MS = 10,
    MF = 11,
    ZFCoeng = 12,
}

fn categories() -> &'static [Cat; 0x17DE - 0x1780] {
    static CATEGORIES: OnceLock<[Cat; 0x17DE - 0x1780]> = OnceLock::new();
    CATEGORIES.get_or_init(|| {
        use Cat::*;
        let mut c = [Other; 0x17DE - 0x1780];
        for x in c.iter_mut().take(0x17A2 - 0x1780 + 1) {
            *x = Base;
        }
        for x in c.iter_mut().take(0x17B3 - 0x1780 + 1).skip(0x17A5 - 0x1780) {
            *x = Base;
        }
        c[0x17B6 - 0x1780] = VPost;
        for x in c.iter_mut().take(0x17BA - 0x1780 + 1).skip(0x17B7 - 0x1780) {
            *x = VA;
        }
        for x in c.iter_mut().take(0x17BD - 0x1780 + 1).skip(0x17BB - 0x1780) {
            *x = VB;
        }
        for x in c.iter_mut().take(0x17C5 - 0x1780 + 1).skip(0x17BE - 0x1780) {
            *x = VPre;
        }
        c[0x17C6 - 0x1780] = MS;
        c[0x17C7 - 0x1780] = MF;
        c[0x17C8 - 0x1780] = MF;
        c[0x17C9 - 0x1780] = Shift;
        c[0x17CA - 0x1780] = Shift;
        c[0x17CB - 0x1780] = MS;
        c[0x17CC - 0x1780] = Robat;
        for x in c.iter_mut().take(0x17D1 - 0x1780 + 1).skip(0x17CD - 0x1780) {
            *x = MS;
        }
        c[0x17D2 - 0x1780] = Coeng;
        c[0x17D3 - 0x1780] = MS;
        for x in c.iter_mut().take(0x17DC - 0x1780 + 1).skip(0x17D4 - 0x1780) {
            *x = Other;
        }
        c[0x17DD - 0x1780] = MS;
        c
    })
}

fn charcat(c: char) -> Cat {
    let cp = c as u32;
    if (0x1780..=0x17DD).contains(&cp) {
        return categories()[(cp - 0x1780) as usize];
    }
    match cp {
        0x200C => Cat::Z,
        0x200D => Cat::ZFCoeng,
        _ => Cat::Other,
    }
}

// --- Khmer consonant classes (from the SIL reference khres) ---

const ZWNJ: char = '\u{200C}';
const ZWJ: char = '\u{200D}';
const COENG: char = '\u{17D2}';
const ROBAT: char = '\u{17CC}';
const BA: char = '\u{1794}';

// B: all bases (incl. dotted circle).
fn is_base(r: char) -> bool {
    ('\u{1780}'..='\u{17A2}').contains(&r)
        || ('\u{17A5}'..='\u{17B3}').contains(&r)
        || r == '\u{25CC}'
}

// NonRo: consonants excluding Ro (U+179A).
fn is_non_ro(r: char) -> bool {
    ('\u{1780}'..='\u{1799}').contains(&r)
        || ('\u{179B}'..='\u{17A2}').contains(&r)
        || ('\u{17A5}'..='\u{17B3}').contains(&r)
}

// NonBA: consonants excluding Ba (U+1794).
fn is_non_ba(r: char) -> bool {
    ('\u{1780}'..='\u{1793}').contains(&r)
        || ('\u{1795}'..='\u{17A2}').contains(&r)
        || ('\u{17A5}'..='\u{17B3}').contains(&r)
}

// S1: series-1 consonants.
fn is_s1(r: char) -> bool {
    matches!(r,
        '\u{1780}'..='\u{1783}'
        | '\u{1785}'..='\u{1788}'
        | '\u{178A}'..='\u{178D}'
        | '\u{178F}'..='\u{1792}'
        | '\u{1795}'..='\u{1797}'
        | '\u{179E}'..='\u{17A0}'
        | '\u{17A2}')
}

// S2: series-2 consonants.
fn is_s2(r: char) -> bool {
    matches!(r,
        '\u{1780}' | '\u{1784}' | '\u{178E}' | '\u{1793}' | '\u{1794}' | '\u{17A1}'
        | '\u{1798}'..='\u{179D}'
        | '\u{17A3}'..='\u{17B3}')
}

fn is_v_pre(r: char) -> bool {
    ('\u{17C1}'..='\u{17C5}').contains(&r)
}

// optRobat returns the position(s) after an optional Robat at p.
// Robat is greedy but the regex engine can also skip it, so when present
// both p (skipped) and p+1 (taken) are reachable.
fn opt_robat(r: &[char], p: usize) -> Vec<usize> {
    if p < r.len() && r[p] == ROBAT {
        vec![p, p + 1]
    } else {
        vec![p]
    }
}

// coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
fn coeng_ends(r: &[char], s: usize) -> Vec<usize> {
    let n = r.len();
    let mut res = Vec::new();
    if s + 1 < n && r[s] == COENG && is_base(r[s + 1]) {
        res.push(s + 2);
    }
    if s + 3 < n && r[s] == COENG && is_non_ro(r[s + 1]) && r[s + 2] == COENG && is_base(r[s + 3]) {
        res.push(s + 4);
    }
    res
}

// strongEnds enumerates all end indices of a STRONG match starting at s.
//
//	S1 ៌? (?:្ NonBA (?:្ NonBA)?)?
//	| NonBA ៌? (?:្ S1 (?:្ NonBA)? | ្ NonBA ្ S1)
fn strong_ends(r: &[char], s: usize, add: &mut dyn FnMut(usize)) {
    let n = r.len();
    if s >= n {
        return;
    }
    if is_s1(r[s]) {
        for p in opt_robat(r, s + 1) {
            add(p);
            if p + 1 < n && r[p] == COENG && is_non_ba(r[p + 1]) {
                let q = p + 2;
                add(q);
                if q + 1 < n && r[q] == COENG && is_non_ba(r[q + 1]) {
                    add(q + 2);
                }
            }
        }
    }
    if is_non_ba(r[s]) {
        for p in opt_robat(r, s + 1) {
            if p + 1 < n && r[p] == COENG && is_s1(r[p + 1]) {
                let q = p + 2;
                add(q);
                if q + 1 < n && r[q] == COENG && is_non_ba(r[q + 1]) {
                    add(q + 2);
                }
            }
            if p + 3 < n
                && r[p] == COENG
                && is_non_ba(r[p + 1])
                && r[p + 2] == COENG
                && is_s1(r[p + 3])
            {
                add(p + 4);
            }
        }
    }
}

// nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
//
//	S2 ៌? (?:្ S2 (?:្ S2)?)?
//	| ប ៌? (?:COENG (?:COENG)?)?
//	| B ៌? (?:្ NonRo ្ ប | ្ ប ្ B)
fn nstrong_ends(r: &[char], s: usize, add: &mut dyn FnMut(usize)) {
    let n = r.len();
    if s >= n {
        return;
    }
    if is_s2(r[s]) {
        for p in opt_robat(r, s + 1) {
            add(p);
            if p + 1 < n && r[p] == COENG && is_s2(r[p + 1]) {
                let q = p + 2;
                add(q);
                if q + 1 < n && r[q] == COENG && is_s2(r[q + 1]) {
                    add(q + 2);
                }
            }
        }
    }
    if r[s] == BA {
        for p in opt_robat(r, s + 1) {
            add(p);
            for e1 in coeng_ends(r, p) {
                add(e1);
                for e2 in coeng_ends(r, e1) {
                    add(e2);
                }
            }
        }
    }
    if is_base(r[s]) {
        for p in opt_robat(r, s + 1) {
            if p + 3 < n
                && r[p] == COENG
                && is_non_ro(r[p + 1])
                && r[p + 2] == COENG
                && r[p + 3] == BA
            {
                add(p + 4);
            }
            if p + 3 < n
                && r[p] == COENG
                && r[p + 1] == BA
                && r[p + 2] == COENG
                && is_base(r[p + 3])
            {
                add(p + 4);
            }
        }
    }
}

// canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
fn can_end_at(r: &[char], target: usize, ends: fn(&[char], usize, &mut dyn FnMut(usize))) -> bool {
    for s in 0..target {
        let mut found = false;
        ends(r, s, &mut |e| {
            if e == target {
                found = true;
            }
        });
        if found {
            return true;
        }
    }
    false
}

// vaSamyokAt is the lookahead (?:VA | ័):
// VA = (?:[ិ-ឺើឿ៝] | ាំ)
fn va_samyok_at(r: &[char], p: usize) -> bool {
    let n = r.len();
    if p >= n {
        return false;
    }
    let c = r[p];
    match c {
        '\u{17D0}' => true,
        '\u{17B7}'..='\u{17BA}' => true,
        '\u{17BE}' | '\u{17BF}' | '\u{17DD}' => true,
        '\u{17B6}' if p + 1 < n && r[p + 1] == '\u{17C6}' => true,
        _ => false,
    }
}

// applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
// CLASS is STRONG (-> U+17CA) or NSTRONG (-> U+17C9). The class prefix and the
// optional pre-vowel are left untouched; only the -u (U+17BB) becomes the shifter.
fn apply_shifter(
    r: &mut [char],
    ends: fn(&[char], usize, &mut dyn FnMut(usize)),
    shifter: char,
) {
    for k in 0..r.len() {
        if r[k] != '\u{17BB}' {
            continue;
        }
        let ctx = can_end_at(r, k, ends)
            || (k >= 1 && is_v_pre(r[k - 1]) && can_end_at(r, k - 1, ends));
        if ctx && va_samyok_at(r, k + 1) {
            r[k] = shifter;
        }
    }
}

// collapseInvis: (‍?្)[្‌‍]+ -> \1
fn collapse_invis(r: &[char]) -> Vec<char> {
    let n = r.len();
    let is_invis = |c: char| c == COENG || c == ZWNJ || c == ZWJ;
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        let mut g1_end: isize = -1;
        if r[i] == ZWJ && i + 1 < n && r[i + 1] == COENG {
            g1_end = (i + 2) as isize;
        } else if r[i] == COENG {
            g1_end = (i + 1) as isize;
        }
        if g1_end >= 0 {
            let g1_end = g1_end as usize;
            let mut k = g1_end;
            while k < n && is_invis(r[k]) {
                k += 1;
            }
            if k > g1_end {
                // [្‌‍]+ matched at least one
                out.extend_from_slice(&r[i..g1_end]);
                i = k;
                continue;
            }
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// pairReplace replaces every non-overlapping [a,b] with the runes in repl.
fn pair_replace(r: &[char], a: char, b: char, repl: &[char]) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + 1 < n && r[i] == a && r[i + 1] == b {
            out.extend_from_slice(repl);
            i += 2;
            continue;
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
fn vowel_split(r: &[char], tail: char, head: char) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if r[i] == '\u{17C1}' {
            if i + 2 < n
                && ('\u{17BB}'..='\u{17BD}').contains(&r[i + 1])
                && r[i + 2] == tail
            {
                out.push(head);
                out.push(r[i + 1]);
                i += 3;
                continue;
            }
            if i + 1 < n && r[i + 1] == tail {
                out.push(head);
                i += 2;
                continue;
            }
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// coengRo: (្រ)(្[ក-ឳ]) -> \2\1
fn coeng_ro(r: &[char]) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + 3 < n
            && r[i] == COENG
            && r[i + 1] == '\u{179A}'
            && r[i + 2] == COENG
            && ('\u{1780}'..='\u{17B3}').contains(&r[i + 3])
        {
            out.push(r[i + 2]);
            out.push(r[i + 3]);
            out.push(r[i]);
            out.push(r[i + 1]);
            i += 4;
            continue;
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// coengDa: (្)ដ -> \1ត
fn coeng_da(r: &[char]) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + 1 < n && r[i] == COENG && r[i + 1] == '\u{178A}' {
            out.push(COENG);
            out.push('\u{178F}');
            i += 2;
            continue;
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

fn is_digit(r: char) -> bool {
    ('\u{17E0}'..='\u{17E9}').contains(&r)
}

// lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
fn lunar1(r: &[char]) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        // greedy ១? first
        if r[i] == '\u{17E1}'
            && i + 3 < n
            && is_digit(r[i + 1])
            && r[i + 2] == COENG
            && r[i + 3] == '\u{17D4}'
        {
            let v = 10 + (r[i + 1] as u32 - 0x17E0);
            if v > 15 {
                out.extend_from_slice(&r[i..i + 4]);
            } else {
                out.push(char::from_u32(0x19E0 + v).unwrap());
            }
            i += 4;
            continue;
        }
        if i + 2 < n && is_digit(r[i]) && r[i + 1] == COENG && r[i + 2] == '\u{17D4}' {
            out.push(char::from_u32(0x19E0 + (r[i] as u32 - 0x17E0)).unwrap());
            i += 3;
            continue;
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
fn lunar2(r: &[char]) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if r[i] == '\u{17D4}' && i + 1 < n && r[i + 1] == COENG {
            if i + 3 < n && r[i + 2] == '\u{17E1}' && is_digit(r[i + 3]) {
                let v = 10 + (r[i + 3] as u32 - 0x17E0);
                if v > 15 {
                    out.extend_from_slice(&r[i..i + 4]);
                } else {
                    out.push(char::from_u32(0x19F0 + v).unwrap());
                }
                i += 4;
                continue;
            }
            if i + 2 < n && is_digit(r[i + 2]) {
                out.push(char::from_u32(0x19F0 + (r[i + 2] as u32 - 0x17E0)).unwrap());
                i += 3;
                continue;
            }
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// pairReplace3 replaces every non-overlapping [a,b,c] with repl.
fn pair_replace3(r: &[char], a: char, b: char, c: char, repl: char) -> Vec<char> {
    let n = r.len();
    let mut out = Vec::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c {
            out.push(repl);
            i += 3;
            continue;
        }
        out.push(r[i]);
        i += 1;
    }
    out
}

// hasByteE1 reports whether s contains byte 0xE1, scanned 8 bytes at a time
// (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte 0xE1,
// so no 0xE1 means no Khmer codepoint and the input is returned unchanged.
fn has_byte_e1(s: &str) -> bool {
    const LO: u64 = 0x0101010101010101;
    const HI: u64 = 0x8080808080808080;
    const MASK: u64 = 0xE1E1E1E1E1E1E1E1;
    let b = s.as_bytes();
    let mut i = 0;
    while i + 8 <= b.len() {
        let w = u64::from_le_bytes(b[i..i + 8].try_into().unwrap());
        let x = w ^ MASK;
        if (x.wrapping_sub(LO)) & !x & HI != 0 {
            return true;
        }
        i += 8;
    }
    while i < b.len() {
        if b[i] == 0xE1 {
            return true;
        }
        i += 1;
    }
    false
}

/// Returns the Khmer-normalized form of `txt`.
pub fn normalize(txt: &str) -> String {
    // SWAR skip/scan fast path: no Khmer byte => identity.
    if !has_byte_e1(txt) {
        return txt.to_string();
    }

    let chars: Vec<char> = txt.chars().collect();
    let n = chars.len();
    let mut cats: Vec<Cat> = chars.iter().map(|&c| charcat(c)).collect();

    for i in 1..n {
        if chars[i - 1] == ZWJ || chars[i - 1] == COENG {
            if cats[i] == Cat::Base || cats[i] == Cat::Coeng {
                cats[i] = cats[i - 1];
            }
        }
    }

    let mut res = String::with_capacity(txt.len());
    let mut i = 0;
    while i < n {
        if cats[i] != Cat::Base {
            res.push(chars[i]);
            i += 1;
            continue;
        }
        let mut j = i + 1;
        while j < n && cats[j] > Cat::Base {
            j += 1;
        }

        let mut indices: Vec<usize> = (i..j).collect();
        indices.sort_by(|&a, &b| cats[a].cmp(&cats[b]).then(a.cmp(&b)));

        let mut syl: Vec<char> = indices.iter().map(|&k| chars[k]).collect();

        syl = collapse_invis(&syl);
        syl = pair_replace(&syl, '\u{17BE}', '\u{17B6}', &['\u{17C4}', '\u{17B8}']); // ើា -> ោី
        syl = vowel_split(&syl, '\u{17B8}', '\u{17BE}'); // េ(◌)ី -> ើ(◌)
        syl = vowel_split(&syl, '\u{17B6}', '\u{17C4}'); // េ(◌)ា -> ោ(◌)
        syl = pair_replace(&syl, '\u{17BE}', '\u{17BB}', &['\u{17BB}', '\u{17BE}']); // ើុ -> ុើ
        apply_shifter(&mut syl, strong_ends, '\u{17CA}'); // strong  -u -> ៊
        apply_shifter(&mut syl, nstrong_ends, '\u{17C9}'); // weak    -u -> ៉
        syl = coeng_ro(&syl);
        syl = coeng_da(&syl);
        syl = lunar1(&syl);
        syl = lunar2(&syl);
        syl = pair_replace3(&syl, '\u{17D4}', '\u{17D2}', '\u{17D4}', '\u{19F0}'); // ។្។ -> ᧰

        for r in &syl {
            res.push(*r);
        }
        i = j;
    }
    res
}
