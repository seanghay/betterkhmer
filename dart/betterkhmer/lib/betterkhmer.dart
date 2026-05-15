// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Dart — betterkhmer package.

const _catOther   = 0;
const _catBase    = 1;
const _catRobat   = 2;
const _catCoeng   = 3;
const _catShift   = 4;
const _catZ       = 5;
const _catVPre    = 6;
const _catVB      = 7;
const _catVA      = 8;
const _catVPost   = 9;
const _catMS      = 10;
const _catMF      = 11;
const _catZFCoeng = 12;

final _categories = () {
  final c = List<int>.filled(0x17DE - 0x1780, _catOther);
  for (var i = 0; i <= 0x17A2 - 0x1780; i++) c[i] = _catBase;
  for (var i = 0x17A5 - 0x1780; i <= 0x17B3 - 0x1780; i++) c[i] = _catBase;
  c[0x17B6 - 0x1780] = _catVPost;
  for (var i = 0x17B7 - 0x1780; i <= 0x17BA - 0x1780; i++) c[i] = _catVA;
  for (var i = 0x17BB - 0x1780; i <= 0x17BD - 0x1780; i++) c[i] = _catVB;
  for (var i = 0x17BE - 0x1780; i <= 0x17C5 - 0x1780; i++) c[i] = _catVPre;
  c[0x17C6 - 0x1780] = _catMS;
  c[0x17C7 - 0x1780] = _catMF;
  c[0x17C8 - 0x1780] = _catMF;
  c[0x17C9 - 0x1780] = _catShift;
  c[0x17CA - 0x1780] = _catShift;
  c[0x17CB - 0x1780] = _catMS;
  c[0x17CC - 0x1780] = _catRobat;
  for (var i = 0x17CD - 0x1780; i <= 0x17D1 - 0x1780; i++) c[i] = _catMS;
  c[0x17D2 - 0x1780] = _catCoeng;
  c[0x17D3 - 0x1780] = _catMS;
  for (var i = 0x17D4 - 0x1780; i <= 0x17DC - 0x1780; i++) c[i] = _catOther;
  c[0x17DD - 0x1780] = _catMS;
  return c;
}();

int _charcat(int cp) {
  if (cp >= 0x1780 && cp <= 0x17DD) return _categories[cp - 0x1780];
  if (cp == 0x200C) return _catZ;
  if (cp == 0x200D) return _catZFCoeng;
  return _catOther;
}

const _s1    = r'[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]';
const _nonBA = r'[ក-នផ-អឥ-ឳ]';
const _s2    = r'[ងកណនបម-ឝឡឣ-ឳ]';
const _nonRo = r'[ក-យល-អឥ-ឳ]';
const _b     = r'[ក-អឥ-ឳ◌]';
const _va    = r'(?:[ិ-ឺើឿ៝]|ាំ)';

String get _strongClean =>
    '$_s1៌?(?:្$_nonBA(?:្$_nonBA)?)?'
    '|$_nonBA៌?(?:្$_s1(?:្$_nonBA)?|្$_nonBA្$_s1)';

String get _nstrong =>
    '(?:$_s2៌?(?:្$_s2(?:្$_s2)?)?'
    '|ប៌?(?:(?:(?:្$_nonRo)?្$_b)(?:(?:្$_nonRo)?្$_b)?)?'
    '|$_b៌?(?:្$_nonRo្ប|្ប(?:្$_b)))';

final _reInvis   = RegExp(r'(‍?្)[្‌‍]+');
final _reVBE     = RegExp(r'ើា');
final _reV1      = RegExp(r'េ([ុ-ួ]?)ី');
final _reV2      = RegExp(r'េ([ុ-ួ]?)ា');
final _reV3      = RegExp(r'(ើ)(ុ)');
final _reStrong  = RegExp('(?:$_strongClean)[េ-ៅ]?ុ(?=$_va|័)');
final _reNStrong = RegExp('$_nstrong[េ-ៅ]?ុ(?=$_va|័)');
final _reCoengRo = RegExp(r'(្រ)(្[ក-ឳ])');
final _reCoengDa = RegExp(r'្ដ');
final _reLunar1  = RegExp(r'(១?)([០-៩])្។');
final _reLunar2  = RegExp(r'។្(១?)([០-៩])');

String? _lunarReplace(Match m, int base) {
  final d1 = m.group(1)!;
  final d2 = m.group(2)!;
  final v1 = d1.isEmpty ? 0 : d1.codeUnitAt(0) - 0x17E0;
  final v = v1 * 10 + d2.codeUnitAt(0) - 0x17E0;
  if (v > 15) return null;
  return String.fromCharCode(base + v);
}

/// Returns the Khmer-normalized form of [txt].
String normalize(String txt, {String lang = 'km'}) {
  if (lang == 'xhm') {
    txt = txt.replaceAllMapped(
      RegExp(r'[ិ-ៅ]្'),
      (m) => '‍${m[0]}',
    );
  }

  final chars = txt.runes.toList();
  final n = chars.length;
  final cats = chars.map(_charcat).toList();

  for (var i = 1; i < n; i++) {
    if (chars[i - 1] == 0x200D || chars[i - 1] == 0x17D2) {
      if (cats[i] == _catBase || cats[i] == _catCoeng) {
        cats[i] = cats[i - 1];
      }
    }
  }

  final buf = StringBuffer();
  var i = 0;
  while (i < n) {
    if (cats[i] != _catBase) {
      buf.writeCharCode(chars[i]);
      i++;
      continue;
    }
    var j = i + 1;
    while (j < n && cats[j] > _catBase) j++;

    final indices = List<int>.generate(j - i, (k) => i + k);
    indices.sort((a, b) {
      final c = cats[a].compareTo(cats[b]);
      return c != 0 ? c : a.compareTo(b);
    });

    var syl = String.fromCharCodes(indices.map((k) => chars[k]));

    syl = syl.replaceAllMapped(_reInvis, (m) => m.group(1)!);
    syl = syl.replaceAll(_reVBE, 'ោី');
    syl = syl.replaceAllMapped(_reV1, (m) => 'ើ${m.group(1)}');
    syl = syl.replaceAllMapped(_reV2, (m) => 'ោ${m.group(1)}');
    syl = syl.replaceAllMapped(_reV3, (m) => '${m.group(2)}${m.group(1)}');
    syl = syl.replaceAllMapped(_reStrong, (m) {
      final s = m.group(0)!;
      return s.substring(0, s.length - 1) + '៊';
    });
    syl = syl.replaceAllMapped(_reNStrong, (m) {
      final s = m.group(0)!;
      return s.substring(0, s.length - 1) + '៉';
    });
    syl = syl.replaceAllMapped(_reCoengRo, (m) => '${m.group(2)}${m.group(1)}');
    syl = syl.replaceAll(_reCoengDa, '្ត');
    syl = syl.replaceAllMapped(_reLunar1, (m) {
      return _lunarReplace(m, 0x19E0) ?? m.group(0)!;
    });
    syl = syl.replaceAllMapped(_reLunar2, (m) {
      return _lunarReplace(m, 0x19F0) ?? m.group(0)!;
    });
    syl = syl.replaceAll('។្។', '᧰');
    buf.write(syl);
    i = j;
  }
  return buf.toString();
}
