pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

/**
* Built-in features that used to be external plugins:
*   catwalk, clipboard, screen-recorder, usb-drive-manager
* Configured through settings.json (catwalk / clipboard / screenRecorder / usbDrives sections).
* Their background logic (the old Main.qml files) lives here and is created once, on demand.
*/
Singleton {
  id: root

  // Parent for the non-visual Main instances; set from shell.qml
  property Item container: null
  property var screenDetector: null

  readonly property var _specs: ({
                                   "catwalk": {
                                     "panel": "catwalkPanel",
                                     "section": "catwalk",
                                     "main": "CatwalkMain.qml"
                                   },
                                   "clipboard": {
                                     "panel": "clipboardPanel",
                                     "section": "clipboard",
                                     "main": "ClipboardMain.qml"
                                   },
                                   "screen-recorder": {
                                     "panel": "screenRecorderPanel",
                                     "section": "screenRecorder",
                                     "main": "ScreenRecorderMain.qml"
                                   },
                                   "usb-drive-manager": {
                                     "panel": "usbDrivesPanel",
                                     "section": "usbDrives",
                                     "main": "UsbDrivesMain.qml"
                                   }
                                 })

  property var _apis: ({})

  function _create(id) {
    var spec = _specs[id];
    if (!spec)
      return null;
    var comp = Qt.createComponent(Qt.resolvedUrl("BuiltinApi.qml"));
    if (comp.status !== Component.Ready) {
      Logger.e("Builtin", "BuiltinApi failed to load:", comp.errorString());
      return null;
    }
    var api = comp.createObject(root, {
                                  "pluginId": id,
                                  "panelName": spec.panel,
                                  "settings": Settings.data[spec.section],
                                  "screenDetector": root.screenDetector
                                });
    _apis[id] = api;
    _startMain(id, api, spec);
    return api;
  }

  // Create the background logic of a feature (shared by all bar/panel/control-center views)
  function _startMain(id, api, spec) {
    var comp = Qt.createComponent(Qt.resolvedUrl(spec.main));
    if (comp.status !== Component.Ready) {
      Logger.e("Builtin", "Failed to load", spec.main, comp.errorString());
      return;
    }
    var inst = comp.createObject(root.container || root, {
                                   "pluginApi": api
                                 });
    api.mainInstance = inst;
  }

  // Returns the (lazily created) API object for a feature id
  function api(id) {
    return _apis[id] || _create(id);
  }

  // Create everything that must run in the background (IPC handlers, watchers)
  function init() {
    Logger.i("Builtin", "Service started");
    for (var id in _specs)
      api(id);
  }
}
