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
        visible: parent.events.length === 0
        text: "Your schedule is clear!"
        font.pixelSize: 14
        font.italic: true
        color: "#a6adc8"
        anchors.centerIn: parent
    }
}
