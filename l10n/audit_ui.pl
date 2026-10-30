#!/usr/bin/perl
# Finds English literals that reach a user-visible API but have no entry in the translation table.
#
# Why a state machine instead of the earlier regex sweep: SwiftUI looks up the key from the literal even
# when the literal is not the direct argument — `Text(cond ? "A" : "B")` and a ternary folded over several
# lines both resolve to LocalizedStringKey. A regex anchored on `Text("…"` sees none of that, which is how
# the marquee hints and the empty-layer prompt slipped through. So: once a line opens a tracked call, every
# literal until that call's parens close is treated as user-facing.
use strict;
use warnings;
use utf8;
use File::Find;
use Encode qw(decode encode);

my ($root, $table) = @ARGV;
$root  //= 'Compositor';
$table //= 'Compositor/zh-Hans.lproj/Localizable.strings';

# Calls whose string argument is shown to the user, looked up by SwiftUI or AppKit.
my @ui_call = qw(
    Text Button Label Toggle Picker Menu Section TextField SecureField Chip
    LayersUnavailableView UnavailableView LabeledContent ConfirmationDialog
    HelpLink Link PopoverToolbarItem
);
# Modifiers taking a localized string.
my @ui_mod = qw(
    help accessibilityLabel accessibilityHint accessibilityValue navigationTitle
    navigationSubtitle windowTitle popoverPresentation textEditor
);
# Properties assigned a string that ends up on screen.
my @ui_prop = qw(
    title messageText informativeText prompt toolTip placeholderString
    statusString label heading caption summary text
);
# Tokens that look like UI calls but carry machine strings; naming these keeps the noise down.
my %skip_call = map { $_ => 1 } qw(
    Image systemName Color Font Spacer URL Bundle Notification Timer
    accessibilityIdentifier identifier tag id encoding UTType
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

my %missing;   # literal -> first place seen
my $scanned = 0;

find({ wanted => sub {
    return unless /\.swift\z/ && -f;
    my $path = $File::Find::name;
    return if $path =~ /Localiz|AppLanguage/;
    open my $fh, '<:encoding(UTF-8)', $path or return;
    my @lines = <$fh>;
    close $fh;
    $scanned++;

    my $pending = 0;      # paren depth inside a call we are tracking
    my $in_block = 0;     # inside /* … */
    for my $number (1 .. @lines) {
        my $line = $lines[$number - 1];
        my ($code, @literals) = strip($line, \$in_block);
        next unless @literals;

        my $tracked = $pending > 0;
        my $opens = 0;
        if ($code =~ /$call_re/ || $code =~ /$mod_re/ || $code =~ /$prop_re/
            || $code =~ /"\s*\.localized\b/ || $code =~ /NSLocalizedString\s*\(/) {
            $tracked = 1;
            $opens = 1;
        }
        # A tracked call that spans lines: pick up its arguments' own calls too.
        if ($tracked) {
            for my $lit (@literals) {
                my $clean = unescape($lit);
                # The table is keyed on the format string, so an interpolation has to fold back to %@
                # before the comparison — otherwise every "Add to \(tab.title)" reads as a missing key.
                $clean =~ s/\\\((?:[^()]|\([^()]*\))*\)/%@/g;
                next if $clean =~ /^\s*$/;
                next if $clean =~ /\\\(/;                        # half an interpolation: the whole key was checked already
                next if $clean =~ /^[%\d@.fsl\-–—×° ,:;()\[\]]+$/; # format scraps, no words in them
                next if $clean =~ /^[a-z]+$/;                     # a lone lowercase word: SF Symbol or identifier
                next if $clean =~ /^(?:ms|s|px|dpi|DPI|with:|changes|UpdateFeedURL)$/;
                next if $clean =~ /^[%0-9.\-]+$/;                 # numbers, format-only scraps
                next if length($clean) == 1;                      # single characters
                next if $clean =~ /^[a-z]+[A-Z]\w*$/;             # camelCase identifiers
                next if $clean =~ /^[a-z][\w.]*$/ && $clean =~ /\./;  # "square.dashed" — SF Symbols
                next if $clean =~ /^(?:[A-Za-z]{1,4}|\w+:[^ ]*)$/;  # very short / url-ish
                $missing{$clean} //= "$path:$number";
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

my @gone = grep { !defined $have{$_} } sort keys %missing;
binmode STDOUT, ':encoding(UTF-8)';
print "scanned $scanned files; table has ", scalar(keys %have), " keys\n";
print "UI literals seen: ", scalar(keys %missing), "   not in table: ", scalar(@gone), "\n\n";
print qq{$_\t$missing{$_}\n} for @gone;

# Splits a line into (code-with-literals-blanked, literal contents), respecting comments and escapes.
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
            # Interpolations hide their own literals; the surrounding key still needs a table entry.
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
