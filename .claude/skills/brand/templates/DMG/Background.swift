import SwiftUI

// The DMG window background: 660 × 400 pt, origin top-left. Bundle/DMG/settings.py
// puts the app icon at (170, 200) and Applications at (490, 200) as 128 pt icons, with
// Finder's labels under them; keep those spots clear. Finder always draws this window
// in light mode, so labels stay black: keep the label areas light. A user's path or
// status bar can cover the bottom 25 pt. Render it with
// .claude/skills/brand/scripts/render-dmg-background.sh.
struct DMGBackground: View {
    static let size = CGSize(width: 660, height: 400)
    static let appIcon = CGPoint(x: 170, y: 200)
    static let applications = CGPoint(x: 490, y: 200)

    let name = "App Name"
    let promise = "One line on what it does for you"
    let accent = Color(red: 0.98, green: 0.45, blue: 0.00)
    let ink = Color(red: 0.23, green: 0.14, blue: 0.07)
    let paper = [Color(red: 1.00, green: 0.97, blue: 0.93), Color(red: 1.00, green: 0.89, blue: 0.77)]

    var body: some View {
        ZStack {
            LinearGradient(colors: paper, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(accent.opacity(0.28))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .position(Self.appIcon)
            Circle()
                .strokeBorder(accent.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(width: 168, height: 168)
                .position(Self.applications)
            Arrow()
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 120, height: 28)
                .position(x: (Self.appIcon.x + Self.applications.x) / 2, y: Self.appIcon.y)
            VStack(spacing: 6) {
                Text(name).font(.system(size: 28, weight: .bold, design: .rounded))
                Text(promise).font(.system(size: 14, weight: .medium)).opacity(0.65)
            }
            .foregroundStyle(ink)
            .position(x: Self.size.width / 2, y: 62)
            Text("Drag to Applications")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.opacity(0.5))
                .position(x: (Self.appIcon.x + Self.applications.x) / 2, y: Self.appIcon.y + 34)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

private struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: rect.maxX - rect.height / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.height / 2, y: rect.maxY))
        return path
    }
}
