import QtQuick

ListView {
    property var events: []
    
    model: events
    spacing: 10
    clip: true

    delegate: CalendarCard {
        width: ListView.view.width
        eventData: modelData 
    }

    Text {
        visible: parent.events.length === 0 && !pythonScript.running
        text: "Your schedule is clear!"
        font.pixelSize: 14
        font.italic: true
        color: "#a6adc8"
        anchors.centerIn: parent
    }

    section.property: "sectionTitle"
    section.criteria: ViewSection.FullString
    section.delegate: Item {
        width: ListView.view.width
        height: 35
        
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: section 
            font.pixelSize: 13
            font.bold: true
            font.family: "Inter"
            color: "#89b4fa" 
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
        }
    }
}
