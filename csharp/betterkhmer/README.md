# betterkhmer · C#

Khmer Unicode normalizer.

## Usage

```csharp
using static BetterKhmer.BetterKhmer;

string result = Normalize("ខ្មែរ");
```

## Build & Test

```bash
cd csharp/betterkhmer
dotnet run --project test/BetterKhmerTest.csproj -- /path/to/fixtures
```
