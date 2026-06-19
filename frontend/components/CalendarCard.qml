import QtQuick

Rectangle {
    property var eventData: null
    property bool isExpanded: false
    signal toggleExpand()
    
    height: isExpanded ? Math.max(120, 90 + expandedDetails.height) : 65
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    
    color: cardMouseArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.09) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
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
        height: 65
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 15
        
        Item { width: 1; height: 1 } // Padding

        // Left color accent bar
        Rectangle {
            width: 4
            height: 41
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: "#f38ba8" 
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
                color: "#cdd6f4"
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
                color: "#a6adc8"
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
                color: Qt.rgba(166/255, 173/255, 200/255, 0.8)
                wrapMode: Text.WordWrap
                width: parent.width
            }

            // Beautiful Open in Browser Button
            Rectangle {
                width: 140
                height: 32
                radius: 6
                color: linkMouseArea.containsMouse ? "#b4befe" : "#89b4fa"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰌹" // Optional Nerd Font Link icon
                        font.pixelSize: 14
                        color: "#1e1e2e"
                        visible: false // Just in case they don't have nerd fonts
                    }
                    Text {
                        text: "Open in Browser"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter"
                        color: "#1e1e2e"
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
