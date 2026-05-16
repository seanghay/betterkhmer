Imports System
Imports System.IO
Imports BetterKhmer

Module Program
    Sub Main(args As String())
        Dim fixturesDir As String = If(args.Length > 0, args(0),
            Path.Combine(AppContext.BaseDirectory, "../../../../../fixtures"))

        Dim got As String = Normalize("ខ្មែរ")
        If got <> "ខ្មែរ" Then Throw New Exception("basic FAILED: got " & got)
        Console.WriteLine("basic: ok")

        Dim inputs = File.ReadAllLines(Path.Combine(fixturesDir, "input.txt"))
        Dim expected = File.ReadAllLines(Path.Combine(fixturesDir, "expected.txt"))
        If inputs.Length <> expected.Length Then Throw New Exception("length mismatch")

        Dim failures As Integer = 0
        For i As Integer = 0 To inputs.Length - 1
            Dim result As String = Normalize(inputs(i))
            If result <> expected(i) Then
                failures += 1
                If failures <= 10 Then Console.Error.WriteLine($"[{i}] got {result}, want {expected(i)}")
            End If
        Next
        If failures > 0 Then Throw New Exception($"{failures}/{inputs.Length} fixture failures")
        Console.WriteLine($"fixtures: {inputs.Length} ok")
    End Sub
End Module
