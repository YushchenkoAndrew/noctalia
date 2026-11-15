import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
* AllBackgrounds - Shape containers for bar and panel backgrounds
*
* Two rendering layouts, only ONE of which is ever instantiated:
* - unified:  bar + panels share a single Shape/shadow (bar and panels are visually merged)
* - separate: panels and bar are rendered independently (separate opacity)
*
* Settings.data.bar.showBackground = false skips the bar background entirely (no Shape,
* no offscreen layer, no shadow). That forces the "separate" layout so panels still render.
*/
Item {
  id: root

  // Reference Bar
  required property var bar

  // Reference to MainScreen (for panel access)
  required property var windowRoot

  readonly property color panelBackgroundColor: Color.mSurface

  readonly property bool barBackgroundEnabled: Settings.data.bar.showBackground
  readonly property bool separateLayout: Settings.data.bar.useSeparateOpacity || !barBackgroundEnabled

  anchors.fill: parent

  // Unified background container (bar + panels in one Shape)
  Loader {
    anchors.fill: parent
    active: !root.separateLayout

    sourceComponent: Item {
      anchors.fill: parent

      // Enable layer caching to prevent continuous re-rendering
      layer.enabled: true
      opacity: Style.effectivePanelOpacity

      Shape {
        id: unifiedBackgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        Component.onCompleted: {
          Logger.d("AllBackgrounds", "AllBackgrounds initialized (unified)");
        }

        BarBackground {
          bar: root.bar
          shapeContainer: unifiedBackgroundsShape
          windowRoot: root.windowRoot
          backgroundColor: root.panelBackgroundColor
        }

        // Slot 0: currently open/opening panel
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: root.panelBackgroundColor
        }

        // Slot 1: closing panel (during transitions)
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: root.panelBackgroundColor
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: unifiedBackgroundsShape
      }
    }
  }

  // Separate layout: panels with panel opacity...
  Loader {
    anchors.fill: parent
    active: root.separateLayout

    sourceComponent: Item {
      anchors.fill: parent

      layer.enabled: true
      opacity: Style.effectivePanelOpacity

      Shape {
        id: panelBackgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        // Slot 0: currently open/opening panel
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: panelBackgroundsShape
          defaultBackgroundColor: root.panelBackgroundColor
        }

        // Slot 1: closing panel (during transitions)
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: panelBackgroundsShape
          defaultBackgroundColor: root.panelBackgroundColor
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: panelBackgroundsShape
      }
    }
  }

  // ...and the bar background with its own opacity (only when it is actually shown)
  Loader {
    anchors.fill: parent
    active: root.separateLayout && root.barBackgroundEnabled

    sourceComponent: Item {
      anchors.fill: parent

      layer.enabled: true
      opacity: Style.effectiveBarOpacity

      Shape {
        id: barBackgroundShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        BarBackground {
          bar: root.bar
          shapeContainer: barBackgroundShape
          windowRoot: root.windowRoot
          backgroundColor: root.panelBackgroundColor
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: barBackgroundShape
      }
    }
  }
}
