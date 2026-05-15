# betterkhmer · Java

Khmer Unicode normalizer.

## Usage

```java
import com.betterkhmer.Khnormal;

String result = Khnormal.normalize("ខ្មែរ");
```

## Build & Test

```bash
cd java/betterkhmer
javac -encoding UTF-8 -d build/classes src/main/java/com/betterkhmer/*.java \
      src/test/java/com/betterkhmer/*.java
java -Dfile.encoding=UTF-8 -cp build/classes \
     -Dfixtures.dir=../../fixtures com.betterkhmer.KhnormalTest
```
