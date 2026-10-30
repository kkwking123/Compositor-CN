#!/usr/bin/perl
# A translation that hands an Int to %@ crashes the app the moment that string appears on screen, and one that
# writes "100%" where the source wrote "100%%" turns the rest of the sentence into a format spec. Both are one
# typo away, and neither shows up until someone opens that panel. This compares the two sides of every entry.
#
# Only keys that actually take arguments are looked at. A string with none in it is handed out of the table as
# written, so a stray percent in it is harmless.
use strict;
use warnings;
use utf8;
use Encode qw(decode encode);

my $path = $ARGV[0] // 'Compositor/zh-Hans.lproj/Localizable.strings';
open my $fh, '<:encoding(UTF-8)', $path or die "$path: $!";
my @rows = <$fh>;
close $fh;

my $conversion = qr/(?:ll|hh|l|h|q|L|j|z|t)?[diuoxXfeEgGcs@]/;

# Reads a format string the way printf does: %% is one literal percent, anything else that matches is an argument.
sub parse {
    my ($text) = @_;
    my (@args, $percent_signs);
    # Flags are kept to the ones this project's strings use. Leaving the space flag out is deliberate: it is what
    # makes "120% of the font size" a percent and the word "of", rather than a `%o` conversion waiting for an argument.
    while ($text =~ /%(?:%|(\d+\$)?[-+0]*(?:\.\d+)?($conversion))?/g) {
        if (defined $2) { push @args, defined $1 ? "%$1$2" : "%$2" }
        else { $percent_signs++ }
    }
    return { arguments => \@args, percents => $percent_signs // 0 };
}

sub describe {
    my ($parsed) = @_;
    my @shown = @{ $parsed->{arguments} };
    push @shown, ('%%') x $parsed->{percents};
    # Numbered arguments are free to arrive in another order, so what matters is which ones, not where.
    @shown = sort @shown if grep { /\d+\$/ } @shown;
    return "@shown";
}

my ($checked, $formatted, @bad);
for my $line (@rows) {
    next unless $line =~ /^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;/;
    my ($key, $value) = ($1, $2);
    $checked++;
    my $from_key = parse($key);
    next unless @{ $from_key->{arguments} };   # Nothing gets substituted in; the text shows as written.
    $formatted++;
    my $from_value = parse($value);
    next if describe($from_key) eq describe($from_value);
    push @bad, sprintf("%s\n    expects %s\n    gives   %s", $key, describe($from_key), describe($from_value));
}

binmode STDOUT, ':encoding(UTF-8)';
print "checked $checked entries, $formatted of which take arguments\n";
if (@bad) {
    print "MISMATCH in ", scalar(@bad), ":\n", join("\n", @bad), "\n";
    exit 1;
}
print "all argument lists agree\n";
