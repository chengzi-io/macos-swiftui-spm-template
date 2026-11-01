# The three brand levels

| Level | What changes |
| --- | --- |
| Default | Nothing: finish here |
| Light brand | A soft gradient in the icon's colors, and an arrow drawn from the icon's motif |
| Full brand | An illustration or texture from the icon's world that leads to Applications, by its composition or a custom arrow; icon spots moved to fit the scene |

## Light brand

- Gradient: two or three of the icon's colors, mixed with 85–95% white so black labels
  read on every part of it.
- Arrow: drawn from the motif, between the icons, pointing from the app to
  Applications. For example the icon's chevron, a row of its dots, paw prints, a pulse
  line, a pixel arrow.

Make two or three variants. For each, write `App/Configs/DMG/Background.swift`, render,
preview, then keep the source as `.build/dmg/<letter>.swift` and the screenshot as
`.build/dmg/<letter>.png`. Show the user the screenshots with one line each on the idea,
and let them pick or adjust in plain words ("thinner arrow", "less color"). Copy the pick
back to `App/Configs/DMG/Background.swift` and render again.

## Full brand

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

Drawn in code: write it in `Background.swift` and make variants as in the light brand.
Turn figures toward Applications from the constants, so they stay right when the icons
move:

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
   numbers below are for the geometry in `templates/`, checked in a real Finder window: a
   3:2 image is scaled to 660 pt wide (440 pt tall) and loses 20 pt at the top and
   bottom. Recompute them if you moved the icons. Pick how the art leads to Applications
   with the scene, and write that choice as the Direction line: a code arrow over the art
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
   `App/Configs/DMG/art.png` (`sips -s format png <file> --out App/Configs/DMG/art.png`
   converts a JPEG or WebP). It needs at least 1320 × 800 px after the crop; a smaller one
   blurs on Retina, so ask for a larger one.
3. Draw it as the bottom layer in `Background.swift`:

   ```swift
   import AppKit

   // In DMGBackground. The renderer runs from the repo root.
   static let art: NSImage = {
       guard let image = NSImage(contentsOfFile: "App/Configs/DMG/art.png") else {
           fatalError("cannot read App/Configs/DMG/art.png")
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
   draw an arrow over the art in code. If the art crowds an icon or a label, move the icon
   spots, put a soft white glow under the label, or write a revised prompt that says what
   to change and ask the user to generate again.
