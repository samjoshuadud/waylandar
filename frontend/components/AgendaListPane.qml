import QtQuick
import Quickshell
import ".."

Item {
    id: root

    property string selectedDateStr
    property var displayedEvents
    property string authError
    property bool isFetching

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Text {
            id: agendaTitle
            // Automatically changes the title if a day is selected
            text: root.selectedDateStr === "" ? "Agenda" : "Agenda - " + new Date(root.selectedDateStr).toLocaleDateString(Qt.locale("en_US"), "ddd, MMM d")
            font.pixelSize: 24
            font.bold: true
            font.family: "Inter"
            color: Theme.colorOnBackground
        }
        
        CalendarList {
            id: rightAgendaList
            width: parent.width
            height: parent.height - agendaTitle.height - 20
            events: root.displayedEvents
            errorMessage: root.authError
            
            // Dim the agenda list when fetching
            opacity: root.isFetching ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }
    
    LoadingSpinner {
        active: root.isFetching
    }
}
