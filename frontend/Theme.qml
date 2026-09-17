pragma Singleton
import QtQuick

QtObject {
    // Fonts. Family names as fontconfig knows them (fc-list : family); an empty
    // string uses the system default font. headerFontFamily is used for titles
    // (month name, "Upcoming Schedule", "Calendars", "Agenda"), fontFamily for
    // everything else. fontScale multiplies every text size.
    property string fontFamily: "Inter"
    property string headerFontFamily: fontFamily
    property real fontScale: 1.0

    property color background: Qt.alpha("#1a1110", 0.90)
    property color colorOnBackground: "#f1dfdc"
    
    property color surface: Qt.alpha("#1a1110", 0.10)
    property color surfaceVariant: Qt.alpha("#534341", 0.20)
    property color colorOnSurface: "#f1dfdc"
    property color colorOnSurfaceVariant: "#d8c2be"
    
    property color primary: "#ffb4a8"
    property color colorOnPrimary: "#561e16"
    
    property color secondary: "#e7bdb6"
    property color tertiary: "#dec48c"
    
    property color outline: Qt.alpha("#a08c89", 0.20)
    property color outlineVariant: Qt.alpha("#534341", 0.10)
    property color error: "#CF6679"
    property color errorContainer: "#93000A"
    property color colorOnErrorContainer: "#FFDAD6"
}
