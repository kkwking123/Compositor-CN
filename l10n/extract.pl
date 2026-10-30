#!/usr/bin/perl
# Scans Swift sources for strings SwiftUI localizes automatically (Text/Button/Label/... first argument),
# so the Chinese .strings catalogue can be built without Xcode's string extraction step.
use strict;
use warnings;
use File::Find;
use Encode qw(decode);

my $root = $ARGV[0] // 'Compositor';
die "no such dir: $root\n" unless -d $root;

my @files;
find({ wanted => sub { push @files, $File::Find::name if /\.swift\z/ }, no_chdir => 1 }, $root);
@files = sort @files;

# Calls whose first string argument becomes a LocalizedStringKey.
my $call = qr/(?:Text|Button|Label|Menu|Toggle|Picker|TextField|SecureField|Section|Link|confirmationDialog|alert|\.help|\.accessibilityLabel|\.accessibilityHint|\.navigationTitle|\.navigationSubtitle)\s*\(\s*/;

my (%key_count, %key_files, %key_literal);
my $total = 0;

for my $f (@files) {
    open my $fh, '<:raw', $f or next;
    my $body = do { local $/; <$fh> };
    close $fh;
    my $src = decode('UTF-8', $body);

    my $line_of = 1;
    while ($src =~ /$call"((?:[^"\\]|\\.)*)"/g) {
        my $key = $1;
        my $pos = $-[0];
        my $line = 1 + (() = substr($src, 0, $pos) =~ /\n/g);
        my $file = $f =~ s{^\./}{}r;

        # Not user-facing: SF Symbol names, format-only tokens, identifiers and paths.
        next unless $key =~ /[A-Za-z]/;
        next if $key =~ /^[a-z0-9]+(?:\.[a-z0-9]+)+$/;
        next if $key =~ /^(?:https?:\/\/|file:|com\.)/;
        next if $key =~ /^[a-z]+\.[a-z]+$/;

        $total++;
        $key_count{$key}++;
        $key_literal{$key} = 1;
        push @{ $key_files{$key} }, "$file:$line";
    }
}

binmode STDOUT, ':encoding(UTF-8)';

my @sorted = sort { $key_count{$b} <=> $key_count{$a} || $a cmp $b } keys %key_count;

printf "TOTAL call sites: %d\nUNIQUE keys: %d\n\n", $total, scalar(@sorted);
for my $k (@sorted) {
    (my $shown = $k) =~ s/\n/\\n/g;
    my $interp = $k =~ /\\\(/ ? '  [INTERP]' : '';
    printf "%3d  %s%s\n     -> %s\n", $key_count{$k}, $shown, $interp, join(', ', @{ $key_files{$k} }[0..($#{ $key_files{$k} } > 2 ? 2 : $#{ $key_files{$k} })] );
}

# A plain one-key-per-line list, easy to translate.
if ($ARGV[1]) {
    open my $out, '>:encoding(UTF-8)', $ARGV[1] or die "cannot write $ARGV[1]: $!\n";
    print $out "$_\n" for sort keys %key_count;
    close $out;
}
