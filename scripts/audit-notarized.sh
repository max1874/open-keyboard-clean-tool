#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <dmg-path> [expected-version]" >&2
    exit 2
fi

dmg_path=$1
expected_version=${2-}
work_dir=$(mktemp -d -t openkeyboard-notarized-audit)
work_dir=$(CDPATH='' cd -- "$work_dir" && pwd -P)
mount_dir="$work_dir/mount"
mkdir "$mount_dir"
mounted=0

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM

    if [ "$mounted" -eq 1 ]; then
        if ! hdiutil detach "$mount_dir" >/dev/null; then
            echo "Audit cleanup failed: could not detach $mount_dir." >&2
            status=1
        fi
    fi

    if mount | grep -Fq " on $mount_dir "; then
        echo "Audit cleanup warning: $mount_dir is still mounted." >&2
        status=1
    else
        case "$(basename "$work_dir")" in
            openkeyboard-notarized-audit.*) rm -rf "$work_dir" || status=1 ;;
            *) echo "Refusing to remove unexpected audit directory: $work_dir" >&2; status=1 ;;
        esac
    fi

    exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ ! -f "$dmg_path" ]; then
    echo "Release audit failed: DMG not found: $dmg_path" >&2
    exit 1
fi

hdiutil verify "$dmg_path" >/dev/null

if ! xcrun stapler validate "$dmg_path" >/dev/null 2>&1; then
    echo "Release audit failed: the disk image carries no stapled notarization ticket." >&2
    exit 1
fi

if ! spctl --assess --type open --context context:primary-signature "$dmg_path" >/dev/null 2>&1; then
    echo "Release audit failed: Gatekeeper rejects the disk image." >&2
    spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg_path" >&2 || true
    exit 1
fi

hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg_path" >/dev/null
mounted=1

app_path="$mount_dir/OpenKeyboardCleanTool.app"
applications_link="$mount_dir/Applications"
executable="$app_path/Contents/MacOS/OpenKeyboardCleanTool"

if [ ! -d "$app_path" ]; then
    echo "Release audit failed: application bundle is missing from the DMG." >&2
    exit 1
fi

if [ ! -L "$applications_link" ] || [ "$(readlink "$applications_link")" != "/Applications" ]; then
    echo "Release audit failed: Applications must be a symlink to /Applications." >&2
    exit 1
fi

codesign --verify --deep --strict "$app_path"
signature_details=$(codesign -d --verbose=4 "$app_path" 2>&1)

if ! printf '%s\n' "$signature_details" | grep -q '^Authority=Developer ID Application: '; then
    echo "Release audit failed: the application is not signed with a Developer ID Application certificate." >&2
    exit 1
fi

if ! printf '%s\n' "$signature_details" | grep -q '^TeamIdentifier=[A-Z0-9]'; then
    echo "Release audit failed: no team identifier is embedded." >&2
    exit 1
fi

if ! printf '%s\n' "$signature_details" | grep -q '^Timestamp='; then
    echo "Release audit failed: the signature carries no secure timestamp." >&2
    exit 1
fi

if ! printf '%s\n' "$signature_details" | grep -q 'flags=.*runtime'; then
    echo "Release audit failed: the hardened runtime is not enabled." >&2
    exit 1
fi

if ! xcrun stapler validate "$app_path" >/dev/null 2>&1; then
    echo "Release audit failed: the application carries no stapled notarization ticket." >&2
    exit 1
fi

assessment=$(spctl --assess --type exec --verbose=4 "$app_path" 2>&1 || true)
if ! printf '%s\n' "$assessment" | grep -Fq "source=Notarized Developer ID"; then
    echo "Release audit failed: Gatekeeper does not report the application as notarized." >&2
    printf '%s\n' "$assessment" >&2
    exit 1
fi

if [ -n "$expected_version" ]; then
    actual_version=$(plutil -extract CFBundleShortVersionString raw "$app_path/Contents/Info.plist")
    if [ "$actual_version" != "$expected_version" ]; then
        echo "Release audit failed: expected version $expected_version, found $actual_version." >&2
        exit 1
    fi
fi

architectures=$(lipo -archs "$executable")
case " $architectures " in
    *" arm64 "*) ;;
    *) echo "Release audit failed: Apple silicon architecture is missing." >&2; exit 1 ;;
esac

echo "Release audit passed: Developer ID signature, hardened runtime, secure timestamp, stapled ticket, Gatekeeper accepts, arm64 present."
