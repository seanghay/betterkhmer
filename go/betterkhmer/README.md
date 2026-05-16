# betterkhmer · Go

Khmer Unicode normalizer.

Not published to a package registry — copy `go/betterkhmer/betterkhmer.go` into your project.

## Usage

```go
import "github.com/seanghay/betterkhmer"

result := betterkhmer.Normalize("ខ្មែរ")
```

## Test

```bash
cd go/betterkhmer
go test ./...
```
