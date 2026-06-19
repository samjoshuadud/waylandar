import QtQuick
import ".."

ListView {
    property var events: []
    
    model: events
    spacing: 12
    clip: true
    
    // Tracks which card is currently expanded!
    property int expandedIndex: -1

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
        visible: parent.events.length === 0 && !pythonScript.running
        text: "Your schedule is clear! 󰄬"
        font.pixelSize: 14
        font.italic: true
        color: Theme.colorOnSurfaceVariant
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
