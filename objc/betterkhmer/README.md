# betterkhmer · Objective-C

Khmer Unicode normalizer. Regex-free. Requires macOS / Foundation.

## Usage

```objc
#import "BetterKhmer.h"

NSString *result = [BetterKhmer normalize:@"ខ្មែរ"];
```

## Build & Test

```bash
cd objc/betterkhmer
make
./build/test_normalize /path/to/fixtures
```
