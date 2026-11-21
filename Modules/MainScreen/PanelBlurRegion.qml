import QtQuick
import Quickshell
import qs.Commons

/**
* Blur region matching an open panel's real outline.
*
* The panel background is drawn with rounded corners, and with concave "inverted" corners (flares) where an
* attached panel meets the bar. Upstream Quickshell's Region has no concave corner, so each flare is built from
* two regions: a small square next to the panel corner minus a circle (the arc). The geometry follows
* PanelBackground.qml / ShapeCornerHelper.qml:
*   state  0 : normal rounded corner   state -1 : flat (square)
*   state  1 : flare outward along X   state  2 : flare outward along Y
*/
Region {
  id: root

  // Anything with x, y, width, height and top/bottom Left/Right CornerState (a PanelBackground)
  property var panel: null

  readonly property int r: Style.radiusL

  x: panel ? Math.round(panel.x) : 0
  y: panel ? Math.round(panel.y) : 0
  width: panel ? Math.round(panel.width) : 0
  height: panel ? Math.round(panel.height) : 0

  radius: r
  topLeftRadius: (panel ? panel.topLeftCornerState : 0) === 0 ? r : 0
  topRightRadius: (panel ? panel.topRightCornerState : 0) === 0 ? r : 0
  bottomLeftRadius: (panel ? panel.bottomLeftCornerState : 0) === 0 ? r : 0
  bottomRightRadius: (panel ? panel.bottomRightCornerState : 0) === 0 ? r : 0

  // Geometry of the flare at one corner: the square next to the corner and the centre of the circle to cut out.
  // corner: 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right. Returns null when the corner has no flare.
  function flare(corner, state) {
    if (state !== 1 && state !== 2)
      return null;
    const px = Math.round(panel ? panel.x : 0);
    const py = Math.round(panel ? panel.y : 0);
    const pw = Math.round(panel ? panel.width : 0);
    const ph = Math.round(panel ? panel.height : 0);
    if (pw <= 0 || ph <= 0)
      return null;
    const sx = (corner === 0 || corner === 2) ? -1 : 1; // outward direction on X
    const sy = (corner === 0 || corner === 1) ? -1 : 1; // outward direction on Y
    const cx = sx < 0 ? px : px + pw;
    const cy = sy < 0 ? py : py + ph;
    if (state === 1) {
      return {
        "sx": sx < 0 ? cx - r : cx,
        "sy": sy < 0 ? cy : cy - r,
        "dx": cx + sx * r,
        "dy": cy - sy * r
      };
    }
    return {
      "sx": sx < 0 ? cx : cx - r,
      "sy": sy < 0 ? cy - r : cy,
      "dx": cx - sx * r,
      "dy": cy + sy * r
    };
  }

  component Flare: Region {
    id: f
    required property int corner
    required property int cornerState
    readonly property var g: root.flare(corner, cornerState)

    x: g ? g.sx : 0
    y: g ? g.sy : 0
    width: g ? root.r : 0
    height: g ? root.r : 0

    Region {
      intersection: Intersection.Subtract
      shape: RegionShape.Ellipse
      x: f.g ? f.g.dx - root.r : 0
      y: f.g ? f.g.dy - root.r : 0
      width: f.g ? root.r * 2 : 0
      height: f.g ? root.r * 2 : 0
    }
  }

  Flare {
    corner: 0
    cornerState: root.panel ? root.panel.topLeftCornerState : 0
  }
  Flare {
    corner: 1
    cornerState: root.panel ? root.panel.topRightCornerState : 0
  }
  Flare {
    corner: 2
    cornerState: root.panel ? root.panel.bottomLeftCornerState : 0
  }
  Flare {
    corner: 3
    cornerState: root.panel ? root.panel.bottomRightCornerState : 0
  }
}
