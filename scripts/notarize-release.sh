#!/bin/sh
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
build_dir="$project_dir/build"
app_path="$build_dir/OpenKeyboardCleanTool.app"
version=$(plutil -extract CFBundleShortVersionString raw "$project_dir/Resources/Info.plist")
dmg_path="$build_dir/OpenKeyboardCleanTool-$version.dmg"
work_dir=$(mktemp -d -t openkeyboard-notarize)
work_dir=$(CDPATH='' cd -- "$work_dir" && pwd -P)

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM

    case "$(basename "$work_dir")" in
        openkeyboard-notarize.*) rm -rf "$work_dir" || status=1 ;;
        *) echo "Refusing to remove unexpected work directory: $work_dir" >&2; status=1 ;;
    esac

    exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ "${SIGN_IDENTITY+x}" = "x" ]; then
    signing_identity=$SIGN_IDENTITY
else
    signing_identity=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
        | sed -n '1p')
fi

case "$signing_identity" in
    "Developer ID Application"*) ;;
    *)
        echo "Error: notarization requires a Developer ID Application certificate." >&2
        echo "None is installed, and SIGN_IDENTITY does not name one." >&2
        echo "Create one at developer.apple.com as the Account Holder, then import it into the login keychain." >&2
        exit 1
        ;;
esac

if [ -n "${ASC_P8_PATH-}" ] && [ -n "${ASC_KEY_ID-}" ] && [ -n "${ASC_ISSUER_ID-}" ]; then
    key_path=$ASC_P8_PATH
    key_id=$ASC_KEY_ID
    issuer_id=$ASC_ISSUER_ID
else
    credentials_file=${ASC_CREDENTIALS_FILE-}
    if [ -z "$credentials_file" ] || [ ! -f "$credentials_file" ]; then
        echo "Error: no App Store Connect credentials." >&2
        echo "Set ASC_P8_PATH, ASC_KEY_ID and ASC_ISSUER_ID, or point ASC_CREDENTIALS_FILE at a three-line" >&2
        echo "file holding the .p8 path, the key id and the issuer id." >&2
        exit 1
    fi
    key_path=$(sed -n '1p' "$credentials_file")
    key_id=$(sed -n '2p' "$credentials_file")
    issuer_id=$(sed -n '3p' "$credentials_file")
fi

if [ ! -f "$key_path" ] || [ -z "$key_id" ] || [ -z "$issuer_id" ]; then
    echo "Error: incomplete App Store Connect credentials (key path, key id, issuer id)." >&2
    exit 1
fi

# notarytool exits non-zero when the submission is rejected, but the reason only
# comes back from the log endpoint, so keep the id and fetch it before failing.
submit() {
    submission_output="$work_dir/notarytool-output.txt"
    # Not piped into tee: in a pipeline the shell reports tee's status, which
    # would turn a rejected submission into a successful build.
    if xcrun notarytool submit "$1" \
        --key "$key_path" \
        --key-id "$key_id" \
        --issuer "$issuer_id" \
        --wait \
        --timeout 30m > "$submission_output" 2>&1
    then
        cat "$submission_output"
        if grep -q '^ *status: Accepted$' "$submission_output"; then
            return 0
        fi
        echo "Notarization did not end in the Accepted state." >&2
    else
        cat "$submission_output" >&2
    fi

    submission_id=$(sed -n 's/^ *id: \([0-9a-f-]*\)$/\1/p' "$submission_output" | sed -n '1p')
    if [ -n "$submission_id" ]; then
        echo "Notarization failed. Log for submission $submission_id:" >&2
        xcrun notarytool log "$submission_id" \
            --key "$key_path" \
            --key-id "$key_id" \
            --issuer "$issuer_id" >&2 || true
    fi
    return 1
}

echo "==> Building and signing with: $signing_identity"
SIGN_IDENTITY="$signing_identity" "$project_dir/scripts/build-app.sh" >/dev/null

echo "==> Notarizing the application bundle"
ditto -c -k --keepParent "$app_path" "$work_dir/OpenKeyboardCleanTool.zip"
submit "$work_dir/OpenKeyboardCleanTool.zip"
xcrun stapler staple "$app_path"

echo "==> Building the disk image around the stapled application"
SKIP_APP_BUILD=1 "$project_dir/scripts/build-dmg.sh" >/dev/null

echo "==> Notarizing the disk image"
codesign --force --timestamp --sign "$signing_identity" "$dmg_path"
submit "$dmg_path"
xcrun stapler staple "$dmg_path"

# Recorded as a bare filename so `shasum -a 256 -c` works next to the download,
# and so the maintainer's build path never ships as a release asset.
dmg_name=$(basename "$dmg_path")
(cd "$build_dir" && shasum -a 256 "$dmg_name" > "$dmg_name.sha256")

echo "==> Auditing the notarized release"
"$project_dir/scripts/audit-notarized.sh" "$dmg_path" "$version"

echo "$dmg_path"
cat "$dmg_path.sha256"
