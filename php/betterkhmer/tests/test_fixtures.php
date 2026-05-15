<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/BetterKhmer.php';

use BetterKhmer\Khnormal;

$root = __DIR__ . '/../../..';

function loadLines(string $path): array {
    return array_filter(
        explode("\n", file_get_contents($path)),
        fn($l) => true  // keep empty too so indices align
    );
}

// Basic test
$got = Khnormal::normalize('ខ្មែរ');
if ($got !== 'ខ្មែរ') {
    fwrite(STDERR, "basic FAILED: got " . json_encode($got) . "\n");
    exit(1);
}
echo "basic: ok\n";

$inputs   = loadLines($root . '/fixtures/input.txt');
$expected = loadLines($root . '/fixtures/expected.txt');

// Remove trailing empty element from split
if (end($inputs) === '') array_pop($inputs);
if (end($expected) === '') array_pop($expected);

$inputs   = array_values($inputs);
$expected = array_values($expected);

if (count($inputs) !== count($expected)) {
    fwrite(STDERR, "length mismatch\n");
    exit(1);
}

$failures = 0;
foreach ($inputs as $i => $inp) {
    $result = Khnormal::normalize($inp);
    if ($result !== $expected[$i]) {
        $failures++;
        if ($failures <= 10) {
            fwrite(STDERR, "[$i] got " . json_encode($result) . ", want " . json_encode($expected[$i]) . "\n");
        }
    }
}

if ($failures > 0) {
    fwrite(STDERR, "$failures/" . count($inputs) . " fixture failures\n");
    exit(1);
}
echo "fixtures: " . count($inputs) . " ok\n";
