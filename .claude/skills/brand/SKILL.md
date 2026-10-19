---
name: brand
description: Design this app's brand assets - the Liquid Glass app icon (Bundle/AppIcon.icon, layered SVGs for Icon Composer) and a branded DMG installer window (Bundle/DMG). Use when the user asks for an app icon or logo, a DMG background or installer look, or wants the first download to look distinctive.
---

# Brand

The DMG window and the app icon are the first two things a new user sees. Make them
say what the product is and look like one brand. Work brief → icon → DMG; each step
reads the brief, so the assets stay consistent.

| Output | What it is |
| --- | --- |
| `docs/BRAND.md` | The brief: promise, personality, motif, palette. Source for every asset |
| `Bundle/AppIcon.icon/` | `icon.json` plus SVG layers; the build compiles it, Icon Composer edits it |
| `Bundle/DMG/` | `Background.swift` (design source), `background.png` and `@2x`, `settings.py` (layout) |

The plain DMG stays the default. Once `Bundle/DMG/settings.py` exists,
`scripts/make-dmg.sh` (and so `make release`) uses the design; delete `Bundle/DMG/` to go
back. Scripts below live in `.claude/skills/brand/scripts/` and run from the repo root.

## 1. Brief

Read `README.md`, `Bundle/app.env` and an existing `docs/BRAND.md` first. Then ask the
user, in one message, only for what is still missing:

- what the app does and for whom, in one sentence;
- three personality words (for example: calm, precise, playful);
- brand colors they already have, or a mood;
- a motif they want (an object, a shape), or none.

Propose two or three concepts in words (motif, palette, mood, one line each) and let the
user pick before drawing anything. Write the pick to `docs/BRAND.md` from
`templates/BRAND.md`.

## 2. App icon

Edit `Bundle/AppIcon.icon` in place: `icon.json` plus `Assets/*.svg`. Keep its schema
(the current file is a working example).

- Canvas: 1024 × 1024 pt. The whole canvas is the icon body; the system cuts the rounded
  square and adds the edge light, glass and shadow. Never draw the rounded square, a
  shadow or gloss yourself.
- Background: the `fill` in `icon.json`, not a layer. Forms that work: `{"solid": C}`,
  `{"linear-gradient": [C1, C2]}` (top to bottom), `{"automatic-gradient": C}`. Colors are
  strings like `"srgb:1.00000,0.67059,0.20000,1.00000"` (r, g, b, alpha) or `display-p3:…`.
- Foreground: one to three SVG layers, each with `width="1024" height="1024"
  viewBox="0 0 1024 1024"`, transparent background, flat fills. Put each depth plane in
  its own group; the first group in `groups` is the frontmost. Set `"glass": true` on the
  layer that should catch the light.
- Per group: `shadow` (`{"kind": "neutral", "opacity": 0.5}`) and `translucency`
  (`{"enabled": true, "value": 0.4}`). Leave other glass parameters to Icon Composer.
- One idea and one strong silhouette, inside the central ~65% of the canvas. At most two
  colors plus white over the fill. No text, no thin lines under ~16 pt, no tiny detail.
- Never use SF Symbols (their license forbids app icons), Apple product imagery, or
  anyone else's logo.

Check every iteration:

```bash
.claude/skills/brand/scripts/preview-icon.sh                       # → .build/brand/icon.png
.claude/skills/brand/scripts/preview-icon.sh Bundle/AppIcon.icon .build/brand/icon-32.png 32
```

Look at both images: the 512 pt one for craft, the 32 pt one (Finder list and menu
size) for whether the silhouette still reads. The preview shows what this Mac renders: Liquid Glass on macOS 26,
flattened images on macOS 14 and 15. Then tell the user to open `Bundle/AppIcon.icon` in
Icon Composer (Xcode › Open Developer Tool) to tune glass, specular, and the dark and
tinted appearances; you cannot drive that app. They save in place.

## 3. DMG window

```bash
mkdir -p Bundle/DMG && cp .claude/skills/brand/templates/DMG/* Bundle/DMG/
```

`Background.swift` is a SwiftUI view rendered to an image. Rewrite its body for the
brand; keep the struct name `DMGBackground` and its `size`, `appIcon` and `applications`
constants. Those must match `window_rect` and `icon_locations` in `settings.py`: change
them together.

- Read top to bottom in three seconds: product name, the promise (eight words at most),
  then the drag gesture from the app to Applications.
- Use the palette from the brief and the icon's motif or shapes. A soft glow or shape
  behind the app icon draws the eye to it.
- Finder places the real icons and draws their labels. Keep a clear area around each
  icon spot (128 pt icon, label below it) and keep it light: Finder always draws this
  window in light mode, so labels are black.
- A user's path bar or status bar can cover the bottom 25 pt; keep text above that.
- No text under 11 pt, no app screenshots (too small to read), one language.

Render and look at the real window:

```bash
.claude/skills/brand/scripts/render-dmg-background.sh   # → Bundle/DMG/background.png, @2x
make app && .claude/skills/brand/scripts/preview-dmg.sh # → .build/brand/dmg.png
```

`preview-dmg.sh` mounts the DMG, opens it in Finder and screenshots the window, so the
terminal needs Screen Recording permission. Without it, open `.build/brand/preview.dmg`
and look yourself, or ask the user to.

The designed DMG needs `python3` 3.10 or later for dmgbuild, which `scripts/make-dmg.sh`
installs hash-pinned into `.build/`. Its first `make release` proves the release path.

## 4. Finish

1. `make ci`.
2. Show the user `.build/brand/icon.png`, `.build/brand/icon-32.png` and
   `.build/brand/dmg.png`, and remind them to fine-tune the icon in Icon Composer.
3. Commit `docs/BRAND.md`, `Bundle/AppIcon.icon` and `Bundle/DMG`, for example
   `feat(brand): add icon and dmg design`.
