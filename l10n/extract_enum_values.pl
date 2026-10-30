#!/usr/bin/perl
# Collects the string values of `case x = "Value"` declarations, which are what the interface shows for a
# tool, filter or blend mode. The raw value stays the key saved in the project file; these are the words to
# translate.
use strict;
use warnings;
use File::Find;
use Encode qw(encode decode);

my $root = $ARGV[0] // 'Compositor';
my @files;
find({ wanted => sub { push @files, $File::Find::name if /\.swift\z/ }, no_chdir => 1 }, $root);

my %values;
for my $f (sort @files) {
    open my $fh, '<:raw', $f or next;
    my $body = do { local $/; <$fh> };
    close $fh;
    my $src = decode('UTF-8', $body);

    # Only inside a String-backed enum.
    while ($src =~ /(?:enum|extension)\s+\w+(?:\.[\w.]+)?\s*:\s*[^{]*(?:String|[\w.]*\bString\b)[^{]*\{/g) {
        my $open = pos($src);
        # Slice out the body by brace depth.
        my ($depth, $i, $body_start) = (1, $open, $open);
        my $len = length $src;
        while ($i < $len && $depth > 0) {
            my $c = substr($src, $i, 1);
            $depth++ if $c eq '{';
            $depth-- if $c eq '}';
            $i++;
        }
        my $enum_body = substr($src, $body_start, $i - $body_start - 1);
        # Every string in the body is a case's value, however many cases share a line.
        while ($enum_body =~ /"((?:[^"\\]|\\.)*)"/g) {
            $values{$1} = 1;
        }
    }
}

binmode STDOUT, ':encoding(UTF-8)';
print "$_\n" for sort keys %values;
