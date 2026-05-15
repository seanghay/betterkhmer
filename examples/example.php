<?php
require_once __DIR__ . '/../php/betterkhmer/vendor/autoload.php';

use BetterKhmer\BetterKhmer;

$text = 'ខ្មែរ';
$result = BetterKhmer::normalize($text);
echo $result . "\n";
