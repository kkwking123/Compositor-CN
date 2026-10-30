import AppKit
// @Published lives in Combine, and this project builds with MemberImportVisibility on: reaching it through
// SwiftUI's re-export isn't allowed, so the module that defines it is named.
import Combine
import SwiftUI

/// The language the interface shows in, chosen from the app's own menu.
///
/// macOS normally decides this from the system's language list. Writing `AppleLanguages` into the app's own
/// defaults overrides it for this app alone, leaving every other application as the system set it, and the
/// override is read once, at launch — so a change is applied by starting the app again.
enum AppLanguage: String, CaseIterable, Identifiable {
    /// Whatever the system offers, which is how the app behaves until a language is picked here.
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// A language is known by its own name, so the two choices read the same whichever language is showing.
    /// Only "follow the system" needs translating, since it isn't the name of a language.
    var title: String {
        switch self {
        case .system: return "System Language".localized
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

@MainActor
final class LanguageController: ObservableObject {
    static let shared = LanguageController()

    /// The menu's tick, kept apart from `AppleLanguages` so the app can tell "never chosen" from "chosen: system".
    @Published private(set) var preferred: AppLanguage

    private static let chosenKey = "app.preferredLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    private init() {
        preferred = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.chosenKey) ?? "") ?? .system
    }

    func choose(_ language: AppLanguage) -> Bool {
        guard language != preferred else { return false }
        let defaults = UserDefaults.standard
        switch language {
        case .system: defaults.removeObject(forKey: Self.appleLanguagesKey)
        default: defaults.set([language.rawValue], forKey: Self.appleLanguagesKey)
        }
        defaults.set(language.rawValue, forKey: Self.chosenKey)
        preferred = language
        return true
    }

    /// Restarts the app so it reads the new language. The replacement comes up first and the running copy goes
    /// once it is, so the editor never sits closed with nothing to click.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Asks before restarting, naming the language just chosen — the one on screen is still the old one.
    func askToRelaunch(_ language: AppLanguage, over window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = String(format: "Show Compositor in %@?".localized, language.title)
        alert.informativeText = "The change takes effect the next time Compositor starts.".localized
        alert.addButton(withTitle: "Restart Now".localized)
        alert.addButton(withTitle: "Later".localized)
        guard let window else {
            if alert.runModal() == .alertFirstButtonReturn { relaunch() }
            return
        }
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { self.relaunch() }
        }
    }
}
