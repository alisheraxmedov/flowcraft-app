#!/usr/bin/env bash
# Packages the release build produced by `flutter build linux --release`
# into an installable .deb.
#
# Run from the `example/` directory:
#   VERSION=1.2.3 bash linux/packaging/build_deb.sh
#
# Used by .github/workflows/build-desktop.yml; safe to run locally too
# (on a Debian/Ubuntu machine with dpkg-deb available).
set -euo pipefail

VERSION="${VERSION:-0.0.0}"
ARCH="amd64"
PKG_NAME="flowcraft"
BUNDLE_DIR="build/linux/x64/release/bundle"
STAGE="dist/${PKG_NAME}_${VERSION}_${ARCH}"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "error: $BUNDLE_DIR not found — run 'flutter build linux --release' first" >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p \
  "$STAGE/DEBIAN" \
  "$STAGE/usr/lib/$PKG_NAME" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/256x256/apps"

cp -r "$BUNDLE_DIR"/. "$STAGE/usr/lib/$PKG_NAME/"

cat > "$STAGE/usr/bin/$PKG_NAME" <<'LAUNCHER'
#!/usr/bin/env bash
cd /usr/lib/flowcraft
exec ./flowcraft_example "$@"
LAUNCHER
chmod +x "$STAGE/usr/bin/$PKG_NAME"

cp linux/packaging/flowcraft.desktop "$STAGE/usr/share/applications/flowcraft.desktop"
cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png \
  "$STAGE/usr/share/icons/hicolor/256x256/apps/flowcraft.png"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Maintainer: FlowCraft <noreply@example.com>
Description: FlowCraft Whiteboard
 Miro / Excalidraw-style interactive whiteboard, built with Flutter.
EOF

dpkg-deb --build --root-owner-group "$STAGE"
echo "Built ${STAGE}.deb"
