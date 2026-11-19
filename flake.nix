{
  description = "Noctalia shell - a Wayland desktop shell built with Quickshell";

  # Plain upstream Quickshell (>= 0.3.0) from nixpkgs, which keeps it building against the current Qt.
  # To track Quickshell git instead, add an input and pass it in your own config:
  #   quickshell = { url = "git+https://git.outfoxxed.me/quickshell/quickshell"; inputs.nixpkgs.follows = "nixpkgs"; };
  #   ... noctalia.packages.${system}.default.override { quickshell = inputs.quickshell.packages.${system}.default; }
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux;
      pkgsFor = eachSystem (
        system:
        nixpkgs.legacyPackages.${system}.appendOverlays [
          self.overlays.default
        ]
      );

      mkDate =
        longDate:
        nixpkgs.lib.concatStringsSep "-" [
          (builtins.substring 0 4 longDate)
          (builtins.substring 4 2 longDate)
          (builtins.substring 6 2 longDate)
        ];

      version = mkDate (self.lastModifiedDate or "19700101") + "_" + (self.shortRev or "dirty");
    in
    {
      formatter = eachSystem (system: pkgsFor.${system}.nixfmt);

      packages = eachSystem (system: {
        default = pkgsFor.${system}.noctalia-shell;
      });

      overlays = {
        default = final: prev: {
          noctalia-shell = final.callPackage ./nix/package.nix {
            inherit version;
          };
        };
      };

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.callPackage ./nix/shell.nix { };
      });

      homeModules.default =
        {
          pkgs,
          lib,
          ...
        }:
        {
          imports = [ ./nix/home-module.nix ];
          programs.noctalia-shell.package =
            lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      nixosModules.default =
        {
          pkgs,
          lib,
          ...
        }:
        {
          imports = [ ./nix/nixos-module.nix ];
          services.noctalia-shell.package =
            lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
    };
}
