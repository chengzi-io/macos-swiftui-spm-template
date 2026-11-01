# Making the artwork

The three ways to a layer, and the rules each one keeps.

## From an image

- **SVG**: give each part that sits at its own depth its own layer file, with
  `width="1024" height="1024" viewBox="0 0 1024 1024"`, scaled into the central ~640 pt
  by a `transform`. Keep the fills; drop filters, masks and text, and check that what is
  left renders.
- **PNG or JPG**:

  ```bash
  xcrun swift <skill>/scripts/image-layer.swift <image> \
      .build/icon/a.icon/Assets/<layer>.png [size=640] [x=512] [y=512]
  ```

  Trims the image, fits it into a `size` square centered on (`x`, `y`), y down, and
  writes a 1024 × 1024 layer. An image without transparency first has its subject cut
  out by Vision, which also drops enclosed areas that match the background (a white
  window in a logo on white): look at the check, and prefer a transparent export.
- **A finished icon** (an `.iconset`, an `.icns`, an image with its own tile and
  shadow) is not a layer: the system would draw its tile around that tile. Take the mark
  from its source (an SVG, the code that drew it); without one, redraw the mark with the
  icon as the concept.

Take the fill from the logo's colors and write `icon.json`.

## Concepts

Draw six to eight concepts as black marks on a transparent 1024 canvas,
`.build/icon/concepts/<letter>-<idea>.svg`, and render them:

```bash
<skill>/scripts/concepts.sh    # → .build/icon/concepts.png
```

- Every concept is a different idea, not a variation of one. Find it in what is specific
  to this app. The category's obvious symbol (a gauge for a monitor, a gear for
  settings, a cloud for sync) is at most one concept, and it needs a twist.
- One idea, one silhouette. It must read at 32 pt: lines thinner than ~48 pt on the
  canvas (3 px at 32 pt) disappear.

## Drawing the pick

Build the pick as layers in `.build/icon/<letter>.icon` (start from a copy of
`App/Application/AppIcon.icon`), in two or three variants of color and depth.

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

## The image-model prompt

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
then place each one with `image-layer.swift`: the layout is decided there, not by the
model.
