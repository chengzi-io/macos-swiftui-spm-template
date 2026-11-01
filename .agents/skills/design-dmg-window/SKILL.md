---
name: design-dmg-window
description: Design the DMG installer window (App/Configs/DMG) - background and layout, from a plain default to a branded illustration. Wires dmgbuild into the project's build on first use and renders the real Finder window for the user to judge.
disable-model-invocation: true
---

# DMG window

The DMG window is the first screen of the product a user sees: the app icon, an arrow,
the Applications folder. The app icon carries the brand; the background frames it. The
background never has text: it is one image for every language, and the arrow needs none.

`<skill>` below is this skill's directory, `.agents/skills/design-dmg-window`. Its
scripts run from anywhere inside the project.

## Status

Moves the `make status` dmg line from `-- dmg` ("the plain window (optional)") to
`ok dmg` ("a designed window (App/Configs/DMG)").

## Before you start

- `make status`: the project line is `ok`.
- The app icon is the app's own, not the template's: the background takes its colors.
- The terminal has Screen Recording permission, so `preview-dmg.sh` can screenshot the
  window; without it, open the DMG and look, or ask the user to.
- `scripts/make-dmg.sh`, `scripts/package-dmg.sh` and `scripts/common.sh` (which exports
  `APP_NAME` and `APP_DISPLAY_NAME` and defines `die` and `log`) ship with the project.

## Plan

Say what will change and wait for the user's go-ahead: `App/Configs/DMG/`
(`Background.swift`, `settings.py`, the PNGs), the two files of step 1, and the window
itself. The level is the user's call: default, light brand or full brand.

## How the designed DMG is built

The project ships a plain window: its `scripts/make-dmg.sh` runs hdiutil on the app and
an Applications link. Step 1 swaps in dmgbuild 1.6.7, which builds the window from
`App/Configs/DMG/`:

```text
hdiutil create a blank image and attach it; copy the app, link Applications, write
.VolumeIcon.icns from the app's AppIcon.icns, copy background.png and @2x, write .DS_Store
(window size, icon spots, background); detach, shrink, convert to compressed UDZO
```

| Input | Source | Change it here |
| --- | --- | --- |
| App, volume icon, volume name | `make app` or `make release`; the app's `AppIcon.icns`; `APP_DISPLAY_NAME` | No |
| Background | `App/Configs/DMG/Background.swift`, rendered to `background.png` and `@2x`; `art.png` when an image model made the art | Yes |
| Layout | `window_rect`, `icon_size`, `text_size`, `icon_locations` in `App/Configs/DMG/settings.py` | Yes, with the constants in `Background.swift` |
| The rest of `settings.py` | `format`, `files`, `symlinks`, `icon`; no `hide_extensions` (it fails `codesign --strict`) | No |
| `scripts/make-dmg.sh`, `scripts/dmgbuild-requirements.txt` | Step 1 | No, after step 1 |

## Steps

### 1. Wire dmgbuild into the build

Once per project; skip it when `scripts/make-dmg.sh` already runs dmgbuild.

```bash
cp <skill>/wiring/make-dmg.sh scripts/make-dmg.sh
cp <skill>/wiring/dmgbuild-requirements.txt scripts/dmgbuild-requirements.txt
```

dmgbuild needs `python3` 3.10 or later; the one Xcode installs is 3.9. On a Mac without
a newer one, `scripts/make-dmg.sh` fails and says so: `brew install python`. On first use
it installs dmgbuild, hash-pinned, into `.build/dmgbuild-1.6.7`.

The release workflow already sets up the Python that dmgbuild needs, so nothing in
`.github/workflows/release.yml` changes. The release job builds from the committed PNGs
and never renders `Background.swift`; PR CI (`make ci`) builds no DMG, so the preview is
the check.

If the user decides against a designed window, undo this step: restore
`scripts/make-dmg.sh` from git, and delete `App/Configs/DMG/` and the requirements file.

### 2. Default

```bash
mkdir -p App/Configs/DMG && cp <skill>/templates/* App/Configs/DMG/   # skip if App/Configs/DMG exists
<skill>/scripts/render-dmg-background.sh                    # → App/Configs/DMG/background.png, @2x
make app && <skill>/scripts/preview-dmg.sh                  # → .build/dmg/dmg.png
```

White paper and a dark gray arrow. `preview-dmg.sh` mounts the DMG, opens it in Finder
and screenshots the window. Show the user the screenshot. Unless they already said which
level they want, ask: [the three brand levels](references/brand-levels.md).

### 3. Read the brand

The brand is the app icon. Take the colors from `App/Application/AppIcon.icon/icon.json`
(the `fill`) and its layers in `Assets/`, and look at the icon in `.build/dmg/dmg.png`.
Pick the motif: a shape from the icon that still reads at 30–60 pt.

### 4. Light brand

A soft gradient in the icon's colors and an arrow drawn from its motif, in two or three
variants. Write each one into `App/Configs/DMG/Background.swift`, render, preview, and
show the user the screenshots. Steps: [light brand](references/brand-levels.md#light-brand).

### 5. Full brand

An illustration or texture from the icon's world that leads to Applications, drawn in
code or made by an image model. Propose two or three scenes, say how each one is made,
and let the user pick. Steps and the image-model prompt:
[full brand](references/brand-levels.md#full-brand).

### 6. Finish

1. Render once more, so the PNGs match `Background.swift`, and run `preview-dmg.sh`.
2. Commit `App/Configs/DMG/` and the two files in `scripts/` together, for example
   `feat(dmg): add a designed installer window`. Reverting that commit brings back the
   plain DMG.

## Changes

| File | Change |
| --- | --- |
| `App/Configs/DMG/Background.swift` | the background, drawn in code |
| `App/Configs/DMG/settings.py` | `window_rect`, `icon_size`, `text_size`, `icon_locations` |
| `App/Configs/DMG/background.png`, `@2x`, `art.png` | rendered from it, or the user's art |
| `scripts/make-dmg.sh`, `scripts/dmgbuild-requirements.txt` | step 1, once per project |

## The user's part

- Pick the level, and the scene or variant they like.
- Look at the preview screenshot of the real Finder window, and generate the art when the
  full brand uses an image model.

## Done when

- `preview-dmg.sh` shows the window the user approved, at the level they picked, and the
  PNGs match `Background.swift`.
- `make ci` exits 0, and `make status` shows `ok dmg`.

## Never

- Edit `.github/workflows/release.yml` after step 1: the workflow already sets up the
  Python dmgbuild needs.
- Draw a dark full background, or put anything dark under an icon or its label: Finder
  draws the 128 pt icons and their labels in black, and a window with a background
  picture stays in light mode.
- Put text in the background or the art: it is one image for every language. Keep the
  bottom 25 pt clear: a user's path bar or status bar can cover it.
- Draw a brand shape with an SF Symbol, or use another brand's artwork or characters:
  their license forbids use in logos and other trademark use.
- Rename `DMGBackground` or change its `size`, `appIcon` and `applications` without
  changing `settings.py` too: they match `window_rect` and `icon_locations`.
