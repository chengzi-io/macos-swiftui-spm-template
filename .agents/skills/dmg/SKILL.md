---
name: dmg
description: Design the DMG installer window (Bundle/DMG) - a quiet background that frames the app icon and carries one brand element. Renders variants as real Finder screenshots for the user to pick.
disable-model-invocation: true
---

# DMG window

The DMG window is the first screen of the product a user sees. It frames the app icon
and shows the drag to Applications. The app icon carries the brand; the background
echoes it with one element and otherwise stays quiet. No headline, tagline, feature
list or screenshot.

| File | What it is |
| --- | --- |
| `Bundle/DMG/Background.swift` | SwiftUI view rendered to the background: the design source |
| `Bundle/DMG/background.png`, `@2x` | Rendered from it; the build uses these, so commit them |
| `Bundle/DMG/settings.py` | dmgbuild layout: window size and icon positions |

Without `Bundle/DMG/settings.py`, `scripts/make-dmg.sh` (and so `make release`) builds a
plain DMG; with it, the designed one. Delete `Bundle/DMG/` to go back. Scripts live in
`.agents/skills/dmg/scripts/` and run from the repo root.

## 1. Baseline

```bash
mkdir -p Bundle/DMG && cp .agents/skills/dmg/templates/* Bundle/DMG/  # skip if Bundle/DMG exists
.agents/skills/dmg/scripts/render-dmg-background.sh                 # → Bundle/DMG/background.png, @2x
make app && .agents/skills/dmg/scripts/preview-dmg.sh               # → .build/dmg/dmg.png
```

The template is white paper and a small gray arrow: the baseline every variant must
beat. `preview-dmg.sh` mounts the DMG, opens it in Finder and screenshots the window, so
the terminal needs Screen Recording permission. Without it, open `.build/dmg/preview.dmg`
and look yourself, or ask the user to.

## 2. Read the brand

The brand is the app icon. Take the colors from `Bundle/AppIcon.icon/icon.json` (the
`fill`) and its `Assets/*.svg`, and look at the icon in `.build/dmg/dmg.png`. Read
`docs/BRAND.md` if it exists. Pick one brand color and one motif: a shape from the icon
that still reads at 30–60 pt.

## 3. Variants

Brand levers, quietest first:

1. **Accent**: the arrow in the brand color.
2. **Motif connector**: the arrow drawn from the motif, still pointing from the app to
   Applications: the icon's chevron, a row of its dots, its stroke style, a pulse line
   for a monitor.
3. **Tint**: mix 4–8% of the brand color into the paper, or a soft brand glow behind
   the app icon (opacity ≤ 15%, blur ≥ 60 pt).
4. **Watermark**: the motif large and faint (a few percent from the paper), cropped by a
   window edge, clear of both icons and their labels.

Use at most two levers in one design. Make three variants from quiet to expressive, for
example 1, 2, and 2 + 3. For each, write `Bundle/DMG/Background.swift`, render, preview,
then keep the source as `.build/dmg/<letter>.swift` and the screenshot as
`.build/dmg/<letter>.png`. Show the user the three screenshots with one line each on the
idea, and let them pick or adjust in plain words ("thinner arrow", "less color"). Copy
the pick back to `Bundle/DMG/Background.swift` and render again.

Rules for every variant:

- Keep the struct name `DMGBackground` and its `size`, `appIcon` and `applications`
  constants; they must match `window_rect` and `icon_locations` in `settings.py`. Draw
  from them, and change both files together.
- Finder places the real 128 pt icons and draws their labels under them. Keep those
  areas clear and light: Finder always draws this window in light mode, so labels are
  black. No dark backgrounds.
- No text by default. If the user wants a word, use `APP_NAME` from `Bundle/app.env`
  (the app's label is that file name) or "Drag to Applications", at least 11 pt, one
  language.
- A user's path bar or status bar can cover the bottom 25 pt.
- Draw the brand element with `Shape` or `Path`, never an SF Symbol: their license
  forbids use in logos and other trademark use.

## 4. Python and CI

dmgbuild needs `python3` 3.10 or later; the one Xcode installs is 3.9. On a Mac without
a newer one, `scripts/make-dmg.sh` fails and says so: `brew install python`. On first use
it installs dmgbuild 1.6.7, hash-pinned, into `.build/dmgbuild-1.6.7`.

Nothing in CI needs changing. The release workflow sets up Python when
`Bundle/DMG/settings.py` exists, and builds from the committed PNGs; it never renders
`Background.swift`. PR CI (`make ci`) builds no DMG: the preview in step 1 is the check.

## 5. Finish

1. Render once more, so the PNGs match `Background.swift`, and run `preview-dmg.sh`.
2. Commit `Bundle/DMG/` (all four files), for example
   `feat(dmg): add a designed installer window`.
