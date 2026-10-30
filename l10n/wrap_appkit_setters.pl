#!/usr/bin/perl
# DO NOT RUN. Kept only as a record of why this class of change can't be scripted.
#
# The idea was sound: AppKit shows the text it is handed, so an NSAlert, a save panel's title, a cell's tooltip
# and a code-built menu item all miss the automatic lookup SwiftUI does for literals in `Text(…)`, and each needs
# `.localized` added by hand.
#
# Tried over the tree, it produced code that was wrong in ways a compiler may not even catch. A dry run's output:
#
#   joined(separator: "\n".localized)                    a newline separator, looked up as prose
#   ShortcutChord("\r".localized, 1)                    a control character, looked up as prose
#   ?? ".localizedUntitled")                            mangled: the line's real text is interpolated
#   title == "Zoom In".localized                        translated text used as a lookup key — see below
#   "Editable text layer".localized : ".localizedSelect image pixels"
#
# Two separate mistakes, both mine:
#
# 1. The literal matcher excluded `(` to skip interpolated strings, but allowed `\.` — and the interpolation
#    marker *is* a backslash followed by a paren, so every `"…\(value)…"` slipped through and got wrapped where
#    only part of the line matched.
#
# 2. Worse, and not fixable by a better regexp: nothing in the source says whether a string is for a person to
#    read or for the code to compare against. `ShortcutDefinition.title` is matched against literals elsewhere,
#    so localizing where it is built breaks that lookup — the same trap BlendModePicker fell into, where
#    `LayerBlendMode(rawValue: item.title)` stopped resolving once the title was translated. Fixing that needed
#    `representedObject` to carry the value; a script cannot tell the two situations apart.
#
# These are done a file at a time instead, reading each one: see the `title`/`messageText`/`toolTip` assignments
# in Compositor/IO, Compositor/Document and Compositor/UI.
__exit;
