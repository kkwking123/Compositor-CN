#!/usr/bin/perl
# The table is the one place a phrase is answered in each language, so a key written twice is a mistake and a key
# the code never asks for is dead weight. This reads the table and a list of phrases, one per line, and says which
# of them the table has and which it hasn't — used when adding a batch, so none of them go in twice.
use strict;
use warnings;
use utf8;

my $table = 'Compositor/zh-Hans.lproj/Localizable.strings';
open my $fh, '<:encoding(UTF-8)', $table or die "$table: $!";
my %have;
while (<$fh>) { $have{$1} = 1 if /^\s*"((?:[^"\\]|\\.)*)"\s*=/ }
close $fh;

open my $list, '<:encoding(UTF-8)', $ARGV[0] or die "$ARGV[0]: $!";
my ($missing, $present) = (0, 0);
binmode STDOUT, ':encoding(UTF-8)';
while (my $phrase = <$list>) {
    chomp $phrase;
    next unless length $phrase;
    if ($have{$phrase}) { $present++; next }
    $missing++;
    print "$phrase\n";
}
warn "# $present already in the table, $missing to add\n";
