// Queries the built app bundle's own tables — the ones Xcode converted to UTF-16 and placed under
// Resources/*.lproj — rather than the source files, so this checks the shipping artifact.
// Run as:  probe_bundle <App.app> -AppleLanguages zh-Hans
import Foundation

let args = CommandLine.arguments

// The language has to be in UserDefaults before the bundle is asked: a command-line tool resolves its
// own domain otherwise and reports English, which looks exactly like a bundle with no Chinese in it.
// (Skipping this step produced precisely that false alarm once, so the shim is not optional here.)
if let index = args.firstIndex(of: "-AppleLanguages"), index + 1 < args.count {
    let tag = args[index + 1].filter { $0 != "(" && $0 != ")" && $0 != "\"" && $0 != "'" }
    UserDefaults.standard.set([tag], forKey: "AppleLanguages")
    UserDefaults.standard.synchronize()
}

let app = Bundle(path: args[1])!
let chinese = app.preferredLocalizations.first?.hasPrefix("zh") == true
func look(_ key: String) -> String { app.localizedString(forKey: key, value: key, table: nil) }

print("解析到的语言: \(app.preferredLocalizations)")
print("bundle 可用语言: \(app.localizations)")

for key in ["File", "Layer", "Blend Mode", "Drop Shadow", "New Canvas", "Export",
            "Undo", "System Language", "(Multiple)", "Bake and Delete",
            "Save changes to %@?", "%1$@ × %2$@ in at %3$@ DPI"] {
    let value = look(key)
    print("  \(chinese ? "✓" : " ") \(key) → \(value)")
}

print("— 带参数 —")
print("  " + String(format: look("Save changes to %@?"), "未标题"))
print("  " + String(format: look("%1$@ × %2$@ in at %3$@ DPI"), "8.27", "11.69", "300"))
print("  " + String(format: look("Undo %@"), look("Move Layer")))
