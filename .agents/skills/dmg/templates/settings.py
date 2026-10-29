# dmgbuild settings for the installer window: https://dmgbuild.readthedocs.io
# scripts/make-dmg.sh runs it from the repo root with -D app=<path to the .app>.
# Points from the content's top-left. Background.swift draws for the same geometry:
# change both together.
import os.path

app = defines["app"]
app_name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
# No hide_extensions: it sets FinderInfo on the .app, which fails codesign --strict.
# The mounted volume shows the app icon.
icon = os.path.join(app, "Contents/Resources/AppIcon.icns")

# dmgbuild pairs background.png with background@2x.png for Retina screens.
background = "App/Configs/DMG/background.png"
# The window size includes the 28 pt title bar: 660 × 400 of content.
window_rect = ((200, 120), (660, 428))
icon_size = 128
text_size = 13
icon_locations = {app_name: (170, 200), "Applications": (490, 200)}
