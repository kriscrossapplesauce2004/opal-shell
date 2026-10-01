import QtQuick
import Quickshell
import "src" as Opal

// Drives LockController against throwaway PAM configs. Markers go to the log.
ShellRoot {
    property var attempts: (Quickshell.env("OPAL_TEST_PASSWORDS") || "any password").split(",")
    property int attempt: 0
    Opal.LockController {
        id: lock
        onUnlocked: { console.log("LOCK_UNLOCKED " + attempt); Qt.quit(); }
        onErrorChanged: if (error !== "") {
            console.log("LOCK_ERROR " + error);
            if (attempt + 1 < attempts.length) { attempt++; Qt.callLater(() => lock.submit(attempts[attempt])); }
            else Qt.quit();
        }
    }
    Component.onCompleted: Qt.callLater(() => lock.submit(attempts[0]))
    Timer { interval: 10000; running: true; onTriggered: { console.log("LOCK_TIMEOUT"); Qt.quit(); } }
}
