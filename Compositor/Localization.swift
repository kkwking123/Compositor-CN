import Foundation

extension String {
    /// The same text in the language the app is running in.
    ///
    /// SwiftUI localizes `Text("…")`, `Button("…")` and the rest from the literal in the source on its own.
    /// Text that only exists at runtime — a blend mode's name, an AppKit menu item, a title built from parts —
    /// is invisible to that, and is looked up here instead. An English string with no translation comes back
    /// unchanged, so this is safe to call on anything shown in the interface.
    var localized: String { NSLocalizedString(self, comment: "") }

    /// The same text in the language the app is running in, looked up under a context of its own.
    ///
    /// A word can mean two things in two places — "Light" as Camera Raw's tone panel, and as a pale tone — and
    /// the two need different translations. The panel keys its name apart with a context; every other word in
    /// that panel has no keyed entry and so falls back to the plain one, translating as usual.
    func localized(context: String) -> String {
        let marker = "\u{0}"
        let keyed = Bundle.main.localizedString(forKey: "\(context): \(self)", value: marker, table: nil)
        return keyed == marker ? localized : keyed
    }
}
