# betterkhmer · Kotlin

Khmer Unicode normalizer.

## Usage

```kotlin
import com.betterkhmer.Khnormal

val result = Khnormal.normalize("ខ្មែរ")
```

## Build & Test

```bash
cd kotlin/betterkhmer
kotlinc src/main/kotlin/com/betterkhmer/Khnormal.kt \
        src/test/kotlin/com/betterkhmer/KhnormalTest.kt \
        -include-runtime -d build/betterkhmer-test.jar
java -Dfile.encoding=UTF-8 -Dfixtures.dir=../../fixtures \
     -jar build/betterkhmer-test.jar com.betterkhmer.KhnormalTestKt
```
