# Noctalia (lean fork)

A trimmed, glassy fork of the legacy [Noctalia v4](https://github.com/noctalia-dev/noctalia-shell/tree/legacy-v4) shell for Wayland. It runs on **plain upstream Quickshell**, ships a few former plugins built in, and is driven by `settings.json` and Nix rather than a settings GUI.

The goal is a shell that stays light, doesn't depend on a frozen fork, and looks the same on every Quickshell/Qt update.

> This fork is built and tested for **niri** on NixOS. Hyprland, Sway, Labwc and ext-workspace code is still in the tree but is not exercised here.

---

## What is different from upstream v4

### Runs on plain upstream Quickshell

- No `noctalia-qs` fork. Any Quickshell **>= 0.3.0** works (nixpkgs' `quickshell` by default, or a git build you pass in).
- The audio visualizer uses `cava` instead of the fork's native analyzer.
- The Nix package and dev shell use your system's nixpkgs, so the shell is built against the same Qt and glibc as your GPU drivers.

### Lean by default

Removed outright:

- settings GUI, setup wizard and changelog
- wallpaper management (use `wbg`, `swww`, etc.)
- update checker and telemetry
- MangoWC support

Kept but off by default and switchable from `settings.json`: idle management, desktop widgets, the external plugin system (`plugins.enabled`), and DDC brightness (`brightness.enableDdcSupport`, needs the `ddcSupport` Nix override).

The launcher, including **fuzzy search**, is untouched: `noctalia-shell ipc call launcher toggle`.

### Built-in former plugins

These are part of the shell now, with their own `settings.json` sections and no plugin loading:

| Feature                                           | Section          | Needs                      |
| ------------------------------------------------- | ---------------- | -------------------------- |
| Catwalk (CPU-following cat, bar + desktop widget) | `catwalk`        | none                       |
| Clipboard history panel                           | `clipboard`      | `cliphist`, `wl-clipboard` |
| Screen recorder (+ replay buffer)                 | `screenRecorder` | `gpu-screen-recorder`      |
| USB drive manager                                 | `usbDrives`      | `udisks`                   |

Their bar and control-center widgets are registered like any other widget.

### Built-in calendar (no EDS/khal)

The third-party calendar backend is replaced by a pure-QML iCalendar/RRULE parser (`Helpers/Ics.js`). Point it at calendars in `settings.json`:

```json
"location": {
  "calendarSources": [
    "Work|https://example.com/calendar.ics",
    "/home/me/calendars/personal.ics",
    "/home/me/calendars/folder-of-ics-files"
  ]
}
```

Sources can be `https://`, `webcal://`, a `.ics` file, or a folder of `.ics` files, optionally prefixed `"Name|"`. Nothing here depends on system services that can break on a NixOS update.

### Night light fixed

- Automatic schedule starts reliably (the old code skipped location until a weather fetch had happened).
- A watchdog re-applies `wlsunset` if it dies.
- IPC: `noctalia-shell ipc call nightLight reapply` and `... nightLight status`.

### Glass look

Everything dark is translucent; everything accent-coloured stays solid.

- **Neutral colours** (`mSurface`, `mSurfaceVariant`, `mOutline`, ...) follow the opacity settings.
- **Accent colours** (`mPrimary`, `mSecondary`, `mTertiary`, `mError`, `mHover`) are never made transparent. That covers connect buttons, connected rows, selected launcher entries and toggles.
- Hover and selected states use a dark `mOnHover` so the icon or text stays readable on a bright hover colour.
- The bar can be solid or fully transparent, and with `bar.showBackground: false` its background is not rendered at all, so it costs nothing.
- Panels, cards and rows inside panels all follow the same settings, including the Wi-Fi/Bluetooth/Ethernet rows and the launcher.

```json
"ui": {
  "translucentWidgets": true,
  "panelBackgroundOpacity": 0.25,
  "widgetBackgroundOpacity": 0.15
},
"bar": { "showBackground": false }
```

Button outlines (icon buttons, tab buttons, disabled and session-menu buttons) are transparent by default. Set `ui.buttonBorderEnabled: true` to bring the `mOutline` border back; accent borders such as hover or selected stay as they are. `ui.boxBorderEnabled` does the same for cards and boxes.

`widgetBackgroundOpacity` is the opacity of cards and rows inside a panel, independent of the panel's own `panelBackgroundOpacity`. Performance mode forces everything opaque.

### Blur that follows the panel shape

Noctalia asks the compositor for blur only over the panel, dock and launcher areas (`ext-background-effect`), and the region follows rounded corners and the inverted "flare" corners where panels meet the bar. It needs niri 26.04+ or any compositor with that protocol.

Do **not** put `blur true` in a niri layer rule for the Noctalia surfaces: `noctalia-background-<screen>` is full-screen and it would blur the whole display. The only rule needed:

```kdl
layer-rule {
    match namespace="^noctalia-(background|dock|launcher-overlay)-"
    background-effect { xray false }
}
```

A tuned `blur {}` block is in `niri-blur.kdl`.

### Colour scheme: Eldritch-Lime

A custom palette lives in `Assets/ColorScheme/Eldritch-Lime/`: green primary `#37f499`, cyan secondary `#04d1f9`, lime tertiary and hover `#c4e88d`, with the original light-pink outline. Select it with `colorSchemes.predefinedScheme = "Eldritch-Lime"`. The other schemes (Tokyo Night, Night Owl, Catppuccin, Nord, Gruvbox, ...) are still available.

If you also set `colors` in Nix, those values must match the scheme file, or the shell will rewrite `colors.json` with the scheme's values.

---

## Install (NixOS + home-manager)

Add the fork as a flake input:

```nix
inputs.noctalia = {
  url = "github:YushchenkoAndrew/noctalia/legacy-v4";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then in your home-manager config:

```nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    # package = inputs.noctalia.packages.${pkgs.system}.default.override {
    #   ddcSupport = true;        # external-monitor brightness
    #   multimediaSupport = true; # QtMultimedia: notification sounds
    #   extraPackages = [ pkgs.gpu-screen-recorder ];
    # };
    settings = {
      colorSchemes = { darkMode = true; predefinedScheme = "Eldritch-Lime"; };
      bar.showBackground = false;
      ui = { translucentWidgets = true; panelBackgroundOpacity = 0.25; widgetBackgroundOpacity = 0.15; };
      nightLight = { enabled = true; autoSchedule = true; };
    };
  };
}
```

Use plain `"#rrggbb"` strings for any colours in Nix, with no backticks.

The package puts `cava`, `cliphist`, `brightnessctl`, `wlsunset`, `wl-clipboard`, `imagemagick` and `python3` on the shell's PATH. Other tools (`gpu-screen-recorder`, `udisks`, `ddcutil`) go in `extraPackages` or the system.

Without Nix, install Quickshell >= 0.3.0 and the tools above, clone this repo to `~/.config/quickshell/noctalia` (or run `qs -p /path/to/repo`), and start it.

## Develop

```sh
nix-shell nix/env/shell.nix     # or: echo 'use nix nix/env/shell.nix' > .envrc && direnv allow
noctalia-dev                    # run THIS checkout with an isolated config in .dev/
```

The dev shell provides `qmllint`, `qmlformat` and `qmlls` from the same Qt Quickshell is built against, so VS Code's QML support resolves `qs.*` imports. `noctalia-dev` never touches your real `~/.config/noctalia`; copy a `settings.json` into `.dev/config/` to make it look like your setup.

Notes:

- `noctalia-dev` unsets `LD_LIBRARY_PATH`. A global one (for example from nix-ld) makes Nix binaries load a mismatched glibc.
- If nothing renders and the log says `EGL not available`, the shell was built from a different nixpkgs than the system. Use the system `<nixpkgs>` (the default) instead of the pinned one.
- Flakes ignore untracked files. `git add` new files before `nix build` or `nixos-rebuild`.

## Useful IPC

```sh
noctalia-shell ipc call launcher toggle
noctalia-shell ipc call calendar toggle
noctalia-shell ipc call controlCenter toggle
noctalia-shell ipc call nightLight toggle
noctalia-shell ipc call nightLight reapply
noctalia-shell ipc call nightLight status
noctalia-shell ipc call darkMode toggle
noctalia-shell ipc call sessionMenu toggle
```

Run `noctalia-shell ipc show` for the full list of targets and functions.

## Requirements

- A Wayland compositor (niri 26.04+ for blur)
- Quickshell >= 0.3.0 (upstream, no fork)
- `cava` for the visualizer; the rest depends on which features you enable (see the table above)

## Status and known limits

- Changes were checked with `qmllint` and Nix evaluation, plus the pure-JS parts under node. The visuals depend on a real compositor, so expect small tweaks.
- The Noctalia-Quickshell fork carried some stability fixes (PipeWire, layer-shell, MPRIS, Bluetooth) that are not backported. Report anything that misbehaves on plain Quickshell.
- The niri integration is the older socket-based one; newer niri event types are not specially handled.

## Credits and license

Based on [Noctalia](https://github.com/noctalia-dev/noctalia-shell) v4 by its contributors, which is archived upstream in favour of Noctalia v5. The original theming, bar, panels and services are theirs; this fork only trims, rewires and restyles them. See [CREDITS.md](./CREDITS.md).

MIT License, see [LICENSE](./LICENSE).
