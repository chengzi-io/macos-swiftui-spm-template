# How `AppIcon.icon` works

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
- macOS 14 and 15 show flattened images that actool bakes from the same file.

## Properties

Everything Icon Composer sets lives in `icon.json`; write it directly. `C` is a color
string: `"srgb:1.00000,0.67059,0.20000,1.00000"` (r, g, b, alpha), `display-p3:…`, or
`gray:1.00000,1.00000` (white, alpha). The current `App/Application/AppIcon.icon` is a
working example.

| Where | Property | Value | Effect |
| --- | --- | --- | --- |
| root | `fill` | `{"solid": C}`, `{"linear-gradient": [C1, C2]}` (top to bottom), `{"automatic-gradient": C}` | The background |
| group | `shadow` | `{"kind": "neutral" \| "layer-color" \| "none", "opacity": 0–1}` | The shadow on the groups behind |
| group | `translucency` | `{"enabled": true, "value": 0–1}` | Lets the fill show through; off for a bright layer over a dark fill, which goes muddy |
| group | `specular` | `true` / `false` | The bright glass edge; off for a matte shape |
| group | `blur-material` | `null` or 0–1 | Frosts what is behind the group |
| group | `lighting` | `"combined"` / `"individual"` | Lights the group's layers as one shape, or each on its own |
| group, layer | `blend-mode` | `"normal"`, `"screen"`, `"hard-light"`, `"plus-darker"`, `"darken"`… | How it mixes with what is behind |
| group, layer | `opacity`, `hidden` | 0–1; `true` / `false` | |
| group, layer | `position` | `{"scale": 1, "translation-in-points": [x, y]}`, y down | Moves or resizes without touching the image |
| layer | `glass` | `true` / `false` | The layer catches the light |
| layer | `fill` | as the root `fill` | Repaints the whole layer in one color or gradient, replacing the image's colors |

## Specializations

Any property can differ by appearance: write `"<property>-specializations"` instead, a
list of `{"value": …}` for the default and `{"appearance": "dark" | "tinted", "value": …}`
entries. A darker background in Dark only:

```json
"fill-specializations" : [
  { "value" : { "linear-gradient" : [ "srgb:1.00000,0.67059,0.20000,1.00000", "srgb:0.98039,0.40000,0.00000,1.00000" ] } },
  { "appearance" : "dark", "value" : { "solid" : "srgb:0.16000,0.10000,0.05000,1.00000" } }
]
```

Reach for them when the check shows a problem: a layer that vanishes in Dark gets a
`fill` for `dark`; a detail that turns to mush in Tinted gets `hidden` for `tinted`; a
mark that sits off center gets a `position`. actool rejects bad values, and
`check-icon.sh` rejects property names this Xcode ignores (a typo, or one from a newer
Icon Composer).
