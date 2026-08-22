#!/usr/bin/env bash
# Packages the release build produced by `flutter build linux --release`
# into an installable .deb.
#
# Run from the repo root:
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
  "$STAGE/usr/share/applications"

cp -r "$BUNDLE_DIR"/. "$STAGE/usr/lib/$PKG_NAME/"

cat > "$STAGE/usr/bin/$PKG_NAME" <<'LAUNCHER'
#!/usr/bin/env bash
cd /usr/lib/flowcraft
exec ./flowcraft "$@"
LAUNCHER
chmod +x "$STAGE/usr/bin/$PKG_NAME"

cp linux/packaging/flowcraft.desktop "$STAGE/usr/share/applications/flowcraft.desktop"
# Launcher icons. Generated from assets/branding/flowcraft-icon-1024.png by
# `python3 tool/generate_icons.py`; the name must match Icon= in the .desktop
# file and the gtk_window_set_icon_name() call in linux/runner/my_application.cc.
for size in 128 256 512; do
  mkdir -p "$STAGE/usr/share/icons/hicolor/${size}x${size}/apps"
  cp "linux/packaging/icons/flowcraft-${size}.png" \
    "$STAGE/usr/share/icons/hicolor/${size}x${size}/apps/flowcraft.png"
done

# Depends: what a Flutter Linux bundle dlopens at runtime. The CI runner has
# libgtk-3-dev installed so the build never notices when these are missing;
# `apt install ./flowcraft_*.deb` on a minimal system needs them spelled out.
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0 (>= 3.22), libglib2.0-0, libstdc++6, libgcc-s1, libc6
Maintainer: Alisher Axmedov <alisheraxmedov@users.noreply.github.com>
Homepage: https://github.com/alisheraxmedov/flowcraft-app
Installed-Size: $(du -sk "$STAGE/usr" | cut -f1)
Description: Local-first whiteboard with a built-in MCP server
 FlowCraft is an infinite-canvas whiteboard and diagramming app with a
 hand-drawn rendering style. It embeds a Model Context Protocol (MCP)
 server on 127.0.0.1:5199 so AI coding agents such as Claude Code, Codex
 CLI and Gemini CLI can draw architecture diagrams live on the canvas.
 No account, no cloud, works offline.
EOF

dpkg-deb --build --root-owner-group "$STAGE"
echo "Built ${STAGE}.deb"
