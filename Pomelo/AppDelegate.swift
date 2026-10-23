import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        Log.app.notice(
            "launched version=\(version, privacy: .public) build=\(build, privacy: .public) sandboxed=\(sandboxed, privacy: .public)"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.notice("terminating")
    }
}
