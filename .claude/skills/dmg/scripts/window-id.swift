import CoreGraphics

// Prints the id of the first on-screen window with the given owner pid and title.
// Matches the pid, not the owner name, which is localized ("访达" for Finder).
// usage: window-id.swift <pid> <title>
let args = CommandLine.arguments
let pid = Int(args[1])
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows
where window[kCGWindowOwnerPID as String] as? Int == pid
    && window[kCGWindowName as String] as? String == args[2]
{
    print(window[kCGWindowNumber as String] ?? "")
    break
}
