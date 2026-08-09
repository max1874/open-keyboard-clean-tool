#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <dmg-path> [expected-version]" >&2
    exit 2
fi

dmg_path=$1
expected_version=${2-}
work_dir=$(mktemp -d -t openkeyboard-release-audit)
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
            openkeyboard-release-audit.*) rm -rf "$work_dir" || status=1 ;;
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

if ! printf '%s\n' "$signature_details" | grep -Fxq "Signature=adhoc"; then
    echo "Release audit failed: application is not ad-hoc signed." >&2
    exit 1
fi

if ! printf '%s\n' "$signature_details" | grep -Fxq "TeamIdentifier=not set"; then
    echo "Release audit failed: a signing team identifier is embedded." >&2
    exit 1
fi

if printf '%s\n' "$signature_details" | grep -q '^Authority='; then
    echo "Release audit failed: a signing certificate authority is embedded." >&2
    exit 1
fi

certificate_prefix="$work_dir/extracted-certificate"
codesign -d --extract-certificates="$certificate_prefix" "$app_path" >/dev/null 2>&1 || true
if find "$work_dir" -maxdepth 1 -type f -name 'extracted-certificate*' | grep -q .; then
    echo "Release audit failed: an identity certificate is embedded." >&2
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

identity_pattern='Users/[[:alnum:]_.-]+/|Apple (Development|Distribution):|[[:alnum:]_.%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}'
identity_matches="$work_dir/identity-matches.txt"
: > "$identity_matches"

find "$mount_dir" -type f -print | while IFS= read -r file_path
do
    matches=$(strings -a "$file_path" \
        | LC_ALL=C grep -E "$identity_pattern" \
        | grep -Ev '^icon_[0-9]+x[0-9]+@2x\.png$' \
        || true)
    if [ -n "$matches" ]; then
        printf '%s\n%s\n' "$file_path" "$matches" >> "$identity_matches"
    fi
done

if [ -s "$identity_matches" ]; then
    echo "Release audit failed: printable identity-bearing content was found." >&2
    cat "$identity_matches" >&2
    exit 1
fi

echo "Release audit passed: ad-hoc signature, no certificate identity, arm64 present, privacy scan clean."
