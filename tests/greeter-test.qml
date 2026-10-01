import QtQuick
import Quickshell
import "src" as Opal

// Drives GreeterController against a fake greetd socket. Markers go to the log.
ShellRoot {
    Opal.GreeterController {
        id: greeter
        infoCommand: ["python3", Quickshell.env("OPAL_TEST_INFO")]
        property int step: 0
        onUsersChanged: if (users.length && step === 0) Qt.callLater(begin)
        function begin() { step = 1; console.log("GREETER_USERS " + users.length + " " + user.login + " " + session.id); submit("wrong"); }
        onErrorChanged: if (error !== "" && step === 1) { step = 2; console.log("GREETER_ERROR " + error); Qt.callLater(() => submit("right")); }
        onLaunchedChanged: if (launched) { console.log("GREETER_LAUNCHED"); Qt.quit(); }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.log("GREETER_TIMEOUT"); Qt.quit(); } }
}
