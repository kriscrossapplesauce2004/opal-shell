import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "src" as Opal

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    QtObject {
        id: flow
        property string message: "Authentication is required to install software."
        property string actionId: "org.freedesktop.policykit.exec"
        property var identities: [{displayName: "Melissa", string: "melissa", id: 1000}, {displayName: "Administrator", string: "root", id: 0}]
        property var selectedIdentity: identities[0]
        property bool failed: false
        property bool responseVisible: false
        property bool isResponseRequired: true
        property bool isCompleted: false
        property string inputPrompt: "Password:"
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property int submissions: 0
        property int cancellations: 0
        signal authenticationFailed()
        function submit(response) { submissions++; isResponseRequired = false; inputPrompt = ""; }
        function cancelAuthenticationRequest() { cancellations++; isCompleted = true; }
    }
    Window {
        id: window
        width: 640; height: 620; visible: true; color: Opal.Theme.base
        Opal.PolkitCard { id: card; anchors.centerIn: parent; width: Math.min(456, parent.width - 32); flow: flow }
        TestCase {
            id: checks
            name: "PolkitCard"
            when: false
            function test_authentication() {
                const input = findChild(card, "polkitResponse");
                compare(card.identity, "Melissa");
                compare(input.echoMode, TextInput.Password);
                verify(!card.canSubmit);
                input.text = "test-only";
                card.revealed = true;
                verify(card.canSubmit);
                card.submit();
                compare(flow.submissions, 1);
                compare(input.text, "");
                verify(!card.revealed);
                verify(card.busy);
                verify(!card.canSubmit);
                card.submit();
                compare(flow.submissions, 1);
                flow.failed = true;
                flow.authenticationFailed();
                flow.inputPrompt = "Password:";
                flow.isResponseRequired = true;
                tryCompare(input, "activeFocus", true);
                verify(!card.busy);
                verify(card.hasError);
                input.text = "discard-on-account-change";
                flow.selectedIdentity = flow.identities[1];
                compare(input.text, "");
                compare(card.identity, "Administrator");
                flow.responseVisible = true;
                flow.inputPrompt = "Verification code:";
                compare(card.prompt, "Verification code");
                compare(input.echoMode, TextInput.Normal);
                input.text = "discard-on-cancel";
                card.cancel();
                compare(flow.cancellations, 1);
                compare(input.text, "");
                verify(!card.canSubmit);
                flow.isCompleted = false;
                flow.failed = false;
                flow.selectedIdentity = flow.identities[0];
                flow.responseVisible = false;
                flow.inputPrompt = "Password:";
                console.log("POLKIT_BEHAVIOR_PASSED");
                captures.start();
            }
        }
        Timer {
            interval: 300; running: true
            onTriggered: {
                try { checks.test_authentication(); }
                catch (error) { console.error("ASSERTION_FAILED " + error); Qt.exit(1); }
            }
        }
        property int captureIndex: 0
        property var cases: ["dark", "light", "phone", "error", "busy", "details"]
        Timer {
            id: captures
            interval: 300; repeat: true
            onTriggered: {
                const label = window.cases[window.captureIndex];
                if (!label) { stop(); console.log("OFFSCREEN_TESTS_COMPLETE"); Qt.quit(); return; }
                Opal.Hub.prefs = Object.assign({}, Opal.Hub.prefs, {light: label === "light" || label === "phone"});
                window.width = label === "phone" ? 360 : 640;
                window.height = label === "phone" ? 740 : 620;
                flow.failed = label === "error";
                flow.isResponseRequired = label !== "busy";
                flow.supplementaryMessage = label === "error" ? "Authentication failed. Please try again." : "";
                flow.supplementaryIsError = label === "error";
                card.detailsOpen = label === "details";
                captureDelay.start();
                stop();
            }
        }
        Timer {
            id: captureDelay
            interval: 250
            onTriggered: window.contentItem.grabToImage(result => {
                result.saveToFile(Quickshell.env("OPAL_TEST_OUTPUT") + "/polkit-" + window.cases[window.captureIndex] + ".png");
                window.captureIndex++;
                captures.start();
            })
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("ASSERTION_FAILED polkit test timeout"); Qt.exit(1); } }
}
