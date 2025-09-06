{
  description = "Blender Daily Build Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flakelight.url = "github:nix-community/flakelight";
    wrapper-manager = {
      url = "github:viperML/wrapper-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;

      # Development shell packages
      devShell.packages = pkgs: with pkgs; [
        curl
        jq
        gnutar
        patchelf
      ];
    };
}
