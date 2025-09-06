{ callPackage, inputs, lib, system, ... }@pkgs:
let
  # Get the full nixpkgs with all functions
  fullPkgs = inputs.nixpkgs.legacyPackages.${system};

  # Build the base blender-daily script
  blender-daily-base = callPackage ./blender-daily.nix { };

  # Create wrapper-manager evaluation
  wm-eval = inputs.wrapper-manager.lib {
    pkgs = fullPkgs;
    inherit lib;
    modules = [
      {
        wrappers.blender-daily = {
          basePackage = blender-daily-base;
          # Set up environment variables for Wayland/X11
          env = {
            QT_QPA_PLATFORM.value = "wayland";
            GDK_BACKEND.value = "wayland";
            SDL_VIDEODRIVER.value = "wayland";
            WAYLAND_DISPLAY.value = "\${WAYLAND_DISPLAY:-wayland-1}";
          };
        };
      }
    ];
  };
in
wm-eval.config.wrappers.blender-daily.wrapped
