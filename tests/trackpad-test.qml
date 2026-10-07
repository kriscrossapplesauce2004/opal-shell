import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "src" as Opal

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    Window {
        width: 400; height: 700; visible: true
        Opal.DockTrackpad { id: pad; anchors.fill: parent }
        TestCase {
            id: tests
            name: "Trackpad"
            when: false
            property var commands: []
            property var area
            function initTestCase() {
                area = findChild(pad, "trackpadTouch");
                verify(area !== null);
                pad.send = function(data) { commands.push(data); };
            }
            function init() { area.reset(); commands = []; }
            function test_moveAndTap() {
                const sequence = touchEvent(area);
                sequence.press(0, area, 100, 100).commit();
                sequence.move(0, area, 110, 105).commit();
                sequence.release(0, area, 110, 105).commit();
                compare(commands.length, 1);
                compare(commands[0].op, "move");
                compare(commands[0].dx, 18);
                compare(commands[0].dy, 9);
                commands = [];
                sequence.press(0, area, 100, 100).commit();
                sequence.release(0, area, 100, 100).commit();
                compare(commands.length, 1);
                compare(commands[0].op, "click");
                compare(commands[0].button, "left");
            }
            function test_twoFingerTap() {
                const sequence = touchEvent(area);
                sequence.press(0, area, 100, 100).press(1, area, 150, 100).commit();
                sequence.release(0, area, 100, 100).release(1, area, 150, 100).commit();
                compare(commands.length, 1);
                compare(commands[0].button, "right");
            }
            function test_scrollThenLift() {
                const sequence = touchEvent(area);
                sequence.press(0, area, 100, 100).press(1, area, 150, 100).commit();
                sequence.move(0, area, 100, 120).move(1, area, 150, 120).commit();
                sequence.release(1, area, 150, 120).stationary(0).commit();
                sequence.move(0, area, 100, 140).commit();
                sequence.release(0, area, 100, 140).commit();
                verify(commands.length > 0);
                verify(commands.every(c => c.op === "scroll"));
            }
            function test_cancelDrag() {
                const sequence = touchEvent(area);
                sequence.press(0, area, 100, 100).commit();
                wait(500);
                verify(pad.holding);
                area.canceled([]);
                verify(!pad.holding);
                compare(commands[commands.length - 1].op, "up");
                sequence.release(0, area, 100, 100).commit();
            }
            function test_mouseIgnored() {
                mousePress(area, 100, 100);
                mouseMove(area, 120, 120);
                mouseRelease(area, 120, 120);
                compare(commands.length, 0);
            }
            function cleanupTestCase() {
                console.log("OFFSCREEN_TESTS_COMPLETE");
                Qt.callLater(function() { Qt.quit(); });
            }
        }
        Timer {
            interval: 600; running: true
            onTriggered: {
                try {
                    tests.initTestCase();
                    for (const name of ["test_moveAndTap", "test_twoFingerTap", "test_scrollThenLift", "test_cancelDrag", "test_mouseIgnored"]) {
                        tests.init(); tests[name](); console.log("PASSED", name);
                    }
                    tests.cleanupTestCase();
                } catch (error) { console.error("ASSERTION_FAILED", error); Qt.quit(); }
            }
        }
    }
}
