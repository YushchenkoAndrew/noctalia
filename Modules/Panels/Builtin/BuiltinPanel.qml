import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Builtin
import qs.Modules.MainScreen
import qs.Services.UI

/**
* SmartPanel hosting the panel content of a built-in feature
* (formerly the plugin panel slot). One instance per feature and screen.
*/
SmartPanel {
  id: root

  // Feature id as used by Builtin.api(), e.g. "clipboard"
  property string builtinId: ""
  // QML file (url) with the panel content
  property url contentSource

  // Panel content item (null while the panel is closed)
  property var pluginInstance: null

  panelAnchorHorizontalCenter: pluginInstance?.panelAnchorHorizontalCenter ?? false
  panelAnchorVerticalCenter: pluginInstance?.panelAnchorVerticalCenter ?? false
  panelAnchorTop: pluginInstance?.panelAnchorTop ?? false
  panelAnchorBottom: pluginInstance?.panelAnchorBottom ?? false
  panelAnchorLeft: pluginInstance?.panelAnchorLeft ?? false
  panelAnchorRight: pluginInstance?.panelAnchorRight ?? false

  panelBackgroundColor: pluginInstance?.panelBackgroundColor ?? Color.mSurface

  panelContent: Component {
    Item {
      id: panelContainer

      // Required by SmartPanel for background rendering geometry
      readonly property var geometryPlaceholder: contentItem

      // The content may opt out of attachment but cannot override the global setting
      readonly property bool allowAttach: {
        var globalAllow = Settings.data.ui.panelsAttachedToBar || root.forceAttachToBar;
        if (!globalAllow)
          return false;
        if (contentLoader.item && contentLoader.item.allowAttach !== undefined)
          return contentLoader.item.allowAttach;
        return globalAllow;
      }

      property var contentPreferredWidth: {
        if (contentLoader.item && contentLoader.item.contentPreferredWidth !== undefined && contentLoader.item.contentPreferredWidth > 0)
          return contentLoader.item.contentPreferredWidth;
        return undefined;
      }

      property var contentPreferredHeight: {
        if (contentLoader.item && contentLoader.item.contentPreferredHeight !== undefined && contentLoader.item.contentPreferredHeight > 0)
          return contentLoader.item.contentPreferredHeight;
        return undefined;
      }

      anchors.fill: parent

      Item {
        id: contentItem
        anchors.fill: parent

        Loader {
          id: contentLoader
          anchors.fill: parent
          active: false
        }
      }

      Component.onCompleted: {
        contentLoader.active = true;
        contentLoader.setSource(root.contentSource, {
                                  "pluginApi": Builtin.api(root.builtinId)
                                });
        root.pluginInstance = contentLoader.item;
      }
    }
  }

  Component.onCompleted: PanelService.registerPanel(root)

  onOpened: {
    var api = Builtin.api(root.builtinId);
    if (api)
      api.panelOpenScreen = root.screen;
  }

  onClosed: {
    var api = Builtin.api(root.builtinId);
    if (api)
      api.panelOpenScreen = null;
    root.pluginInstance = null;
  }
}
