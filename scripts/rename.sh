#!/usr/bin/env bash
# Renames the app: APP_NAME, and the Xcode project, its app and UI test targets, the
# scheme and the source folders, which carry the same name.
#
#   scripts/rename.sh NewName
#
# The bundle identifier and APP_DISPLAY_NAME stay; change them in
# Configs/Identity.xcconfig. Needs a clean working tree; review `git diff HEAD`
# (renames are staged), then commit. Close the project in Xcode first: Xcode writes its
# window state back to the old path.

source "$(dirname "$0")/common.sh"

[[ $# -eq 1 ]] || die "usage: scripts/rename.sh NewName"
old=$APP_TARGET
new=$1
[[ $new =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "the name must be letters and digits; it names the .app and the executable"
[[ $new != "$old" ]] || die "the app is already called $old"
# The project's own vocabulary: renaming the targets rewrites these words in project.pbxproj.
case $new in
    AppModules | AppRoot | AppStore | Configs | Debug | Frameworks | Products | Release | Resources | Services | ServicesLive | Sources)
        die "$new is a name the Xcode project already uses; pick another"
        ;;
esac
for path in "$new" "${new}UITests" "$new.xcodeproj"; do
    [[ ! -e $path ]] || die "$path already exists; pick another name"
done
[[ -z $(git status --porcelain) ]] || die "commit or stash your changes first, so the rename diff stays reviewable"
schemes=$old.xcodeproj/xcshareddata/xcschemes
[[ -f $schemes/$old.xcscheme ]] || die "no $schemes/$old.xcscheme"

log "rename $old to $new: Xcode project, targets, scheme, folders and APP_NAME"
sed -i '' -E \
    -e "s/(remoteInfo|path|name|productName) = $old(UITests)?(\.app|\.xctest)?;/\1 = $new\2\3;/" \
    -e "s#/\* $old(UITests)?(\.app|\.xctest)? \*/#/* $new\1\2 */#g" \
    -e "s/(PBXNativeTarget|PBXProject) \"$old(UITests)?\"/\1 \"$new\2\"/g" \
    "$old.xcodeproj/project.pbxproj"
# Every scheme, the AppStore one included, points into the project; BuildableName is
# the product, named by APP_NAME.
for scheme in "$schemes"/*.xcscheme; do
    sed -i '' -E \
        -e "s/BlueprintName = \"$old(UITests)?\"/BlueprintName = \"$new\1\"/" \
        -e "s/BuildableName = \"${old}UITests\.xctest\"/BuildableName = \"${new}UITests.xctest\"/" \
        -e "s/BuildableName = \"$APP_NAME\.app\"/BuildableName = \"$new.app\"/" \
        -e "s/container:$old\.xcodeproj/container:$new.xcodeproj/" \
        "$scheme"
done
sed -i '' -E "s/^TEST_TARGET_NAME = $old\$/TEST_TARGET_NAME = $new/" Configs/UITests.xcconfig
sed -i '' -E "s/^APP_NAME[[:space:]]*=.*/APP_NAME = $new/" Configs/Identity.xcconfig

git mv "$schemes/$old.xcscheme" "$schemes/$new.xcscheme"
git mv "$old.xcodeproj" "$new.xcodeproj"
git mv "$old" "$new"
git mv "${old}UITests" "${new}UITests"

grep -qx "TEST_TARGET_NAME = $new" Configs/UITests.xcconfig || die "TEST_TARGET_NAME in Configs/UITests.xcconfig is not $new"
for expected in "path = $new;" "path = ${new}UITests;"; do
    grep -qF "$expected" "$new.xcodeproj/project.pbxproj" || die "no '$expected' in $new.xcodeproj/project.pbxproj"
done
targets=$(xcodebuild -list -json -project "$new.xcodeproj" | plutil -extract project.targets json -o - -)
[[ $targets == *"\"$new\""* && $targets == *"\"${new}UITests\""* ]] ||
    die "$new.xcodeproj has targets $targets, expected $new and ${new}UITests"

log "renamed $old to $new; APP_DISPLAY_NAME and BUNDLE_ID stay as they were"
