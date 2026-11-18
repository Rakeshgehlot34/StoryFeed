#!/usr/bin/env bash
# ==============================================================================
# scripts/gen_icons.sh
# Generates Android adaptive icons, monochrome icons, notification icons,
# Play Store 512x512 icon, and 1024x500 feature graphic from SVG branding assets.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_SVG="$PROJECT_ROOT/assets/branding/app_icon.svg"
MONO_SVG="$PROJECT_ROOT/assets/branding/app_icon_monochrome.svg"

RES_DIR="$PROJECT_ROOT/android/app/src/main/res"
BRANDING_DIR="$PROJECT_ROOT/assets/branding"

echo "🎨 Generating ShortsSplitter branding and launcher icons..."

if [ ! -f "$SOURCE_SVG" ]; then
  echo "❌ Error: Source SVG not found at $SOURCE_SVG"
  exit 1
fi

mkdir -p "$BRANDING_DIR"
mkdir -p "$RES_DIR/drawable"

# 1. Play Store Icon (512x512)
echo "Generating Play Store icon (512x512)..."
convert -background none -size 512x512 "$SOURCE_SVG" "$BRANDING_DIR/play_store_512.png"

# 2. Feature Graphic (1024x500)
echo "Generating Feature Graphic (1024x500)..."
python3 - <<EOF
from PIL import Image, ImageDraw, ImageFont

bg = Image.new("RGBA", (1024, 500), (28, 25, 42, 255))
icon = Image.open("$BRANDING_DIR/play_store_512.png").convert("RGBA")
icon = icon.resize((320, 320), Image.Resampling.LANCZOS)
bg.paste(icon, (90, 90), icon)

draw = ImageDraw.Draw(bg)
# Title & Subtitle
draw.text((450, 180), "ShortsSplitter", fill=(255, 255, 255, 255))
draw.text((450, 240), "Creative On-Device Video Studio", fill=(0, 229, 255, 255))
draw.text((450, 280), "Split • Edit • Convert • Audio • Screenshot • Merge", fill=(208, 188, 255, 255))

bg.save("$BRANDING_DIR/feature_graphic_1024x500.png")
EOF

# 3. Small Notification Icon (White silhouette on transparent, 24x24 / 48x48)
echo "Generating Notification icons..."
convert -background none -size 48x48 "$MONO_SVG" "$RES_DIR/drawable/ic_notification.png"

# 4. Adaptive Mipmap Icons & Round Icons
MIPMAP_SIZES=(
  "mipmap-mdpi:48:108"
  "mipmap-hdpi:72:162"
  "mipmap-xhdpi:96:216"
  "mipmap-xxhdpi:144:324"
  "mipmap-xxxhdpi:192:432"
)

for entry in "${MIPMAP_SIZES[@]}"; do
  IFS=":" read -r folder legacy_size adaptive_size <<< "$entry"
  DIR="$RES_DIR/$folder"
  mkdir -p "$DIR"

  # Legacy square launcher icon
  convert -background none -size "${legacy_size}x${legacy_size}" "$SOURCE_SVG" "$DIR/ic_launcher.png"

  # Legacy round icon
  convert -background none -size "${legacy_size}x${legacy_size}" "$SOURCE_SVG" "$DIR/ic_launcher_round.png"

  # Adaptive icon foreground
  convert -background none -size "${adaptive_size}x${adaptive_size}" "$SOURCE_SVG" "$DIR/ic_launcher_foreground.png"

  # Monochrome layer (for Android 13+ themed icons)
  convert -background none -size "${adaptive_size}x${adaptive_size}" "$MONO_SVG" "$DIR/ic_launcher_monochrome.png"
done

echo "✅ All icons generated successfully!"

