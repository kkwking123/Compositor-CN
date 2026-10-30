#!/usr/bin/perl
# Localizes interface text that AppKit draws and SwiftUI therefore can't extract: menu items, submenu
# titles, accessibility labels. Only string literals are touched; titles passed as variables are handled
# where they are built.
use strict;
use warnings;
use File::Find;
use Encode qw(encode decode);

my $root = $ARGV[0] // 'Compositor';
my @files;
find({ wanted => sub { push @files, $File::Find::name if /\.swift\z/ }, no_chdir => 1 }, $root);

my $changed = 0;
for my $f (@files) {
    open my $fh, '<:raw', $f or next;
    my $body = do { local $/; <$fh> };
    close $fh;
    my $src = decode('UTF-8', $body);
    my $before = $src;

    $src =~ s/\b(NSMenuItem|NSMenu)\(title: "([^"]*)"/$1(title: "$2".localized/g;
    $src =~ s/\baddItem\(withTitle: "([^"]*)"\)/addItem(withTitle: "$1".localized)/g;
    $src =~ s/\bsetAccessibilityLabel\("([^"]*)"\)/setAccessibilityLabel("$1".localized)/g;
    $src =~ s/\bsetAccessibilityHelp\("([^"]*)"\)/setAccessibilityHelp("$1".localized)/g;

    next if $src eq $before;

    open my $out, '>:raw', $f or die "cannot write $f: $!\n";
    print $out encode('UTF-8', $src);
    close $out;
    $changed++;
    print "updated $f\n";
}
print "files changed: $changed\n";
