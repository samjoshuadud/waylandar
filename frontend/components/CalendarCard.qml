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
    
    Item {
        id: topRow
        width: parent.width
        height: 55
        anchors.top: parent.top
        
        // Left color accent bar
        Rectangle {
            id: accentBar
            width: 4
            height: 34
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: eventData && eventData.calendar_color ? eventData.calendar_color : Theme.tertiary 
        }

        // Text details container
        Column {
            spacing: 4
            anchors.left: accentBar.right
            anchors.leftMargin: 15
            anchors.right: parent.right
            anchors.rightMargin: 16
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
                    let isAllDay = eventData.start.length === 10;
                    
                    let d = new Date(eventData.start);
                    if (isAllDay) {
                        let parts = eventData.start.split('-');
                        d = new Date(parts[0], parts[1] - 1, parts[2], 0, 0, 0);
                    }
                    
                    let endD = eventData.end ? new Date(eventData.end) : d;
                    if (eventData.end && eventData.end.length === 10) {
                        let parts = eventData.end.split('-');
                        endD = new Date(parts[0], parts[1] - 1, parts[2], 23, 59, 59);
                    }

                    let loc = Qt.locale("en_US"); 
                    let now = new Date();
                    
                    let isOngoing = (d <= now && now <= endD);
                    let ongoingBadge = isOngoing ? "  🔴 (Ongoing)" : "";
                    
                    if (isAllDay) {
                        return d.toLocaleDateString(loc, "ddd MMM d") + " (All Day) • " + (eventData.calendar_name || "Unknown") + ongoingBadge;
                    }
                    
                    let timeRange = d.toLocaleTimeString(loc, "h:mm AP");
                    if (eventData.end && eventData.end !== eventData.start) {
                        timeRange += " - " + endD.toLocaleTimeString(loc, "h:mm AP");
                    }
                    
                    return d.toLocaleDateString(loc, "ddd MMM d") + " at " + timeRange + " • " + (eventData.calendar_name || "Unknown") + ongoingBadge;
                }
                font.pixelSize: 12
                font.family: "Inter"
                color: Theme.colorOnSurfaceVariant
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // The expanding details container
    Item {
        id: expandedDetails
        anchors.top: topRow.bottom
        anchors.left: parent.left
        anchors.leftMargin: 35
        anchors.right: parent.right
        anchors.rightMargin: 16
        
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
                text: {
                    if (!eventData || !eventData.reminders || eventData.reminders.length === 0) return "🔔 No reminder set.";
                    let textArr = eventData.reminders.map(r => r === 0 ? "At time of event" : r + " minutes before");
                    return "🔔 Reminder: " + textArr.join(", ");
                }
                font.pixelSize: 12
                font.family: "Inter"
                font.bold: true
                color: Theme.tertiary
            }

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
