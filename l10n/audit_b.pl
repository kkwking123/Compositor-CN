#!/usr/bin/perl
# The other half of the sweep: prose literals that never reach a lookup at all.
#
# audit_ui.pl catches "the key is missing from the table" (Class A) — SwiftUI looks those up by itself, so
# adding a row fixes them. This script catches Class B: a literal that is handed to something taking plain
# `String` (`-> String` helpers, string concatenation, a ternary that settles on String), so it is displayed
# verbatim no matter how complete the table is. Class B stays invisible to a key-set diff, because the key
# may well be in the table already and simply never consulted.
#
# A literal counts as looked up when any of these hold: it is followed by `.localized`; it sits inside
# NSLocalizedString / a LocalizedStringKey argument; or it is inside a call we know takes LocalizedStringKey
# (the same tracked-call state machine audit_ui.pl uses, kept in sync deliberately).
use strict;
use warnings;
use utf8;
use File::Find;
use Encode qw(decode encode);

my ($root, $table) = @ARGV;
$root  //= 'Compositor';
$table //= 'Compositor/zh-Hans.lproj/Localizable.strings';

my @ui_call = qw(
    Text Button Label Toggle Picker Menu Section TextField SecureField Chip
    LayersUnavailableView UnavailableView LabeledContent ConfirmationDialog
    HelpLink Link PopoverToolbarItem
);
my @ui_mod = qw(
    help accessibilityLabel accessibilityHint accessibilityValue navigationTitle
    navigationSubtitle windowTitle popoverPresentation textEditor
);
my @ui_prop = qw(
    title messageText informativeText prompt toolTip placeholderString
    statusString label heading caption summary text
);

my $call_re = '\b(?:' . join('|', @ui_call) . ')\s*\(';
my $mod_re  = '\.(?:'  . join('|', @ui_mod)  . ')\s*\(';
my $prop_re = '\b(?:'  . join('|', @ui_prop) . ')\s*=\s*';

my %have;
{
    open my $fh, '<:encoding(UTF-8)', $table or die "$table: $!";
    while (<$fh>) { $have{$1} = 1 while /^\s*"((?:[^"\\]|\\.)*)"\s*=/g }
    close $fh;
}

# Strings that merely happen to contain a space: identifiers, keys, diagnostics. Not things a user reads.
my @benign = (
    qr/\b(?:NSLog|os\.log|Logger|print|debugPrint|assert|precondition|fatalError|dump)\b/,
    qr/\b(?:UserDefaults|forKey|setValue|object\(forKey|register\(defaults|notificationName|Notification\.Name)/,
    qr/\b(?:UTType|CGDataProvider|CGColorSpace|NSPasteboard|write\(to|contentsOfFile|bundleIdentifier)/,
    qr/^\s*(?:\/\/|\/\*|\*)/,
    qr/\bimport\b/,
    qr/#(?:selector|function|filePath|line|if)/,
);

my %candidate;
my $scanned = 0;

find({ wanted => sub {
    return unless /\.swift\z/ && -f;
    my $path = $File::Find::name;
    return if $path =~ /Localiz|AppLanguage/;
    open my $fh, '<:encoding(UTF-8)', $path or return;
    my @lines = <$fh>;
    close $fh;
    $scanned++;

    my $pending = 0;
    my $in_block = 0;
    for my $number (1 .. @lines) {
        my $line = $lines[$number - 1];
        chomp $line;
        my ($code, @literals) = strip($line, \$in_block);
        next unless @literals;

        my $tracked = $pending > 0;
        my $opens = 0;
        if ($code =~ /$call_re/ || $code =~ /$mod_re/ || $code =~ /$prop_re/
            || $code =~ /"\s*\.localized\b/ || $code =~ /NSLocalizedString\s*\(/) {
            $tracked = 1;
            $opens = 1;
        }

        if (!$tracked) {
            next if grep { $line =~ $_ } @benign;
            for my $lit (@literals) {
                my $clean = unescape($lit);
                # An interpolation makes the value partly dynamic; the static part is checked on its own line.
                next if $clean =~ /\\\(/;
                next if $clean =~ /^\s*$/;
                next unless $clean =~ /[A-Za-z]/;
                next if length($clean) < 4;
                # Only prose: more than one word, or a capitalised term with a space.
                next unless $clean =~ /\s/;
                next if $clean =~ /^[a-z][\w.]*\s/ && $clean !~ /^[\w.]+\s+[\w.]+\s/; # "foo.bar baz" — key paths
                next if $clean =~ /^[a-z]+[A-Z]\w*\z/;
                next if $clean =~ /^[\w.\-]+\s*[:=]\s*[\w.\-]+\z/;
                next if $clean =~ /\A(?:GET|POST|PUT|DELETE|https?|file|public|private|internal|indirect)/;
                # Trailing `.localized` on this line or the next still means a lookup happened.
                my $quoted = quotemeta($clean);
                next if $line =~ /"$quoted"\s*\.localized/;
                if ($line =~ /"$quoted"\s*$/) {
                    my $nxt = $lines[$number] // '';
                    next if $nxt =~ /^\s*\.localized\b/;
                }
                $candidate{$clean} //= [0, "$path:$number"];
                $candidate{$clean}[0]++;
            }
        }

        $pending = 0 unless $tracked;
        if ($tracked && $opens) {
            my $open  = () = $code =~ /\(/g;
            my $close = () = $code =~ /\)/g;
            $pending += $open - $close if $open > $close;
            $pending = 0 if $pending < 0;
        }
    }
}, no_chdir => 1 }, $root);

binmode STDOUT, ':encoding(UTF-8)';
my @rows = sort { $b->[1][0] <=> $a->[1][0] || $a->[0] cmp $b->[0] } map { [ $_, $candidate{$_} ] } keys %candidate;
my $inTable = grep { $have{$_->[0]} } @rows;
print "scanned $scanned files; prose literals never looked up: ", scalar(@rows), " (of which $inTable ARE in the table)\n\n";
for my $r (@rows) {
    my $mark = $have{$r->[0]} ? 'K' : '-';
    printf "%s x%-2d %s\t%s\n", $mark, $r->[1][0], $r->[0], $r->[1][1];
}

sub strip {
    my ($line, $block_ref) = @_;
    my ($code, @lit, $buf);
    my $i = 0; my $n = length $line;
    while ($i < $n) {
        my $c = substr($line, $i, 1);
        if ($$block_ref) {
            if ($c eq '*' && substr($line, $i + 1, 1) eq '/') { $$block_ref = 0; $i += 2; next }
            $i++; next;
        }
        if ($c eq '/' && substr($line, $i + 1, 1) eq '*') { $$block_ref = 1; $i += 2; next }
        if ($c eq '/' && substr($line, $i + 1, 1) eq '/') { last }
        if ($c eq '"') {
            my $j = $i + 1; my $out = '';
            while ($j < $n) {
                my $d = substr($line, $j, 1);
                if ($d eq "\\") { $out .= substr($line, $j, 2) // ''; $j += 2; next }
                last if $d eq '"';
                $out .= $d; $j++;
            }
            push @lit, $out;
            $code .= '"'; $i = $j + 1; next;
        }
        $code .= $c; $i++;
    }
    return ($code // '', @lit);
}

sub unescape {
    my $s = shift;
    $s =~ s/\\(["\\nrt])/$1 eq 'n' ? ' ' : $1/ge;
    return $s;
}
