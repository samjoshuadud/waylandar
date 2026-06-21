import QtQuick
import Quickshell
import ".."

Rectangle {
    id: root
    property bool active: false

    anchors.centerIn: parent
    width: 32
    height: 32
    color: "transparent"
    radius: 16
    border.color: Theme.primary
    border.width: 3
    
    visible: opacity > 0
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 300 } }

    Rectangle {
        width: 16; height: 16; 
        color: Theme.background
        anchors.top: parent.top; anchors.right: parent.right
    }

    RotationAnimation on rotation {
        loops: Animation.Infinite
        from: 0; to: 360
        duration: 800
        running: active
    }
}
