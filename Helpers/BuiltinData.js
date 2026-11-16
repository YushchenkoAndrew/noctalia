// Generated from the four built-in features (catwalk, clipboard, screen-recorder, usb-drive-manager).
// English strings + manifest data, used by Modules/Builtin/Builtin.qml.
.pragma library

var manifests = {
  "catwalk": {
    "id": "catwalk",
    "name": "Catwalk",
    "version": "1.1.7",
    "description": "A cute animated cat for your bar.",
    "metadata": {
      "defaultSettings": {
        "minimumThreshold": 10,
        "hideBackground": false
      }
    }
  },
  "clipboard": {
    "id": "clipboard",
    "name": "Clipboard",
    "version": "1.0.3",
    "description": "Clipboard history panel with search, pinning, and image previews.",
    "metadata": {
      "defaultSettings": {
        "maxHistorySize": 100,
        "showImagePreviews": true,
        "density": "comfortable"
      }
    }
  },
  "screen-recorder": {
    "id": "screen-recorder",
    "name": "Screen Recorder",
    "version": "1.3.7",
    "description": "Hardware-accelerated screen recording using gpu-screen-recorder with customizable video and audio settings",
    "metadata": {
      "defaultSettings": {
        "hideInactive": false,
        "iconColor": "none",
        "directory": "",
        "filenamePattern": "recording_yyyyMMdd_HHmmss",
        "frameRate": "60",
        "audioCodec": "opus",
        "videoCodec": "h264",
        "quality": "very_high",
        "colorRange": "limited",
        "showCursor": true,
        "copyToClipboard": false,
        "audioSource": "default_output",
        "videoSource": "portal",
        "resolution": "original",
        "replayEnabled": false,
        "replayDuration": "30",
        "customReplayDuration": "30",
        "replayStorage": "ram",
        "restorePortalSession": false
      }
    }
  },
  "usb-drive-manager": {
    "id": "usb-drive-manager",
    "name": "USB Drive Manager",
    "version": "1.4.0",
    "description": "Manage USB drives: detect, mount, unmount, safely eject, and browse files",
    "metadata": {
      "defaultSettings": {
        "autoMount": false,
        "fileBrowser": "yazi",
        "terminalCommand": "kitty",
        "showNotifications": true,
        "hideWhenEmpty": false,
        "showBadge": false,
        "iconColor": "none"
      }
    }
  }
};

var strings = {
  "catwalk": {
    "panel": {
      "cpuLabel": "CPU: {usage}%",
      "title": "Catwalk"
    },
    "settings": {
      "currentThreshold": "Current threshold: {value}%",
      "hideBackground": {
        "description": "Hide the background of the desktop widget",
        "label": "Hide Background"
      },
      "minimumThreshold": {
        "description": "CPU usage must be above this percentage for the cat to start running",
        "label": "Minimum CPU Threshold"
      },
      "title": "Catwalk Settings"
    },
    "tooltip": {
      "running": "Cat is running",
      "sleeping": "Cat is sleeping"
    }
  },
  "clipboard": {
    "bar": {
      "tooltip": "Clipboard History"
    },
    "context": {
      "toggle": "Toggle Clipboard History",
      "settings": "Open Settings"
    },
    "panel": {
      "title": "Clipboard History",
      "empty": "No clipboard history yet",
      "no-matches": "No matches",
      "search-placeholder": "Search...",
      "delete": "Delete entry",
      "pin": "Pin entry",
      "unpin": "Unpin entry",
      "wipe": "Clear history",
      "close": "Close",
      "settings": "Settings",
      "filter-text": "Text",
      "filter-images": "Images",
      "filter-files": "Files",
      "filter-text-count": "Text ({count})",
      "filter-images-count": "Images ({count})",
      "filter-files-count": "Files ({count})"
    },
    "settings": {
      "tab-general": "General",
      "max-history-size": "Maximum history size",
      "max-history-size-description": "Number of clipboard entries kept in history. Takes effect on the next refresh.",
      "show-image-previews": "Show image previews",
      "show-image-previews-description": "Decode and display thumbnails for image entries. Disable on low-memory systems.",
      "density": "Density",
      "density-description": "Spacing of clipboard entries in the panel.",
      "density-compact": "Compact",
      "density-comfortable": "Comfortable",
      "density-spacious": "Spacious"
    },
    "toast": {
      "item-copied-text-title": "Text copied",
      "item-copied-text-body": "You can paste the text from the clipboard.",
      "item-copied-image-title": "Image copied",
      "item-copied-image-body": "You can paste the image from the clipboard.",
      "item-copied-file-title": "File copied",
      "item-copied-file-body": "You can paste the file from the clipboard.",
      "item-pinned": "Item pinned",
      "item-unpinned": "Item unpinned",
      "history-cleared": "Clipboard history cleared"
    },
    "time": {
      "just-now": "just now",
      "minutes-ago": "{minutes}m ago",
      "hours-ago": "{hours}h ago",
      "yesterday": "yesterday"
    }
  },
  "screen-recorder": {
    "description": "Hardware-accelerated screen recording with customizable video and audio settings",
    "messages": {
      "failed-general": "Recorder exited with an error.",
      "failed-gpu": "gpu-screen-recorder exited unexpectedly.",
      "failed-start": "Failed to start recording.",
      "no-portals": "Desktop portals not running.",
      "no-portals-desc": "Start xdg-desktop-portal and a compositor portal (wlr/hyprland/gnome/kde).",
      "not-installed": "gpu-screen-recorder not installed.",
      "not-installed-desc": "Please install gpu-screen-recorder to use screen recording features.",
      "saved": "Recording saved.",
      "start-recording": "Screen Recorder (start recording)",
      "started": "Recording started.",
      "stop-recording": "Screen Recorder (stop recording)",
      "stopping": "Stopping recording…",
      "open-file": "Open file",
      "monitor-not-found": "Could not detect the monitor under cursor.",
      "replay-saved": "Replay saved.",
      "replay-started": "Replay buffer started.",
      "replay-stopped": "Replay buffer stopped.",
      "replay-failed": "Failed to start replay buffer.",
      "replay-active": "Screen Recorder (replay active)",
      "save-replay": "Save replay buffer",
      "start-replay": "Start replay buffer",
      "stop-replay": "Stop replay buffer"
    },
    "name": "Screen Recorder",
    "settings": {
      "audio": {
        "audio-sources-both": "System output + microphone input",
        "audio-sources-microphone-input": "Microphone input",
        "audio-sources-none": "No audio",
        "audio-sources-system-output": "System output",
        "codec": "Audio codec",
        "codec-desc": "Opus is recommended for best performance and smallest audio size",
        "source": "Audio source",
        "source-desc": "Audio source to capture during recording",
        "title": "Audio Settings"
      },
      "filename-pattern": {
        "description": "Filename pattern using date/time codes (e.g., recording_yyyyMMdd_HHmmss)",
        "label": "Filename pattern"
      },
      "general": {
        "copy-to-clipboard": "Copy to clipboard",
        "copy-to-clipboard-description": "Copy the file to clipboard after recording finishes.",
        "hide-when-inactive": "Hide when inactive",
        "hide-when-inactive-description": "Hide the bar indicator when not recording",
        "output-folder": "Output folder",
        "output-folder-description": "Folder where screen recordings will be saved",
        "restore-portal-session": "Restore portal session",
        "restore-portal-session-description": "Automatically restore the previous portal session for subsequent recordings (disables the selection prompt)",
        "show-cursor": "Show cursor",
        "show-cursor-description": "Record mouse cursor in the video",
        "title": "General"
      },
      "replay": {
        "enable": "Enable replay buffer",
        "enable-desc": "Keep a rolling buffer of recent screen activity that can be saved on demand",
        "duration": "Replay duration",
        "duration-desc": "Length of the replay buffer in seconds",
        "custom-duration": "Custom replay duration",
        "custom-duration-desc": "Enter a custom replay buffer duration in seconds",
        "storage": "Replay storage",
        "storage-desc": "Where to store the replay buffer",
        "storage-ram": "RAM (recommended)",
        "storage-disk": "Disk"
      },
      "title": "Screen Recorder Settings",
      "video": {
        "codec": "Video codec",
        "codec-desc": "h264 is the most common codec",
        "color-range": "Color range",
        "color-range-desc": "Limited is recommended for better compatibility",
        "color-range-full": "Full",
        "color-range-limited": "Limited",
        "frame-rate": "Frame rate",
        "frame-rate-custom": "Custom",
        "frame-rate-desc": "Target frame rate for screen recordings",
        "custom-frame-rate": "Custom frame rate",
        "custom-frame-rate-desc": "Enter a custom frame rate value (FPS)",
        "quality": "Video quality",
        "quality-desc": "Higher quality results in larger file sizes",
        "quality-high": "High",
        "quality-medium": "Medium",
        "quality-ultra": "Ultra",
        "quality-very-high": "Very high",
        "resolution": "Resolution",
        "resolution-desc": "Limit output resolution. Default uses original screen resolution",
        "resolution-original": "Default",
        "source": "Video source",
        "source-desc": "Portal is recommended, if you get artifacts try Screen",
        "sources-portal": "Portal",
        "sources-screen": "Screen",
        "sources-focused-monitor": "Focused monitor (Hyprland)",
        "title": "Video Settings"
      }
    }
  },
  "usb-drive-manager": {
    "bar": {
      "tooltip-empty": "No USB devices",
      "tooltip-count": "%1 device(s) mounted"
    },
    "panel": {
      "title": "USB Manager",
      "mounted": "mounted",
      "refresh": "Refresh",
      "empty": "No USB devices detected",
      "empty-hint": "Plug in a USB drive to get started",
      "unmount-all": "Unmount All",
      "eject-all": "Eject All"
    },
    "device": {
      "mounted": "Mounted",
      "loading": "Loading...",
      "used": "{size} used",
      "free": "{size} free",
      "action-open": "Open",
      "action-mount": "Mount",
      "action-unmount": "Unmount",
      "action-eject": "Safely eject",
      "action-copy-path": "Copy path"
    },
    "context": {
      "open": "Open USB Manager",
      "refresh": "Refresh Devices",
      "unmount-all": "Unmount All",
      "eject-all": "Eject All",
      "settings": "Settings"
    },
    "notifications": {
      "mounted": "Mounted",
      "unmounted": "Unmounted",
      "ejected": "Safely ejected",
      "mount-failed": "Mount failed",
      "unmount-failed": "Unmount failed",
      "eject-failed": "Eject failed",
      "unmount-all": "All devices unmounted",
      "eject-all": "All devices ejected",
      "path-copied": "Path copied"
    },
    "settings": {
      "section-bar": "Bar Widget",
      "hide-when-empty": "Hide when no devices",
      "hide-when-empty-desc": "Hide the bar icon when no USB devices are connected",
      "show-badge": "Show count badge",
      "show-badge-desc": "Show the number of mounted devices as a badge on the bar icon",
      "icon-color": "Icon color",
      "icon-color-desc": "Custom icon color (leave as 'none' for default)",
      "section-behavior": "Behavior",
      "auto-mount": "Auto-mount",
      "auto-mount-desc": "Automatically mount USB drives when plugged in",
      "notifications": "Notifications",
      "notifications-desc": "Show toast notifications for mount/unmount/eject events",
      "section-browser": "File Browser",
      "file-browser": "File browser",
      "file-browser-desc": "Command used to open the file browser (e.g. yazi, ranger, xdg-open, dolphin)",
      "terminal": "Terminal emulator",
      "terminal-desc": "Terminal used to open terminal-based file managers (yazi, ranger, etc.)"
    }
  }
};
