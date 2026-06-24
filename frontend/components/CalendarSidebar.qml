import QtQuick
import ".."

Item {
    id: root
    
    property var availableCalendars: []
    property var selectedCalendarIds: ({})
    property bool isFetching: false
    property bool isSyncing: false
    property string authError: ""
    
    // States for account collapse/expand and account toggles
    property var accountStates: ({})
    property var collapsedAccounts: ({})
    
    signal toggleCalendar(string calendarId)
    signal toggleAccount(string accountId, string provider, bool enabled)
    signal syncRequested()

    property var parsedConfig: ({})

    // Compute grouped accounts dynamically from parsedConfig
    property var groupedAccounts: {
        let groups = [];
        let providers = parsedConfig.providers || {};
        
        // 1. Google Accounts
        let googleAccs = providers.google ? (providers.google.accounts || []) : [];
        for (let i = 0; i < googleAccs.length; i++) {
            let acc = googleAccs[i];
            groups.push({
                id: acc.id,
                name: acc.name || ("Google - " + acc.email),
                provider: "google",
                enabled: acc.enabled !== false,
                calendars: getCalendarsForAccount(acc.id)
            });
        }
        
        // 2. Nextcloud Accounts
        let ncAccs = providers.nextcloud ? (providers.nextcloud.accounts || []) : [];
        for (let i = 0; i < ncAccs.length; i++) {
            let acc = ncAccs[i];
            groups.push({
                id: acc.id,
                name: acc.name || ("Nextcloud - " + acc.username),
                provider: "nextcloud",
                enabled: acc.enabled !== false,
                calendars: getCalendarsForAccount(acc.id)
            });
        }
        
        // 3. iCloud Accounts
        let icAccs = providers.icloud ? (providers.icloud.accounts || []) : [];
        for (let i = 0; i < icAccs.length; i++) {
            let acc = icAccs[i];
            groups.push({
                id: acc.id,
                name: acc.name || ("iCloud - " + acc.username),
                provider: "icloud",
                enabled: acc.enabled !== false,
                calendars: getCalendarsForAccount(acc.id)
            });
        }
        
        // 4. ICS Feeds (grouped under "ICS Subscriptions")
        let icsFeeds = providers.ics ? (providers.ics.feeds || []) : [];
        if (icsFeeds.length > 0) {
            let icsEnabled = providers.ics.enabled !== false;
            groups.push({
                id: "ics",
                name: "ICS Subscriptions",
                provider: "ics",
                enabled: icsEnabled,
                calendars: getCalendarsForAccount("ics")
            });
        }
        
        // 5. Local Directories (grouped under "Local Directories")
        let vdirDirs = providers.vdirsyncer ? (providers.vdirsyncer.directories || []) : [];
        if (vdirDirs.length > 0) {
            let vdirEnabled = providers.vdirsyncer.enabled !== false;
            groups.push({
                id: "vdirsyncer",
                name: "Local Directories",
                provider: "vdirsyncer",
                enabled: vdirEnabled,
                calendars: getCalendarsForAccount("vdirsyncer")
            });
        }
        
        return groups;
    }
    
    function getCalendarsForAccount(accId) {
        let list = [];
        for (let i = 0; i < availableCalendars.length; i++) {
            if (availableCalendars[i].account_id === accId) {
                list.push(availableCalendars[i]);
            }
        }
        return list;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Item {
          id: headerLayout
          width: parent.width
          height: 32

          Text {
              id: sidebarTitle
              text: "Calendars"
              font.pixelSize: 20
              font.bold: true
              font.family: "Inter"
              color: Theme.colorOnBackground
              anchors.left: parent.left
              anchors.right: syncStatusButton.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
          }

          Rectangle {
              id: syncStatusButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: 26
              radius: 13
              width: syncRow.implicitWidth + 16
              color: syncMouse.containsMouse ? Theme.surfaceVariant : "transparent"

              Behavior on color { ColorAnimation { duration: 150 } }

              Row {
                  id: syncRow
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                      text: "↻"
                      font.pixelSize: 13
                      font.family: "Inter"
                      font.bold: true
                      color: root.authError !== "" ? Theme.error : (root.isSyncing ? Theme.primary : Theme.colorOnSurfaceVariant)
                      anchors.verticalCenter: parent.verticalCenter
                      opacity: root.isSyncing || root.authError !== "" ? 1.0 : 0.6

                      RotationAnimation on rotation {
                          running: root.isSyncing
                          loops: Animation.Infinite
                          from: 0; to: 360
                          duration: 1000
                          easing.type: Easing.Linear
                      }
                  }

                  Text {
                      text: root.authError !== "" ? "Error" : (root.isSyncing ? "Syncing..." : "Synced")
                      font.pixelSize: 11
                      font.family: "Inter"
                      font.bold: true
                      color: root.authError !== "" ? Theme.error : (root.isSyncing ? Theme.primary : Theme.colorOnSurfaceVariant)
                      anchors.verticalCenter: parent.verticalCenter
                      opacity: root.isSyncing || root.authError !== "" ? 1.0 : 0.6
                  }
              }

              MouseArea {
                  id: syncMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: root.isSyncing ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onClicked: {
                      if (!root.isSyncing) root.syncRequested()
                  }
              }
          }
      }
        
        ListView {
            id: accountsListView
            width: parent.width
            height: parent.height - headerLayout.height - cliLabel.height - 50
            model: root.groupedAccounts
            spacing: 16
            clip: true
            
            opacity: root.isFetching ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            delegate: Column {
                width: accountsListView.width
                spacing: 8
                
                // Account Header Row
                Row {
                    width: parent.width
                    height: 24
                    spacing: 8
                    
                    // Collapse/Expand Chevron
                    Text {
                        width: 12
                        text: root.collapsedAccounts[modelData.id] ? "▶" : "▼"
                        font.pixelSize: 11
                        color: Theme.colorOnBackground
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 0.7
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let col = Object.assign({}, root.collapsedAccounts);
                                col[modelData.id] = !col[modelData.id];
                                root.collapsedAccounts = col;
                            }
                        }
                    }
                    
                    // Account Toggle Checkbox
                    Rectangle {
                        id: accountCheckbox
                        width: 14; height: 14; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accountStates[modelData.id] !== false ? Theme.primary : "transparent"
                        border.color: Theme.primary
                        border.width: 1.5
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Theme.background
                            visible: root.accountStates[modelData.id] !== false
                            font.pixelSize: 10
                            font.bold: true
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let current = root.accountStates[modelData.id] !== false;
                                root.toggleAccount(modelData.id, modelData.provider, !current);
                            }
                        }
                    }
                    
                    // Account Name
                    Text {
                        text: modelData.name
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "Inter"
                        color: root.accountStates[modelData.id] !== false ? Theme.colorOnBackground : Theme.colorOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - 45
                        opacity: root.accountStates[modelData.id] !== false ? 1.0 : 0.5
                    }
                }
                
                // Nested Calendars List
                Column {
                    width: parent.width
                    spacing: 8
                    leftPadding: 20
                    visible: !root.collapsedAccounts[modelData.id] && root.accountStates[modelData.id] !== false
                    
                    Repeater {
                        model: modelData.calendars
                        
                        delegate: Item {
                            width: parent.width - 20
                            height: 20
                            
                            Rectangle {
                                id: checkbox
                                width: 14; height: 14; radius: 3
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.selectedCalendarIds[modelData.id] ? modelData.color : "transparent"
                                border.color: modelData.color
                                border.width: 1.5
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Theme.background
                                    visible: root.selectedCalendarIds[modelData.id] === true
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                            
                            Text {
                                text: modelData.name
                                font.pixelSize: 12
                                font.family: "Inter"
                                color: Theme.colorOnBackground
                                anchors.left: checkbox.right
                                anchors.leftMargin: 8
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
            }
        }
    }
    
    // Bottom-aligned CLI management hint
    Text {
        id: cliLabel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: 15
        text: "Manage Accounts in CLI\n(run 'waylandar' in terminal)"
        font.pixelSize: 11
        font.italic: true
        font.family: "Inter"
        horizontalAlignment: Text.AlignHCenter
        color: Theme.colorOnSurfaceVariant
        opacity: 0.6
        lineHeight: 1.2
    }

}
