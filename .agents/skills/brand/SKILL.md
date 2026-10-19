---
name: brand
description: Design this app's brand brief and Liquid Glass app icon (Bundle/AppIcon.icon, layered SVGs for Icon Composer). Use when the user asks for an app icon, a logo or a brand look.
---

# Brand

The app icon is the first thing a new user sees, and every later asset echoes it. Work
brief → icon; the brief keeps later assets consistent. The DMG window has its own skill,
`/dmg`, which only the user starts.

| Output | What it is |
| --- | --- |
| `docs/BRAND.md` | The brief: product, personality, motif, palette. Source for every asset |
| `Bundle/AppIcon.icon/` | `icon.json` plus SVG layers; the build compiles it, Icon Composer edits it |

Scripts below live in `.agents/skills/brand/scripts/` and run from the repo root.

## 1. Brief

Read `README.md`, `Bundle/app.env` and an existing `docs/BRAND.md` first. Then ask the
user, in one message, only for what is still missing:

- what the app does and for whom, in one sentence;
- three personality words (for example: calm, precise, playful);
- brand colors they already have, or a mood;
- a motif they want (an object, a shape), or none.

Propose two or three concepts in words (motif, palette, mood, one line each) and let the
user pick before drawing anything. Write the pick, and why the others lost, to
`docs/BRAND.md` from `templates/BRAND.md`.

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
- Per group: `shadow` (`{"kind": "neutral", "opacity": 0.5}`; `"none"` for a glow) and
  `translucency` (`{"enabled": true, "value": 0.4}`). Translucency lets the fill show
  through: turn it off (`"enabled": false`) for a bright layer over a dark fill, or the
  layer goes muddy. Leave other glass parameters to Icon Composer.
- One idea and one strong silhouette, inside the central ~65% of the canvas. At most two
  colors plus white over the fill. No text, no thin lines under ~16 pt, no tiny detail.
- Use opaque colors. A warm color at low opacity over a dark fill turns brown; for a soft
  light use white at low opacity.
- Never use SF Symbols (their license forbids app icons), Apple product imagery, or
  anyone else's logo.

Check every iteration:

```bash
.agents/skills/brand/scripts/preview-icon.sh                       # → .build/brand/icon.png
.agents/skills/brand/scripts/preview-icon.sh Bundle/AppIcon.icon .build/brand/icon-32.png 32
```

Look at both images: the 512 pt one for craft, the 32 pt one (Finder list and menu
size) for whether the silhouette still reads. The preview shows what this Mac renders:
Liquid Glass on macOS 26, flattened images on macOS 14 and 15. Then tell the user to open
`Bundle/AppIcon.icon` in Icon Composer (Xcode › Open Developer Tool) to tune glass,
specular, and the dark and tinted appearances; you cannot drive that app. They save in
place.

## 3. Finish

1. `make ci`.
2. Show the user `.build/brand/icon.png` and `.build/brand/icon-32.png`, and remind them
   to fine-tune the icon in Icon Composer.
3. Commit `docs/BRAND.md` and `Bundle/AppIcon.icon`, for example
   `feat(brand): add the app icon`.
