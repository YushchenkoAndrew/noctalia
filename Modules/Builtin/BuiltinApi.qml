import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI

import "../../Helpers/BuiltinData.js" as Data

/**
* Per-feature adapter exposing the small `pluginApi` surface that the built-in
* features (catwalk, clipboard, screen-recorder, usb-drive-manager) are written against.
* Settings come from settings.json (Settings.data.<section>) instead of plugin files.
*/
QtObject {
  id: root

  // Set by Builtin.qml
  required property string pluginId
  required property string panelName
  required property var settings
  property var screenDetector: null

  readonly property var manifest: Data.manifests[pluginId] || ({})
  readonly property string pluginDir: Quickshell.shellDir + "/Modules/Builtin"

  // Read-only view of the matching settings.json section
  readonly property var pluginSettings: settings

  property var mainInstance: null
  property var panelOpenScreen: null

  // Settings are edited in settings.json, nothing to persist at runtime
  function saveSettings() {
  }

  function _lookup(key) {
    var cur = Data.strings[pluginId];
    var parts = key.split('.');
    for (var i = 0; i < parts.length; i++) {
      if (cur === undefined || cur === null)
        return undefined;
      cur = cur[parts[i]];
    }
    return cur;
  }

  function tr(key, interpolations) {
    var s = _lookup(key);
    if (typeof s !== 'string')
      return "!!" + key + "!!";
    if (interpolations) {
      for (var p in interpolations)
        s = s.replace(new RegExp('\\{' + p + '\\}', 'g'), interpolations[p]);
    }
    return s;
  }

  function trp(key, count, interpolations) {
    var merged = {
      "count": count
    };
    for (var p in interpolations || ({}))
      merged[p] = interpolations[p];
    return tr(count === 1 ? key : key + "-plural", merged);
  }

  function hasTranslation(key) {
    return typeof _lookup(key) === 'string';
  }

  function withCurrentScreen(callback) {
    if (!screenDetector) {
      callback(Quickshell.screens[0]);
      return;
    }
    screenDetector.withCurrentScreen(callback);
  }

  // True when this feature's panel is currently open on the given screen
  function isPanelOpen(screen) {
    var panel = screen ? PanelService.getPanel(panelName, screen) : null;
    return panel ? panel.isPanelOpen === true : false;
  }

  function togglePanel(screen, buttonItem) {
    var panel = screen ? PanelService.getPanel(panelName, screen) : null;
    if (!panel)
      return false;
    panel.toggle(buttonItem);
    return true;
  }

  function openPanel(screen, buttonItem) {
    var panel = screen ? PanelService.getPanel(panelName, screen) : null;
    if (!panel)
      return false;
    panel.open(buttonItem);
    return true;
  }

  function closePanel(screen) {
    var panel = screen ? PanelService.getPanel(panelName, screen) : null;
    if (!panel)
      return false;
    panel.close();
    return true;
  }
}
