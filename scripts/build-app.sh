#!/bin/sh
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$project_dir/build/OpenKeyboardCleanTool.app"
contents_dir="$app_dir/Contents"
module_cache="$project_dir/.build/clang-module-cache"
identity_file="$project_dir/.signing-identity"

if [ "${SIGN_IDENTITY+x}" = "x" ]; then
    signing_identity=$SIGN_IDENTITY
elif [ -f "$identity_file" ]; then
    IFS= read -r signing_identity < "$identity_file"
else
    signing_identity=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' \
        | sed -n '1p')
fi

cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache"
swift build --disable-sandbox -c release --product OpenKeyboardCleanTool -Xswiftc -gnone

case "$app_dir" in
    "$project_dir"/build/OpenKeyboardCleanTool.app) rm -rf "$app_dir" ;;
    *) echo "Refusing to remove unexpected app directory: $app_dir" >&2; exit 1 ;;
esac
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp ".build/release/OpenKeyboardCleanTool" "$contents_dir/MacOS/OpenKeyboardCleanTool"
cp "Resources/Info.plist" "$contents_dir/Info.plist"
xcrun actool "Resources/Assets.xcassets" \
    --compile "$contents_dir/Resources" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$project_dir/build/asset-info.plist" \
    >/dev/null
if [ "$signing_identity" = "-" ]; then
    codesign --force --sign - "$app_dir"
    echo "Warning: ad-hoc signing was explicitly requested; Accessibility permission may need to be granted again after rebuilding." >&2
elif [ -n "$signing_identity" ]; then
    codesign --force --sign "$signing_identity" "$app_dir"
    echo "Signed with: $signing_identity"
else
    echo "Error: no Apple Development signing identity found." >&2
    echo "Set SIGN_IDENTITY to a certificate name, or explicitly use SIGN_IDENTITY=- for an ad-hoc one-off build." >&2
    exit 1
fi

echo "$app_dir"
