#!/usr/bin/perl
# The compiler is the only real check, and it isn't available; this is the next best thing. Swift source is
# balanced — every ( has its ) — so a file whose brackets don't close has been edited into something that won't
# build. Comments and string text are stripped first, as they hold brackets of their own.
#
# It is a heuristic: a string with an interpolation that itself holds a quote is read wrong, exactly as the Swift
# lexer would not be. So this only ever says "look here", never "this is fine".
use strict;
use warnings;
use utf8;

for my $path (@ARGV) {
    open my $fh, '<:encoding(UTF-8)', $path or die "$path: $!";
    my @lines = <$fh>;
    close $fh;

    my $src = join "", @lines;
    $src =~ s{/\*.*?\*/}{}gs;             # block comments
    $src =~ s{//[^\n]*}{}g;               # line comments
    $src =~ s{"((?:[^"\\\n]|\\.)*)"}{}g;  # string literals, one line each

    my %depth = ( '(' => 0, '[' => 0, '{' => 0 );
    my %close = ( ')' => '(', ']' => '[', '}' => '{' );
    for my $c (split //, $src) {
        if (exists $depth{$c}) { $depth{$c}++ }
        elsif (exists $close{$c}) { $depth{$close{$c}}-- }
    }
    my @bad = grep { $depth{$_} != 0 } keys %depth;
    next unless @bad;
    print "$path: ", join(", ", map { "$_ short by $depth{$_}" } @bad), "\n";
}
print "checked ", scalar(@ARGV), " files\n";
