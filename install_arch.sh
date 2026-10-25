#!/usr/bin/env bash
set -euo pipefail

echo "=== StreamEast Arch Linux Installer ==="

# 1. Install system dependencies (GTK3, MPV/libmpv, CMake, Ninja, Clang)
echo "[1/4] Checking and installing system dependencies via pacman..."
sudo pacman -S --needed --noconfirm base-devel clang cmake ninja pkgconf gtk3 mpv git curl unzip xz

# 2. Ensure Flutter SDK is available
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="$HOME/.local/share/flutter"
  if [ ! -d "$FLUTTER_DIR" ]; then
    echo "[2/4] Flutter not found in PATH. Cloning Flutter stable SDK to $FLUTTER_DIR..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
else
  echo "[2/4] Using existing Flutter SDK: $(command -v flutter)"
fi

flutter config --enable-linux-desktop

# 3. Build Release Bundle
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[3/4] Fetching Dart packages and building Linux release..."
flutter pub get
flutter build linux --release

# 4. Install to ~/.local/share/streameast and create .desktop entry
INSTALL_DIR="$HOME/.local/share/streameast"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"

echo "[4/4] Installing StreamEast to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APP_DIR" "$ICON_DIR"

cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"
cp icon.png "$ICON_DIR/streameast.png"
ln -sf "$INSTALL_DIR/iptv_app" "$BIN_DIR/streameast"

cat > "$APP_DIR/streameast.desktop" <<EOF
[Desktop Entry]
Name=StreamEast
Comment=Asian Live TV (Japan, South Korea, China) IPTV Player
Exec=$INSTALL_DIR/iptv_app
Icon=$ICON_DIR/streameast.png
Terminal=false
Type=Application
Categories=AudioVideo;Video;Player;TV;
StartupWMClass=com.example.iptv_app
EOF

echo "=== Installation Complete! ==="
echo "Run with: $INSTALL_DIR/iptv_app (or 'streameast' from your app launcher)"
