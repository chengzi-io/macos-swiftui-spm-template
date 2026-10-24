#!/usr/bin/env bash
# Renames the app before its first release: APP_NAME, APP_DISPLAY_NAME and BUNDLE_ID,
# and what carries APP_NAME: the Xcode project App/<App>.xcodeproj, its app and UI test
# targets, the scheme and the package in Package.swift. After a release a new name or
# bundle identifier is a different app to macOS, Sparkle and Homebrew, so this refuses.
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
        Application | AppRoot | AppStore | Configs | Debug | Frameworks | Platform | PlatformLive | Products | Release | Resources | Sources | UITests)
            die "$new is a name the Xcode project already uses; pick another"
            ;;
    esac
    [[ ! -e App/$new.xcodeproj ]] || die "App/$new.xcodeproj already exists; pick another name"
    schemes=$XCODE_PROJECT/xcshareddata/xcschemes
    [[ -f $schemes/$old.xcscheme ]] || die "no $schemes/$old.xcscheme"
    grep -qx "    name: \"$old\"," Package.swift || die "Package.swift does not name the package $old"

    log "rename $old to $new: Xcode project, targets, scheme and package"
    sed -i '' -E \
        -e "s/(remoteInfo|path|name|productName) = $old(UITests)?(\.app|\.xctest)?;/\1 = $new\2\3;/" \
        -e "s#/\* $old(UITests)?(\.app|\.xctest)? \*/#/* $new\1\2 */#g" \
        -e "s/(PBXNativeTarget|PBXProject) \"$old(UITests)?\"/\1 \"$new\2\"/g" \
        "$XCODE_PROJECT/project.pbxproj"
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
    sed -i '' -E "s/^TEST_TARGET_NAME = $old\$/TEST_TARGET_NAME = $new/" App/Configs/UITests.xcconfig
    sed -i '' -E "s/^    name: \"$old\",\$/    name: \"$new\",/" Package.swift

    git mv "$schemes/$old.xcscheme" "$schemes/$new.xcscheme"
    git mv "$XCODE_PROJECT" "App/$new.xcodeproj"

    grep -qx "TEST_TARGET_NAME = $new" App/Configs/UITests.xcconfig || die "TEST_TARGET_NAME in App/Configs/UITests.xcconfig is not $new"
    grep -qx "    name: \"$new\"," Package.swift || die "Package.swift does not name the package $new"
    grep -qF "name = $new; path = ..;" "App/$new.xcodeproj/project.pbxproj" || die "App/$new.xcodeproj does not reference the package as $new"
    targets=$(xcodebuild -list -json -project "App/$new.xcodeproj" | plutil -extract project.targets json -o - -)
    [[ $targets == *"\"$new\""* && $targets == *"\"${new}UITests\""* ]] ||
        die "App/$new.xcodeproj has targets $targets, expected $new and ${new}UITests"
fi

set_identity APP_NAME "$new"
set_identity APP_DISPLAY_NAME "$display_name"
set_identity BUNDLE_ID "$bundle_id"
log "the app is $new ($bundle_id), shown as \"$display_name\""
