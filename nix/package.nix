{
  version ? "dirty",
  # Extra binaries for features you enable in settings.json, e.g.
  #   noctalia-shell.override { extraPackages = [ pkgs.cava ]; }
  extraPackages ? [ ],

  # Optional features, off by default to keep the closure small.
  # Turn on with `.override { ddcSupport = true; }` (and the matching settings.json key).
  ddcSupport ? false, # external-monitor brightness   <-> brightness.enableDdcSupport
  multimediaSupport ? false, # QtMultimedia, only needed by plugins that import it
  calendarSupport ? false, # evolution-data-server calendar events

  # What the shell needs for the features that are on in a lean setup.
  runtimeDeps ? [
    brightnessctl
    cliphist
    wlsunset
    wl-clipboard
    imagemagick # notification icon processing
    (python3.withPackages (pp: lib.optional calendarSupport pp.pygobject3))
  ]
  ++ lib.optional ddcSupport ddcutil,

  lib,
  stdenvNoCC,
  # build
  qt6,
  quickshell,
  # runtime deps
  brightnessctl,
  cliphist,
  ddcutil,
  wlsunset,
  wl-clipboard,
  imagemagick,
  python3,
  wayland-scanner,
  # calendar support deps
  evolution-data-server,
  libical,
  glib,
  libsoup_3,
  json-glib,
  gobject-introspection,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      !(builtins.any (prefix: lib.path.hasPrefix (../. + prefix) (/. + path)) [
        /.github
        /.gitignore
        /Scripts/dev
        /nix
        /LICENSE
        /README.md
        /flake.nix
        /flake.lock
        /shell.nix
        /lefthook.yml
        /CLAUDE.md
        /CREDITS.md
      ]);
  };

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    evolution-data-server
    libical
    glib.out
    libsoup_3
    json-glib
    gobject-introspection
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-shell";
  inherit version src;

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
  ]
  ++ lib.optional multimediaSupport qt6.qtmultimedia;

  installPhase = ''
    mkdir -p $out/share/noctalia-shell $out/bin
    cp -r . $out/share/noctalia-shell
    ln -s ${quickshell}/bin/qs $out/bin/noctalia-shell
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ extraPackages)}
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share
      --set-default QS_CONFIG_PATH "$out/share/noctalia-shell"
      ${lib.optionalString calendarSupport "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
    )
  '';

  meta = {
    description = "A sleek and minimal desktop shell thoughtfully crafted for Wayland, built with Quickshell.";
    homepage = "https://github.com/noctalia-dev/noctalia-shell";
    license = lib.licenses.mit;
    mainProgram = "noctalia-shell";
  };
}
