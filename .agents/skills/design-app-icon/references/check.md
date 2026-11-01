# Reading the check sheets

`check-icon.sh` writes two sheets into `.build/icon/`; look at both after every change,
and fix before showing the user.

| Sheet | Shows |
| --- | --- |
| `<name>-check.png` | macOS 26 in all six appearances (ictool, Icon Composer's renderer, works on any macOS with Xcode 26), 32 pt, and this Mac's Finder icon (the flattened image on macOS 14 and 15) |
| `<name>-dock.png` | this Mac's rendering between the apps given (default Safari, Notes, Photos, App Store), at 128 pt and 32 pt |

It fails when actool rejects the icon or warns about it (a missing layer image), and when
`icon.json` has a property name this Xcode ignores (a typo, or one from a newer Icon
Composer).

- 32 pt: the silhouette reads; nothing turns to mush.
- Dark, Tinted, Clear: every element stays visible; none sinks into the fill.
- No stray lines, muddy translucency or cropped edges.
- Dock row: it holds its own beside the neighbors in weight, finish and simplicity; it
  is not smaller, busier or flatter than they are.
