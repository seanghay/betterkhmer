import 'dart:io';
import 'package:test/test.dart';
import 'package:betterkhmer/betterkhmer.dart';

List<String> loadLines(String path) =>
    File(path).readAsLinesSync();

void main() {
  final fixturesDir = '${Directory.current.path}/../../fixtures';

  test('basic', () {
    expect(normalize('ខ្មែរ'), equals('ខ្មែរ'));
  });

  test('fixtures', () {
    final inputs   = loadLines('$fixturesDir/input.txt');
    final expected = loadLines('$fixturesDir/expected.txt');
    expect(inputs.length, equals(expected.length));

    var failures = 0;
    for (var i = 0; i < inputs.length; i++) {
      final got = normalize(inputs[i]);
      if (got != expected[i]) {
        failures++;
        if (failures <= 10) {
          print('[$i] got ${got.runes.map((r) => r.toRadixString(16)).join(' ')}, '
                'want ${expected[i].runes.map((r) => r.toRadixString(16)).join(' ')}');
        }
      }
    }
    expect(failures, equals(0), reason: '$failures/${inputs.length} fixture failures');
  });
}
