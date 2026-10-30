// The updater was removed from this fork.
//
// Upstream checks for new versions with Sparkle, against an appcast signed with the author's EdDSA key. Applying
// one of those updates would replace this Chinese edition with the English original, and Sparkle won't install
// over an ad-hoc signed build — the way this fork is packaged — so its driver and the feed's startup are gone.
//
// New versions come from this fork's GitHub Releases. Config/Info.plist says what turning the updater back on takes.
