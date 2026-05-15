// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Rust — betterkhmer crate.

use once_cell::sync::Lazy;
use regex::{Captures, Regex};

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
enum Cat {
    Other   = 0, Base   = 1, Robat   = 2, Coeng   = 3,
    Shift   = 4, Z      = 5, VPre    = 6, VB      = 7,
    VA      = 8, VPost  = 9, MS      = 10, MF      = 11,
    ZFCoeng = 12,
}

static CATEGORIES: Lazy<Vec<Cat>> = Lazy::new(|| {
    use Cat::*;
    let mut c = vec![Other; 0x17DE - 0x1780];
    for i in 0..=(0x17A2 - 0x1780) { c[i] = Base; }
    for i in (0x17A5 - 0x1780)..=(0x17B3 - 0x1780) { c[i] = Base; }
    c[0x17B6 - 0x1780] = VPost;
    for i in (0x17B7 - 0x1780)..=(0x17BA - 0x1780) { c[i] = VA; }
    for i in (0x17BB - 0x1780)..=(0x17BD - 0x1780) { c[i] = VB; }
    for i in (0x17BE - 0x1780)..=(0x17C5 - 0x1780) { c[i] = VPre; }
    c[0x17C6 - 0x1780] = MS;
    c[0x17C7 - 0x1780] = MF;
    c[0x17C8 - 0x1780] = MF;
    c[0x17C9 - 0x1780] = Shift;
    c[0x17CA - 0x1780] = Shift;
    c[0x17CB - 0x1780] = MS;
    c[0x17CC - 0x1780] = Robat;
    for i in (0x17CD - 0x1780)..=(0x17D1 - 0x1780) { c[i] = MS; }
    c[0x17D2 - 0x1780] = Coeng;
    c[0x17D3 - 0x1780] = MS;
    for i in (0x17D4 - 0x1780)..=(0x17DC - 0x1780) { c[i] = Other; }
    c[0x17DD - 0x1780] = MS;
    c
});

fn charcat(c: char) -> Cat {
    let cp = c as u32;
    if cp >= 0x1780 && cp <= 0x17DD {
        return CATEGORIES[(cp - 0x1780) as usize];
    }
    match cp {
        0x200C => Cat::Z,
        0x200D => Cat::ZFCoeng,
        _ => Cat::Other,
    }
}

const S1: &str = r"[\u{1780}-\u{1783}\u{1785}-\u{1788}\u{178A}-\u{178D}\u{178F}-\u{1792}\u{1795}-\u{1797}\u{179E}-\u{17A0}\u{17A2}]";
const NON_BA: &str = r"[\u{1780}-\u{1793}\u{1795}-\u{17A2}\u{17A5}-\u{17B3}]";
const S2: &str = r"[\u{1784}\u{1780}\u{178E}\u{1793}\u{1794}\u{1798}-\u{179D}\u{17A1}\u{17A3}-\u{17B3}]";
const NON_RO: &str = r"[\u{1780}-\u{1799}\u{179B}-\u{17A2}\u{17A5}-\u{17B3}]";
const B: &str = r"[\u{1780}-\u{17A2}\u{17A5}-\u{17B3}\u{25CC}]";
const VA: &str = r"(?:[\u{17B7}-\u{17BA}\u{17BE}\u{17BF}\u{17DD}]|\u{17B6}\u{17C6})";

// Group 1 = STRONG+optional_VPre, Group 2 = VA-or-17D0 (mimics lookahead)
fn make_strong_pat() -> String {
    format!(
        r"((?:{S1}\u{{17CC}}?(?:\u{{17D2}}{NON_BA}(?:\u{{17D2}}{NON_BA})?)?|{NON_BA}\u{{17CC}}?(?:\u{{17D2}}{S1}(?:\u{{17D2}}{NON_BA})?|\u{{17D2}}{NON_BA}\u{{17D2}}{S1}))[\u{{17C1}}-\u{{17C5}}]?)\u{{17BB}}({VA}|\u{{17D0}})"
    )
}

fn make_nstrong_pat() -> String {
    let coeng = format!(r"(?:(?:\u{{17D2}}{NON_RO})?\u{{17D2}}{B})");
    format!(
        r"((?:{S2}\u{{17CC}}?(?:\u{{17D2}}{S2}(?:\u{{17D2}}{S2})?)?|\u{{1794}}\u{{17CC}}?(?:{coeng}(?:{coeng})?)?|{B}\u{{17CC}}?(?:\u{{17D2}}{NON_RO}\u{{17D2}}\u{{1794}}|\u{{17D2}}\u{{1794}}(?:\u{{17D2}}{B})))[\u{{17C1}}-\u{{17C5}}]?)\u{{17BB}}({VA}|\u{{17D0}})"
    )
}

static RE_INVIS: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(\u{200D}?\u{17D2})[\u{17D2}\u{200C}\u{200D}]+").unwrap()
});
static RE_V1: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\u{17C1}([\u{17BB}-\u{17BD}]?)\u{17B8}").unwrap()
});
static RE_V2: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\u{17C1}([\u{17BB}-\u{17BD}]?)\u{17B6}").unwrap()
});
static RE_V3: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(\u{17BE})(\u{17BB})").unwrap()
});
static RE_STRONG: Lazy<Regex> = Lazy::new(|| {
    Regex::new(&make_strong_pat()).expect("STRONG pattern failed")
});
static RE_NSTRONG: Lazy<Regex> = Lazy::new(|| {
    Regex::new(&make_nstrong_pat()).expect("NSTRONG pattern failed")
});
static RE_COENG_RO: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(\u{17D2}\u{179A})(\u{17D2}[\u{1780}-\u{17B3}])").unwrap()
});
static RE_COENG_DA: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\u{17D2}\u{178A}").unwrap()
});
static RE_LUNAR1: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(\u{17E1}?)([\u{17E0}-\u{17E9}])\u{17D2}\u{17D4}").unwrap()
});
static RE_LUNAR2: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"\u{17D4}\u{17D2}(\u{17E1}?)([\u{17E0}-\u{17E9}])").unwrap()
});

fn lunar_replace(caps: &Captures, base: u32) -> String {
    let d1 = caps.get(1).map_or("", |m| m.as_str());
    let d2 = caps.get(2).unwrap().as_str();
    let v1: u32 = d1.chars().next().map_or(0, |c| c as u32 - 0x17E0);
    let v2 = d2.chars().next().unwrap() as u32 - 0x17E0;
    let v = v1 * 10 + v2;
    if v > 15 {
        caps[0].to_string()
    } else {
        char::from_u32(base + v).unwrap().to_string()
    }
}

/// Returns the Khmer-normalized form of `txt`.
pub fn normalize(txt: &str) -> String {
    let chars: Vec<char> = txt.chars().collect();
    let n = chars.len();
    let mut cats: Vec<Cat> = chars.iter().map(|&c| charcat(c)).collect();

    for i in 1..n {
        if chars[i - 1] == '\u{200D}' || chars[i - 1] == '\u{17D2}' {
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

        let mut syl: String = indices.iter().map(|&k| chars[k]).collect();

        syl = RE_INVIS.replace_all(&syl, "$1").into_owned();
        syl = syl.replace("\u{17BE}\u{17B6}", "\u{17C4}\u{17B8}");
        syl = RE_V1.replace_all(&syl, "\u{17BE}$1").into_owned();
        syl = RE_V2.replace_all(&syl, "\u{17C4}$1").into_owned();
        syl = RE_V3.replace_all(&syl, "$2$1").into_owned();
        syl = RE_STRONG.replace_all(&syl, "$1\u{17CA}$2").into_owned();
        syl = RE_NSTRONG.replace_all(&syl, "$1\u{17C9}$2").into_owned();
        syl = RE_COENG_RO.replace_all(&syl, "$2$1").into_owned();
        syl = RE_COENG_DA.replace_all(&syl, "\u{17D2}\u{178F}").into_owned();
        syl = RE_LUNAR1
            .replace_all(&syl, |caps: &Captures| lunar_replace(caps, 0x19E0))
            .into_owned();
        syl = RE_LUNAR2
            .replace_all(&syl, |caps: &Captures| lunar_replace(caps, 0x19F0))
            .into_owned();
        syl = syl.replace("\u{17D4}\u{17D2}\u{17D4}", "\u{19F0}");
        res.push_str(&syl);
        i = j;
    }
    res
}
