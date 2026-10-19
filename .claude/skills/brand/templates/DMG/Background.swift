import SwiftUI

// The DMG window background: 660 × 400 pt, origin top-left. Bundle/DMG/settings.py
// puts the app icon at (170, 200) and Applications at (490, 200) as 128 pt icons, with
// Finder's labels under them; keep those spots clear. Finder always draws this window
// in light mode, so labels stay black: keep the label areas light. A user's path or
// status bar can cover the bottom 25 pt. Render it with
// .claude/skills/brand/scripts/render-dmg-background.sh.
//
// The default is deliberately plain: white paper and one small neutral arrow, so it
// ships with any app and reads in one glance. Replace the body with the brand's palette
// and motif; keep the body drawn from `size`, `appIcon` and `applications` so the
// background keeps matching settings.py.
struct DMGBackground: View {
    static let size = CGSize(width: 660, height: 400)
    static let appIcon = CGPoint(x: 170, y: 200)
    static let applications = CGPoint(x: 490, y: 200)

    let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    let paper = Color.white

    var body: some View {
        ZStack {
            paper
            // Small enough not to compete with the 128 pt icons: 26 pt of glyph in a
            // 320 pt gap. Keep it above the icon labels' baseline.
            Image(systemName: "arrow.right")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(ink.opacity(0.55))
                .position(
                    x: (Self.appIcon.x + Self.applications.x) / 2,
                    y: Self.appIcon.y
                )
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
