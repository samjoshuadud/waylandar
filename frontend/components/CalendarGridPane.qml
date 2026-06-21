import QtQuick
import Quickshell
import ".."

Item {
    id: root

    property int currentViewMonth
    property int currentViewYear
    property string currentMonthStr
    property var monthDays
    property var activeEventDays
    property string selectedDateStr
    property bool isFetching

    signal changeMonth(int offset)
    signal dateSelected(string dateStr)

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Row {
            spacing: 20
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Previous Month Button
            Rectangle {
                width: 32; height: 32; radius: 16
                color: prevMouseArea.containsMouse ? Theme.outline : "transparent"
                Text { text: "◀"; anchors.centerIn: parent; color: Theme.primary; font.pixelSize: 14 }
                MouseArea {
                    id: prevMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.changeMonth(-1)
                }
            }
            
            Text {
                text: root.currentMonthStr
                font.pixelSize: 28
                font.bold: true
                font.family: "Inter"
                color: Theme.colorOnBackground
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Next Month Button
            Rectangle {
                width: 32; height: 32; radius: 16
                color: nextMouseArea.containsMouse ? Theme.outline : "transparent"
                Text { text: "▶"; anchors.centerIn: parent; color: Theme.primary; font.pixelSize: 14 }
                MouseArea {
                    id: nextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.changeMonth(1)
                }
            }
        }
        
        Row {
            width: parent.width
            spacing: 0
            Repeater {
                model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                Text {
                    width: parent.width / 7
                    text: modelData
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "Inter"
                    color: Theme.primary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        
        // The actual 7x6 month grid
        GridView {
            id: calGrid
            width: parent.width
            height: parent.height - 100
            cellWidth: width / 7
            cellHeight: height / 6
            model: root.monthDays
            interactive: false
            
            // Dim the grid when fetching
            opacity: root.isFetching ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            delegate: Rectangle {
                width: calGrid.cellWidth - 10
                height: calGrid.cellHeight - 10
                
                color: modelData.isCurrentMonth ? Theme.outline : Theme.surface
                radius: 12
                
                // Dim all unselected days, but less aggressively
                opacity: root.selectedDateStr === "" || root.selectedDateStr === modelData.dateStr ? 1.0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 200 } }
                
                border.color: modelData.dateStr === new Date().toDateString() ? Theme.tertiary : "transparent"
                border.width: 2
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.dayNum
                    font.pixelSize: 18
                    font.family: "Inter"
                    font.bold: modelData.dateStr === new Date().toDateString()
                    color: modelData.isCurrentMonth ? Theme.colorOnBackground : Theme.colorOnSurfaceVariant
                }
                
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.primary
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.activeEventDays[modelData.dateStr] === true
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selectedDateStr === modelData.dateStr) {
                            root.dateSelected(""); 
                        } else {
                            root.dateSelected(modelData.dateStr); 
                        }
                    }
                }
            }
        }
    }
    
    LoadingSpinner {
        active: root.isFetching
    }
}
