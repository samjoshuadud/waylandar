pragma Singleton
import QtQuick

// Resolves the font settings from Theme.qml. A user's Theme.qml is kept
// across upgrades, so one written before these properties existed still
// works: every missing property falls back to the previous fixed value.
QtObject {
    readonly property string family: Theme.fontFamily !== undefined ? Theme.fontFamily : "Inter"
    readonly property string headerFamily: Theme.headerFontFamily !== undefined ? Theme.headerFontFamily : family
    readonly property real scale: Theme.fontScale !== undefined ? Theme.fontScale : 1.0

    function px(size) { return Math.round(size * scale) }
}
