#!/usr/bin/perl
# Every key the code asks the table for, against the keys the table actually has. What's left is either untranslated
# or a key the code builds at run time and can never be found.
use strict;
use warnings;
use File::Find;
use Encode qw(decode encode);

my ($root, $table) = @ARGV;
$root //= 'Compositor';
$table //= 'Compositor/zh-Hans.lproj/Localizable.strings';

my %have;
{
    open my $fh, '<:encoding(UTF-8)', $table or die "$table: $!";
    while (<$fh>) {
        $have{$1} = 1 while /^\s*"((?:[^"\\]|\\.)*)"\s*=/g;
    }
    close $fh;
}

my %wanted;
find({ wanted => sub {
    return unless /\.swift\z/ && -f;
    open my $fh, '<:encoding(UTF-8)', $File::Find::name or return;
    my $src = do { local $/; <$fh> };
    close $fh;
    return if $File::Find::name =~ /Localiz/;

    # "…".localized  and  NSLocalizedString("…", value: …)
    while ($src =~ /"((?:[^"\\]|\\.)*)"\s*\.localized\b/g) { $wanted{$1} //= $File::Find::name }
    # Text("…"), Button("…"), .help("…") and friends: SwiftUI looks these up from the literal itself.
    while ($src =~ /\b(?:Text|Button|Label|Toggle|Picker|Section|TextField|Menu|SecureField|Chip)
                   \(\s*"((?:[^"\\]|\\.)*)"/gx) { $wanted{$1} //= $File::Find::name }
    while ($src =~ /\.(?:help|accessibilityLabel|accessibilityHint|accessibilityValue|navigationTitle|
                         windowTitle|popoverPresentation|textEditor)\s*\(\s*"((?:[^"\\]|\\.)*)"/gx) {
        $wanted{$1} //= $File::Find::name;
    }
}, no_chdir => 1 }, $root);

my @missing = sort grep { !defined $have{$_} } keys %wanted;
binmode STDOUT, ':encoding(UTF-8)';
print "table has ", scalar(keys %have), " keys; code asks for ", scalar(keys %wanted), "\n";
print "missing ", scalar(@missing), ":\n";
print qq{$_\t$wanted{$_}\n} for @missing;
