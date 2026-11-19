# Dev shell for working on / running this Noctalia checkout (VS Code + qmlls, `qs -p .`).
#
#   nix-shell nix/env/shell.nix                      # enter the shell
#   echo 'use nix nix/env/shell.nix' > .envrc        # or: direnv (nix-direnv) + `direnv allow`
#
# Inside the shell:
#   noctalia-dev                   run THIS checkout with an isolated config (.dev/)
#   qmllint / qmlformat / qmlls    from the same Qt that quickshell is built against
#
# quickshell is plain upstream Quickshell (>= 0.3.0) from nixpkgs -- no fork. It comes from the same
# nixpkgs as everything else, so it is built/cached together with your system and always matches the Qt
# you have (a pinned fork stops compiling whenever Qt moves).
#
# nixpkgs: on NixOS this uses the SYSTEM's nixpkgs (<nixpkgs>). That matters: a GUI built from a
# different nixpkgs has a different glibc than your system's GPU drivers (/run/opengl-driver),
# so EGL fails to load ("EGL not available", nothing renders). Without <nixpkgs> on NIX_PATH
# (non-NixOS / no flake registry) it falls back to the nixpkgs pinned in flake.lock.
#
# Overrides (all optional):
#   nix-shell nix/env/shell.nix --arg pkgs '(builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux'
#   nix-shell nix/env/shell.nix --arg quickshell 'builtins.getFlake "git+https://git.outfoxxed.me/quickshell/quickshell"' ...
#     (or any other Quickshell package, e.g. one built from git master)
let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  locked = name: lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
  fetchLocked =
    n:
    builtins.fetchTarball {
      url = "https://github.com/${n.owner}/${n.repo}/archive/${n.rev}.tar.gz";
      sha256 = n.narHash;
    };
in
let
  hasSystemNixpkgs = builtins.any (e: e.prefix == "nixpkgs") builtins.nixPath;
in
{
  pkgs ? if hasSystemNixpkgs then import <nixpkgs> { } else import (fetchLocked (locked "nixpkgs")) { },
  quickshell ? pkgs.quickshell,
}:
let
  inherit (pkgs) lib;
  qt = pkgs.qt6;

  # Modules qmlls needs to resolve `import QtQuick...` and `import Quickshell...`
  # (the project's own `qs.*` modules are resolved through the .qmlls.ini quickshell writes).
  qmlImportPath = lib.makeSearchPath qt.qtbase.qtQmlPrefix [
    qt.qtdeclarative
    quickshell
  ];

  # Binaries the shell shells out to for the features that are on by default.
  # Add more here (ddcutil, cava, ...) when you enable the matching settings.json options.
  runtimeDeps = with pkgs; [
    cava
    brightnessctl
    cliphist
    wlsunset
    wl-clipboard
    imagemagick
    python3
  ];

  # Run this checkout with a throw-away config so it never touches your real
  # ~/.config/noctalia (and never tries to write into Nix-managed, read-only files).
  # Copy your settings.json to .dev/config/ if you want the dev instance to look like your setup.
  noctalia-dev = pkgs.writeShellScriptBin "noctalia-dev" ''
    root="''${NOCTALIA_DEV_ROOT:-$(${lib.getExe pkgs.git} rev-parse --show-toplevel 2>/dev/null || pwd)}"
    export NOCTALIA_CONFIG_DIR="''${NOCTALIA_CONFIG_DIR:-$root/.dev/config}"
    export NOCTALIA_CACHE_DIR="''${NOCTALIA_CACHE_DIR:-$root/.dev/cache}"
    mkdir -p "$NOCTALIA_CONFIG_DIR" "$NOCTALIA_CACHE_DIR"
    # A global LD_LIBRARY_PATH (e.g. nix-ld's lib dir) overrides the binary's own RUNPATH and
    # loads system libs built against a different glibc than this quickshell -> GLIBC_x.y not found.
    unset LD_LIBRARY_PATH
    exec ${quickshell}/bin/qs -p "$root" "$@"
  '';
in
pkgs.mkShell {
  name = "noctalia-dev";

  NOCTALIA_DEV_NIXPKGS = if hasSystemNixpkgs then "system" else "pinned";

  packages = [
    quickshell
    qt.qtdeclarative
    noctalia-dev
  ]
  ++ runtimeDeps;

  # qmlls (Qt QML VS Code extension) reads QML_IMPORT_PATH; QML2_IMPORT_PATH is the older alias
  QML_IMPORT_PATH = qmlImportPath;
  QML2_IMPORT_PATH = qmlImportPath;

  shellHook = ''
    # see noctalia-dev: keep nix-ld / system library paths out of this Nix-built toolchain
    unset LD_LIBRARY_PATH
    echo "quickshell  : ${quickshell}/bin/qs  (${quickshell.version or "unknown"})"
    echo "nixpkgs     : $NOCTALIA_DEV_NIXPKGS"
    if [ "$NOCTALIA_DEV_NIXPKGS" = pinned ]; then
      echo "  WARNING: no <nixpkgs> on NIX_PATH, using the flake.lock pin. On NixOS this can fail to render"
      echo "  (EGL/glibc mismatch). Use: --arg pkgs '(builtins.getFlake \"nixpkgs\").legacyPackages.x86_64-linux'"
    fi
    echo "qmlls       : $(command -v qmlls || echo 'not found')"
    echo "QML imports : $QML_IMPORT_PATH"
    echo
    echo "Run the shell:  noctalia-dev   (stop the system instance first: pkill -f noctalia-shell)"
    echo "VS Code qmlls:  start noctalia-dev once so quickshell writes .qmlls.ini, then reload the editor"
  '';
}
