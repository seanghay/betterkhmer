using System;
using System.IO;
using static BetterKhmer.BetterKhmer;

string fixturesDir = args.Length > 0 ? args[0]
    : Path.Combine(AppContext.BaseDirectory, "../../../../../fixtures");

string got = Normalize("ខ្មែរ");
if (got != "ខ្មែរ") throw new Exception($"basic FAILED: got {got}");
Console.WriteLine("basic: ok");

var inputs   = File.ReadAllLines(Path.Combine(fixturesDir, "input.txt"));
var expected = File.ReadAllLines(Path.Combine(fixturesDir, "expected.txt"));
if (inputs.Length != expected.Length) throw new Exception("length mismatch");

int failures = 0;
for (int i = 0; i < inputs.Length; i++)
{
    string result = Normalize(inputs[i]);
    if (result != expected[i])
    {
        failures++;
        if (failures <= 10) Console.Error.WriteLine($"[{i}] got {result}, want {expected[i]}");
    }
}
if (failures > 0) throw new Exception($"{failures}/{inputs.Length} fixture failures");
Console.WriteLine($"fixtures: {inputs.Length} ok");
