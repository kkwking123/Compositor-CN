// Runs the parts of this session that static checks can only reason about: whether a translated table is
// actually found when the process says it prefers Chinese, whether the language menu's mechanism works
// (AppleLanguages in the app's own defaults), and whether every format string renders with the argument
// types the app passes — which is where a %@ given an Int would crash rather than warn.
//
// Built into Probe.app and launched from there, so Bundle.main is a real bundle with two localisations,
// exactly as the app's would be.
import Foundation

let table = Bundle.main
let chinese = Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true

// The app's own lookup: NSLocalizedString passes the key as the default value, so a key with no entry comes
// back unchanged. That is why en.lproj can hold nothing at all and English still reads right — and why the
// default here has to be the key, not a sentinel, or English looks like a wall of blanks.
func look(_ key: String) -> String { table.localizedString(forKey: key, value: key, table: nil) }

/// Whether the table really holds the key — an entry that translates to the same word ("Camera Raw…") would
/// read as a miss if the only test were "did the text change".
func held(_ key: String) -> Bool { table.localizedString(forKey: key, value: "\u{0}", table: nil) != "\u{0}" }

func show(_ key: String, _ args: any CVarArg...) {
    if chinese && !held(key) { print("  缺条目  \(key)"); return }
    print("  \(String(format: look(key), arguments: args))")
}

print("本机偏好语言: \(Bundle.main.preferredLocalizations.first ?? "无")")

// The plain lookups the interface leans on, including the runtime names that only exist once composed.
for key in ["Undo", "Redo", "Blend mode", "System Language", "(Multiple)", "Multiply", "Drop Shadow",
            "Export", "Untitled", "Bake and Delete", "Guided", "Layer via Copy", "Camera Raw…",
            "正片叠底"] {
    let value = look(key)
    print("  \(key) → \(value)" + (chinese && !held(key) ? "   ← 表内无此项" : ""))
}

print("— 带参数的格式串 —")
show("Undo %@", "Move Layer")
show("Save changes to %@?", "Untitled")
show("%lld of these files already exist in “%@”. Replace them?", 3, "Out")
show("%1$@ × %2$@ in at %3$@ DPI", "8.27", "11.69", "300")
show("%1$@ %2$@ is ready to install — you have %3$@.", "Compositor", "1.5.12", "1.5.11")
show("%1$@. Double-click to reset.", "Exposure")
show("%1$@ of %2$@.", "Hue", "Red")
show("%1$@ is assigned to both %2$@ and %3$@.", "⌘⇧Z", "Undo", "Redo")
show("Export %lld Layers as PNGs", 4)
show("%lld frames", 12)
// The arguments the app builds from Ints, the way pageSize and the size sheets do.
show("New: %lld × %lld pixels · %@ uncompressed", 1920, 1080, "8.3 MB")
show("Final dimensions must be 1–%@ pixels per side.", "32768")
