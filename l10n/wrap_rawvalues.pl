#!/usr/bin/perl
# Wraps enum rawValues that are shown in the interface with `.localized`, so a translated name is drawn
# while the raw value stays the key the project file and the code use.
# Only call sites whose argument is displayed are touched: Text(…), Label(…), Picker(…), .accessibilityLabel(…).
use strict;
use warnings;
use File::Find;
use Encode qw(encode decode);

my $root = $ARGV[0] // 'Compositor';
my @files;
find({ wanted => sub { push @files, $File::Find::name if /\.swift\z/ }, no_chdir => 1 }, $root);

# A simple identifier, `$0`-style closure argument, or a member chain.
my $expr = qr/(?:\$[0-9]+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)/;

my $changed = 0;
for my $f (@files) {
    open my $fh, '<:raw', $f or next;
    my $body = do { local $/; <$fh> };
    close $fh;
    my $src = decode('UTF-8', $body);
    my $before = $src;

    # Text(x.rawValue) / Label(x.rawValue) / Picker(x.rawValue,
    $src =~ s/\b(Text|Label|Picker)\(($expr)\.rawValue\)/$1($2.rawValue.localized)/g;
    $src =~ s/\b(Text|Label|Picker)\(($expr)\.rawValue(\s*,)/$1($2.rawValue.localized$3)/g;
    # .accessibilityLabel(x.rawValue)
    $src =~ s/\.accessibilityLabel\(($expr)\.rawValue\)/.accessibilityLabel($1.rawValue.localized)/g;

    next if $src eq $before;

    open my $out, '>:raw', $f or die "cannot write $f: $!\n";
    print $out encode('UTF-8', $src);
    close $out;
    $changed++;
    print "updated $f\n";
}
print "files changed: $changed\n";
