{ pkgs ? import <nixpkgs> {} }:

let
  quickshell = pkgs.quickshell;
  qtdeclarative = pkgs.kdePackages.qtdeclarative;
  qtbase = pkgs.kdePackages.qtbase;
  qtwayland = pkgs.kdePackages.qtwayland;

in pkgs.mkShell {
  packages = [
    quickshell
    qtdeclarative
    qtbase
    qtwayland
  ];

  shellHook = ''
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    # Discover Quickshell's generated virtual filesystems.
    VFS_PATHS=""

    for vfs in "$XDG_RUNTIME_DIR"/quickshell/vfs/*; do
      if [ -f "$vfs/qs/qmldir" ]; then
        VFS_PATHS="''${VFS_PATHS:+$VFS_PATHS:}$vfs"
      fi
    done

    # Qt QML import paths.
    QT_IMPORT_PATHS="${qtdeclarative}/lib/qt-6/qml:${qtwayland}/lib/qt-6/qml:${quickshell}/lib/qt-6/qml"

    export QML_IMPORT_PATH="$QT_IMPORT_PATHS''${VFS_PATHS:+:$VFS_PATHS}"
    export QML2_IMPORT_PATH="$QML_IMPORT_PATH"

    # Tell qmlls where Quickshell generates its QML environment.
    export QMLLS_BUILD_DIRS="$VFS_PATHS"

    # Create a wrapper that discovers VFS paths again whenever qmlls starts.
    QM LLS_WRAPPER="$XDG_RUNTIME_DIR/noctalia-qmlls"
    cat > "$XDG_RUNTIME_DIR/noctalia-qmlls" <<EOF
#!/usr/bin/env bash

args=()

for vfs in "$XDG_RUNTIME_DIR"/quickshell/vfs/*; do
  if [ -f "\$vfs/qs/qmldir" ]; then
    args+=(-I "\$vfs")
  fi
done

exec ${qtdeclarative}/bin/qmlls \
  -I ${qtdeclarative}/lib/qt-6/qml \
  -I ${qtwayland}/lib/qt-6/qml \
  -I ${quickshell}/lib/qt-6/qml \
  "''${args[@]}" "\$@"
EOF

    chmod +x "$XDG_RUNTIME_DIR/noctalia-qmlls"

    echo "Quickshell: $(which quickshell)"
    echo "QML Language Server: $XDG_RUNTIME_DIR/noctalia-qmlls"
    echo "QML Import Paths: $QML_IMPORT_PATH"
  '';
}
