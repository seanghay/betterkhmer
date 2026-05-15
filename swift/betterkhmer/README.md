# betterkhmer · Swift

Khmer Unicode normalizer.

## Install

Add to `Package.swift`:

```swift
.package(url: "https://github.com/seanghay/betterkhmer-swift", from: "1.0.0")
```

## Usage

```swift
import BetterKhmer

let result = normalize("ខ្មែរ")
```

## Test

```bash
cd swift/betterkhmer
swift test
```
