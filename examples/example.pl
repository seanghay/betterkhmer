#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use lib '../perl/betterkhmer/lib';
use BetterKhmer;

my $text   = "\x{1781}\x{17D2}\x{1798}\x{17C2}\x{179A}"; # ខ្មែរ
my $result = BetterKhmer::normalize($text);
print "$result\n";
