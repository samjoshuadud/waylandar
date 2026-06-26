pragma Singleton
import QtQuick

QtObject {
    property color background: Qt.alpha("{{colors.background.default.hex}}", 0.90)
    property color colorOnBackground: "{{colors.on_background.default.hex}}"
    
    property color surface: Qt.alpha("{{colors.surface.default.hex}}", 0.10)
    property color surfaceVariant: Qt.alpha("{{colors.surface_variant.default.hex}}", 0.20)
    property color colorOnSurface: "{{colors.on_surface.default.hex}}"
    property color colorOnSurfaceVariant: "{{colors.on_surface_variant.default.hex}}"
    
    property color primary: "{{colors.primary.default.hex}}"
    property color colorOnPrimary: "{{colors.on_primary.default.hex}}"
    
    property color secondary: "{{colors.secondary.default.hex}}"
    property color tertiary: "{{colors.tertiary.default.hex}}"
    
    property color outline: Qt.alpha("{{colors.outline.default.hex}}", 0.20)
    property color outlineVariant: Qt.alpha("{{colors.outline_variant.default.hex}}", 0.10)
    property color error: "{{colors.error.default.hex}}"
    property color errorContainer: "{{colors.error_container.default.hex}}"
    property color colorOnErrorContainer: "{{colors.on_error_container.default.hex}}"
}
