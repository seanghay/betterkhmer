# betterkhmer · VB.NET

Khmer Unicode normalizer. Regex-free.

## Usage

```vb
Imports BetterKhmer

Dim result As String = Normalize("ខ្មែរ")
```

## Test

```bash
cd vbnet/betterkhmer
dotnet run --project test -- ../../fixtures
```
