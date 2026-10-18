import AppCore
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unbundled"
        let build = info["CFBundleVersion"] as? String ?? "unbundled"
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        Log.app.notice(
            "launched version=\(version, privacy: .public) build=\(build, privacy: .public) sandboxed=\(sandboxed, privacy: .public)"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.notice("terminating")
    }
}
