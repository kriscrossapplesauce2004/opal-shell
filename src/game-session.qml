import QtQuick
import Quickshell
import Quickshell.Io

// Opal as the gamescope shell. Two X11 windows that gamescope_bridge.py labels by title:
// opal-home is the base app (Steam's app id 769) under every game, opal-overlay is composited above the focused app.
// The overlay paints only what is open: Quick Access, the glance, a shell page and toasts. Elsewhere it is transparent.
ShellRoot {
    id: session
    Component.onCompleted: Quickshell.watchFiles = false
    // quickshell ipc -p <config>/game-session.qml call opal <function>, for keybinds and controllers without Guide.
    IpcHandler {
        target: "opal"
        function quickaccess(): void { ControllerNav.guide(true); }
        function home(): void { Compositor.showHome(); }
        function guide(): void { ControllerNav.input("guide"); }
        function navigate(key: string): void { ControllerNav.input(key); }
        function inspect(): string { return JSON.stringify({home: Compositor.homeShown, quickAccess: GameState.quickAccess, stage: GameState.stage, game: GameState.gameTitle, windows: Hub.windows.length}); }
    }
    readonly property var output: Quickshell.screens.length ? Quickshell.screens[0] : null
    FloatingWindow {
        id: homeWindow
        title: "opal-home"
        implicitWidth: session.output ? session.output.width : 1280
        implicitHeight: session.output ? session.output.height : 800
        color: Theme.base
        ConsoleHome { anchors.fill: parent; embedded: true }
    }
    FloatingWindow {
        id: overlayWindow
        title: "opal-overlay"
        implicitWidth: homeWindow.implicitWidth
        implicitHeight: homeWindow.implicitHeight
        color: "transparent"
        QuickAccess { anchors.fill: parent }
        // Shell pages the home opens (Settings, Controls) appear as a sheet in the overlay.
        Rectangle {
            anchors.fill: parent; color: Theme.alpha("#000000", .5)
            visible: page.active
            MouseArea { anchors.fill: parent; onClicked: Hub.close() }
        }
        Surface {
            id: pageSurface
            visible: page.active
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, Hub.page === "settings" ? 920 : 520); height: Math.min(parent.height - 48, Hub.page === "settings" ? 760 : 720)
            radius: 32
            MouseArea { anchors.fill: parent }
            Loader {
                id: page
                anchors.fill: parent
                active: Hub.page === "settings" || Hub.page === "controls"
                sourceComponent: Hub.page === "settings" ? settingsPage : controlsPage
            }
            ControllerFocus { anchors.fill: parent; root: page; priority: 9; active: page.active; tabHints: true }
        }
        Component { id: settingsPage; Settings {} }
        Component { id: controlsPage; QuickSettings {} }
        // Messages from the shell.
        Rectangle {
            visible: Hub.toast !== ""
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 32
            height: 48; width: toastText.implicitWidth + 40; radius: 24
            color: Theme.alpha(Theme.level(4), .96); border.width: 1; border.color: Theme.outline
            MText { id: toastText; anchors.centerIn: parent; text: Hub.toast; role: "titleS" }
        }
    }
    // Gamescope gives the overlay input only while something in it is open.
    readonly property bool overlayWantsInput: (GameState.quickAccess && GameState.stage === "sheet") || page.active
    onOverlayWantsInputChanged: Compositor.overlayInput(overlayWantsInput)
}
