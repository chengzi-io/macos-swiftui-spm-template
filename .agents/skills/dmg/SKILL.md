---
name: dmg
description: Design the DMG installer window (Configs/DMG) - background and layout, from a plain default to a branded illustration. Wires dmgbuild into the project's build on first use and renders the real Finder window for the user to judge.
disable-model-invocation: true
---

# DMG window

The DMG window is the first screen of the product a user sees: the app icon, an arrow,
the Applications folder. The app icon carries the brand; the background frames it. The
background never has text: it is one image for every language, and the arrow needs none.

## What this skill expects from the project

It is written for apps made from macos-swiftui-spm-template:

- `Configs/Identity.xcconfig` sets `APP_NAME` and `APP_DISPLAY_NAME` as plain
  `KEY = value` lines; `App/AppIcon.icon` is the app icon.
- `make app` builds the debug app at `.build/xcode/Build/Products/Debug/$APP_NAME.app`,
  with `Contents/Resources/AppIcon.icns`.
- `scripts/make-dmg.sh <app> <dmg>` makes the unsigned DMG and `scripts/package-dmg.sh`
  signs and notarizes it; `scripts/common.sh` exports `Configs/Identity.xcconfig` and
  defines `die` and `log`.
- `.github/workflows/release.yml` runs `make release` on a macOS runner.

`<skill>` below is this skill's directory, for example `.agents/skills/dmg`. Its scripts
run from anywhere inside the project.

## How the designed DMG is built

The project ships a plain window: its `scripts/make-dmg.sh` runs hdiutil on the app and
an Applications link. Step 1 swaps in dmgbuild 1.6.7, which builds the window from
`Configs/DMG/`:

```
hdiutil create a blank image and attach it
copy the app, link Applications, write .VolumeIcon.icns from the app's AppIcon.icns,
copy background.png and @2x, write .DS_Store (window size, icon spots, background)
detach, shrink, convert to compressed UDZO
```

| Input | Source | Change it here |
| --- | --- | --- |
| App, volume icon, volume name | `make app` or `make release`; the app's `AppIcon.icns`; `APP_DISPLAY_NAME` | No |
| Background | `Configs/DMG/Background.swift`, rendered to `background.png` and `@2x`; `art.png` when an image model made the art | Yes |
| Layout | `window_rect`, `icon_size`, `text_size`, `icon_locations` in `Configs/DMG/settings.py` | Yes, with the constants in `Background.swift` |
| The rest of `settings.py` | `format`, `files`, `symlinks`, `icon`; no `hide_extensions` (it fails `codesign --strict`) | No |
| `scripts/make-dmg.sh`, `scripts/dmgbuild-requirements.txt`, the release workflow's Python step | Step 1 | No, after step 1 |

## 1. Wire dmgbuild into the build

Once per project; skip it when `scripts/make-dmg.sh` already runs dmgbuild.

```bash
cp <skill>/wiring/make-dmg.sh scripts/make-dmg.sh
cp <skill>/wiring/dmgbuild-requirements.txt scripts/dmgbuild-requirements.txt
```

dmgbuild needs `python3` 3.10 or later; the one Xcode installs is 3.9. On a Mac without
a newer one, `scripts/make-dmg.sh` fails and says so: `brew install python`. On first use
it installs dmgbuild, hash-pinned, into `.build/dmgbuild-1.6.7`.

The release runner needs that Python too. In `.github/workflows/release.yml`, add this
step to the publish job, before the step that runs `make release`:

```yaml
      # scripts/make-dmg.sh builds the DMG window with dmgbuild, which needs Python 3.10+.
      - uses: actions/setup-python@v7
        with:
          python-version: '3.13'
```

Nothing else in CI changes. The release job builds from the committed PNGs and never
renders `Background.swift`; PR CI (`make ci`) builds no DMG, so the preview is the check.

If the user decides against a designed window, undo this step: restore
`scripts/make-dmg.sh` and the workflow from git, and delete `Configs/DMG/` and
`scripts/dmgbuild-requirements.txt`.

## 2. Default

```bash
mkdir -p Configs/DMG && cp <skill>/templates/* Configs/DMG/   # skip if Configs/DMG exists
<skill>/scripts/render-dmg-background.sh                    # → Configs/DMG/background.png, @2x
make app && <skill>/scripts/preview-dmg.sh                  # → .build/dmg/dmg.png
```

White paper and a dark gray arrow. `preview-dmg.sh` mounts the DMG, opens it in Finder
and screenshots the window, so the terminal needs Screen Recording permission. Without
it, open `.build/dmg/preview.dmg` and look yourself, or ask the user to.

Show the user the screenshot. Unless they already said which level they want, ask:

| Level | What changes |
| --- | --- |
| Default | Nothing: finish here |
| Light brand | A soft gradient in the icon's colors, and an arrow drawn from the icon's motif |
| Full brand | An illustration or texture from the icon's world that leads to Applications, by its composition or a custom arrow; icon spots moved to fit the scene |

## 3. Read the brand

The brand is the app icon. Take the colors from `App/AppIcon.icon/icon.json` (the
`fill`) and its layers in `Assets/`, and look at the icon in `.build/dmg/dmg.png`. Pick
the motif: a shape from the icon that still reads at 30–60 pt.

## 4. Light brand

- Gradient: two or three of the icon's colors, mixed with 85–95% white so black labels
  read on every part of it.
- Arrow: drawn from the motif, between the icons, pointing from the app to
  Applications. For example the icon's chevron, a row of its dots, paw prints, a pulse
  line, a pixel arrow.

Make two or three variants. For each, write `Configs/DMG/Background.swift`, render,
preview, then keep the source as `.build/dmg/<letter>.swift` and the screenshot as
`.build/dmg/<letter>.png`. Show the user the screenshots with one line each on the idea,
and let them pick or adjust in plain words ("thinner arrow", "less color"). Copy the pick
back to `Configs/DMG/Background.swift` and render again.

## 5. Full brand

Propose two or three scenes from the icon's world, one line each; a pixel-art cat icon
might become a pixel night landscape where paw prints lead to Applications. Say for each
whether you draw it in code or it needs an image model, and let the user pick.

The scene leads the eye from the app to Applications, one of two ways:

- A connector between the icons: an arrow, paw prints, a row of dots, a path.
- Composition: figures around Applications that point or move toward it, a trail from
  the app to Applications, light that flows to the right. Grok Bot's window has no
  arrow: six mascots with cursors circle the Applications folder, all pointing at it,
  and the app sits far left to make room. With composition, drop the arrow.

Code draws well: shapes, lines, gradients, layered silhouettes, stars, dots; flat
figures placed around a spot and turned to face it; pixel art (rows of characters drawn
as squares on whole points, so 1x and 2x stay crisp); grain from a seeded random
generator, so 1x and 2x match. Code cannot draw painterly or hand-drawn art, shaded
characters, or realistic texture and light: those need an image model.

Drawn in code: write it in `Background.swift` and make variants as in step 4. Turn
figures toward Applications from the constants, so they stay right when the icons move:

```swift
// Turns a view drawn pointing right (+x) so it points from `point` at `target`.
func angle(from point: CGPoint, to target: CGPoint) -> Angle {
    .radians(atan2(target.y - point.y, target.x - point.x))
}

Cursor()
    .rotationEffect(angle(from: spot, to: Self.applications))
    .position(spot)
```

Made by an image model:

1. Write the user a prompt to paste into ChatGPT, Gemini or another image model. The
   numbers below are for the geometry in `templates/`, checked in a real Finder window: a 3:2
   image is scaled to 660 pt wide (440 pt tall) and loses 20 pt at the top and bottom.
   Recompute them if you moved the icons. Pick how the art leads to Applications with
   the scene, and write that choice as the Direction line: a code arrow over the art
   (exact, but can look pasted onto painterly art), an arrow the model draws in the
   scene's style, or a composition with no arrow.

   ```
   Background artwork for an app installer window. Landscape 3:2, 1536 × 1024 pixels.
   Only the background: no window, title bar, app icons, folders, text, letters, logos,
   signature or watermark.
   Scene: <one or two sentences>. Style: <style>. Colors: <hex colors>. Overall light, so
   black captions stay readable.
   Direction: <one of:
     No arrows. Keep the band between the two areas plain: x 38–62%, y 42–58%. An
     arrow is added there later.
     Draw one arrow in the scene's style inside x 40–60%, y 44–56%, pointing right,
     from the left area to the right area.
     No arrow shapes. The picture leads the eye from the left area to the right area:
     <a trail from the left area to the right area | small figures around the right
     area, all facing its center at x 74%, y 50% | light that flows to the right>.>
   Layout, in percent of width and height from the top-left corner:
   - Keep two areas plain and light, like empty paper: x 14–38%, y 32–73% and
     x 62–86%, y 32–73%. Icons and their captions go there later.
   - Detail can go anywhere else: the corners, the edges, around the right area, and
     above and below the middle (x 38–62%, y 42–58%).
   - The top and bottom 4% are cut off and the bottom 10% may be covered: nothing
     important there.
   ```

2. The user generates, picks one and gives you the file. Save it as
   `Configs/DMG/art.png` (`sips -s format png <file> --out Configs/DMG/art.png` converts a
   JPEG or WebP). It needs at least 1320 × 800 px after the crop; a smaller one blurs on
   Retina, so ask for a larger one.
3. Draw it as the bottom layer in `Background.swift`:

   ```swift
   import AppKit

   // In DMGBackground. The renderer runs from the repo root.
   static let art: NSImage = {
       guard let image = NSImage(contentsOfFile: "Configs/DMG/art.png") else {
           fatalError("cannot read Configs/DMG/art.png")
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
   for them. Models only roughly follow a direction: check that the arrow points at
   Applications, figures face it and a trail ends there; if not, revise the prompt or
   draw an arrow over the art in code. If the art crowds an icon or a label, move the icon spots, put a soft white
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
- Lead the eye from the app to Applications: a connector, or the composition.
- A user's path bar or status bar can cover the bottom 25 pt.
- Draw brand shapes with `Shape` or `Path`, never an SF Symbol: their license forbids
  use in logos and other trademark use. No other brand's artwork or characters.

## 6. Finish

1. Render once more, so the PNGs match `Background.swift`, and run `preview-dmg.sh`.
2. Commit `Configs/DMG/`, the two files in `scripts/` and the workflow step together, for
   example `feat(dmg): add a designed installer window`. Reverting that commit brings
   back the plain DMG.
