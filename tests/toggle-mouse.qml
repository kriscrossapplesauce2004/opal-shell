import QtQuick
import QtQuick.Window
import QtTest
import "src" as Opal

// Real hit-tested mouse clicks against the settings row widgets, headless.
TestCase {
    id: tc
    name: "ToggleMouse"
    width: 480
    height: 500
    when: windowShown

    Column {
        id: list
        width: 460
    }

    function clickRow(key) {
        const comp = Qt.createComponent(Qt.resolvedUrl("src/SettingToggle.qml"));
        tryVerify(function() { return comp.status !== Component.Loading }, 20000);
        if (comp.status !== Component.Ready) console.log("COMP FAIL", comp.errorString());
        compare(comp.status, Component.Ready);
        // Inline handler, exactly the convention the settings pages use.
        const r = comp.createObject(list, {title: key,
                                           checked: !!Opal.Hub.prefs[key],
                                           onToggled: function() { Opal.Hub.set(key, !checked) }});
        tryVerify(function() { return r !== null }, 20000);
        tryVerify(function() { return r.checked === !!Opal.Hub.prefs[key] }, 5000, "checked mirrors prefs for " + key);
        const before = !!Opal.Hub.prefs[key];
        mouseClick(r, r.width * 0.4, r.height / 2, Qt.LeftButton);
        tryVerify(function() { return !!Opal.Hub.prefs[key] === !before }, 5000, key + " flips on click");
        tryVerify(function() { return r.checked === !before }, 5000, key + " check binding follows");
        tc.wait(1200); // the bridge echo must not revert
        compare(!!Opal.Hub.prefs[key], !before, key + " survives the echo");
        r.destroy();
    }

    function test_rowClickFlipsAndSticks() {
        clickRow("taskbarAutoHide");
        clickRow("desktopWidgets");
    }
}
