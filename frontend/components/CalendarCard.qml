import QtQuick

Rectangle {
    property var eventData: null
    
    height: eventData && eventData.description ? 95 : 65
    color: cardMouseArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.09) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
    radius: 12
    
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor 
        
        onClicked: {
            if (eventData && eventData.link) {
                console.log("Opening link: " + eventData.link);
                Qt.openUrlExternally(eventData.link);
            }
        }
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 15

        Rectangle {
            width: 4
            height: parent.height
            radius: 2
            color: "#f38ba8" 
        }

        Column {
            spacing: 4
            width: parent.width - 30

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
                    var loc = Qt.locale("en_US"); // Forces English!
                    return d.toLocaleDateString(loc, "ddd MMM d") + " at " + d.toLocaleTimeString(loc, "h:mm AP");
                }
                font.pixelSize: 12
                font.family: "Inter"
                color: "#a6adc8"
            }

            // Description block (only shows if description exists)
            Text {
                text: eventData && eventData.description ? eventData.description : ""
                font.pixelSize: 11
                font.family: "Inter"
                color: Qt.rgba(166/255, 173/255, 200/255, 0.7) // Faded text
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                width: parent.width
                visible: text !== ""
            }
        }
    }
}
