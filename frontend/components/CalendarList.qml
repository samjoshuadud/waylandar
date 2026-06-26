import QtQuick
import ".."

ListView {
    property var events: []
    
    model: events
    spacing: 12
    clip: true
    
    // Tracks which card is currently expanded!
    property int expandedIndex: -1
    property string errorMessage: ""

    delegate: CalendarCard {
        width: ListView.view.width
        eventData: modelData 
        
        // Pass down the expansion state
        isExpanded: expandedIndex === index
        
        onToggleExpand: {
            if (expandedIndex === index) {
                expandedIndex = -1; // collapse
            } else {
                expandedIndex = index; // expand
            }
        }
    }

    Text {
        visible: parent.events.length === 0 && !pythonScript.running && errorMessage === ""
        text: "Your schedule is clear!"
        font.pixelSize: 14
        font.italic: true
        color: Theme.colorOnSurfaceVariant
        anchors.centerIn: parent
    }

    header: Item {
        width: ListView.view.width
        height: visible ? implicitHeight : 0
        visible: errorMessage !== "" && parent.events.length > 0
        implicitHeight: warningText.implicitHeight + 20
        
        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 8
            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
            border.color: Theme.error
            border.width: 1
            radius: 6
            
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                
                Text {
                    text: "⚠️"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    id: warningText
                    width: parent.width - 30
                    text: "Sync Alert:\n" + errorMessage
                    font.pixelSize: 11
                    font.family: "Inter"
                    color: Theme.colorOnBackground
                    wrapMode: Text.WrapAnywhere
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        visible: errorMessage !== "" && parent.events.length === 0
        contentWidth: width
        contentHeight: errorText.implicitHeight
        clip: true
        
        Text {
            id: errorText
            width: parent.width
            text: errorMessage
            font.pixelSize: 12
            font.family: "Inter"
            color: Theme.colorOnBackground
            wrapMode: Text.WrapAnywhere
            horizontalAlignment: Text.AlignHCenter
        }
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
            color: Theme.primary 
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }
    }
}
