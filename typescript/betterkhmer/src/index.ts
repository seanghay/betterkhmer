// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to TypeScript — betterkhmer package. Regex-free.

const Cat = {
  Other: 0, Base: 1, Robat: 2, Coeng: 3,
  Shift: 4, Z: 5, VPre: 6, VB: 7, VA: 8,
  VPost: 9, MS: 10, MF: 11, ZFCoeng: 12,
} as const;

const CATEGORIES: Uint8Array = (() => {
  const c = new Uint8Array(0x17DE - 0x1780);
  for (let i = 0; i <= 0x17A2 - 0x1780; i++) c[i] = Cat.Base;
  for (let i = 0x17A5 - 0x1780; i <= 0x17B3 - 0x1780; i++) c[i] = Cat.Base;
  c[0x17B6 - 0x1780] = Cat.VPost;
  for (let i = 0x17B7 - 0x1780; i <= 0x17BA - 0x1780; i++) c[i] = Cat.VA;
  for (let i = 0x17BB - 0x1780; i <= 0x17BD - 0x1780; i++) c[i] = Cat.VB;
  for (let i = 0x17BE - 0x1780; i <= 0x17C5 - 0x1780; i++) c[i] = Cat.VPre;
  c[0x17C6 - 0x1780] = Cat.MS;
  c[0x17C7 - 0x1780] = Cat.MF; c[0x17C8 - 0x1780] = Cat.MF;
  c[0x17C9 - 0x1780] = Cat.Shift; c[0x17CA - 0x1780] = Cat.Shift;
  c[0x17CB - 0x1780] = Cat.MS; c[0x17CC - 0x1780] = Cat.Robat;
  for (let i = 0x17CD - 0x1780; i <= 0x17D1 - 0x1780; i++) c[i] = Cat.MS;
  c[0x17D2 - 0x1780] = Cat.Coeng; c[0x17D3 - 0x1780] = Cat.MS;
  for (let i = 0x17D4 - 0x1780; i <= 0x17DC - 0x1780; i++) c[i] = Cat.Other;
  c[0x17DD - 0x1780] = Cat.MS;
  return c;
})();

function charcat(cp: number): number {
  if (cp >= 0x1780 && cp <= 0x17DD) return CATEGORIES[cp - 0x1780];
  if (cp === 0x200C) return Cat.Z;
  if (cp === 0x200D) return Cat.ZFCoeng;
  return Cat.Other;
}

// --- Khmer consonant classes (from the SIL reference khres) ---

const ZWNJ = 0x200C;
const ZWJ = 0x200D;
const COENG = 0x17D2;
const ROBAT = 0x17CC;
const BA = 0x1794;

// B: all bases (incl. dotted circle).
function isBase(cp: number): boolean {
  return (cp >= 0x1780 && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3) || cp === 0x25CC;
}

// NonRo: consonants excluding Ro (U+179A).
function isNonRo(cp: number): boolean {
  return (cp >= 0x1780 && cp <= 0x1799) || (cp >= 0x179B && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3);
}

// NonBA: consonants excluding Ba (U+1794).
function isNonBA(cp: number): boolean {
  return (cp >= 0x1780 && cp <= 0x1793) || (cp >= 0x1795 && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3);
}

// S1: series-1 consonants.
function isS1(cp: number): boolean {
  return (cp >= 0x1780 && cp <= 0x1783) ||
    (cp >= 0x1785 && cp <= 0x1788) ||
    (cp >= 0x178A && cp <= 0x178D) ||
    (cp >= 0x178F && cp <= 0x1792) ||
    (cp >= 0x1795 && cp <= 0x1797) ||
    (cp >= 0x179E && cp <= 0x17A0) ||
    cp === 0x17A2;
}

// S2: series-2 consonants.
function isS2(cp: number): boolean {
  return cp === 0x1780 || cp === 0x1784 || cp === 0x178E || cp === 0x1793 ||
    cp === 0x1794 || cp === 0x17A1 ||
    (cp >= 0x1798 && cp <= 0x179D) ||
    (cp >= 0x17A3 && cp <= 0x17B3);
}

function isVPre(cp: number): boolean { return cp >= 0x17C1 && cp <= 0x17C5; }

// optRobat returns the position(s) after an optional Robat at p.
function optRobat(r: number[], p: number): number[] {
  if (p < r.length && r[p] === ROBAT) return [p, p + 1];
  return [p];
}

// coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
function coengEnds(r: number[], s: number): number[] {
  const n = r.length;
  const res: number[] = [];
  if (s + 1 < n && r[s] === COENG && isBase(r[s + 1])) res.push(s + 2);
  if (s + 3 < n && r[s] === COENG && isNonRo(r[s + 1]) && r[s + 2] === COENG && isBase(r[s + 3])) res.push(s + 4);
  return res;
}

// strongEnds enumerates all end indices of a STRONG match starting at s.
function strongEnds(r: number[], s: number, add: (e: number) => void): void {
  const n = r.length;
  if (s >= n) return;
  if (isS1(r[s])) {
    for (const p of optRobat(r, s + 1)) {
      add(p);
      if (p + 1 < n && r[p] === COENG && isNonBA(r[p + 1])) {
        const q = p + 2;
        add(q);
        if (q + 1 < n && r[q] === COENG && isNonBA(r[q + 1])) add(q + 2);
      }
    }
  }
  if (isNonBA(r[s])) {
    for (const p of optRobat(r, s + 1)) {
      if (p + 1 < n && r[p] === COENG && isS1(r[p + 1])) {
        const q = p + 2;
        add(q);
        if (q + 1 < n && r[q] === COENG && isNonBA(r[q + 1])) add(q + 2);
      }
      if (p + 3 < n && r[p] === COENG && isNonBA(r[p + 1]) && r[p + 2] === COENG && isS1(r[p + 3])) add(p + 4);
    }
  }
}

// nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
function nstrongEnds(r: number[], s: number, add: (e: number) => void): void {
  const n = r.length;
  if (s >= n) return;
  if (isS2(r[s])) {
    for (const p of optRobat(r, s + 1)) {
      add(p);
      if (p + 1 < n && r[p] === COENG && isS2(r[p + 1])) {
        const q = p + 2;
        add(q);
        if (q + 1 < n && r[q] === COENG && isS2(r[q + 1])) add(q + 2);
      }
    }
  }
  if (r[s] === BA) {
    for (const p of optRobat(r, s + 1)) {
      add(p);
      for (const e1 of coengEnds(r, p)) {
        add(e1);
        for (const e2 of coengEnds(r, e1)) add(e2);
      }
    }
  }
  if (isBase(r[s])) {
    for (const p of optRobat(r, s + 1)) {
      if (p + 3 < n && r[p] === COENG && isNonRo(r[p + 1]) && r[p + 2] === COENG && r[p + 3] === BA) add(p + 4);
      if (p + 3 < n && r[p] === COENG && r[p + 1] === BA && r[p + 2] === COENG && isBase(r[p + 3])) add(p + 4);
    }
  }
}

// canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
function canEndAt(r: number[], target: number,
                  ends: (r: number[], s: number, add: (e: number) => void) => void): boolean {
  for (let s = 0; s < target; s++) {
    let found = false;
    ends(r, s, (e) => { if (e === target) found = true; });
    if (found) return true;
  }
  return false;
}

// vaSamyokAt is the lookahead (?:VA | ័):
// VA = (?:[ិ-ឺើឿ៝] | ាំ)
function vaSamyokAt(r: number[], p: number): boolean {
  const n = r.length;
  if (p >= n) return false;
  const c = r[p];
  if (c === 0x17D0) return true;
  if (c >= 0x17B7 && c <= 0x17BA) return true;
  if (c === 0x17BE || c === 0x17BF || c === 0x17DD) return true;
  if (c === 0x17B6 && p + 1 < n && r[p + 1] === 0x17C6) return true;
  return false;
}

// applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
function applyShifter(r: number[],
                      ends: (r: number[], s: number, add: (e: number) => void) => void,
                      shifter: number): void {
  for (let k = 0; k < r.length; k++) {
    if (r[k] !== 0x17BB) continue;
    const ctx = canEndAt(r, k, ends) ||
      (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, k - 1, ends));
    if (ctx && vaSamyokAt(r, k + 1)) r[k] = shifter;
  }
}

// collapseInvis: (‍?្)[្‌‍]+ -> \1
function collapseInvis(r: number[]): number[] {
  const n = r.length;
  const isInvis = (c: number) => c === COENG || c === ZWNJ || c === ZWJ;
  const out: number[] = [];
  let i = 0;
  while (i < n) {
    let g1End = -1;
    if (r[i] === ZWJ && i + 1 < n && r[i + 1] === COENG) g1End = i + 2;
    else if (r[i] === COENG) g1End = i + 1;
    if (g1End >= 0) {
      let k = g1End;
      while (k < n && isInvis(r[k])) k++;
      if (k > g1End) {
        for (let p = i; p < g1End; p++) out.push(r[p]);
        i = k;
        continue;
      }
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// pairReplace replaces every non-overlapping [a,b] with the codepoints in repl.
function pairReplace(r: number[], a: number, b: number, ...repl: number[]): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (i + 1 < n && r[i] === a && r[i + 1] === b) {
      for (const x of repl) out.push(x);
      i += 2;
      continue;
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// pairReplace3 replaces every non-overlapping [a,b,c] with repl.
function pairReplace3(r: number[], a: number, b: number, c: number, repl: number): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (i + 2 < n && r[i] === a && r[i + 1] === b && r[i + 2] === c) {
      out.push(repl);
      i += 3;
      continue;
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
function vowelSplit(r: number[], tail: number, head: number): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (r[i] === 0x17C1) {
      if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] === tail) {
        out.push(head, r[i + 1]);
        i += 3;
        continue;
      }
      if (i + 1 < n && r[i + 1] === tail) {
        out.push(head);
        i += 2;
        continue;
      }
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// coengRo: (្រ)(្[ក-ឳ]) -> \2\1
function coengRo(r: number[]): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (i + 3 < n && r[i] === COENG && r[i + 1] === 0x179A &&
        r[i + 2] === COENG && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
      out.push(r[i + 2], r[i + 3], r[i], r[i + 1]);
      i += 4;
      continue;
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// coengDa: (្)ដ -> \1ត
function coengDa(r: number[]): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (i + 1 < n && r[i] === COENG && r[i + 1] === 0x178A) {
      out.push(COENG, 0x178F);
      i += 2;
      continue;
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

function isDigit(cp: number): boolean { return cp >= 0x17E0 && cp <= 0x17E9; }

// lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
function lunar1(r: number[]): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (r[i] === 0x17E1 && i + 3 < n && isDigit(r[i + 1]) && r[i + 2] === COENG && r[i + 3] === 0x17D4) {
      const v = 10 + (r[i + 1] - 0x17E0);
      if (v > 15) {
        for (let p = i; p < i + 4; p++) out.push(r[p]);
      } else {
        out.push(0x19E0 + v);
      }
      i += 4;
      continue;
    }
    if (i + 2 < n && isDigit(r[i]) && r[i + 1] === COENG && r[i + 2] === 0x17D4) {
      out.push(0x19E0 + (r[i] - 0x17E0));
      i += 3;
      continue;
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
function lunar2(r: number[]): number[] {
  const n = r.length;
  const out: number[] = [];
  for (let i = 0; i < n;) {
    if (r[i] === 0x17D4 && i + 1 < n && r[i + 1] === COENG) {
      if (i + 3 < n && r[i + 2] === 0x17E1 && isDigit(r[i + 3])) {
        const v = 10 + (r[i + 3] - 0x17E0);
        if (v > 15) {
          for (let p = i; p < i + 4; p++) out.push(r[p]);
        } else {
          out.push(0x19F0 + v);
        }
        i += 4;
        continue;
      }
      if (i + 2 < n && isDigit(r[i + 2])) {
        out.push(0x19F0 + (r[i + 2] - 0x17E0));
        i += 3;
        continue;
      }
    }
    out.push(r[i]);
    i++;
  }
  return out;
}

// hasKhmer reports whether any codepoint lies in the Khmer block U+1780–U+17FF.
// No Khmer codepoint => identity, matching the Go SWAR fast path.
function hasKhmer(cps: number[]): boolean {
  for (let i = 0; i < cps.length; i++) {
    const c = cps[i];
    if (c >= 0x1780 && c <= 0x17FF) return true;
  }
  return false;
}

/** Returns the Khmer-normalized form of txt. */
export function normalize(txt: string, lang = 'km'): string {
  let cps: number[] = [];
  for (const ch of txt) {
    const cp = ch.codePointAt(0);
    if (cp !== undefined) cps.push(cp);
  }

  // No Khmer codepoint => identity (matches the Go SWAR fast path).
  if (!hasKhmer(cps)) return txt;

  if (lang === 'xhm') {
    // [ា-ៅ]្  ->  ‍ + match  (U+17B6..U+17C5 followed by U+17D2)
    const tmp: number[] = [];
    for (let p = 0; p < cps.length; p++) {
      if (cps[p] >= 0x17B6 && cps[p] <= 0x17C5 && p + 1 < cps.length && cps[p + 1] === 0x17D2) {
        tmp.push(ZWJ, cps[p], 0x17D2);
        p++;
        continue;
      }
      tmp.push(cps[p]);
    }
    cps = tmp;
  }

  const n = cps.length;
  const cats: number[] = new Array(n);
  for (let i = 0; i < n; i++) cats[i] = charcat(cps[i]);

  for (let i = 1; i < n; i++) {
    if (cps[i - 1] === 0x200D || cps[i - 1] === 0x17D2) {
      if (cats[i] === Cat.Base || cats[i] === Cat.Coeng) cats[i] = cats[i - 1];
    }
  }

  const parts: string[] = [];
  let i = 0;
  while (i < n) {
    if (cats[i] !== Cat.Base) { parts.push(String.fromCodePoint(cps[i])); i++; continue; }
    let j = i + 1;
    while (j < n && cats[j] > Cat.Base) j++;

    const indices: number[] = [];
    for (let k = i; k < j; k++) indices.push(k);
    indices.sort((a, b) => cats[a] !== cats[b] ? cats[a] - cats[b] : a - b);

    let syl: number[] = [];
    for (let k = 0; k < indices.length; k++) syl.push(cps[indices[k]]);

    syl = collapseInvis(syl);
    syl = pairReplace(syl, 0x17BE, 0x17B6, 0x17C4, 0x17B8); // ើា -> ោី
    syl = vowelSplit(syl, 0x17B8, 0x17BE);                  // េ(◌)ី -> ើ(◌)
    syl = vowelSplit(syl, 0x17B6, 0x17C4);                  // េ(◌)ា -> ោ(◌)
    syl = pairReplace(syl, 0x17BE, 0x17BB, 0x17BB, 0x17BE); // ើុ -> ុើ
    applyShifter(syl, strongEnds, 0x17CA);                  // strong  -u -> ៊
    applyShifter(syl, nstrongEnds, 0x17C9);                 // weak    -u -> ៉
    syl = coengRo(syl);
    syl = coengDa(syl);
    syl = lunar1(syl);
    syl = lunar2(syl);
    syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0); // ។្។ -> ᧰

    parts.push(String.fromCodePoint(...syl));
    i = j;
  }
  return parts.join('');
}
