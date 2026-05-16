-- Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
-- Ported to betterkhmer Lua module. Regex-free, Lua-pattern-free.

local utf8 = require("utf8")

local M = {}

-- Character categories
local CAT_OTHER    = 0
local CAT_BASE     = 1
local CAT_ROBAT    = 2
local CAT_COENG    = 3
local CAT_SHIFT    = 4
local CAT_Z        = 5
local CAT_VPRE     = 6
local CAT_VB       = 7
local CAT_VA       = 8
local CAT_VPOST    = 9
local CAT_MS       = 10
local CAT_MF       = 11
local CAT_ZFCOENG  = 12

local ZWNJ  = 0x200C
local ZWJ   = 0x200D
local COENG = 0x17D2
local ROBAT = 0x17CC
local BA    = 0x1794

-- categories[i] for codepoint 0x1780 + i, i in [0, 0x17DD-0x1780]
local categories = {}
do
  local size = 0x17DD - 0x1780
  for i = 0, size do
    categories[i] = CAT_OTHER
  end
  for i = 0, 0x17A2 - 0x1780 do
    categories[i] = CAT_BASE
  end
  for i = 0x17A5 - 0x1780, 0x17B3 - 0x1780 do
    categories[i] = CAT_BASE
  end
  categories[0x17B6 - 0x1780] = CAT_VPOST
  for i = 0x17B7 - 0x1780, 0x17BA - 0x1780 do
    categories[i] = CAT_VA
  end
  for i = 0x17BB - 0x1780, 0x17BD - 0x1780 do
    categories[i] = CAT_VB
  end
  for i = 0x17BE - 0x1780, 0x17C5 - 0x1780 do
    categories[i] = CAT_VPRE
  end
  categories[0x17C6 - 0x1780] = CAT_MS
  categories[0x17C7 - 0x1780] = CAT_MF
  categories[0x17C8 - 0x1780] = CAT_MF
  categories[0x17C9 - 0x1780] = CAT_SHIFT
  categories[0x17CA - 0x1780] = CAT_SHIFT
  categories[0x17CB - 0x1780] = CAT_MS
  categories[0x17CC - 0x1780] = CAT_ROBAT
  for i = 0x17CD - 0x1780, 0x17D1 - 0x1780 do
    categories[i] = CAT_MS
  end
  categories[0x17D2 - 0x1780] = CAT_COENG
  categories[0x17D3 - 0x1780] = CAT_MS
  for i = 0x17D4 - 0x1780, 0x17DC - 0x1780 do
    categories[i] = CAT_OTHER
  end
  categories[0x17DD - 0x1780] = CAT_MS
end

local function charcat(r)
  if r >= 0x1780 and r <= 0x17DD then
    return categories[r - 0x1780]
  end
  if r == ZWNJ then
    return CAT_Z
  end
  if r == ZWJ then
    return CAT_ZFCOENG
  end
  return CAT_OTHER
end

-- --- Khmer consonant classes (from the SIL reference khres) ---

-- B: all bases (incl. dotted circle).
local function isBase(r)
  return (r >= 0x1780 and r <= 0x17A2) or (r >= 0x17A5 and r <= 0x17B3) or r == 0x25CC
end

-- NonRo: consonants excluding Ro (U+179A).
local function isNonRo(r)
  return (r >= 0x1780 and r <= 0x1799) or (r >= 0x179B and r <= 0x17A2)
      or (r >= 0x17A5 and r <= 0x17B3)
end

-- NonBA: consonants excluding Ba (U+1794).
local function isNonBA(r)
  return (r >= 0x1780 and r <= 0x1793) or (r >= 0x1795 and r <= 0x17A2)
      or (r >= 0x17A5 and r <= 0x17B3)
end

-- S1: series-1 consonants.
local function isS1(r)
  return (r >= 0x1780 and r <= 0x1783)
      or (r >= 0x1785 and r <= 0x1788)
      or (r >= 0x178A and r <= 0x178D)
      or (r >= 0x178F and r <= 0x1792)
      or (r >= 0x1795 and r <= 0x1797)
      or (r >= 0x179E and r <= 0x17A0)
      or r == 0x17A2
end

-- S2: series-2 consonants.
local function isS2(r)
  return r == 0x1780 or r == 0x1784 or r == 0x178E or r == 0x1793
      or r == 0x1794 or r == 0x17A1
      or (r >= 0x1798 and r <= 0x179D)
      or (r >= 0x17A3 and r <= 0x17B3)
end

local function isVPre(r)
  return r >= 0x17C1 and r <= 0x17C5
end

local function isDigit(r)
  return r >= 0x17E0 and r <= 0x17E9
end

-- optRobat returns the position(s) after an optional Robat at p.
-- Robat is greedy but the regex engine can also skip it, so when present
-- both p (skipped) and p+1 (taken) are reachable.
-- r is a 1-indexed array of codepoints; positions are 0-based offsets.
local function optRobat(r, p)
  if p < #r and r[p + 1] == ROBAT then
    return { p, p + 1 }
  end
  return { p }
end

-- coengEnds enumerates end indices of one COENG: (?:(?:_ NonRo)? _ B)
local function coengEnds(r, s)
  local n = #r
  local res = {}
  if s + 1 < n and r[s + 1] == COENG and isBase(r[s + 2]) then
    res[#res + 1] = s + 2
  end
  if s + 3 < n and r[s + 1] == COENG and isNonRo(r[s + 2])
      and r[s + 3] == COENG and isBase(r[s + 4]) then
    res[#res + 1] = s + 4
  end
  return res
end

-- strongEnds enumerates all end indices of a STRONG match starting at s.
local function strongEnds(r, s, add)
  local n = #r
  if s >= n then
    return
  end
  if isS1(r[s + 1]) then
    for _, p in ipairs(optRobat(r, s + 1)) do
      add(p)
      if p + 1 < n and r[p + 1] == COENG and isNonBA(r[p + 2]) then
        local q = p + 2
        add(q)
        if q + 1 < n and r[q + 1] == COENG and isNonBA(r[q + 2]) then
          add(q + 2)
        end
      end
    end
  end
  if isNonBA(r[s + 1]) then
    for _, p in ipairs(optRobat(r, s + 1)) do
      if p + 1 < n and r[p + 1] == COENG and isS1(r[p + 2]) then
        local q = p + 2
        add(q)
        if q + 1 < n and r[q + 1] == COENG and isNonBA(r[q + 2]) then
          add(q + 2)
        end
      end
      if p + 3 < n and r[p + 1] == COENG and isNonBA(r[p + 2])
          and r[p + 3] == COENG and isS1(r[p + 4]) then
        add(p + 4)
      end
    end
  end
end

-- nstrongEnds enumerates all end indices of an NSTRONG match starting at s.
local function nstrongEnds(r, s, add)
  local n = #r
  if s >= n then
    return
  end
  if isS2(r[s + 1]) then
    for _, p in ipairs(optRobat(r, s + 1)) do
      add(p)
      if p + 1 < n and r[p + 1] == COENG and isS2(r[p + 2]) then
        local q = p + 2
        add(q)
        if q + 1 < n and r[q + 1] == COENG and isS2(r[q + 2]) then
          add(q + 2)
        end
      end
    end
  end
  if r[s + 1] == BA then
    for _, p in ipairs(optRobat(r, s + 1)) do
      add(p)
      for _, e1 in ipairs(coengEnds(r, p)) do
        add(e1)
        for _, e2 in ipairs(coengEnds(r, e1)) do
          add(e2)
        end
      end
    end
  end
  if isBase(r[s + 1]) then
    for _, p in ipairs(optRobat(r, s + 1)) do
      if p + 3 < n and r[p + 1] == COENG and isNonRo(r[p + 2])
          and r[p + 3] == COENG and r[p + 4] == BA then
        add(p + 4)
      end
      if p + 3 < n and r[p + 1] == COENG and r[p + 2] == BA
          and r[p + 3] == COENG and isBase(r[p + 4]) then
        add(p + 4)
      end
    end
  end
end

-- canEndAt reports whether some match (per ends) starting anywhere ends
-- exactly at target.
local function canEndAt(r, target, ends)
  for s = 0, target - 1 do
    local found = false
    ends(r, s, function(e)
      if e == target then
        found = true
      end
    end)
    if found then
      return true
    end
  end
  return false
end

-- vaSamyokAt is the lookahead (?:VA | _):
-- VA = (?:[ិ-ឺើឿ៝] | ាំ)
local function vaSamyokAt(r, p)
  local n = #r
  if p >= n then
    return false
  end
  local c = r[p + 1]
  if c == 0x17D0 then
    return true
  end
  if c >= 0x17B7 and c <= 0x17BA then
    return true
  end
  if c == 0x17BE or c == 0x17BF or c == 0x17DD then
    return true
  end
  if c == 0x17B6 and p + 1 < n and r[p + 2] == 0x17C6 then
    return true
  end
  return false
end

-- applyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
local function applyShifter(r, ends, shifter)
  for k = 0, #r - 1 do
    if r[k + 1] == 0x17BB then
      local ctx = canEndAt(r, k, ends)
          or (k >= 1 and isVPre(r[k]) and canEndAt(r, k - 1, ends))
      if ctx and vaSamyokAt(r, k + 1) then
        r[k + 1] = shifter
      end
    end
  end
end

-- collapseInvis: ((?:ZWJ)?COENG)[COENG ZWNJ ZWJ]+ -> \1
local function collapseInvis(r)
  local n = #r
  local function isInvis(c)
    return c == COENG or c == ZWNJ or c == ZWJ
  end
  local out = {}
  local i = 0
  while i < n do
    local g1End = -1
    if r[i + 1] == ZWJ and i + 1 < n and r[i + 2] == COENG then
      g1End = i + 2
    elseif r[i + 1] == COENG then
      g1End = i + 1
    end
    if g1End >= 0 then
      local k = g1End
      while k < n and isInvis(r[k + 1]) do
        k = k + 1
      end
      if k > g1End then
        for t = i, g1End - 1 do
          out[#out + 1] = r[t + 1]
        end
        i = k
        goto continue
      end
    end
    out[#out + 1] = r[i + 1]
    i = i + 1
    ::continue::
  end
  return out
end

-- pairReplace replaces every non-overlapping [a,b] with repl (a list).
local function pairReplace(r, a, b, repl)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if i + 1 < n and r[i + 1] == a and r[i + 2] == b then
      for _, v in ipairs(repl) do
        out[#out + 1] = v
      end
      i = i + 2
    else
      out[#out + 1] = r[i + 1]
      i = i + 1
    end
  end
  return out
end

-- pairReplace3 replaces every non-overlapping [a,b,c] with repl.
local function pairReplace3(r, a, b, c, repl)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if i + 2 < n and r[i + 1] == a and r[i + 2] == b and r[i + 3] == c then
      out[#out + 1] = repl
      i = i + 3
    else
      out[#out + 1] = r[i + 1]
      i = i + 1
    end
  end
  return out
end

-- vowelSplit: េ([ុ-ួ]?)tail -> head + \1
local function vowelSplit(r, tail, head)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if r[i + 1] == 0x17C1 then
      if i + 2 < n and r[i + 2] >= 0x17BB and r[i + 2] <= 0x17BD
          and r[i + 3] == tail then
        out[#out + 1] = head
        out[#out + 1] = r[i + 2]
        i = i + 3
        goto continue
      end
      if i + 1 < n and r[i + 2] == tail then
        out[#out + 1] = head
        i = i + 2
        goto continue
      end
    end
    out[#out + 1] = r[i + 1]
    i = i + 1
    ::continue::
  end
  return out
end

-- coengRo: (្រ)(្[ក-ឳ]) -> \2\1
local function coengRo(r)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if i + 3 < n and r[i + 1] == COENG and r[i + 2] == 0x179A
        and r[i + 3] == COENG and r[i + 4] >= 0x1780 and r[i + 4] <= 0x17B3 then
      out[#out + 1] = r[i + 3]
      out[#out + 1] = r[i + 4]
      out[#out + 1] = r[i + 1]
      out[#out + 1] = r[i + 2]
      i = i + 4
    else
      out[#out + 1] = r[i + 1]
      i = i + 1
    end
  end
  return out
end

-- coengDa: (្)ដ -> \1ត
local function coengDa(r)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if i + 1 < n and r[i + 1] == COENG and r[i + 2] == 0x178A then
      out[#out + 1] = COENG
      out[#out + 1] = 0x178F
      i = i + 2
    else
      out[#out + 1] = r[i + 1]
      i = i + 1
    end
  end
  return out
end

-- lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
local function lunar1(r)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if r[i + 1] == 0x17E1 and i + 3 < n and isDigit(r[i + 2])
        and r[i + 3] == COENG and r[i + 4] == 0x17D4 then
      local v = 10 + (r[i + 2] - 0x17E0)
      if v > 15 then
        for t = i, i + 3 do
          out[#out + 1] = r[t + 1]
        end
      else
        out[#out + 1] = 0x19E0 + v
      end
      i = i + 4
    elseif i + 2 < n and isDigit(r[i + 1]) and r[i + 2] == COENG
        and r[i + 3] == 0x17D4 then
      out[#out + 1] = 0x19E0 + (r[i + 1] - 0x17E0)
      i = i + 3
    else
      out[#out + 1] = r[i + 1]
      i = i + 1
    end
  end
  return out
end

-- lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
local function lunar2(r)
  local n = #r
  local out = {}
  local i = 0
  while i < n do
    if r[i + 1] == 0x17D4 and i + 1 < n and r[i + 2] == COENG then
      if i + 3 < n and r[i + 3] == 0x17E1 and isDigit(r[i + 4]) then
        local v = 10 + (r[i + 4] - 0x17E0)
        if v > 15 then
          for t = i, i + 3 do
            out[#out + 1] = r[t + 1]
          end
        else
          out[#out + 1] = 0x19F0 + v
        end
        i = i + 4
        goto continue
      end
      if i + 2 < n and isDigit(r[i + 3]) then
        out[#out + 1] = 0x19F0 + (r[i + 3] - 0x17E0)
        i = i + 3
        goto continue
      end
    end
    out[#out + 1] = r[i + 1]
    i = i + 1
    ::continue::
  end
  return out
end

-- hasByteE1 reports whether s contains byte 0xE1, scanned 8 bytes at a time
-- (SWAR-style; on a Lua byte string a plain string.byte scan is sufficient).
-- The whole Khmer block U+1780-U+17FF encodes as UTF-8 lead byte 0xE1, so no
-- 0xE1 means no Khmer codepoint and the input is returned unchanged.
local function hasByteE1(s)
  local len = #s
  local i = 1
  while i + 7 <= len do
    local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(s, i, i + 7)
    if b1 == 0xE1 or b2 == 0xE1 or b3 == 0xE1 or b4 == 0xE1
        or b5 == 0xE1 or b6 == 0xE1 or b7 == 0xE1 or b8 == 0xE1 then
      return true
    end
    i = i + 8
  end
  while i <= len do
    if string.byte(s, i) == 0xE1 then
      return true
    end
    i = i + 1
  end
  return false
end

-- Stable sort of indices by (cats[idx], idx).
local function stableSortIndices(indices, cats)
  table.sort(indices, function(a, b)
    local ca, cb = cats[a], cats[b]
    if ca ~= cb then
      return ca < cb
    end
    return a < b
  end)
end

-- normalize returns the Khmer-normalized form of txt.
-- lang defaults to "km"; "xhm" applies the Middle Khmer final-coeng prefix.
function M.normalize(txt, lang)
  lang = lang or "km"

  -- xhm prefix: a U+17B6..U+17C5 codepoint immediately followed by U+17D2
  -- gets U+200D prepended (matches resources/khnormal.py's [ា-ៅ]្).
  if lang == "xhm" then
    local cps = {}
    for _, c in utf8.codes(txt) do
      cps[#cps + 1] = c
    end
    local out = {}
    local n = #cps
    for i = 1, n do
      local o = cps[i]
      if o >= 0x17B6 and o <= 0x17C5 and i < n and cps[i + 1] == COENG then
        out[#out + 1] = ZWJ
      end
      out[#out + 1] = o
    end
    txt = utf8.char(table.unpack(out))
  end

  -- SWAR skip/scan fast path: no Khmer byte => identity.
  if not hasByteE1(txt) then
    return txt
  end

  local runes = {}
  for _, c in utf8.codes(txt) do
    runes[#runes + 1] = c
  end
  local n = #runes

  local cats = {}
  for i = 1, n do
    cats[i] = charcat(runes[i])
  end

  for i = 2, n do
    if runes[i - 1] == ZWJ or runes[i - 1] == COENG then
      if cats[i] == CAT_BASE or cats[i] == CAT_COENG then
        cats[i] = cats[i - 1]
      end
    end
  end

  local res = {}
  local i = 1
  while i <= n do
    if cats[i] ~= CAT_BASE then
      res[#res + 1] = runes[i]
      i = i + 1
    else
      local j = i + 1
      while j <= n and cats[j] > CAT_BASE do
        j = j + 1
      end

      local indices = {}
      for k = i, j - 1 do
        indices[#indices + 1] = k
      end
      stableSortIndices(indices, cats)

      local syl = {}
      for k = 1, #indices do
        syl[k] = runes[indices[k]]
      end

      syl = collapseInvis(syl)
      syl = pairReplace(syl, 0x17BE, 0x17B6, { 0x17C4, 0x17B8 }) -- ើា -> ោី
      syl = vowelSplit(syl, 0x17B8, 0x17BE)                      -- េ(◌)ី -> ើ(◌)
      syl = vowelSplit(syl, 0x17B6, 0x17C4)                      -- េ(◌)ា -> ោ(◌)
      syl = pairReplace(syl, 0x17BE, 0x17BB, { 0x17BB, 0x17BE }) -- ើុ -> ុើ
      applyShifter(syl, strongEnds, 0x17CA)                      -- strong -u -> ៊
      applyShifter(syl, nstrongEnds, 0x17C9)                     -- weak   -u -> ៉
      syl = coengRo(syl)
      syl = coengDa(syl)
      syl = lunar1(syl)
      syl = lunar2(syl)
      syl = pairReplace3(syl, 0x17D4, 0x17D2, 0x17D4, 0x19F0)    -- ។្។ -> ᧰

      for k = 1, #syl do
        res[#res + 1] = syl[k]
      end
      i = j
    end
  end

  return utf8.char(table.unpack(res))
end

return M
