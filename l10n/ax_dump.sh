#!/bin/bash
# Dumps every string an AX client can read out of Compositor's windows, without touching the screen.
# The app runs hidden (open -g -j) so nothing is drawn and no focus is taken; AX still sees the tree.
# Used to catch translations that a static key diff cannot: a key can be in the table and still reach
# the screen as a plain String, which no lookup ever consults.
# System Events is the AX bridge; it quits when idle, and a query against it then fails with -600.
osascript -e 'tell application "System Events" to launch' >/dev/null 2>&1
sleep 1
osascript -e 'tell application "System Events" to tell process "Compositor"
set out to ""
repeat with n from 1 to (count of windows)
tell window n
set out to out & "=== WINDOW: " & (name of it) & linefeed
repeat with e in (entire contents)
try
set v to value of e
if v is not "" and v is not missing value then set out to out & ((class of e) as text) & "|" & v & linefeed
end try
try
set d to description of e
if d is not "" and d is not missing value then set out to out & "desc|" & d & linefeed
end try
try
set h to help of e
if h is not "" and h is not missing value then set out to out & "help|" & h & linefeed
end try
end repeat
end tell
end repeat
return out
end tell' 2>&1 | sort -u | grep -v 'missing value'
