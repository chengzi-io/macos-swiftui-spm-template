# Privacy manifest

`App/Application/PrivacyInfo.xcprivacy` ships in every build and declares UserDefaults
(`CA92.1`: the app reads its own defaults). Add an entry when code or an SDK uses
another required-reason API (file timestamps, disk space, system boot time, active
keyboards) or collects data. The App Store checks it; Developer ID builds carry it
for consistency.
