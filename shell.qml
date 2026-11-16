/*
* Noctalia – made by https://github.com/noctalia-dev
* Licensed under the MIT License.
* Forks and modifications are allowed under the MIT License,
* but proper credit must be given to the original author.
*/

//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,vdpau
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi,vdpau

// Qt & Quickshell Core
import QtQuick
import Quickshell

// Commons & Services
import qs.Commons

// Modules
import qs.Modules.Background
import qs.Modules.Builtin
import qs.Modules.Bar
import qs.Modules.DesktopWidgets
import qs.Modules.Dock
import qs.Modules.LockScreen
import qs.Modules.MainScreen
import qs.Modules.Notification
import qs.Modules.OSD

import qs.Modules.Panels.Launcher
import qs.Modules.Toast
import qs.Services.Control
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Location
import qs.Services.Networking
import qs.Services.Noctalia
import qs.Services.Power
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI

ShellRoot {
  id: shellRoot

  property bool i18nLoaded: false
  property bool settingsLoaded: false
  property bool shellStateLoaded: false

  Component.onCompleted: {
    Logger.i("Shell", "---------------------------");
    Logger.i("Shell", "Noctalia Hello!");
  }

  Connections {
    target: Quickshell
    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup();
    }
    function onReloadFailed() {
      if (!Settings?.isDebug) {
        Quickshell.inhibitReloadPopup();
      }
    }
  }

  Connections {
    target: I18n ? I18n : null
    function onTranslationsLoaded() {
      i18nLoaded = true;
    }
  }

  Connections {
    target: Settings ? Settings : null
    function onSettingsLoaded() {
      settingsLoaded = true;
      // External plugin system is opt-in (settings.json: plugins.enabled)
      if (Settings.data.plugins.enabled) {
        PluginRegistry.init();
      }
    }
  }

  Connections {
    target: ShellState ? ShellState : null
    function onIsLoadedChanged() {
      if (ShellState.isLoaded) {
        shellStateLoaded = true;
      }
    }
  }

  Loader {
    active: i18nLoaded && settingsLoaded && shellStateLoaded

    sourceComponent: Item {
      Component.onCompleted: {
        Logger.i("Shell", "---------------------------");

        // Critical services needed for initial UI rendering
        ImageCacheService.init();
        AppThemeService.init();
        ColorSchemeService.init();
        DarkModeService.init();

        // Defer non-critical services to unblock first frame
        Qt.callLater(function () {
          LocationService.init();
          NightLightService.apply();
          IdleInhibitorService.init();
          IdleService.init();
          PowerProfileService.init();
          HostService.init();
          NotificationRulesService.init();
          CustomButtonIPCService.init();
          IPCService.init(screenDetector);
          Builtin.init();

          // Force ClipboardService initialization so clipboard watchers
          // start immediately instead of waiting for first launcher open
          if (Settings.data.appLauncher.enableClipboardHistory) {
            ClipboardService.checkCliphistAvailability();
          }
        });

        delayedInitTimer.restart();
      }

      DesktopWidgets {}
      AllScreens {}
      Dock {}
      Notification {}
      ToastOverlay {}
      OSD {}

      // Launcher overlay window (for overlay layer mode)
      Loader {
        active: Settings.data.appLauncher.overviewLayer
        sourceComponent: Component {
          LauncherOverlayWindow {}
        }
      }

      LockScreen {}
      FadeOverlay {}

      // Shared screen detector for IPC and plugins
      CurrentScreenDetector {
        id: screenDetector
      }

      // IPCService is a singleton, initialized via init() in deferred services block

      // Container for the Main instances of built-in features (and external plugins, if enabled)
      Item {
        id: pluginContainer
        visible: false

        Component.onCompleted: {
          Builtin.container = pluginContainer;
          Builtin.screenDetector = screenDetector;
          if (Settings.data.plugins.enabled) {
            PluginService.pluginContainer = pluginContainer;
            PluginService.screenDetector = screenDetector;
          }
        }
      }
    }
  }

  // Delayed initialization of non-critical services
  Timer {
    id: delayedInitTimer
    running: false
    interval: 1500
    onTriggered: HooksService.init()
  }
}
