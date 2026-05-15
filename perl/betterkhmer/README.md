# betterkhmer — Perl

Khmer Unicode normalizer for Perl.

## Requirements

- Perl 5.20+

## Usage

```perl
use lib 'lib';
use BetterKhmer;

my $result = BetterKhmer::normalize("ខ្មែរ");
print "$result\n";
```

## Test

```sh
perl -Ilib t/fixtures.pl /path/to/fixtures
```
