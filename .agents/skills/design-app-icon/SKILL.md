---
name: design-app-icon
description: Create this app's icon (App/Application/AppIcon.icon, Icon Composer layers with Liquid Glass) from the user's logo or image, as drawn SVG layers, or through an image-model prompt. Renders every appearance and sets it beside installed apps. Use when the user asks for an app icon or a logo.
---

# App icon

The icon has to hold up next to the best icons in the user's Dock, in every appearance
and at 32 pt. A weak icon is worse than the template's, so nothing replaces
`App/Application/AppIcon.icon` until the user has seen the draft beside other apps and
approved it.

`<skill>` is this skill's directory, `.agents/skills/design-app-icon`. Its scripts run
from anywhere inside the project and take paths relative to the project root. Drafts and
renders go in `.build/icon/`.

## Status

Moves the `make status` icon line from `todo icon` ("App/Application/AppIcon.icon is the
template's") to `ok icon` ("the app's own AppIcon.icon").

## Before you start

- `make status`: the project line is `ok`.
- Xcode 26 is selected, with Icon Composer: its `ictool` renders the checks.
- `README.md` and `App/Configs/Identity.xcconfig` say what the app does and what it is
  called.

## Plan

Say what will change and wait for the user's go-ahead: `App/Application/AppIcon.icon`,
the whole folder, replaced by the approved draft, and one commit. Nothing else changes.

## Steps

### 1. Start

Read `README.md`, `App/Configs/Identity.xcconfig` and the current
`App/Application/AppIcon.icon` ([how it works](references/icon-json.md)). Then ask the
user, in one message, only for what is still missing:

- what the app does and for whom, in one sentence;
- a logo or image to start from, if they have one;
- colors they want, or a mood;
- two to four installed apps whose icons they like: the Dock check sets the draft
  between them.

| They have | Path |
| --- | --- |
| A logo or an image | step 2 |
| Nothing; a mark of simple shapes suits the app | step 3, then 4 |
| Nothing; it wants a character, an illustration or soft volume | step 3, then 5 |

### 2. From an image

Turn the logo into one layer file per depth: an SVG layer, or a PNG or JPG placed with
`image-layer.swift`. A finished icon with its own tile is not a layer. Take the fill from
the logo's colors and write `icon.json`. The rules and the command:
[from an image](references/artwork.md#from-an-image).

### 3. Concepts

Draw six to eight different ideas as black marks, render them with
`<skill>/scripts/concepts.sh`, and show the sheet. The user picks one or two, or asks for
another round. Rules: [concepts](references/artwork.md#concepts).

### 4. Draw

Build the pick as layers in `.build/icon/<letter>.icon` (start from a copy of
`App/Application/AppIcon.icon`), in two or three variants of color and depth. Rules:
[drawing the pick](references/artwork.md#drawing-the-pick).

### 5. Image model

For what code draws badly (a character, an illustration, soft 3D volume), give the user
one prompt per layer to generate: [the image-model prompt](references/artwork.md#the-image-model-prompt).
Reject what comes back with text, a signature, a tile or a drawn shadow, then place each
one with `image-layer.swift`: the layout is decided there, not by the model.

### 6. Check

```bash
<skill>/scripts/check-icon.sh .build/icon/a.icon [/Applications/<App>.app ...]
```

It renders macOS 26 in all six appearances, 32 pt, this Mac's Finder icon, and the icon
between installed apps at 128 pt and 32 pt, and it fails when actool rejects or warns
about the icon. What to look for: [the check sheets](references/check.md).

### 7. Approve

Show the user both sheets of each variant. They pick, ask for changes, or reject. After
two rounds without a pick, stop and say so: suggest the image-model path (step 5) if it
was not tried, or a designer. Never put a draft the user has not approved into
`App/Application/`.

### 8. Finish

1. Replace `App/Application/AppIcon.icon` with the approved draft, the whole folder, so
   no old layer file lingers.
2. `make ci`.
3. Tell the user that Icon Composer (Xcode › Open Developer Tool) edits the same file, if
   they want to tune it by hand; run `check-icon.sh` again after they save.
4. When Dock or Finder keeps showing the old icon: the built `.app` is still right. Look
   at the `.app` itself (`open -R <path>`, then Get Info) and refresh the cache with
   `killall Dock`, or log out and in.
5. Commit `App/Application/AppIcon.icon`. Before the first release (`version.txt` is
   `0.0.0`) the message is `chore(icon): set the app icon`; after it, the user picks the
   type: `feat`, `fix` or `chore`.

## Changes

| File | Change |
| --- | --- |
| `App/Application/AppIcon.icon/icon.json` | the fill, the groups and their properties |
| `App/Application/AppIcon.icon/Assets/` | one image per layer |
| `App/Application/AppIcon.icon` | replaced as a folder, so old layers go |

## The user's part

- Give the logo, the image or the colors, and name the apps whose icons they like.
- Pick a concept from the sheet, and approve the final draft.
- Generate the image-model layers, if that path is taken.

## Done when

- `check-icon.sh` passes and both sheets look right at 32 pt, in every appearance, and in
  the Dock row.
- The user approved the draft, and `make ci` exits 0 after the replacement.
- `make status` shows `ok icon`.

## Never

- Put a draft into `App/Application/` that the user has not approved.
- Draw a rounded square, a tile, a shadow or gloss: the system adds those.
- Use an SF Symbol, Apple product imagery or another brand's logo.
- Advise `make clean` when Dock or Finder shows the old icon: the build is not at fault.
