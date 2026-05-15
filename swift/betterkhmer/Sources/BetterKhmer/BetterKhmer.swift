// Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
// Ported to Swift — BetterKhmer package.

import Foundation

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

private let s1    = "[ក-ឃច-ឈដ-ឍត-ធផ-ភឞ-ហអ]"
private let nonBA = "[ក-នផ-អឥ-ឳ]"
private let s2    = "[ងកណនបម-ឝឡឣ-ឳ]"
private let nonRo = "[ក-យល-អឥ-ឳ]"
private let b     = "[ក-អឥ-ឳ◌]"
private let va    = "(?:[ិ-ឺើឿ៝]|ាំ)"

private let strongClean =
    "\(s1)\\u17CC?(?:\\u17D2\(nonBA)(?:\\u17D2\(nonBA))?)?|\(nonBA)\\u17CC?(?:\\u17D2\(s1)(?:\\u17D2\(nonBA))?|\\u17D2\(nonBA)\\u17D2\(s1))"

private let nstrong =
    "(?:\(s2)\\u17CC?(?:\\u17D2\(s2)(?:\\u17D2\(s2))?)?|\\u1794\\u17CC?(?:(?:(?:\\u17D2\(nonRo))?\\u17D2\(b))(?:(?:(?:\\u17D2\(nonRo))?\\u17D2\(b)))?)?|\(b)\\u17CC?(?:\\u17D2\(nonRo)\\u17D2\\u1794|\\u17D2\\u1794(?:\\u17D2\(b))))"

private func makeRE(_ p: String, opts: NSRegularExpression.Options = []) -> NSRegularExpression {
    try! NSRegularExpression(pattern: p, options: opts)
}

// Use capture groups instead of lookaheads (group1 = prefix, group2 = VA/17D0)
private let reInvis   = makeRE("(\\u200D?\\u17D2)[\\u17D2\\u200C\\u200D]+")
private let reVBE     = makeRE("\\u17BE\\u17B6")
private let reV1      = makeRE("\\u17C1([\\u17BB-\\u17BD]?)\\u17B8")
private let reV2      = makeRE("\\u17C1([\\u17BB-\\u17BD]?)\\u17B6")
private let reV3      = makeRE("(\\u17BE)(\\u17BB)")
private let reStrong  = makeRE("((?:\(strongClean))[\\u17C1-\\u17C5]?)\\u17BB(\(va)|\\u17D0)")
private let reNStrong = makeRE("((?:\(nstrong))[\\u17C1-\\u17C5]?)\\u17BB(\(va)|\\u17D0)")
private let reCoengRo = makeRE("(\\u17D2\\u179A)(\\u17D2[\\u1780-\\u17B3])")
private let reCoengDa = makeRE("\\u17D2\\u178A")
private let reLunar1  = makeRE("(\\u17E1?)([\\u17E0-\\u17E9])\\u17D2\\u17D4")
private let reLunar2  = makeRE("\\u17D4\\u17D2(\\u17E1?)([\\u17E0-\\u17E9])")

private func nsRange(of s: String) -> NSRange { NSRange(s.startIndex..., in: s) }

private func sub(_ re: NSRegularExpression, _ s: String, _ tmpl: String) -> String {
    re.stringByReplacingMatches(in: s, range: nsRange(of: s), withTemplate: tmpl)
}

private func subCB(_ re: NSRegularExpression, _ str: String, _ fn: (NSTextCheckingResult) -> String) -> String {
    let nsStr = str as NSString
    var result = str
    var utf16Offset = 0
    for m in re.matches(in: str, range: nsRange(of: str)) {
        let range = NSRange(location: m.range.location + utf16Offset, length: m.range.length)
        guard let swRange = Range(range, in: result) else { continue }
        let replacement = fn(m)
        let oldLen = result[swRange].utf16.count
        result.replaceSubrange(swRange, with: replacement)
        utf16Offset += replacement.utf16.count - oldLen
        _ = nsStr  // keep reference
    }
    return result
}

private func lunarSub(_ re: NSRegularExpression, _ str: String, base: UInt32) -> String {
    let nsStr = str as NSString
    return subCB(re, str) { m in
        let g1 = m.range(at: 1)
        let g2 = m.range(at: 2)
        let d1 = g1.location != NSNotFound ? nsStr.substring(with: g1) : ""
        let d2 = nsStr.substring(with: g2)
        let v1 = d1.isEmpty ? 0 : Int(d1.unicodeScalars.first!.value) - 0x17E0
        let v2 = Int(d2.unicodeScalars.first!.value) - 0x17E0
        let v = v1 * 10 + v2
        if v > 15 { return nsStr.substring(with: m.range) }
        return String(Unicode.Scalar(base + UInt32(v))!)
    }
}

/// Returns the Khmer-normalized form of `txt`.
public func normalize(_ txt: String, lang: String = "km") -> String {
    var txt = txt
    if lang == "xhm" {
        txt = sub(makeRE("[\\u17B7-\\u17C5]\\u17D2"), txt, "\\u200D$0")
    }

    let scalars = Array(txt.unicodeScalars)
    let n = scalars.count
    var cats = scalars.map { charcat(Int($0.value)) }

    for i in 1..<n {
        let cp = Int(scalars[i - 1].value)
        if cp == 0x200D || cp == 0x17D2 {
            if cats[i] == .base || cats[i] == .coeng { cats[i] = cats[i - 1] }
        }
    }

    var result = ""
    var i = 0
    while i < n {
        guard cats[i] == .base else {
            result.unicodeScalars.append(scalars[i]); i += 1; continue
        }
        var j = i + 1
        while j < n && cats[j] > .base { j += 1 }

        var indices = Array(i..<j)
        indices.sort { a, b in cats[a] != cats[b] ? cats[a] < cats[b] : a < b }

        var syl = String(String.UnicodeScalarView(indices.map { scalars[$0] }))

        syl = sub(reInvis,   syl, "$1")
        syl = sub(reVBE,     syl, "\u{17C4}\u{17B8}")
        syl = sub(reV1,      syl, "\u{17BE}$1")
        syl = sub(reV2,      syl, "\u{17C4}$1")
        syl = sub(reV3,      syl, "$2$1")
        syl = sub(reStrong,  syl, "$1\u{17CA}$2")
        syl = sub(reNStrong, syl, "$1\u{17C9}$2")
        syl = sub(reCoengRo, syl, "$2$1")
        syl = sub(reCoengDa, syl, "\u{17D2}\u{178F}")
        syl = lunarSub(reLunar1, syl, base: 0x19E0)
        syl = lunarSub(reLunar2, syl, base: 0x19F0)
        syl = syl.replacingOccurrences(of: "\u{17D4}\u{17D2}\u{17D4}", with: "\u{19F0}")
        result += syl
        i = j
    }
    return result
}
