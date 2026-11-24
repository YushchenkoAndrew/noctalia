import QtQuick
import qs.Commons

// Rounded group container using the variant surface color.
// To be used in side panels and settings panes to group fields or buttons.
// Neutral colors follow ui.widgetBackgroundOpacity; accent colors (primary, error, hover, ...) always stay solid.

Item {
  id: root

  property color color: NColor.mSurfaceVariant
  property bool forceOpaque: false
  property alias radius: bg.radius
  property alias border: bg.border

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.radiusM
    border.color: Style.boxBorderColor
    border.width: Style.borderS
    color: {
      if (forceOpaque || NColor.isAccent(root.color)) {
        return root.color;
      }

      return NColor.smartAlpha(root.color);
    }
  }
}
