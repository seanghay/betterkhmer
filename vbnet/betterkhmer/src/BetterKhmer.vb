' Copyright (c) 2021-2024, SIL Global. Licensed under MIT license.
' Ported to VB.NET — BetterKhmer package. Regex-free (1:1 with the C#/Go reference).

Imports System
Imports System.Collections.Generic
Imports System.Linq
Imports System.Text

Public Module BetterKhmer

    Private Const CatOther As Integer = 0
    Private Const CatBase As Integer = 1
    Private Const CatRobat As Integer = 2
    Private Const CatCoeng As Integer = 3
    Private Const CatShift As Integer = 4
    Private Const CatZ As Integer = 5
    Private Const CatVPre As Integer = 6
    Private Const CatVB As Integer = 7
    Private Const CatVA As Integer = 8
    Private Const CatVPost As Integer = 9
    Private Const CatMS As Integer = 10
    Private Const CatMF As Integer = 11
    Private Const CatZFCoeng As Integer = 12

    Private Const Zwnj As Integer = &H200C
    Private Const Zwj As Integer = &H200D
    Private Const Coeng As Integer = &H17D2
    Private Const Robat As Integer = &H17CC
    Private Const Ba As Integer = &H1794

    Private ReadOnly Categories As Integer() = BuildCategories()

    Private Function BuildCategories() As Integer()
        Dim c(&H17DE - &H1780 - 1) As Integer
        For i As Integer = 0 To c.Length - 1
            c(i) = CatOther
        Next
        For i As Integer = 0 To &H17A2 - &H1780
            c(i) = CatBase
        Next
        For i As Integer = &H17A5 - &H1780 To &H17B3 - &H1780
            c(i) = CatBase
        Next
        c(&H17B6 - &H1780) = CatVPost
        For i As Integer = &H17B7 - &H1780 To &H17BA - &H1780
            c(i) = CatVA
        Next
        For i As Integer = &H17BB - &H1780 To &H17BD - &H1780
            c(i) = CatVB
        Next
        For i As Integer = &H17BE - &H1780 To &H17C5 - &H1780
            c(i) = CatVPre
        Next
        c(&H17C6 - &H1780) = CatMS
        c(&H17C7 - &H1780) = CatMF
        c(&H17C8 - &H1780) = CatMF
        c(&H17C9 - &H1780) = CatShift
        c(&H17CA - &H1780) = CatShift
        c(&H17CB - &H1780) = CatMS
        c(&H17CC - &H1780) = CatRobat
        For i As Integer = &H17CD - &H1780 To &H17D1 - &H1780
            c(i) = CatMS
        Next
        c(&H17D2 - &H1780) = CatCoeng
        c(&H17D3 - &H1780) = CatMS
        For i As Integer = &H17D4 - &H1780 To &H17DC - &H1780
            c(i) = CatOther
        Next
        c(&H17DD - &H1780) = CatMS
        Return c
    End Function

    Private Function Charcat(cp As Integer) As Integer
        If cp >= &H1780 AndAlso cp <= &H17DD Then Return Categories(cp - &H1780)
        If cp = &H200C Then Return CatZ
        If cp = &H200D Then Return CatZFCoeng
        Return CatOther
    End Function

    ' --- Khmer consonant classes (from the SIL reference khres) ---

    Private Function IsBase(r As Integer) As Boolean
        Return (r >= &H1780 AndAlso r <= &H17A2) OrElse (r >= &H17A5 AndAlso r <= &H17B3) OrElse r = &H25CC
    End Function

    Private Function IsNonRo(r As Integer) As Boolean
        Return (r >= &H1780 AndAlso r <= &H1799) OrElse (r >= &H179B AndAlso r <= &H17A2) OrElse (r >= &H17A5 AndAlso r <= &H17B3)
    End Function

    Private Function IsNonBA(r As Integer) As Boolean
        Return (r >= &H1780 AndAlso r <= &H1793) OrElse (r >= &H1795 AndAlso r <= &H17A2) OrElse (r >= &H17A5 AndAlso r <= &H17B3)
    End Function

    Private Function IsS1(r As Integer) As Boolean
        If r >= &H1780 AndAlso r <= &H1783 Then Return True
        If r >= &H1785 AndAlso r <= &H1788 Then Return True
        If r >= &H178A AndAlso r <= &H178D Then Return True
        If r >= &H178F AndAlso r <= &H1792 Then Return True
        If r >= &H1795 AndAlso r <= &H1797 Then Return True
        If r >= &H179E AndAlso r <= &H17A0 Then Return True
        Return r = &H17A2
    End Function

    Private Function IsS2(r As Integer) As Boolean
        If r = &H1780 OrElse r = &H1784 OrElse r = &H178E OrElse r = &H1793 OrElse r = &H1794 OrElse r = &H17A1 Then Return True
        If r >= &H1798 AndAlso r <= &H179D Then Return True
        Return r >= &H17A3 AndAlso r <= &H17B3
    End Function

    Private Function IsVPre(r As Integer) As Boolean
        Return r >= &H17C1 AndAlso r <= &H17C5
    End Function

    Private Delegate Sub Ends(r As Integer(), s As Integer, add As Action(Of Integer))

    Private Function OptRobat(r As Integer(), p As Integer) As Integer()
        If p < r.Length AndAlso r(p) = Robat Then Return New Integer() {p, p + 1}
        Return New Integer() {p}
    End Function

    ' CoengEnds enumerates end indices of one COENG: (?:(?:្ NonRo)? ្ B)
    Private Sub CoengEnds(r As Integer(), s As Integer, add As Action(Of Integer))
        Dim n As Integer = r.Length
        If s + 1 < n AndAlso r(s) = Coeng AndAlso IsBase(r(s + 1)) Then add(s + 2)
        If s + 3 < n AndAlso r(s) = Coeng AndAlso IsNonRo(r(s + 1)) AndAlso r(s + 2) = Coeng AndAlso IsBase(r(s + 3)) Then add(s + 4)
    End Sub

    ' StrongEnds enumerates all end indices of a STRONG match starting at s.
    Private Sub StrongEnds(r As Integer(), s As Integer, add As Action(Of Integer))
        Dim n As Integer = r.Length
        If s >= n Then Return
        If IsS1(r(s)) Then
            For Each p As Integer In OptRobat(r, s + 1)
                add(p)
                If p + 1 < n AndAlso r(p) = Coeng AndAlso IsNonBA(r(p + 1)) Then
                    Dim q As Integer = p + 2
                    add(q)
                    If q + 1 < n AndAlso r(q) = Coeng AndAlso IsNonBA(r(q + 1)) Then add(q + 2)
                End If
            Next
        End If
        If IsNonBA(r(s)) Then
            For Each p As Integer In OptRobat(r, s + 1)
                If p + 1 < n AndAlso r(p) = Coeng AndAlso IsS1(r(p + 1)) Then
                    Dim q As Integer = p + 2
                    add(q)
                    If q + 1 < n AndAlso r(q) = Coeng AndAlso IsNonBA(r(q + 1)) Then add(q + 2)
                End If
                If p + 3 < n AndAlso r(p) = Coeng AndAlso IsNonBA(r(p + 1)) AndAlso r(p + 2) = Coeng AndAlso IsS1(r(p + 3)) Then add(p + 4)
            Next
        End If
    End Sub

    ' NstrongEnds enumerates all end indices of an NSTRONG match starting at s.
    Private Sub NstrongEnds(r As Integer(), s As Integer, add As Action(Of Integer))
        Dim n As Integer = r.Length
        If s >= n Then Return
        If IsS2(r(s)) Then
            For Each p As Integer In OptRobat(r, s + 1)
                add(p)
                If p + 1 < n AndAlso r(p) = Coeng AndAlso IsS2(r(p + 1)) Then
                    Dim q As Integer = p + 2
                    add(q)
                    If q + 1 < n AndAlso r(q) = Coeng AndAlso IsS2(r(q + 1)) Then add(q + 2)
                End If
            Next
        End If
        If r(s) = Ba Then
            For Each p As Integer In OptRobat(r, s + 1)
                add(p)
                CoengEnds(r, p, Sub(e1)
                                    add(e1)
                                    CoengEnds(r, e1, add)
                                End Sub)
            Next
        End If
        If IsBase(r(s)) Then
            For Each p As Integer In OptRobat(r, s + 1)
                If p + 3 < n AndAlso r(p) = Coeng AndAlso IsNonRo(r(p + 1)) AndAlso r(p + 2) = Coeng AndAlso r(p + 3) = Ba Then add(p + 4)
                If p + 3 < n AndAlso r(p) = Coeng AndAlso r(p + 1) = Ba AndAlso r(p + 2) = Coeng AndAlso IsBase(r(p + 3)) Then add(p + 4)
            Next
        End If
    End Sub

    ' CanEndAt reports whether some match (per ends) starting anywhere ends exactly at target.
    Private Function CanEndAt(r As Integer(), target As Integer, e As Ends) As Boolean
        For s As Integer = 0 To target - 1
            Dim found As Boolean = False
            e(r, s, Sub(x) If x = target Then found = True)
            If found Then Return True
        Next
        Return False
    End Function

    ' VaSamyokAt is the lookahead (?:VA | ័): VA = (?:[ិ-ឺើឿ៝] | ាំ)
    Private Function VaSamyokAt(r As Integer(), p As Integer) As Boolean
        Dim n As Integer = r.Length
        If p >= n Then Return False
        Dim c As Integer = r(p)
        If c = &H17D0 Then Return True
        If c >= &H17B7 AndAlso c <= &H17BA Then Return True
        If c = &H17BE OrElse c = &H17BF OrElse c = &H17DD Then Return True
        Return c = &H17B6 AndAlso p + 1 < n AndAlso r(p + 1) = &H17C6
    End Function

    ' ApplyShifter replaces ((?:CLASS)[េ-ៅ]?)ុ(?=VA|័) with the shifter.
    Private Sub ApplyShifter(r As Integer(), e As Ends, shifter As Integer)
        For k As Integer = 0 To r.Length - 1
            If r(k) <> &H17BB Then Continue For
            Dim ctx As Boolean = CanEndAt(r, k, e) OrElse (k >= 1 AndAlso IsVPre(r(k - 1)) AndAlso CanEndAt(r, k - 1, e))
            If ctx AndAlso VaSamyokAt(r, k + 1) Then r(k) = shifter
        Next
    End Sub

    Private Function IsInvis(c As Integer) As Boolean
        Return c = Coeng OrElse c = Zwnj OrElse c = Zwj
    End Function

    ' CollapseInvis: (‍?្)[្‌‍]+ -> \1
    Private Function CollapseInvis(r As Integer()) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            Dim g1End As Integer = -1
            If r(i) = Zwj AndAlso i + 1 < n AndAlso r(i + 1) = Coeng Then
                g1End = i + 2
            ElseIf r(i) = Coeng Then
                g1End = i + 1
            End If
            If g1End >= 0 Then
                Dim k As Integer = g1End
                While k < n AndAlso IsInvis(r(k))
                    k += 1
                End While
                If k > g1End Then
                    For t As Integer = i To g1End - 1
                        outp.Add(r(t))
                    Next
                    i = k
                    Continue While
                End If
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' PairReplace replaces every non-overlapping [a,b] with [r0,r1].
    Private Function PairReplace(r As Integer(), a As Integer, b As Integer, r0 As Integer, r1 As Integer) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If i + 1 < n AndAlso r(i) = a AndAlso r(i + 1) = b Then
                outp.Add(r0)
                outp.Add(r1)
                i += 2
                Continue While
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' PairReplace3 replaces every non-overlapping [a,b,c] with repl.
    Private Function PairReplace3(r As Integer(), a As Integer, b As Integer, c As Integer, repl As Integer) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If i + 2 < n AndAlso r(i) = a AndAlso r(i + 1) = b AndAlso r(i + 2) = c Then
                outp.Add(repl)
                i += 3
                Continue While
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' VowelSplit: េ([ុ-ួ]?)tail -> head + \1   (reV1/reV2)
    Private Function VowelSplit(r As Integer(), tail As Integer, head As Integer) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If r(i) = &H17C1 Then
                If i + 2 < n AndAlso r(i + 1) >= &H17BB AndAlso r(i + 1) <= &H17BD AndAlso r(i + 2) = tail Then
                    outp.Add(head)
                    outp.Add(r(i + 1))
                    i += 3
                    Continue While
                End If
                If i + 1 < n AndAlso r(i + 1) = tail Then
                    outp.Add(head)
                    i += 2
                    Continue While
                End If
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' CoengRo: (្រ)(្[ក-ឳ]) -> \2\1
    Private Function CoengRo(r As Integer()) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If i + 3 < n AndAlso r(i) = Coeng AndAlso r(i + 1) = &H179A AndAlso r(i + 2) = Coeng AndAlso r(i + 3) >= &H1780 AndAlso r(i + 3) <= &H17B3 Then
                outp.Add(r(i + 2))
                outp.Add(r(i + 3))
                outp.Add(r(i))
                outp.Add(r(i + 1))
                i += 4
                Continue While
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' CoengDa: (្)ដ -> \1ត
    Private Function CoengDa(r As Integer()) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If i + 1 < n AndAlso r(i) = Coeng AndAlso r(i + 1) = &H178A Then
                outp.Add(Coeng)
                outp.Add(&H178F)
                i += 2
                Continue While
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    Private Function IsDigit(r As Integer) As Boolean
        Return r >= &H17E0 AndAlso r <= &H17E9
    End Function

    ' Lunar1: (១?)([០-៩])្។ -> lunar symbol (base U+19E0)
    Private Function Lunar1(r As Integer()) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If r(i) = &H17E1 AndAlso i + 3 < n AndAlso IsDigit(r(i + 1)) AndAlso r(i + 2) = Coeng AndAlso r(i + 3) = &H17D4 Then
                Dim v As Integer = 10 + (r(i + 1) - &H17E0)
                If v > 15 Then
                    For t As Integer = i To i + 3
                        outp.Add(r(t))
                    Next
                Else
                    outp.Add(&H19E0 + v)
                End If
                i += 4
                Continue While
            End If
            If i + 2 < n AndAlso IsDigit(r(i)) AndAlso r(i + 1) = Coeng AndAlso r(i + 2) = &H17D4 Then
                outp.Add(&H19E0 + (r(i) - &H17E0))
                i += 3
                Continue While
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' Lunar2: ។្(១?)([០-៩]) -> lunar symbol (base U+19F0)
    Private Function Lunar2(r As Integer()) As Integer()
        Dim n As Integer = r.Length
        Dim outp As New List(Of Integer)(n)
        Dim i As Integer = 0
        While i < n
            If r(i) = &H17D4 AndAlso i + 1 < n AndAlso r(i + 1) = Coeng Then
                If i + 3 < n AndAlso r(i + 2) = &H17E1 AndAlso IsDigit(r(i + 3)) Then
                    Dim v As Integer = 10 + (r(i + 3) - &H17E0)
                    If v > 15 Then
                        For t As Integer = i To i + 3
                            outp.Add(r(t))
                        Next
                    Else
                        outp.Add(&H19F0 + v)
                    End If
                    i += 4
                    Continue While
                End If
                If i + 2 < n AndAlso IsDigit(r(i + 2)) Then
                    outp.Add(&H19F0 + (r(i + 2) - &H17E0))
                    i += 3
                    Continue While
                End If
            End If
            outp.Add(r(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ' HasByteE1 reports whether s contains UTF-8 byte 0xE1, scanned 8 bytes at a
    ' time (SWAR). The whole Khmer block U+1780–U+17FF encodes as UTF-8 lead byte
    ' 0xE1, so no 0xE1 means no Khmer codepoint and the input is unchanged.
    Private Function HasByteE1(s As Byte()) As Boolean
        Const lo As ULong = &H101010101010101UL
        Const hi As ULong = &H8080808080808080UL
        Const mask As ULong = &HE1E1E1E1E1E1E1E1UL
        Dim i As Integer = 0
        Do While i + 8 <= s.Length
            Dim w As ULong = CULng(s(i)) Or (CULng(s(i + 1)) << 8) Or (CULng(s(i + 2)) << 16) Or (CULng(s(i + 3)) << 24) _
                Or (CULng(s(i + 4)) << 32) Or (CULng(s(i + 5)) << 40) Or (CULng(s(i + 6)) << 48) Or (CULng(s(i + 7)) << 56)
            Dim x As ULong = w Xor mask
            If ((x - lo) And (Not x) And hi) <> 0UL Then Return True
            i += 8
        Loop
        Do While i < s.Length
            If s(i) = &HE1 Then Return True
            i += 1
        Loop
        Return False
    End Function

    ' CodePoints decodes txt into an array of Unicode code points.
    Private Function CodePoints(txt As String) As Integer()
        Dim cps As New List(Of Integer)(txt.Length)
        Dim ci As Integer = 0
        While ci < txt.Length
            Dim cp As Integer = Char.ConvertToUtf32(txt, ci)
            cps.Add(cp)
            ci += If(cp > &HFFFF, 2, 1)
        End While
        Return cps.ToArray()
    End Function

    ' XhmPrefix replaces [ិ-ៅ]្ with ‍$0 (prepend U+200D before the pair).
    Private Function XhmPrefix(cps As Integer()) As Integer()
        Dim n As Integer = cps.Length
        Dim outp As New List(Of Integer)(n + 8)
        Dim i As Integer = 0
        While i < n
            If i + 1 < n AndAlso cps(i) >= &H17B7 AndAlso cps(i) <= &H17C5 AndAlso cps(i + 1) = Coeng Then
                outp.Add(Zwj)
                outp.Add(cps(i))
                outp.Add(cps(i + 1))
                i += 2
                Continue While
            End If
            outp.Add(cps(i))
            i += 1
        End While
        Return outp.ToArray()
    End Function

    ''' <summary>Returns the Khmer-normalized form of txt.</summary>
    Public Function Normalize(txt As String, Optional lang As String = "km") As String
        ' SWAR skip/scan fast path: no Khmer byte => identity.
        If lang <> "xhm" AndAlso Not HasByteE1(Encoding.UTF8.GetBytes(txt)) Then Return txt

        Dim cps As Integer() = CodePoints(txt)
        If lang = "xhm" Then cps = XhmPrefix(cps)
        Dim n As Integer = cps.Length
        Dim cats(n - 1) As Integer
        For i As Integer = 0 To n - 1
            cats(i) = Charcat(cps(i))
        Next

        For i As Integer = 1 To n - 1
            If cps(i - 1) = Zwj OrElse cps(i - 1) = Coeng Then
                If cats(i) = CatBase OrElse cats(i) = CatCoeng Then cats(i) = cats(i - 1)
            End If
        Next

        Dim res As New StringBuilder(txt.Length)
        Dim idx As Integer = 0
        While idx < n
            If cats(idx) <> CatBase Then
                res.Append(Char.ConvertFromUtf32(cps(idx)))
                idx += 1
                Continue While
            End If
            Dim j As Integer = idx + 1
            While j < n AndAlso cats(j) > CatBase
                j += 1
            End While

            Dim indices = Enumerable.Range(idx, j - idx).OrderBy(Function(k) cats(k)).ThenBy(Function(k) k).ToArray()

            Dim syl(indices.Length - 1) As Integer
            For k As Integer = 0 To indices.Length - 1
                syl(k) = cps(indices(k))
            Next

            syl = CollapseInvis(syl)
            syl = PairReplace(syl, &H17BE, &H17B6, &H17C4, &H17B8)  ' ើា -> ោី
            syl = VowelSplit(syl, &H17B8, &H17BE)                   ' េ(◌)ី -> ើ(◌)
            syl = VowelSplit(syl, &H17B6, &H17C4)                   ' េ(◌)ា -> ោ(◌)
            syl = PairReplace(syl, &H17BE, &H17BB, &H17BB, &H17BE)  ' ើុ -> ុើ
            ApplyShifter(syl, AddressOf StrongEnds, &H17CA)         ' strong  -u -> ៊
            ApplyShifter(syl, AddressOf NstrongEnds, &H17C9)        ' weak    -u -> ៉
            syl = CoengRo(syl)
            syl = CoengDa(syl)
            syl = Lunar1(syl)
            syl = Lunar2(syl)
            syl = PairReplace3(syl, &H17D4, &H17D2, &H17D4, &H19F0) ' ។្។ -> ᧰

            For Each rr As Integer In syl
                res.Append(Char.ConvertFromUtf32(rr))
            Next
            idx = j
        End While
        Return res.ToString()
    End Function

End Module
