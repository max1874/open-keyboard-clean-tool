#!/bin/sh
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
app_path="$project_dir/build/OpenKeyboardCleanTool.app"
version=$(plutil -extract CFBundleShortVersionString raw "$project_dir/Resources/Info.plist")
dmg_path="$project_dir/build/OpenKeyboardCleanTool-$version.dmg"
mkdir -p "$project_dir/build"
work_dir=$(mktemp -d "$project_dir/build/dmg-source.XXXXXX")
source_dir="$work_dir/source"
background_dir="$work_dir/background"

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM

    case "$work_dir" in
        "$project_dir"/build/dmg-source.*) rm -rf "$work_dir" || status=1 ;;
        *) echo "Refusing to remove unexpected work directory: $work_dir" >&2; status=1 ;;
    esac

    exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "Error: create-dmg is required. Install it with: brew install create-dmg" >&2
    exit 1
fi

"$project_dir/scripts/build-app.sh"
mkdir -p "$source_dir" "$background_dir"
cp -R "$app_path" "$source_dir/OpenKeyboardCleanTool.app"

qlmanage -t -s 680 -o "$background_dir" \
    "$project_dir/Resources/DMGBackground.svg" >/dev/null 2>&1
background_png="$background_dir/DMGBackground.svg.png"
test -f "$background_png"

create_image() {
    create-dmg \
        --volname "OpenKeyboardCleanTool" \
        --volicon "$app_path/Contents/Resources/AppIcon.icns" \
        --background "$background_png" \
        --window-pos 220 160 \
        --window-size 680 440 \
        --text-size 13 \
        --icon-size 112 \
        --icon "OpenKeyboardCleanTool.app" 180 235 \
        --hide-extension "OpenKeyboardCleanTool.app" \
        --app-drop-link 500 235 \
        --filesystem APFS \
        --format UDZO \
        --applescript-sleep-duration 8 \
        --overwrite \
        "$dmg_path" \
        "$source_dir"
}

clean_intermediate_images() {
    find "$project_dir/build" -maxdepth 1 -type f \
        -name "rw.*.$(basename "$dmg_path")" -delete
}

clean_intermediate_images
attempt=1
while ! create_image
do
    clean_intermediate_images
    if [ "$attempt" -ge 3 ]; then
        echo "Error: create-dmg failed after $attempt attempts." >&2
        exit 1
    fi

    attempt=$((attempt + 1))
    echo "Retrying create-dmg after Finder layout failure (attempt $attempt of 3)..." >&2
    sleep 2
done

hdiutil verify "$dmg_path" >/dev/null
echo "$dmg_path"
shasum -a 256 "$dmg_path"
