import QtQuick

Rectangle {
    property var eventData: null
    
    height: 65
    color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
    radius: 12
    
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
                    return d.toLocaleDateString(Qt.locale(), "ddd MMM d") + " at " + d.toLocaleTimeString(Qt.locale(), "h:mm AP");
                }
                font.pixelSize: 12
                font.family: "Inter"
                color: "#a6adc8"
            }
        }
    }
}
