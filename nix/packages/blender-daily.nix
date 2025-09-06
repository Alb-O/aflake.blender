{ writeShellScriptBin
, curl
, jq
, gnutar
, patchelf
, glibc
, gcc-unwrapped
, xorg
, libdecor
, libGL
, libGLU
, libxkbcommon
, freetype
, zlib
, glib
, alsa-lib
, pulseaudio
, fontconfig
, dbus
, wayland
, stdenv
, lib
}:

writeShellScriptBin "blender-daily" ''
  set -euo pipefail

  CACHE_DIR="$HOME/.cache/blender-daily"
  INSTALL_DIR="$HOME/.local/share/blender-daily"
  CURRENT_LINK="$INSTALL_DIR/current"

  # Parse command line arguments
  UPDATE_BUILD=false
  BLENDER_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --update|--download)
        UPDATE_BUILD=true
        shift
        ;;
      -h|--help)
        echo "Usage: blender-daily [--update|--download] [blender arguments...]"
        echo ""
        echo "Options:"
        echo "  --update, --download    Download newer daily build if available"
        echo "  -h, --help             Show this help message"
        echo ""
        echo "By default, uses existing installation or latest available build."
        echo "Use --update to check for and download newer builds."
        exit 0
        ;;
      *)
        BLENDER_ARGS+=("$1")
        shift
        ;;
    esac
  done

  mkdir -p "$CACHE_DIR" "$INSTALL_DIR"

  # Check if we have an existing installation
  if [[ -L "$CURRENT_LINK" && -d "$CURRENT_LINK" ]] && [[ "$UPDATE_BUILD" != true ]]; then
    echo "Using existing Blender installation at: $CURRENT_LINK"
    BUILD_DIR=$(readlink "$CURRENT_LINK")
  else
    # Fetch latest daily build from Blender API (JSON endpoint)
    echo "Fetching latest Blender daily build from API..."
    API_URL="https://builder.blender.org/download/daily/?format=json&v=1"

    # Get architecture (x86_64 for most Linux systems)
    ARCH="x86_64"

    echo "Querying API: $API_URL"
    LATEST_URL=$(${curl}/bin/curl -s "$API_URL" | \
      ${jq}/bin/jq -r --arg arch "$ARCH" '
        [.[] | select(.platform == "linux" and .architecture == $arch and (.file_name | test("tar\\.xz$")) and (.file_name | test("sha256") | not))] |
        sort_by(.file_mtime) | reverse | .[0].url // empty
      ')

    echo "Found URL: $LATEST_URL"

    # Extract version/build info from URL
    FILENAME=$(basename "$LATEST_URL")
    BUILD_DIR="$INSTALL_DIR/$FILENAME"

    echo "Latest build: $FILENAME"

    # Check if already downloaded
    if [[ -d "$BUILD_DIR" ]]; then
      echo "Build already exists, linking..."
    else
      echo "Downloading $LATEST_URL..."
      TEMP_FILE="$CACHE_DIR/$FILENAME"

      ${curl}/bin/curl -L --progress-bar -o "$TEMP_FILE" "$LATEST_URL"

      echo "Extracting to $BUILD_DIR..."
      mkdir -p "$BUILD_DIR"
      ${gnutar}/bin/tar -xf "$TEMP_FILE" -C "$BUILD_DIR" --strip-components=1

      # Cleanup
      rm -f "$TEMP_FILE"
    fi
  fi

  # Always patch Blender binaries for NixOS (even for existing installations)
  echo "Patching Blender binaries for NixOS..."
  LIBRARY_PATH="${
    lib.makeLibraryPath [
      glibc
      gcc-unwrapped.lib
      xorg.libX11
      xorg.libXi
      xorg.libXrender
      xorg.libXxf86vm
      xorg.libXfixes
      xorg.libXcursor
      xorg.libXinerama
      xorg.libXrandr
      xorg.libXt
      xorg.libSM
      xorg.libICE
      libdecor
      libGL
      libGLU
      libxkbcommon
      freetype
      zlib
      glib
      alsa-lib
      pulseaudio
      stdenv.cc.cc.lib
      fontconfig
      dbus
      wayland
    ]
  }:$BUILD_DIR/lib"

  # Patch main Blender binary
  if [[ -f "$BUILD_DIR/blender" ]]; then
    ${patchelf}/bin/patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 "$BUILD_DIR/blender"
    ${patchelf}/bin/patchelf --set-rpath "$LIBRARY_PATH" "$BUILD_DIR/blender"
    echo "Main Blender binary patched"
  fi

  # Patch all shared libraries
  echo "Patching shared libraries..."
  find "$BUILD_DIR" -name "*.so*" -type f | while read -r lib; do
    ${patchelf}/bin/patchelf --set-rpath "$LIBRARY_PATH" "$lib" 2>/dev/null || true
  done

  echo "Blender binaries patched successfully"

  # Update current symlink
  rm -f "$CURRENT_LINK"
  ln -sf "$BUILD_DIR" "$CURRENT_LINK"

  echo "Blender daily build ready at: $CURRENT_LINK/blender"

  # Set up display environment for Wayland/X11
  export QT_QPA_PLATFORM=wayland
  export GDK_BACKEND=wayland
  export SDL_VIDEODRIVER=wayland
  export WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-wayland-1}

  # Run with collected arguments
  if [[ ''${#BLENDER_ARGS[@]} -eq 0 ]]; then
    exec "$CURRENT_LINK/blender"
  else
    exec "$CURRENT_LINK/blender" "''${BLENDER_ARGS[@]}"
  fi
''
