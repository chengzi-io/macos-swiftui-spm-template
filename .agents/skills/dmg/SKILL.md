---
name: dmg
description: Design the DMG installer window (Bundle/DMG) - background and layout, from a plain default to a branded illustration. Renders the real Finder window for the user to judge.
disable-model-invocation: true
---

# DMG window

The DMG window is the first screen of the product a user sees: the app icon, an arrow,
the Applications folder. The app icon carries the brand; the background frames it. The
background never has text: it is one image for every language, and the arrow needs none.

## How the DMG is built

```
scripts/make-dmg.sh <app> <dmg>   (make release runs it, then signs and notarizes the DMG)
  without Bundle/DMG/settings.py: hdiutil, the app and an Applications link, plain window
  with it, dmgbuild 1.6.7:
    hdiutil create a blank image and attach it
    copy the app, link Applications, write .VolumeIcon.icns from the app's AppIcon.icns,
    copy background.png and @2x, write .DS_Store (window size, icon spots, background)
    detach, shrink, convert to compressed UDZO
```

| Input | Source | Change it here |
| --- | --- | --- |
| App, volume icon, volume name | `make app` or `make release`; the app's `AppIcon.icns`; `APP_DISPLAY_NAME` | No |
| Background | `Bundle/DMG/Background.swift`, rendered to `background.png` and `@2x`; `art.png` when an image model made the art | Yes |
| Layout | `window_rect`, `icon_size`, `text_size`, `icon_locations` in `Bundle/DMG/settings.py` | Yes, with the constants in `Background.swift` |
| The rest of `settings.py` | `format`, `files`, `symlinks`, `icon`; no `hide_extensions` (it fails `codesign --strict`) | No |
| `scripts/`, `.github/workflows/` | | No |

Delete `Bundle/DMG/` to go back to the plain DMG. Scripts below live in
`.agents/skills/dmg/scripts/` and run from the repo root.

## 1. Default

```bash
mkdir -p Bundle/DMG && cp .agents/skills/dmg/templates/* Bundle/DMG/  # skip if Bundle/DMG exists
.agents/skills/dmg/scripts/render-dmg-background.sh                 # → Bundle/DMG/background.png, @2x
make app && .agents/skills/dmg/scripts/preview-dmg.sh               # → .build/dmg/dmg.png
```

White paper and a dark gray arrow. `preview-dmg.sh` mounts the DMG, opens it in Finder
and screenshots the window, so the terminal needs Screen Recording permission. Without
it, open `.build/dmg/preview.dmg` and look yourself, or ask the user to.

Show the user the screenshot. Unless they already said which level they want, ask:

| Level | What changes |
| --- | --- |
| Default | Nothing: finish here |
| Light brand | A soft gradient in the icon's colors, and an arrow drawn from the icon's motif |
| Full brand | An illustration or texture from the icon's world, a custom arrow, icon spots moved to fit the scene |

## 2. Read the brand

The brand is the app icon. Take the colors from `Bundle/AppIcon.icon/icon.json` (the
`fill`) and its `Assets/*.svg`, look at the icon in `.build/dmg/dmg.png`, and read
`docs/BRAND.md` if it exists. Pick the motif: a shape from the icon that still reads at
30–60 pt.

## 3. Light brand

- Gradient: two or three of the icon's colors, mixed with 85–95% white so black labels
  read on every part of it.
- Arrow: drawn from the motif, between the icons, pointing from the app to
  Applications. For example the icon's chevron, a row of its dots, paw prints, a pulse
  line, a pixel arrow.

Make two or three variants. For each, write `Bundle/DMG/Background.swift`, render,
preview, then keep the source as `.build/dmg/<letter>.swift` and the screenshot as
`.build/dmg/<letter>.png`. Show the user the screenshots with one line each on the idea,
and let them pick or adjust in plain words ("thinner arrow", "less color"). Copy the pick
back to `Bundle/DMG/Background.swift` and render again.

## 4. Full brand

Propose two or three scenes from the icon's world, one line each; a pixel-art cat icon
might become a pixel night landscape where paw prints lead to Applications. Say for each
whether you draw it in code or it needs an image model, and let the user pick.

Code draws well: shapes, lines, gradients, layered silhouettes, stars, dots; pixel art
(rows of characters drawn as squares on whole points, so 1x and 2x stay crisp); grain
from a seeded random generator, so 1x and 2x match. Code cannot draw painterly or
hand-drawn art, shaded characters, or realistic texture and light: those need an image
model.

Drawn in code: write it in `Background.swift` and make variants as in step 3.

Made by an image model:

1. Write the user a prompt to paste into ChatGPT, Gemini or another image model. The
   numbers below are for the template's geometry, checked in a real Finder window: a 3:2
   image is scaled to 660 pt wide (440 pt tall) and loses 20 pt at the top and bottom.
   Recompute them if you moved the icons.

   ```
   Background artwork for an app installer window. Landscape 3:2, 1536 × 1024 pixels.
   Only the background: no window, title bar, app icons, folders, arrows, text, letters,
   logos, signature or watermark.
   Scene: <one or two sentences>. Style: <style>. Colors: <hex colors>. Overall light, so
   black captions stay readable.
   Layout, in percent of width and height from the top-left corner:
   - Keep two areas plain and light, like empty paper: x 14–38%, y 32–73% and
     x 62–86%, y 32–73%. Icons and their captions go there later.
   - Keep the band between them plain: x 38–62%, y 42–58%. An arrow goes there later.
   - Put the detail in the corners, along the top above y 30% and along the bottom
     below y 74%.
   - The top and bottom 4% are cut off and the bottom 10% may be covered: nothing
     important there.
   ```

2. The user generates, picks one and gives you the file. Save it as
   `Bundle/DMG/art.png` (`sips -s format png <file> --out Bundle/DMG/art.png` converts a
   JPEG or WebP). It needs at least 1320 × 800 px after the crop; a smaller one blurs on
   Retina, so ask for a larger one.
3. Draw it under the arrow in `Background.swift`:

   ```swift
   import AppKit

   // In DMGBackground. The renderer runs from the repo root.
   static let art: NSImage = {
       guard let image = NSImage(contentsOfFile: "Bundle/DMG/art.png") else {
           fatalError("cannot read Bundle/DMG/art.png")
       }
       return image
   }()

   // First layer of the body's ZStack:
   Image(nsImage: Self.art)
       .resizable()
       .scaledToFill()
       .frame(width: Self.size.width, height: Self.size.height)
       .clipped()
   ```

4. Render and preview. Models add text, letters and signatures despite the prompt: look
   for them. If the art crowds an icon or a label, move the icon spots, put a soft white
   glow under the label, or write a revised prompt that says what to change and ask the
   user to generate again.

## Rules for every level

- Keep the struct name `DMGBackground` and its `size`, `appIcon` and `applications`
  constants; they match `window_rect` and `icon_locations` in `settings.py`. Draw from
  them, and change both files together.
- Finder draws the 128 pt icons and their labels in black: a window with a background
  picture stays in light mode (reported for dark mode too). Keep the area under each
  icon and label light; no dark full backgrounds.
- No text, in the background or the art.
- A user's path bar or status bar can cover the bottom 25 pt.
- Draw brand shapes with `Shape` or `Path`, never an SF Symbol: their license forbids
  use in logos and other trademark use. No other brand's artwork or characters.

## 5. Python and CI

dmgbuild needs `python3` 3.10 or later; the one Xcode installs is 3.9. On a Mac without
a newer one, `scripts/make-dmg.sh` fails and says so: `brew install python`. On first use
it installs dmgbuild, hash-pinned, into `.build/dmgbuild-1.6.7`.

Nothing in CI needs changing. The release workflow sets up Python when
`Bundle/DMG/settings.py` exists and builds from the committed PNGs; it never renders
`Background.swift`. PR CI (`make ci`) builds no DMG: the preview is the check.

## 6. Finish

1. Render once more, so the PNGs match `Background.swift`, and run `preview-dmg.sh`.
2. Commit everything in `Bundle/DMG/`, for example
   `feat(dmg): add a designed installer window`.
