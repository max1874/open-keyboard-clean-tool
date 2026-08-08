#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_png="$project_dir/Resources/AppIcon.png"
iconset_dir="$project_dir/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$iconset_dir"

for size in 16 32 128 256 512; do
    double_size=$((size * 2))
    sips -z "$size" "$size" "$source_png" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    sips -z "$double_size" "$double_size" "$source_png" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done

echo "$iconset_dir"
