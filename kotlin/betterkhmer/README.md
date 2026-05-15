# betterkhmer · Kotlin

Khmer Unicode normalizer.

## Usage

```kotlin
import com.betterkhmer.BetterKhmer

val result = BetterKhmer.normalize("ខ្មែរ")
```

## Build & Test

```bash
cd kotlin/betterkhmer
kotlinc src/main/kotlin/com/betterkhmer/BetterKhmer.kt \
        src/test/kotlin/com/betterkhmer/BetterKhmerTest.kt \
        -include-runtime -d build/betterkhmer-test.jar
java -Dfile.encoding=UTF-8 -Dfixtures.dir=../../fixtures \
     -jar build/betterkhmer-test.jar com.betterkhmer.BetterKhmerTestKt
```
