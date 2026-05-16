// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Dart — betterkhmer package. Regex-free.

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

// --- Khmer consonant classes (from the SIL reference khres) ---

const _zwnj  = 0x200C;
const _zwj   = 0x200D;
const _coeng = 0x17D2;
const _robat = 0x17CC;
const _ba    = 0x1794;

// B: all bases (incl. dotted circle).
bool _isBase(int cp) =>
    (cp >= 0x1780 && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3) || cp == 0x25CC;

// NonRo: consonants excluding Ro (U+179A).
bool _isNonRo(int cp) =>
    (cp >= 0x1780 && cp <= 0x1799) || (cp >= 0x179B && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3);

// NonBA: consonants excluding Ba (U+1794).
bool _isNonBA(int cp) =>
    (cp >= 0x1780 && cp <= 0x1793) || (cp >= 0x1795 && cp <= 0x17A2) || (cp >= 0x17A5 && cp <= 0x17B3);

// S1: series-1 consonants.
bool _isS1(int cp) =>
    (cp >= 0x1780 && cp <= 0x1783) ||
    (cp >= 0x1785 && cp <= 0x1788) ||
    (cp >= 0x178A && cp <= 0x178D) ||
    (cp >= 0x178F && cp <= 0x1792) ||
    (cp >= 0x1795 && cp <= 0x1797) ||
    (cp >= 0x179E && cp <= 0x17A0) ||
    cp == 0x17A2;

// S2: series-2 consonants.
bool _isS2(int cp) =>
    cp == 0x1780 || cp == 0x1784 || cp == 0x178E || cp == 0x1793 ||
    cp == 0x1794 || cp == 0x17A1 ||
    (cp >= 0x1798 && cp <= 0x179D) ||
    (cp >= 0x17A3 && cp <= 0x17B3);

bool _isVPre(int cp) => cp >= 0x17C1 && cp <= 0x17C5;

// optRobat returns the position(s) after an optional Robat at p.
List<int> _optRobat(List<int> r, int p) {
  if (p < r.length && r[p] == _robat) return [p, p + 1];
  return [p];
}

// coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
List<int> _coengEnds(List<int> r, int s) {
  final n = r.length;
  final res = <int>[];
  if (s + 1 < n && r[s] == _coeng && _isBase(r[s + 1])) res.add(s + 2);
  if (s + 3 < n && r[s] == _coeng && _isNonRo(r[s + 1]) && r[s + 2] == _coeng && _isBase(r[s + 3])) {
    res.add(s + 4);
  }
  return res;
}

// strongEnds enumerates all end indices of a STRONG match starting at s.
void _strongEnds(List<int> r, int s, void Function(int) add) {
  final n = r.length;
  if (s >= n) return;
  if (_isS1(r[s])) {
    for (final p in _optRobat(r, s + 1)) {
      add(p);
      if (p + 1 < n && r[p] == _coeng && _isNonBA(r[p + 1])) {
        final q = p + 2;
        add(q);
        if (q + 1 < n && r[q] == _coeng && _isNonBA(r[q + 1])) add(q + 2);
      }
    }
  }
  if (_isNonBA(r[s])) {
    for (final p in _optRobat(r, s + 1)) {
      if (p + 1 < n && r[p] == _coeng && _isS1(r[p + 1])) {
        final q = p + 2;
        add(q);
        if (q + 1 < n && r[q] == _coeng && _isNonBA(r[q + 1])) add(q + 2);
      }
      if (p + 3 < n && r[p] == _coeng && _isNonBA(r[p + 1]) && r[p + 2] == _coeng && _isS1(r[p + 3])) {
        add(p + 4);
      }
    }
  }
}

// nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
void _nstrongEnds(List<int> r, int s, void Function(int) add) {
  final n = r.length;
  if (s >= n) return;
  if (_isS2(r[s])) {
    for (final p in _optRobat(r, s + 1)) {
      add(p);
      if (p + 1 < n && r[p] == _coeng && _isS2(r[p + 1])) {
        final q = p + 2;
        add(q);
        if (q + 1 < n && r[q] == _coeng && _isS2(r[q + 1])) add(q + 2);
      }
    }
  }
  if (r[s] == _ba) {
    for (final p in _optRobat(r, s + 1)) {
      add(p);
      for (final e1 in _coengEnds(r, p)) {
        add(e1);
        for (final e2 in _coengEnds(r, e1)) add(e2);
      }
    }
  }
  if (_isBase(r[s])) {
    for (final p in _optRobat(r, s + 1)) {
      if (p + 3 < n && r[p] == _coeng && _isNonRo(r[p + 1]) && r[p + 2] == _coeng && r[p + 3] == _ba) {
        add(p + 4);
      }
      if (p + 3 < n && r[p] == _coeng && r[p + 1] == _ba && r[p + 2] == _coeng && _isBase(r[p + 3])) {
        add(p + 4);
      }
    }
  }
}

// canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
bool _canEndAt(List<int> r, int target,
    void Function(List<int>, int, void Function(int)) ends) {
  for (var s = 0; s < target; s++) {
    var found = false;
    ends(r, s, (e) { if (e == target) found = true; });
    if (found) return true;
  }
  return false;
}

// vaSamyokAt is the lookahead (?:VA | ័):
// VA = (?:[ិ-ឺើឿ៝] | ាំ)
bool _vaSamyokAt(List<int> r, int p) {
  final n = r.length;
  if (p >= n) return false;
  final c = r[p];
  if (c == 0x17D0) return true;
  if (c >= 0x17B7 && c <= 0x17BA) return true;
  if (c == 0x17BE || c == 0x17BF || c == 0x17DD) return true;
  if (c == 0x17B6 && p + 1 < n && r[p + 1] == 0x17C6) return true;
  return false;
}

// applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
void _applyShifter(List<int> r,
    void Function(List<int>, int, void Function(int)) ends, int shifter) {
  for (var k = 0; k < r.length; k++) {
    if (r[k] != 0x17BB) continue;
    final ctx = _canEndAt(r, k, ends) ||
        (k >= 1 && _isVPre(r[k - 1]) && _canEndAt(r, k - 1, ends));
    if (ctx && _vaSamyokAt(r, k + 1)) r[k] = shifter;
  }
}

// collapseInvis: (‍?្)[្‌‍]+ -> \1
List<int> _collapseInvis(List<int> r) {
  final n = r.length;
  bool isInvis(int c) => c == _coeng || c == _zwnj || c == _zwj;
  final out = <int>[];
  var i = 0;
  while (i < n) {
    var g1End = -1;
    if (r[i] == _zwj && i + 1 < n && r[i + 1] == _coeng) {
      g1End = i + 2;
    } else if (r[i] == _coeng) {
      g1End = i + 1;
    }
    if (g1End >= 0) {
      var k = g1End;
      while (k < n && isInvis(r[k])) k++;
      if (k > g1End) {
        for (var p = i; p < g1End; p++) out.add(r[p]);
        i = k;
        continue;
      }
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// pairReplace replaces every non-overlapping [a,b] with the codepoints in repl.
List<int> _pairReplace(List<int> r, int a, int b, List<int> repl) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (i + 1 < n && r[i] == a && r[i + 1] == b) {
      out.addAll(repl);
      i += 2;
      continue;
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// pairReplace3 replaces every non-overlapping [a,b,c] with repl.
List<int> _pairReplace3(List<int> r, int a, int b, int c, int repl) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c) {
      out.add(repl);
      i += 3;
      continue;
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
List<int> _vowelSplit(List<int> r, int tail, int head) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (r[i] == 0x17C1) {
      if (i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail) {
        out.add(head);
        out.add(r[i + 1]);
        i += 3;
        continue;
      }
      if (i + 1 < n && r[i + 1] == tail) {
        out.add(head);
        i += 2;
        continue;
      }
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// coengRo: (្រ)(្[ក-ឳ]) -> \2\1
List<int> _coengRo(List<int> r) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (i + 3 < n && r[i] == _coeng && r[i + 1] == 0x179A &&
        r[i + 2] == _coeng && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3) {
      out.add(r[i + 2]);
      out.add(r[i + 3]);
      out.add(r[i]);
      out.add(r[i + 1]);
      i += 4;
      continue;
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// coengDa: (្)ដ -> \1ត
List<int> _coengDa(List<int> r) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (i + 1 < n && r[i] == _coeng && r[i + 1] == 0x178A) {
      out.add(_coeng);
      out.add(0x178F);
      i += 2;
      continue;
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

bool _isDigit(int cp) => cp >= 0x17E0 && cp <= 0x17E9;

// lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
List<int> _lunar1(List<int> r) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (r[i] == 0x17E1 && i + 3 < n && _isDigit(r[i + 1]) && r[i + 2] == _coeng && r[i + 3] == 0x17D4) {
      final v = 10 + (r[i + 1] - 0x17E0);
      if (v > 15) {
        for (var p = i; p < i + 4; p++) out.add(r[p]);
      } else {
        out.add(0x19E0 + v);
      }
      i += 4;
      continue;
    }
    if (i + 2 < n && _isDigit(r[i]) && r[i + 1] == _coeng && r[i + 2] == 0x17D4) {
      out.add(0x19E0 + (r[i] - 0x17E0));
      i += 3;
      continue;
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
List<int> _lunar2(List<int> r) {
  final n = r.length;
  final out = <int>[];
  for (var i = 0; i < n;) {
    if (r[i] == 0x17D4 && i + 1 < n && r[i + 1] == _coeng) {
      if (i + 3 < n && r[i + 2] == 0x17E1 && _isDigit(r[i + 3])) {
        final v = 10 + (r[i + 3] - 0x17E0);
        if (v > 15) {
          for (var p = i; p < i + 4; p++) out.add(r[p]);
        } else {
          out.add(0x19F0 + v);
        }
        i += 4;
        continue;
      }
      if (i + 2 < n && _isDigit(r[i + 2])) {
        out.add(0x19F0 + (r[i + 2] - 0x17E0));
        i += 3;
        continue;
      }
    }
    out.add(r[i]);
    i++;
  }
  return out;
}

// hasKhmer reports whether any codepoint lies in the Khmer block U+1780–U+17FF.
// No Khmer codepoint => identity, matching the Go SWAR fast path.
bool _hasKhmer(List<int> cps) {
  for (final c in cps) {
    if (c >= 0x1780 && c <= 0x17FF) return true;
  }
  return false;
}

/// Returns the Khmer-normalized form of [txt].
String normalize(String txt, {String lang = 'km'}) {
  if (lang == 'xhm') {
    // [ិ-ៅ]្  ->  ‍ + match  (U+17B7..U+17C5 followed by U+17D2)
    final src = txt.runes.toList();
    final tmp = <int>[];
    for (var p = 0; p < src.length; p++) {
      if (src[p] >= 0x17B7 && src[p] <= 0x17C5 && p + 1 < src.length && src[p + 1] == 0x17D2) {
        tmp.add(_zwj);
        tmp.add(src[p]);
        tmp.add(0x17D2);
        p++;
        continue;
      }
      tmp.add(src[p]);
    }
    txt = String.fromCharCodes(tmp);
  }

  final chars = txt.runes.toList();
  final n = chars.length;
  if (!_hasKhmer(chars)) return txt;

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

    var syl = indices.map((k) => chars[k]).toList();

    syl = _collapseInvis(syl);
    syl = _pairReplace(syl, 0x17BE, 0x17B6, const [0x17C4, 0x17B8]); // ើា -> ោី
    syl = _vowelSplit(syl, 0x17B8, 0x17BE);                          // េ(◌)ី -> ើ(◌)
    syl = _vowelSplit(syl, 0x17B6, 0x17C4);                          // េ(◌)ា -> ោ(◌)
    syl = _pairReplace(syl, 0x17BE, 0x17BB, const [0x17BB, 0x17BE]); // ើុ -> ុើ
    _applyShifter(syl, _strongEnds, 0x17CA);                         // strong  -u -> ៊
    _applyShifter(syl, _nstrongEnds, 0x17C9);                        // weak    -u -> ៉
    syl = _coengRo(syl);
    syl = _coengDa(syl);
    syl = _lunar1(syl);
    syl = _lunar2(syl);
    syl = _pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0);        // ។្។ -> ᧰

    buf.write(String.fromCharCodes(syl));
    i = j;
  }
  return buf.toString();
}
