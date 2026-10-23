#!/usr/bin/env bash
# Renames the app before its first release: APP_NAME, APP_DISPLAY_NAME and BUNDLE_ID,
# and the Xcode project, its app and UI test targets, the scheme and the source
# folders, which carry APP_NAME. After a release a new name or bundle identifier is a
# different app to macOS, Sparkle and Homebrew, so this refuses.
#
#   scripts/rename.sh --name NewName --bundle-id com.example.newname [--display-name "New Name"]
#
# --display-name defaults to --name. Review `git diff HEAD` (renames are staged), then
# commit. Close the project in Xcode first: Xcode writes its window state back to the
# old path.

source "$(dirname "$0")/common.sh"

usage() {
    sed -n '7p' "$0" | sed 's/^#  //' >&2
    exit 1
}

new="" bundle_id="" display_name=""
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || usage
    case $1 in
        --name) new=$2 ;;
        --bundle-id) bundle_id=$2 ;;
        --display-name) display_name=$2 ;;
        *) usage ;;
    esac
    shift 2
done
[[ -n $new && -n $bundle_id ]] || usage
display_name=${display_name:-$new}
old=$APP_TARGET

[[ $VERSION == 0.0.0 ]] ||
    die "version $VERSION has shipped; a new name or bundle id would make it a different app"
[[ $new =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "--name must be letters and digits; it names the .app and the executable"
[[ $bundle_id =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || die "--bundle-id must look like com.example.myapp"
[[ $display_name != *[\"\$\\\`\|\&]* ]] || die "--display-name cannot contain \" \$ \\ \` | or &"
# Identity.xcconfig would read the rest of the line as a comment.
[[ $display_name != *//* ]] || die "--display-name cannot contain //"
if [[ $new != "$old" ]]; then
    # The project's own vocabulary: renaming the targets rewrites these words in project.pbxproj.
    case $new in
        AppModules | AppRoot | AppStore | Configs | Debug | Frameworks | Products | Release | Resources | Services | ServicesLive | Sources)
            die "$new is a name the Xcode project already uses; pick another"
            ;;
    esac
    for path in "$new" "${new}UITests" "$new.xcodeproj"; do
        [[ ! -e $path ]] || die "$path already exists; pick another name"
    done
    schemes=$old.xcodeproj/xcshareddata/xcschemes
    [[ -f $schemes/$old.xcscheme ]] || die "no $schemes/$old.xcscheme"

    log "rename $old to $new: Xcode project, targets, scheme and folders"
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
fi

set_identity APP_NAME "$new"
set_identity APP_DISPLAY_NAME "$display_name"
set_identity BUNDLE_ID "$bundle_id"
log "the app is $new ($bundle_id), shown as \"$display_name\""
