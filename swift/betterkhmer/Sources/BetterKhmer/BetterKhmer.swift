// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Swift — BetterKhmer package. Regex-free.

private enum Cat: Int, Comparable {
    case other = 0, base = 1, robat = 2, coeng = 3,
         shift = 4, z = 5, vPre = 6, vB = 7, vA = 8,
         vPost = 9, ms = 10, mf = 11, zfCoeng = 12
    static func < (lhs: Cat, rhs: Cat) -> Bool { lhs.rawValue < rhs.rawValue }
}

private let categories: [Cat] = {
    var c = [Cat](repeating: .other, count: 0x17DE - 0x1780)
    for i in 0...(0x17A2 - 0x1780) { c[i] = .base }
    for i in (0x17A5 - 0x1780)...(0x17B3 - 0x1780) { c[i] = .base }
    c[0x17B6 - 0x1780] = .vPost
    for i in (0x17B7 - 0x1780)...(0x17BA - 0x1780) { c[i] = .vA }
    for i in (0x17BB - 0x1780)...(0x17BD - 0x1780) { c[i] = .vB }
    for i in (0x17BE - 0x1780)...(0x17C5 - 0x1780) { c[i] = .vPre }
    c[0x17C6 - 0x1780] = .ms; c[0x17C7 - 0x1780] = .mf; c[0x17C8 - 0x1780] = .mf
    c[0x17C9 - 0x1780] = .shift; c[0x17CA - 0x1780] = .shift
    c[0x17CB - 0x1780] = .ms; c[0x17CC - 0x1780] = .robat
    for i in (0x17CD - 0x1780)...(0x17D1 - 0x1780) { c[i] = .ms }
    c[0x17D2 - 0x1780] = .coeng; c[0x17D3 - 0x1780] = .ms
    for i in (0x17D4 - 0x1780)...(0x17DC - 0x1780) { c[i] = .other }
    c[0x17DD - 0x1780] = .ms
    return c
}()

private func charcat(_ cp: Int) -> Cat {
    if cp >= 0x1780 && cp <= 0x17DD { return categories[cp - 0x1780] }
    if cp == 0x200C { return .z }
    if cp == 0x200D { return .zfCoeng }
    return .other
}

// --- Khmer consonant classes (from the SIL reference khres) ---

private let zwnj = 0x200C
private let zwj = 0x200D
private let coeng = 0x17D2
private let robat = 0x17CC
private let ba = 0x1794

// B: all bases (incl. dotted circle).
private func isBase(_ r: Int) -> Bool {
    (r >= 0x1780 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3) || r == 0x25CC
}

// NonRo: consonants excluding Ro (U+179A).
private func isNonRo(_ r: Int) -> Bool {
    (r >= 0x1780 && r <= 0x1799) || (r >= 0x179B && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3)
}

// NonBA: consonants excluding Ba (U+1794).
private func isNonBA(_ r: Int) -> Bool {
    (r >= 0x1780 && r <= 0x1793) || (r >= 0x1795 && r <= 0x17A2) || (r >= 0x17A5 && r <= 0x17B3)
}

// S1: series-1 consonants.
private func isS1(_ r: Int) -> Bool {
    switch r {
    case 0x1780...0x1783: return true
    case 0x1785...0x1788: return true
    case 0x178A...0x178D: return true
    case 0x178F...0x1792: return true
    case 0x1795...0x1797: return true
    case 0x179E...0x17A0: return true
    case 0x17A2: return true
    default: return false
    }
}

// S2: series-2 consonants.
private func isS2(_ r: Int) -> Bool {
    switch r {
    case 0x1780, 0x1784, 0x178E, 0x1793, 0x1794, 0x17A1: return true
    case 0x1798...0x179D: return true
    case 0x17A3...0x17B3: return true
    default: return false
    }
}

private func isVPre(_ r: Int) -> Bool { r >= 0x17C1 && r <= 0x17C5 }

// optRobat returns the position(s) after an optional Robat at p.
private func optRobat(_ r: [Int], _ p: Int) -> [Int] {
    if p < r.count && r[p] == robat { return [p, p + 1] }
    return [p]
}

// coengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
private func coengEnds(_ r: [Int], _ s: Int) -> [Int] {
    let n = r.count
    var res: [Int] = []
    if s + 1 < n && r[s] == coeng && isBase(r[s + 1]) { res.append(s + 2) }
    if s + 3 < n && r[s] == coeng && isNonRo(r[s + 1]) && r[s + 2] == coeng && isBase(r[s + 3]) {
        res.append(s + 4)
    }
    return res
}

// strongEnds enumerates all end indices of a STRONG match starting at s.
//
//	S1 ៌? (?:្ NonBA (?:្ NonBA)?)?
//	| NonBA ៌? (?:្ S1 (?:្ NonBA)? | ្ NonBA ្ S1)
private func strongEnds(_ r: [Int], _ s: Int, _ add: (Int) -> Void) {
    let n = r.count
    if s >= n { return }
    if isS1(r[s]) {
        for p in optRobat(r, s + 1) {
            add(p)
            if p + 1 < n && r[p] == coeng && isNonBA(r[p + 1]) {
                let q = p + 2
                add(q)
                if q + 1 < n && r[q] == coeng && isNonBA(r[q + 1]) { add(q + 2) }
            }
        }
    }
    if isNonBA(r[s]) {
        for p in optRobat(r, s + 1) {
            if p + 1 < n && r[p] == coeng && isS1(r[p + 1]) {
                let q = p + 2
                add(q)
                if q + 1 < n && r[q] == coeng && isNonBA(r[q + 1]) { add(q + 2) }
            }
            if p + 3 < n && r[p] == coeng && isNonBA(r[p + 1]) && r[p + 2] == coeng && isS1(r[p + 3]) {
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
private func nstrongEnds(_ r: [Int], _ s: Int, _ add: (Int) -> Void) {
    let n = r.count
    if s >= n { return }
    if isS2(r[s]) {
        for p in optRobat(r, s + 1) {
            add(p)
            if p + 1 < n && r[p] == coeng && isS2(r[p + 1]) {
                let q = p + 2
                add(q)
                if q + 1 < n && r[q] == coeng && isS2(r[q + 1]) { add(q + 2) }
            }
        }
    }
    if r[s] == ba {
        for p in optRobat(r, s + 1) {
            add(p)
            for e1 in coengEnds(r, p) {
                add(e1)
                for e2 in coengEnds(r, e1) { add(e2) }
            }
        }
    }
    if isBase(r[s]) {
        for p in optRobat(r, s + 1) {
            if p + 3 < n && r[p] == coeng && isNonRo(r[p + 1]) && r[p + 2] == coeng && r[p + 3] == ba {
                add(p + 4)
            }
            if p + 3 < n && r[p] == coeng && r[p + 1] == ba && r[p + 2] == coeng && isBase(r[p + 3]) {
                add(p + 4)
            }
        }
    }
}

// canEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
private func canEndAt(_ r: [Int], _ target: Int, _ ends: ([Int], Int, (Int) -> Void) -> Void) -> Bool {
    for s in 0..<target {
        var found = false
        ends(r, s) { e in if e == target { found = true } }
        if found { return true }
    }
    return false
}

// vaSamyokAt is the lookahead (?:VA | ័):
// VA = (?:[ិ-ឺើឿ៝] | ាំ)
private func vaSamyokAt(_ r: [Int], _ p: Int) -> Bool {
    let n = r.count
    if p >= n { return false }
    let c = r[p]
    switch c {
    case 0x17D0: return true
    case 0x17B7...0x17BA: return true
    case 0x17BE, 0x17BF, 0x17DD: return true
    case 0x17B6 where p + 1 < n && r[p + 1] == 0x17C6: return true
    default: return false
    }
}

// applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
private func applyShifter(_ r: inout [Int], _ ends: ([Int], Int, (Int) -> Void) -> Void, _ shifter: Int) {
    for k in 0..<r.count {
        if r[k] != 0x17BB { continue }
        let ctx = canEndAt(r, k, ends) || (k >= 1 && isVPre(r[k - 1]) && canEndAt(r, k - 1, ends))
        if ctx && vaSamyokAt(r, k + 1) { r[k] = shifter }
    }
}

// collapseInvis: (‍?្)[្‌‍]+ -> \1
private func collapseInvis(_ r: [Int]) -> [Int] {
    let n = r.count
    func isInvis(_ c: Int) -> Bool { c == coeng || c == zwnj || c == zwj }
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        var g1End = -1
        if r[i] == zwj && i + 1 < n && r[i + 1] == coeng {
            g1End = i + 2
        } else if r[i] == coeng {
            g1End = i + 1
        }
        if g1End >= 0 {
            var k = g1End
            while k < n && isInvis(r[k]) { k += 1 }
            if k > g1End { // [្‌‍]+ matched at least one
                out.append(contentsOf: r[i..<g1End])
                i = k
                continue
            }
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// pairReplace replaces every non-overlapping [a,b] with repl.
private func pairReplace(_ r: [Int], _ a: Int, _ b: Int, _ repl: [Int]) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if i + 1 < n && r[i] == a && r[i + 1] == b {
            out.append(contentsOf: repl)
            i += 2
            continue
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// vowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
private func vowelSplit(_ r: [Int], _ tail: Int, _ head: Int) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if r[i] == 0x17C1 {
            if i + 2 < n && r[i + 1] >= 0x17BB && r[i + 1] <= 0x17BD && r[i + 2] == tail {
                out.append(head)
                out.append(r[i + 1])
                i += 3
                continue
            }
            if i + 1 < n && r[i + 1] == tail {
                out.append(head)
                i += 2
                continue
            }
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// coengRo: (្រ)(្[ក-ឳ]) -> \2\1
private func coengRo(_ r: [Int]) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if i + 3 < n && r[i] == coeng && r[i + 1] == 0x179A
            && r[i + 2] == coeng && r[i + 3] >= 0x1780 && r[i + 3] <= 0x17B3 {
            out.append(r[i + 2])
            out.append(r[i + 3])
            out.append(r[i])
            out.append(r[i + 1])
            i += 4
            continue
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// coengDa: (្)ដ -> \1ត
private func coengDa(_ r: [Int]) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if i + 1 < n && r[i] == coeng && r[i + 1] == 0x178A {
            out.append(coeng)
            out.append(0x178F)
            i += 2
            continue
        }
        out.append(r[i])
        i += 1
    }
    return out
}

private func isDigit(_ r: Int) -> Bool { r >= 0x17E0 && r <= 0x17E9 }

// lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
private func lunar1(_ r: [Int]) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        // greedy ១? first
        if r[i] == 0x17E1 && i + 3 < n && isDigit(r[i + 1]) && r[i + 2] == coeng && r[i + 3] == 0x17D4 {
            let v = 10 + (r[i + 1] - 0x17E0)
            if v > 15 {
                out.append(contentsOf: r[i..<(i + 4)])
            } else {
                out.append(0x19E0 + v)
            }
            i += 4
            continue
        }
        if i + 2 < n && isDigit(r[i]) && r[i + 1] == coeng && r[i + 2] == 0x17D4 {
            out.append(0x19E0 + (r[i] - 0x17E0))
            i += 3
            continue
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
private func lunar2(_ r: [Int]) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if r[i] == 0x17D4 && i + 1 < n && r[i + 1] == coeng {
            if i + 3 < n && r[i + 2] == 0x17E1 && isDigit(r[i + 3]) {
                let v = 10 + (r[i + 3] - 0x17E0)
                if v > 15 {
                    out.append(contentsOf: r[i..<(i + 4)])
                } else {
                    out.append(0x19F0 + v)
                }
                i += 4
                continue
            }
            if i + 2 < n && isDigit(r[i + 2]) {
                out.append(0x19F0 + (r[i + 2] - 0x17E0))
                i += 3
                continue
            }
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// pairReplace3 replaces every non-overlapping [a,b,c] with repl.
private func pairReplace3(_ r: [Int], _ a: Int, _ b: Int, _ c: Int, _ repl: Int) -> [Int] {
    let n = r.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if i + 2 < n && r[i] == a && r[i + 1] == b && r[i + 2] == c {
            out.append(repl)
            i += 3
            continue
        }
        out.append(r[i])
        i += 1
    }
    return out
}

// xhmShift mimics the xhm pre-pass: [ិ-ៅ]្ -> ‍ before the pair.
private func xhmShift(_ scalars: [Int]) -> [Int] {
    let n = scalars.count
    var out: [Int] = []
    out.reserveCapacity(n)
    var i = 0
    while i < n {
        if scalars[i] >= 0x17B7 && scalars[i] <= 0x17C5 && i + 1 < n && scalars[i + 1] == coeng {
            out.append(0x200D)
            out.append(scalars[i])
            out.append(scalars[i + 1])
            i += 2
            continue
        }
        out.append(scalars[i])
        i += 1
    }
    return out
}

private func toString(_ scalars: [Int]) -> String {
    var s = String.UnicodeScalarView()
    s.reserveCapacity(scalars.count)
    for v in scalars { s.append(Unicode.Scalar(UInt32(v))!) }
    return String(s)
}

/// Returns the Khmer-normalized form of `txt`.
public func normalize(_ txt: String, lang: String = "km") -> String {
    var scalars = txt.unicodeScalars.map { Int($0.value) }
    if lang == "xhm" {
        scalars = xhmShift(scalars)
    }

    let n = scalars.count
    var cats = scalars.map { charcat($0) }

    if n > 1 {
        for i in 1..<n {
            let cp = scalars[i - 1]
            if cp == 0x200D || cp == 0x17D2 {
                if cats[i] == .base || cats[i] == .coeng { cats[i] = cats[i - 1] }
            }
        }
    }

    var result: [Int] = []
    result.reserveCapacity(n)
    var i = 0
    while i < n {
        guard cats[i] == .base else {
            result.append(scalars[i]); i += 1; continue
        }
        var j = i + 1
        while j < n && cats[j] > .base { j += 1 }

        var indices = Array(i..<j)
        indices.sort { a, b in cats[a] != cats[b] ? cats[a] < cats[b] : a < b }

        var syl = indices.map { scalars[$0] }

        syl = collapseInvis(syl)
        syl = pairReplace(syl, 0x17BE, 0x17B6, [0x17C4, 0x17B8]) // ើា -> ោី
        syl = vowelSplit(syl, 0x17B8, 0x17BE)                    // េ(◌)ី -> ើ(◌)
        syl = vowelSplit(syl, 0x17B6, 0x17C4)                    // េ(◌)ា -> ោ(◌)
        syl = pairReplace(syl, 0x17BE, 0x17BB, [0x17BB, 0x17BE]) // ើុ -> ុើ
        applyShifter(&syl, strongEnds, 0x17CA)                   // strong  -u -> ៊
        applyShifter(&syl, nstrongEnds, 0x17C9)                  // weak    -u -> ៉
        syl = coengRo(syl)
        syl = coengDa(syl)
        syl = lunar1(syl)
        syl = lunar2(syl)
        syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0)  // ។្។ -> ᧰

        result.append(contentsOf: syl)
        i = j
    }
    return toString(result)
}
