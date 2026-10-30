// A stand-in for the Sparkle module, so the three files that import it can be type-checked while Sparkle
// itself isn't downloaded. It mirrors only what this app already assumes, which is the same set of
// assumptions the untouched upstream makes — so a pass here says the app's own usage is self-consistent,
// not that Sparkle's real signatures were verified. Those remain to be confirmed against the framework
// in a normal build.
//
// SPUUserDriver is marked main-actor because Sparkle's own header marks it so; SPUUpdaterDelegate is not,
// because the app implements it from a plain NSObject that isn't main-actor.
import AppKit

open class SUAppcastItem {
    public init() {}
    open var isInformationOnlyUpdate: Bool { false }
    open var displayVersionString: String { "" }
    open var propertiesDictionary: [String: Any] { [:] }
}

public enum SPUUserUpdateStage { case notDownloaded, downloaded }
public struct SPUUserUpdateState { public var stage: SPUUserUpdateStage = .notDownloaded }
public enum SPUUserUpdateChoice { case install, skip, dismiss }

open class SPUUpdatePermissionRequest { public init() {} }
open class SUUpdatePermissionResponse { public init() {} }
open class SPUDownloadData { public init() {} }

open class SPUUpdater {
    public init(hostBundle: Bundle, applicationBundle: Bundle, userDriver: SPUUserDriver?, delegate: SPUUpdaterDelegate?) {}
    open func start() throws {}
    open func checkForUpdates() {}
    open var allowsAutomaticUpdates: Bool { true }
    open var automaticallyDownloadsUpdates: Bool = false
}

open class SPUStandardUserDriver {
    public init(hostBundle: Bundle, delegate: SPUUpdaterDelegate?) {}
    open func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {}
    open func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {}
    open func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    open func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {}
    open func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {}
    open func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    open func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    open func showDownloadDidReceiveData(ofLength length: UInt64) {}
    open func showDownloadDidStartExtractingUpdate() {}
    open func showExtractionReceivedProgress(_ progress: Double) {}
    open func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {}
    open func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}
    open func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {}
    open func showUpdateInFocus() {}
    open func dismissUpdateInstallation() {}
}

@MainActor public protocol SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void)
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void)
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void)
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData)
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error)
    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void)
    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void)
    func showDownloadInitiated(cancellation: @escaping () -> Void)
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64)
    func showDownloadDidReceiveData(ofLength length: UInt64)
    func showDownloadDidStartExtractingUpdate()
    func showExtractionReceivedProgress(_ progress: Double)
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void)
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void)
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void)
    func showUpdateInFocus()
    func dismissUpdateInstallation()
}

public protocol SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String?
}
