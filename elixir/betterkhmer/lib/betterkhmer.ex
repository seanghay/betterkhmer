# Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
# Ported to Elixir — betterkhmer. Regex-free (1:1 with the Go reference).

defmodule BetterKhmer do
  @moduledoc "Khmer Unicode normalizer."

  # Character categories (integers, ordered like the reference).
  @other 0
  @base 1
  @robat 2
  @coeng_cat 3
  @shift 4
  @z 5
  @vpre 6
  @vb 7
  @va 8
  @vpost 9
  @ms 10
  @mf 11
  @zfcoeng 12

  @coeng 0x17D2
  @zwnj 0x200C
  @zwj 0x200D
  @robat_ch 0x17CC
  @ba 0x1794

  @doc """
  Returns the Khmer-normalized form of `txt`.

  `lang` defaults to `"km"` (Modern Khmer); `"xhm"` enables the Middle Khmer
  final-coeng pre-pass.
  """
  def normalize(txt, lang \\ "km") when is_binary(txt) do
    # SWAR-equivalent skip/scan: the whole Khmer block U+1780–U+17FF encodes
    # as UTF-8 lead byte 0xE1, so no 0xE1 means nothing to normalize.
    if :binary.match(txt, <<0xE1>>) == :nomatch do
      txt
    else
      cps = String.to_charlist(txt)
      cps = if lang == "xhm", do: xhm_prefix(cps), else: cps
      rt = List.to_tuple(cps)
      n = tuple_size(rt)
      ct = cps |> build_cats() |> List.to_tuple()

      rt
      |> process(ct, n, 0, [])
      |> Enum.reverse()
      |> List.to_string()
    end
  end

  # --- categorisation ---

  defp charcat(c) do
    cond do
      c >= 0x1780 and c <= 0x17A2 -> @base
      c >= 0x17A5 and c <= 0x17B3 -> @base
      c == 0x17B6 -> @vpost
      c >= 0x17B7 and c <= 0x17BA -> @va
      c >= 0x17BB and c <= 0x17BD -> @vb
      c >= 0x17BE and c <= 0x17C5 -> @vpre
      c == 0x17C6 -> @ms
      c == 0x17C7 or c == 0x17C8 -> @mf
      c == 0x17C9 or c == 0x17CA -> @shift
      c == 0x17CB -> @ms
      c == 0x17CC -> @robat
      c >= 0x17CD and c <= 0x17D1 -> @ms
      c == 0x17D2 -> @coeng_cat
      c == 0x17D3 -> @ms
      c == 0x17DD -> @ms
      c == @zwnj -> @z
      c == @zwj -> @zfcoeng
      true -> @other
    end
  end

  # Single left-to-right pass: a Base/Coeng after ZWJ/Coeng inherits the
  # previous (already-finalised) category.
  defp build_cats(cps) do
    {acc, _} =
      Enum.reduce(cps, {[], :start}, fn r, {acc, prev} ->
        c0 = charcat(r)

        c =
          case prev do
            {pr, pc} when (pr == @zwj or pr == @coeng) and (c0 == @base or c0 == @coeng_cat) ->
              pc

            _ ->
              c0
          end

        {[c | acc], {r, c}}
      end)

    Enum.reverse(acc)
  end

  # --- syllable scanning ---

  defp process(_rt, _ct, n, i, acc) when i >= n, do: acc

  defp process(rt, ct, n, i, acc) do
    if elem(ct, i) != @base do
      process(rt, ct, n, i + 1, [elem(rt, i) | acc])
    else
      j = scan_syllable(ct, n, i + 1)

      syl =
        i..(j - 1)
        |> Enum.sort_by(fn k -> {elem(ct, k), k} end)
        |> Enum.map(fn k -> elem(rt, k) end)
        |> pipeline()

      process(rt, ct, n, j, Enum.reduce(syl, acc, fn x, a -> [x | a] end))
    end
  end

  defp scan_syllable(ct, n, j) when j < n do
    if elem(ct, j) > @base, do: scan_syllable(ct, n, j + 1), else: j
  end

  defp scan_syllable(_ct, _n, j), do: j

  defp pipeline(syl) do
    syl
    |> collapse_invis()
    |> pair_replace(0x17BE, 0x17B6, [0x17C4, 0x17B8])
    |> vowel_split(0x17B8, 0x17BE)
    |> vowel_split(0x17B6, 0x17C4)
    |> pair_replace(0x17BE, 0x17BB, [0x17BB, 0x17BE])
    |> apply_shifter(&strong_ends/3, 0x17CA)
    |> apply_shifter(&nstrong_ends/3, 0x17C9)
    |> coeng_ro()
    |> coeng_da()
    |> lunar1()
    |> lunar2()
    |> pair_replace3(0x17D4, 0x17D2, 0x17D4, 0x19F0)
  end

  # --- consonant classes ---

  defp base?(c), do: (c >= 0x1780 and c <= 0x17A2) or (c >= 0x17A5 and c <= 0x17B3) or c == 0x25CC

  defp non_ro?(c),
    do: (c >= 0x1780 and c <= 0x1799) or (c >= 0x179B and c <= 0x17A2) or (c >= 0x17A5 and c <= 0x17B3)

  defp non_ba?(c),
    do: (c >= 0x1780 and c <= 0x1793) or (c >= 0x1795 and c <= 0x17A2) or (c >= 0x17A5 and c <= 0x17B3)

  defp s1?(c) do
    (c >= 0x1780 and c <= 0x1783) or (c >= 0x1785 and c <= 0x1788) or
      (c >= 0x178A and c <= 0x178D) or (c >= 0x178F and c <= 0x1792) or
      (c >= 0x1795 and c <= 0x1797) or (c >= 0x179E and c <= 0x17A0) or c == 0x17A2
  end

  defp s2?(c) do
    c in [0x1780, 0x1784, 0x178E, 0x1793, 0x1794, 0x17A1] or
      (c >= 0x1798 and c <= 0x179D) or (c >= 0x17A3 and c <= 0x17B3)
  end

  defp v_pre?(c), do: c >= 0x17C1 and c <= 0x17C5

  # --- STRONG / NSTRONG enumerators (return reachable end indices) ---

  defp opt_robat(t, p, n) do
    if p < n and elem(t, p) == @robat_ch, do: [p, p + 1], else: [p]
  end

  defp coeng_ends(t, s, n) do
    a =
      if s + 1 < n and elem(t, s) == @coeng and base?(elem(t, s + 1)), do: [s + 2], else: []

    b =
      if s + 3 < n and elem(t, s) == @coeng and non_ro?(elem(t, s + 1)) and
           elem(t, s + 2) == @coeng and base?(elem(t, s + 3)),
         do: [s + 4],
         else: []

    a ++ b
  end

  defp strong_ends(_t, s, n) when s >= n, do: []

  defp strong_ends(t, s, n) do
    e1 =
      if s1?(elem(t, s)) do
        Enum.flat_map(opt_robat(t, s + 1, n), fn p ->
          rest =
            if p + 1 < n and elem(t, p) == @coeng and non_ba?(elem(t, p + 1)) do
              q = p + 2

              tail =
                if q + 1 < n and elem(t, q) == @coeng and non_ba?(elem(t, q + 1)),
                  do: [q + 2],
                  else: []

              [q | tail]
            else
              []
            end

          [p | rest]
        end)
      else
        []
      end

    e2 =
      if non_ba?(elem(t, s)) do
        Enum.flat_map(opt_robat(t, s + 1, n), fn p ->
          a =
            if p + 1 < n and elem(t, p) == @coeng and s1?(elem(t, p + 1)) do
              q = p + 2

              tail =
                if q + 1 < n and elem(t, q) == @coeng and non_ba?(elem(t, q + 1)),
                  do: [q + 2],
                  else: []

              [q | tail]
            else
              []
            end

          b =
            if p + 3 < n and elem(t, p) == @coeng and non_ba?(elem(t, p + 1)) and
                 elem(t, p + 2) == @coeng and s1?(elem(t, p + 3)),
               do: [p + 4],
               else: []

          a ++ b
        end)
      else
        []
      end

    e1 ++ e2
  end

  defp nstrong_ends(_t, s, n) when s >= n, do: []

  defp nstrong_ends(t, s, n) do
    e1 =
      if s2?(elem(t, s)) do
        Enum.flat_map(opt_robat(t, s + 1, n), fn p ->
          rest =
            if p + 1 < n and elem(t, p) == @coeng and s2?(elem(t, p + 1)) do
              q = p + 2

              tail =
                if q + 1 < n and elem(t, q) == @coeng and s2?(elem(t, q + 1)),
                  do: [q + 2],
                  else: []

              [q | tail]
            else
              []
            end

          [p | rest]
        end)
      else
        []
      end

    e2 =
      if elem(t, s) == @ba do
        Enum.flat_map(opt_robat(t, s + 1, n), fn p ->
          deep =
            Enum.flat_map(coeng_ends(t, p, n), fn e ->
              [e | coeng_ends(t, e, n)]
            end)

          [p | deep]
        end)
      else
        []
      end

    e3 =
      if base?(elem(t, s)) do
        Enum.flat_map(opt_robat(t, s + 1, n), fn p ->
          a =
            if p + 3 < n and elem(t, p) == @coeng and non_ro?(elem(t, p + 1)) and
                 elem(t, p + 2) == @coeng and elem(t, p + 3) == @ba,
               do: [p + 4],
               else: []

          b =
            if p + 3 < n and elem(t, p) == @coeng and elem(t, p + 1) == @ba and
                 elem(t, p + 2) == @coeng and base?(elem(t, p + 3)),
               do: [p + 4],
               else: []

          a ++ b
        end)
      else
        []
      end

    e1 ++ e2 ++ e3
  end

  defp can_end_at(_t, 0, _n, _ends), do: false

  defp can_end_at(t, target, n, ends) do
    Enum.any?(0..(target - 1), fn s -> target in ends.(t, s, n) end)
  end

  # lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
  defp va_samyok_at(t, p, n) do
    cond do
      p >= n -> false
      true -> va_at(elem(t, p), t, p, n)
    end
  end

  defp va_at(c, t, p, n) do
    cond do
      c == 0x17D0 -> true
      c >= 0x17B7 and c <= 0x17BA -> true
      c == 0x17BE or c == 0x17BF or c == 0x17DD -> true
      c == 0x17B6 and p + 1 < n and elem(t, p + 1) == 0x17C6 -> true
      true -> false
    end
  end

  # ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័)  ->  CLASS prefix kept, -u becomes the shifter.
  defp apply_shifter([], _ends, _shifter), do: []

  defp apply_shifter(syl, ends, shifter) do
    t = List.to_tuple(syl)
    n = tuple_size(t)

    Enum.map(0..(n - 1), fn k ->
      c = elem(t, k)

      if c == 0x17BB do
        ctx =
          can_end_at(t, k, n, ends) or
            (k >= 1 and v_pre?(elem(t, k - 1)) and can_end_at(t, k - 1, n, ends))

        if ctx and va_samyok_at(t, k + 1, n), do: shifter, else: c
      else
        c
      end
    end)
  end

  # --- list rewrites (non-overlapping, left to right) ---

  # (‍?្)[្‌‍]+ -> \1
  defp collapse_invis([@zwj, @coeng | rest]) do
    {dropped, tail} = take_invis(rest, 0)

    if dropped > 0,
      do: [@zwj, @coeng | collapse_invis(tail)],
      else: [@zwj | collapse_invis([@coeng | rest])]
  end

  defp collapse_invis([@coeng | rest]) do
    {dropped, tail} = take_invis(rest, 0)

    if dropped > 0,
      do: [@coeng | collapse_invis(tail)],
      else: [@coeng | collapse_invis(rest)]
  end

  defp collapse_invis([c | rest]), do: [c | collapse_invis(rest)]
  defp collapse_invis([]), do: []

  defp take_invis([c | t], n) when c == @coeng or c == @zwnj or c == @zwj,
    do: take_invis(t, n + 1)

  defp take_invis(list, n), do: {n, list}

  defp pair_replace([x, y | t], a, b, repl) when x == a and y == b,
    do: repl ++ pair_replace(t, a, b, repl)

  defp pair_replace([x | t], a, b, repl), do: [x | pair_replace(t, a, b, repl)]
  defp pair_replace([], _, _, _), do: []

  defp pair_replace3([x, y, z | t], a, b, c, repl) when x == a and y == b and z == c,
    do: [repl | pair_replace3(t, a, b, c, repl)]

  defp pair_replace3([x | t], a, b, c, repl), do: [x | pair_replace3(t, a, b, c, repl)]
  defp pair_replace3([], _, _, _, _), do: []

  # េ([ុ-ួ]?)tail -> head\1
  defp vowel_split([0x17C1, m, t | rest], tail, head)
       when m >= 0x17BB and m <= 0x17BD and t == tail,
       do: [head, m | vowel_split(rest, tail, head)]

  defp vowel_split([0x17C1, t | rest], tail, head) when t == tail,
    do: [head | vowel_split(rest, tail, head)]

  defp vowel_split([c | rest], tail, head), do: [c | vowel_split(rest, tail, head)]
  defp vowel_split([], _, _), do: []

  # (្រ)(្[ក-ឳ]) -> \2\1
  defp coeng_ro([@coeng, 0x179A, @coeng, b | rest]) when b >= 0x1780 and b <= 0x17B3,
    do: [@coeng, b, @coeng, 0x179A | coeng_ro(rest)]

  defp coeng_ro([c | rest]), do: [c | coeng_ro(rest)]
  defp coeng_ro([]), do: []

  # (្)ដ -> \1ត
  defp coeng_da([@coeng, 0x178A | rest]), do: [@coeng, 0x178F | coeng_da(rest)]
  defp coeng_da([c | rest]), do: [c | coeng_da(rest)]
  defp coeng_da([]), do: []

  # (១?)([០-៩])្។ -> lunar (base U+19E0)
  defp lunar1([0x17E1, d, @coeng, 0x17D4 | rest]) when d >= 0x17E0 and d <= 0x17E9 do
    v = 10 + (d - 0x17E0)

    if v > 15,
      do: [0x17E1, d, @coeng, 0x17D4 | lunar1(rest)],
      else: [0x19E0 + v | lunar1(rest)]
  end

  defp lunar1([d, @coeng, 0x17D4 | rest]) when d >= 0x17E0 and d <= 0x17E9,
    do: [0x19E0 + (d - 0x17E0) | lunar1(rest)]

  defp lunar1([c | rest]), do: [c | lunar1(rest)]
  defp lunar1([]), do: []

  # ។្(១?)([០-៩]) -> lunar (base U+19F0)
  defp lunar2([0x17D4, @coeng, 0x17E1, d | rest]) when d >= 0x17E0 and d <= 0x17E9 do
    v = 10 + (d - 0x17E0)

    if v > 15,
      do: [0x17D4, @coeng, 0x17E1, d | lunar2(rest)],
      else: [0x19F0 + v | lunar2(rest)]
  end

  defp lunar2([0x17D4, @coeng, d | rest]) when d >= 0x17E0 and d <= 0x17E9,
    do: [0x19F0 + (d - 0x17E0) | lunar2(rest)]

  defp lunar2([c | rest]), do: [c | lunar2(rest)]
  defp lunar2([]), do: []

  # Middle Khmer (xhm): prepend ZWJ before a vowel + coeng.
  defp xhm_prefix([c, @coeng | rest]) when c >= 0x17B6 and c <= 0x17C5,
    do: [@zwj, c, @coeng | xhm_prefix(rest)]

  defp xhm_prefix([c | rest]), do: [c | xhm_prefix(rest)]
  defp xhm_prefix([]), do: []
end
