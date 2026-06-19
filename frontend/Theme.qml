pragma Singleton
import QtQuick

QtObject {
    property color background: Qt.rgba(5/255, 5/255, 12/255, 0.95)
    property color colorOnBackground: "#cdd6f4"
    
    property color surface: Qt.rgba(255/255, 255/255, 255/255, 0.03)
    property color surfaceVariant: Qt.rgba(255/255, 255/255, 255/255, 0.09)
    property color colorOnSurface: "#cdd6f4"
    property color colorOnSurfaceVariant: "#a6adc8"
    
    property color primary: "#89b4fa"
    property color colorOnPrimary: "#1e1e2e"
    
    property color secondary: "#b4befe"
    property color tertiary: "#f38ba8"
    
    property color outline: Qt.rgba(255/255, 255/255, 255/255, 0.1)
    property color outlineVariant: Qt.rgba(255/255, 255/255, 255/255, 0.05)
}
