---
name: app-icon
description: Create this app's icon (Bundle/AppIcon.icon, Icon Composer layers with Liquid Glass) from the user's logo or image, as drawn SVG layers, or through an image-model prompt. Renders every appearance and sets it beside installed apps. Use when the user asks for an app icon or a logo.
---

# App icon

The icon has to hold up next to the best icons in the user's Dock, in every appearance
and at 32 pt. A weak icon is worse than the template's, so nothing replaces
`Bundle/AppIcon.icon` until the user has seen the draft beside other apps and approved it.

Scripts live in `.agents/skills/app-icon/scripts/` and run from the repo root. Drafts and
renders go in `.build/app-icon/`.

## How the icon works

```text
AppIcon.icon/
├── icon.json   fill (the background) and up to 4 groups, front first; each holds layers
└── Assets/     one image per layer: SVG, or PNG with transparency
```

- The system cuts the rounded square and adds the edge light, the glass, the shadows
  between groups, and the Dark, Tinted and Clear appearances, which it derives layer by
  layer. Never draw a rounded square, a tile, a shadow or gloss.
- Canvas: 1024 × 1024 pt. A group in front casts a shadow on the groups behind it. Use
  two or three: the main shape behind, a smaller accent in front. actool rejects more
  than four.
- `fill`: `{"solid": C}`, `{"linear-gradient": [C1, C2]}` (top to bottom) or
  `{"automatic-gradient": C}`. Colors are strings such as
  `"srgb:1.00000,0.67059,0.20000,1.00000"` (r, g, b, alpha) or `display-p3:…`.
- Layer: `"glass": true` catches the light. Group: `shadow`
  (`{"kind": "neutral", "opacity": 0.5}`) and `translucency`
  (`{"enabled": true, "value": 0.4}`); turn translucency off for a bright layer over a
  dark fill, or it goes muddy. The current `Bundle/AppIcon.icon` is a working example.
- Icon Composer offers more (specular, blur, lighting, blend modes, values per
  appearance). Their file format is unchecked here: leave them to the user in Icon
  Composer.
- macOS 14 and 15 show flattened images that actool bakes from the same file.

## 1. Start

Read `README.md`, `Bundle/app.env` and the current `Bundle/AppIcon.icon`. Then ask the
user, in one message, only for what is still missing:

- what the app does and for whom, in one sentence;
- a logo or image to start from, if they have one;
- colors they want, or a mood;
- two to four installed apps whose icons they like: the Dock check sets the draft
  between them.

| They have | Path |
| --- | --- |
| A logo or an image | 2. From an image |
| Nothing; a mark of simple shapes suits the app | 3. Concepts, then 4. Draw |
| Nothing; it wants a character, an illustration or soft volume | 3. Concepts, then 5. Image model |

## 2. From an image

- **SVG**: give each part that sits at its own depth its own layer file, with
  `width="1024" height="1024" viewBox="0 0 1024 1024"`, scaled into the central ~640 pt
  by a `transform`. Keep the fills; drop filters, masks and text, and check that what is
  left renders.
- **PNG or JPG**:

  ```bash
  xcrun swift .agents/skills/app-icon/scripts/image-layer.swift <image> \
      .build/app-icon/a.icon/Assets/<layer>.png [size=640] [x=512] [y=512]
  ```

  Trims the image, fits it into a `size` square centered on (`x`, `y`), y down, and
  writes a 1024 × 1024 layer. An image without transparency first has its subject cut
  out by Vision, which also drops enclosed areas that match the background (a white
  window in a logo on white): look at the check, and prefer a transparent export.
- **A finished icon** (an `.iconset`, an `.icns`, an image with its own tile and
  shadow) is not a layer: the system would draw its tile around that tile. Take the mark
  from its source (an SVG, the code that drew it); without one, redraw the mark (4)
  with the icon as the concept.

Take the fill from the logo's colors, write `icon.json`, then check (6).

## 3. Concepts

Draw six to eight concepts as black marks on a transparent 1024 canvas,
`.build/app-icon/concepts/<letter>-<idea>.svg`, and render them:

```bash
.agents/skills/app-icon/scripts/concepts.sh    # → .build/app-icon/concepts.png
```

- Every concept is a different idea, not a variation of one. Find it in what is specific
  to this app. The category's obvious symbol (a gauge for a monitor, a gear for
  settings, a cloud for sync) is at most one concept, and it needs a twist.
- One idea, one silhouette. It must read at 32 pt: lines thinner than ~48 pt on the
  canvas (3 px at 32 pt) disappear.

Show the sheet. The user picks one or two, or asks for another round.

## 4. Draw

Build the pick as layers in `.build/app-icon/<letter>.icon` (start from a copy of
`Bundle/AppIcon.icon`), in two or three variants of color and depth.

- Construct it: circles, arcs, rounded rectangles, one stroke width and one corner
  radius throughout. Center it optically, a touch above the geometric center.
- Keep the mark inside the central ~640 pt: the rounded square crops near the edges.
- Every shape is a filled outline. Under glass, a stroked open path shows a faint line
  across its chord.
- Light or saturated marks (white, a bright color) over a darker or saturated fill. A
  dark mark on a light fill vanishes in the Dark and Tinted appearances.
- At most two colors plus white over the fill, all opaque. A warm color at low opacity
  over a dark fill turns brown; for a soft light use white at low opacity. Gradients in
  the SVG render; keep them subtle, the glass adds its own.
- A layer that is easier to compute than to write (a pixel grid, a pattern) can come
  from a Swift script that renders a 1024 × 1024 PNG; the same rules apply.
- Never SF Symbols (their license forbids app icons), Apple product imagery, or another
  brand's logo.

## 5. Image model

For what code draws badly (a character, an illustration, soft 3D volume), write one
prompt per layer and hand them to the user to generate (ChatGPT or another image model).
Each element is generated alone, so it can sit at its own depth:

```text
App icon artwork: <one element, for example "a round white robot head with two tall oval eyes">.
Square, 1024 × 1024 pixels, transparent background (PNG with alpha).
Style: <for example "smooth glossy 3D, soft light from the top left">. Colors: <hex colors>.
- The element alone: no rounded square, tile, frame, background, ground shadow, glow,
  reflection or border; the app icon system adds those.
- Centered, about 70% of the canvas wide, touching no edge.
- Bold, simple forms that still read at 32 pixels: no thin lines, no small details.
- No text, letters, numbers, logos, signature or watermark.
```

When the images come back, reject any with text, a signature, a tile or a drawn shadow,
then place each one with `image-layer.swift` (2): the layout is decided there, not by
the model.

## 6. Check

```bash
.agents/skills/app-icon/scripts/check-icon.sh .build/app-icon/a.icon [/Applications/<App>.app ...]
```

- `.build/app-icon/a-check.png`: macOS 26 in all six appearances (ictool, Icon
  Composer's renderer, works on any macOS with Xcode 26), 32 pt, and this Mac's Finder
  icon (the flattened image on macOS 14 and 15).
- `.build/app-icon/a-dock.png`: this Mac's rendering between the apps given (default
  Safari, Notes, Photos, App Store), at 128 pt and 32 pt.
- It fails when actool rejects the icon or warns about it (a missing layer image).

Look at both sheets after every change, and fix before showing the user:

- 32 pt: the silhouette reads; nothing turns to mush.
- Dark, Tinted, Clear: every element stays visible; none sinks into the fill.
- No stray lines, muddy translucency or cropped edges.
- Dock row: it holds its own beside the neighbors in weight, finish and simplicity; it
  is not smaller, busier or flatter than they are.

## 7. Approve

Show the user both sheets of each variant. They pick, ask for changes, or reject. After
two rounds without a pick, stop and say so: suggest the image-model path (5) if it was
not tried, or a designer. Never put a draft the user has not approved into `Bundle/`.

## 8. Finish

1. Replace `Bundle/AppIcon.icon` with the approved draft, old layer files included.
2. `make ci`.
3. Tell the user they can fine-tune glass, specular and the per-appearance looks in Icon
   Composer (Xcode › Open Developer Tool) and save in place.
4. Commit `Bundle/AppIcon.icon`, for example `feat(icon): add the app icon`.
