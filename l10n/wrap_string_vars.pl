#!/usr/bin/perl
# Text/TextField/Button/help take a `LocalizedStringKey` when handed a literal, but a plain `String` when handed a
# variable — and the second form is shown exactly as given. These panel labels, prompts and tooltips all arrive as
# `String` parameters, so each is looked up by hand on the way to the screen.
#
# Only the files listed below are touched, and only for the identifiers named there: `LayersPanel`'s `title` is
# already a LocalizedStringKey, so a blanket rewrite would have broken it.
use strict;
use warnings;
use Encode qw(encode decode);

my %rules = (
    'Compositor/UI/CameraRawColorControls.swift'            => [['Text(', 'title'], ['.help(', 'help']],
    'Compositor/UI/CameraRawControls.swift'                 => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/CameraRawDetailOpticsControls.swift'     => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/CameraRawGeometryCalibrationControls.swift' => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/EffectsSheet.swift'                      => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/FilterSheet.swift'                       => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/HueSaturationSheet.swift'                => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/NewCanvasSheet.swift'                    => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/RawDevelopSheet.swift'                   => [['Text(', 'title'], ['TextField(', 'title'], ['.help(', 'help']],
    'Compositor/UI/LevelsSheet.swift'                       => [['Text(', 'name'], ['TextField(', 'name']],
    'Compositor/UI/ColorPickerSheet.swift'                  => [['Text(', 'label'], ['TextField(', 'label']],
    'Compositor/UI/TransformInspector.swift'                => [['Text(', 'label'], ['TextField(', 'label']],
);

# One-off fixes, written out in full because each depends on its surroundings.
my %exact = (
    'Compositor/UI/LayersPanel.swift' => [
        [ qr/\bButton\(kind\.rawValue\) \{/, 'Button(kind.rawValue.localized) {' ],
    ],
    'Compositor/UI/ProjectTabs.swift' => [
        [ qr/\bText\(label\)\.font/, 'Text(label.localized).font' ],
    ],
    'Compositor/UI/KeyboardShortcuts.swift' => [
        [ qr/\bText\(group\)\.font/,  'Text(group.localized).font' ],
        [ qr/\bText\(definition\.title\)/, 'Text(definition.title.localized)' ],
    ],
    'Compositor/UI/CommandPaletteView.swift' => [
        [ qr/\bText\(entry\.title\)\.lineLimit/, 'Text(entry.title.localized).lineLimit' ],
    ],
    'Compositor/UI/LassoControls.swift' => [
        [ qr/\bText\(\$0\.title\)\.tag/, 'Text($0.title.localized).tag' ],
    ],
    'Compositor/UI/CanvasSizeSheet.swift' => [
        [ qr/\{ Text\(\$0\) \}/, '{ Text($0.localized) }' ],
    ],
    'Compositor/UI/ImageSizeSheet.swift' => [
        [ qr/\{ Text\(\$0\) \}/, '{ Text($0.localized) }' ],
    ],
    'Compositor/UI/CropControls.swift' => [
        [ qr/\{ Text\(\$0\) \}/, '{ Text($0.localized) }' ],
    ],
    'Compositor/UI/LevelsSheet.swift' => [
        [ qr/\bButton\(mode\.rawValue\)/, 'Button(mode.rawValue.localized)' ],
    ],
);

sub wrap {
    my ($src, $call, $var) = @_;
    # `Text(title)` and `TextField(title,` both put the name straight before a comma or a closing paren, so that is
    # what marks the one still to be looked up — an already-localized `title.localized` has a dot there instead.
    $src =~ s{\b\Q$call\E\Q$var\E(?=[,)])}{$call$var.localized}g;
    # Returned as a list so the caller gets the text back; in scalar context s/// hands out a count instead, which
    # would quietly replace the file with the number of edits made.
    return $src;
}

my %changed;
for my $file (sort keys %rules) {
    my $src = read_source($file);
    my $next = $src;
    for my $pair (@{ $rules{$file} }) {
        $next = wrap($next, @$pair);
    }
    apply_exact(\$next, $file);
    $changed{$file} = $next if $next ne $src;
}
for my $file (sort keys %exact) {
    next if $changed{$file};
    my $src = read_source($file);
    my $next = $src;
    apply_exact(\$next, $file);
    $changed{$file} = $next if $next ne $src;
}

sub apply_exact {
    my ($ref, $file) = @_;
    for my $pair (@{ $exact{$file} // [] }) {
        $$ref =~ s/$pair->[0]/$pair->[1]/g;
    }
}

sub read_source {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "$path: $!";
    my $raw = do { local $/; <$fh> };
    close $fh;
    return decode('UTF-8', $raw);
}

for my $file (sort keys %changed) {
    my $length_before = length read_source($file);
    my $length_after = length $changed{$file};
    # Adding `.localized` lengthens text. Anything that comes out shorter has dropped code, so leave the file be.
    if ($length_after < $length_before) {
        warn "$file: would lose ", $length_before - $length_after, " bytes — not written\n";
        next;
    }
    open my $out, '>:raw', $file or die "$file: $!";
    print $out encode('UTF-8', $changed{$file});
    close $out;
    print "$file\n";
}
