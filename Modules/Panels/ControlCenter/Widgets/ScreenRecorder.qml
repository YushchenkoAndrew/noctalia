
import QtQuick
import Quickshell
import qs.Widgets
import qs.Commons
import qs.Modules.Builtin

NIconButton {
    property ShellScreen screen
    property var pluginApi: Builtin.api("screen-recorder")
    readonly property var mainInstance: pluginApi?.mainInstance

    enabled: mainInstance?.isAvailable ?? false
    icon: "camera-video"
    tooltipText: mainInstance?.buildTooltip()
    colorFg: mainInstance?.isRecording ? Color.mOnPrimary : (mainInstance?.isReplaying ? Color.mSecondary : Color.mPrimary)
    colorBg: mainInstance?.isRecording ? Color.mPrimary : (mainInstance?.isReplaying ? Qt.alpha(Color.mSecondary, 0.25) : Style.capsuleColor)
    onClicked: {
        if (pluginApi && pluginApi.mainInstance) {
            pluginApi.mainInstance.toggleRecording();
        }
    }
}
