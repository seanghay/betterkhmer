#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use lib '../lib';
use BetterKhmer;
use Encode qw(encode decode);

my $fixtures = $ARGV[0] // '../../../fixtures';

# basic test
my $khmer = "\x{1781}\x{17D2}\x{1798}\x{17C2}\x{179A}";
my $got = BetterKhmer::normalize($khmer);
die "basic FAILED: got $got\n" if $got ne $khmer;
print "basic: ok\n";

# fixture tests
open my $fi, '<:encoding(UTF-8)', "$fixtures/input.txt"    or die "Cannot open input: $!";
open my $fe, '<:encoding(UTF-8)', "$fixtures/expected.txt" or die "Cannot open expected: $!";

my $total = 0;
my $failures = 0;

while (defined(my $in = <$fi>) and defined(my $ex = <$fe>)) {
    chomp $in; chomp $ex;
    my $result = BetterKhmer::normalize($in);
    if ($result ne $ex) {
        $failures++;
        if ($failures <= 10) {
            print STDERR "[$total] mismatch\n";
        }
    }
    $total++;
}
close $fi; close $fe;

if ($failures > 0) {
    die "$failures/$total fixture failures\n";
}
print "fixtures: $total ok\n";
