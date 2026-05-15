# betterkhmer · C#

Khmer Unicode normalizer.

## Usage

```csharp
using BetterKhmer;

string result = Khnormal.Normalize("ខ្មែរ");
```

## Build & Test

```bash
cd csharp/betterkhmer
dotnet run --project test/BetterKhmerTest.csproj -- /path/to/fixtures
```
