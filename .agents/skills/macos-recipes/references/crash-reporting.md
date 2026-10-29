# Crash reporting

Developer ID apps get no crash reports from Apple; they stay in
`~/Library/Logs/DiagnosticReports` on the user's Mac. Pick one when the app has users:

- **Sentry**: add `https://github.com/getsentry/sentry-cocoa` to
  `Package.swift` with an `exact:` version as a dependency of
  `PlatformLive` (create it beside `Platform/Core` if the app has none), start it from a
  function there that
  `AppDelegate.applicationDidFinishLaunching` calls, and upload
  `dist/*.dSYM.zip` with `sentry-cli debug-files upload` in the publish job. Declare
  the collected data in the privacy manifest.
- **MetricKit**: subscribe with `MXMetricManager.shared.add(_:)`; crash and hang
  diagnostics (`MXDiagnosticPayload`) arrive on the next launch. You send them to your
  own endpoint and symbolicate with the release dSYM.

Either way, ask for consent where your privacy policy requires it.
