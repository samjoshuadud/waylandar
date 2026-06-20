import QtQuick
import ".."

Item {
    id: root
    
    property var availableCalendars: []
    property var selectedCalendarIds: ({})
    property bool isFetching: false
    
    signal toggleCalendar(string calendarId)

    property string activeProvider: "google"
    
    Rectangle {
        id: providerBadge
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        height: 26
        width: providerIcon.width + providerText.width + 24
        radius: 13
        color: Theme.primary
        opacity: 0.8
        
        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                id: providerIcon
                text: root.activeProvider === "nextcloud" ? "☁" : "G"
                font.pixelSize: 12
                font.bold: true
                color: Theme.colorOnPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: providerText
                text: root.activeProvider === "nextcloud" ? "Nextcloud" : "Google"
                font.pixelSize: 12
                font.bold: true
                font.family: "Inter"
                color: Theme.colorOnPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        anchors.bottomMargin: providerBadge.height + 40 // Make room for the badge
        spacing: 20
        
        Text {
            id: sidebarTitle
            text: "Calendars"
            font.pixelSize: 24
            font.bold: true
            font.family: "Inter"
            color: Theme.colorOnBackground
        }
        
        ListView {
            width: parent.width
            height: parent.height - sidebarTitle.height - 20
            model: availableCalendars
            spacing: 12
            clip: true
            
            opacity: root.isFetching ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            delegate: Item {
              width: ListView.view.width
              height: 24

              Rectangle {
                  id: checkbox
                  width: 18; height: 18; radius: 4
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.selectedCalendarIds[modelData.id] ? modelData.color : "transparent"
                  border.color: modelData.color
                  border.width: 2

                  Text {
                      anchors.centerIn: parent
                      text: "✓"
                      color: Theme.background
                      visible: root.selectedCalendarIds[modelData.id] === true
                      font.pixelSize: 12
                      font.bold: true
                  }
              }

              Text {
                  text: modelData.name
                  font.pixelSize: 13
                  font.family: "Inter"
                  color: Theme.colorOnBackground
                  anchors.left: checkbox.right
                  anchors.leftMargin: 10
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
              }

              MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleCalendar(modelData.id)
              }
          }
        }
    }
    
    // Custom Sleek Loading Spinner for Left Pane
    Rectangle {
        anchors.centerIn: parent
        width: 32
        height: 32
        color: "transparent"
        radius: 16
        border.color: Theme.primary
        border.width: 3
        visible: opacity > 0
        opacity: root.isFetching ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Rectangle {
            width: 16; height: 16; 
            color: Theme.background
            anchors.top: parent.top; anchors.right: parent.right
        }

        RotationAnimation on rotation {
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 800
            running: root.isFetching
        }
    }
}
