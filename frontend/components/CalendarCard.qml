import QtQuick
import ".."

Rectangle {
    property var eventData: null
    property bool isExpanded: false
    signal toggleExpand()
    
    height: isExpanded ? Math.max(110, 80 + expandedDetails.height) : 55
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    
    color: cardMouseArea.containsMouse ? Theme.surfaceVariant : Theme.surface
    radius: 12
    clip: true
    
    // Smoothly fades the color instead of snapping instantly
    Behavior on color { ColorAnimation { duration: 150 } }

    // Clicking the card toggles the expansion
    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleExpand()
    }
    
    Row {
        id: topRow
        width: parent.width
        height: 55
        anchors.top: parent.top
        spacing: 15
        
        Item { width: 1; height: 1 } // Padding

        // Left color accent bar
        Rectangle {
            width: 4
            height: 34
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Theme.tertiary 
        }

        // Text details container
        Column {
            spacing: 4
            width: parent.width - 45
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: eventData ? eventData.title : ""
                font.pixelSize: 14
                font.bold: true
                font.family: "Inter"
                color: Theme.colorOnBackground
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: {
                    if (!eventData) return "";
                    var d = new Date(eventData.start);
                    var loc = Qt.locale("en_US"); 
                    return d.toLocaleDateString(loc, "ddd MMM d") + " at " + d.toLocaleTimeString(loc, "h:mm AP");
                }
                font.pixelSize: 12
                font.family: "Inter"
                color: Theme.colorOnSurfaceVariant
            }
        }
    }

    // The expanding details container
    Item {
        id: expandedDetails
        width: parent.width - 45
        anchors.top: topRow.bottom
        anchors.left: parent.left
        anchors.leftMargin: 35
        
        // Fades in smoothly as it drops down
        opacity: isExpanded ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        
        height: detailCol.height + 15

        Column {
            id: detailCol
            width: parent.width
            spacing: 12

            Text {
                text: eventData && eventData.description ? eventData.description : "No additional description."
                font.pixelSize: 12
                font.family: "Inter"
                color: Theme.colorOnSurfaceVariant
                wrapMode: Text.WordWrap
                width: parent.width
            }

            // Beautiful Open in Browser Button
            Rectangle {
                width: 140
                height: 32
                radius: 6
                color: linkMouseArea.containsMouse ? Theme.secondary : Theme.primary
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰌹" // Optional Nerd Font Link icon
                        font.pixelSize: 14
                        color: Theme.colorOnPrimary
                        visible: false // Just in case they don't have nerd fonts
                    }
                    Text {
                        text: "Open in Browser"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                        color: Theme.colorOnPrimary
                    }
                }

                MouseArea {
                    id: linkMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (eventData && eventData.link) {
                            Qt.openUrlExternally(eventData.link);
                        }
                    }
                }
            }
        }
    }
}
