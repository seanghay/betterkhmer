// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to TypeScript — betterkhmer package.

const enum Cat {
  Other = 0, Base = 1, Robat = 2, Coeng = 3,
  Shift = 4, Z = 5, VPre = 6, VB = 7, VA = 8,
  VPost = 9, MS = 10, MF = 11, ZFCoeng = 12,
}

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

function charcat(cp: number): Cat {
  if (cp >= 0x1780 && cp <= 0x17DD) return CATEGORIES[cp - 0x1780] as Cat;
  if (cp === 0x200C) return Cat.Z;
  if (cp === 0x200D) return Cat.ZFCoeng;
  return Cat.Other;
}

const S1    = String.raw`[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]`;
const NonBA = String.raw`[ក-នផ-អឥ-ឳ]`;
const S2    = String.raw`[ងកណនបម-ឝឡឣ-ឳ]`;
const NonRo = String.raw`[ក-យល-អឥ-ឳ]`;
const B     = String.raw`[ក-អឥ-ឳ◌]`;
const VA    = String.raw`(?:[ិ-ឺើឿ៝]|ាំ)`;
const COENG = `(?:(?:្${NonRo})?្${B})`;

const STRONG =
  `${S1}៌?(?:្${NonBA}(?:្${NonBA})?)?` +
  `|${NonBA}៌?(?:្${S1}(?:្${NonBA})?|្${NonBA}្${S1})`;

const NSTRONG =
  `(?:${S2}៌?(?:្${S2}(?:្${S2})?)?` +
  `|ប៌?(?:${COENG}(?:${COENG})?)?` +
  `|${B}៌?(?:្${NonRo}្ប|្ប(?:្${B})))`;

const reInvis   = new RegExp(String.raw`(‍?្)[្‌‍]+`, 'gu');
const reVBE     = /ើា/gu;
const reV1      = /េ([ុ-ួ]?)ី/gu;
const reV2      = /េ([ុ-ួ]?)ា/gu;
const reV3      = /(ើ)(ុ)/gu;
const reStrong  = new RegExp(`((?:${STRONG})[\\u17C1-\\u17C5]?)ុ(?=${VA}|័)`, 'gu');
const reNStrong = new RegExp(`((?:${NSTRONG})[\\u17C1-\\u17C5]?)ុ(?=${VA}|័)`, 'gu');
const reCoengRo = /(្រ)(្[ក-ឳ])/gu;
const reCoengDa = /្ដ/gu;
const reLunar1  = /(១?)([០-៩])្។/gu;
const reLunar2  = /។្(១?)([០-៩])/gu;

function lunarReplace(d1: string, d2: string, base: number): string {
  const v1 = d1 ? d1.codePointAt(0)! - 0x17E0 : 0;
  const v = v1 * 10 + d2.codePointAt(0)! - 0x17E0;
  if (v > 15) return null as unknown as string;
  return String.fromCodePoint(base + v);
}

/** Returns the Khmer-normalized form of txt. */
export function normalize(txt: string, lang = 'km'): string {
  if (lang === 'xhm') {
    txt = txt.replace(/[ា-ៅ]្/gu, m => '‍' + m);
  }

  const cps = [...txt].map(c => c.codePointAt(0)!);
  const n = cps.length;
  const cats: Cat[] = cps.map(charcat);

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

    const indices = Array.from({ length: j - i }, (_, k) => i + k);
    indices.sort((a, b) => cats[a] !== cats[b] ? cats[a] - cats[b] : a - b);

    let syl = indices.map(k => String.fromCodePoint(cps[k])).join('');

    syl = syl.replace(reInvis,   '$1');
    syl = syl.replace(reVBE,     'ោី');
    syl = syl.replace(reV1,      'ើ$1');
    syl = syl.replace(reV2,      'ោ$1');
    syl = syl.replace(reV3,      '$2$1');
    syl = syl.replace(reStrong,  '$1៊');
    syl = syl.replace(reNStrong, '$1៉');
    syl = syl.replace(reCoengRo, '$2$1');
    syl = syl.replace(reCoengDa, '្ត');
    syl = syl.replace(reLunar1, (_, d1, d2) => lunarReplace(d1, d2, 0x19E0) ?? _);
    syl = syl.replace(reLunar2, (_, d1, d2) => lunarReplace(d1, d2, 0x19F0) ?? _);
    syl = syl.replaceAll('។្។', '᧰');

    // reset lastIndex for stateful global regexes
    [reInvis, reVBE, reV1, reV2, reV3, reStrong, reNStrong,
     reCoengRo, reCoengDa, reLunar1, reLunar2].forEach(r => r.lastIndex = 0);

    parts.push(syl);
    i = j;
  }
  return parts.join('');
}
