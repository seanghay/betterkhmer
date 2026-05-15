# betterkhmer · C

Khmer Unicode normalizer. Requires [PCRE2](https://www.pcre.org/).

## Dependencies

```bash
# macOS
brew install pcre2

# Debian/Ubuntu
apt install libpcre2-dev
```

## Usage

```c
#include "betterkhmer.h"

char *result = normalize("ខ្មែរ", "km");
// ... use result ...
free(result);
```

## Build & Test

```bash
cd c/betterkhmer
cmake -B build
cmake --build build
./build/test_normalize /path/to/fixtures
```
