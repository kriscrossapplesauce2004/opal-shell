import QtQuick
import Quickshell

// Smoke test: real opal/src leaves (via gen/) load through the Luna.Shell shim, then one is hosted in shim surfaces.
Item {
    id: host
    width: 800
    height: 600

    // Leaves expected to load: Theme-based primitives and a card.
    readonly property var leaves: [
        { name: "MText", file: "gen/MText.qml", props: { text: "Smoke", role: "" } },
        { name: "Glyph", file: "gen/Glyph.qml", props: { name: "apps" } },
        { name: "Surface", file: "gen/Surface.qml", props: { width: 120, height: 48 } },
        { name: "ProgressRing", file: "gen/ProgressRing.qml", props: { value: 0.5, width: 32, height: 32 } },
        { name: "SettingsGroup", file: "gen/SettingsGroup.qml", props: { title: "Group" } }
    ]
    // Probes: expected to fail or warn, since they need Quickshell services or attached properties.
    readonly property var probes: [
        { name: "NotificationCard", file: "gen/NotificationCard.qml", props: { entry: { summary: "Probe", body: "", appName: "probe", urgency: 1, icon: "" } } },
        { name: "TopBar", file: "gen/TopBar.qml", props: {} }
    ]

    function oneLine(text) { return String(text).split("\n").join(" | ") }

    function check(entry) {
        var component = Qt.createComponent(Qt.resolvedUrl(entry.file))
        if (component.status === Component.Error)
            return { name: entry.name, ok: false, detail: "load: " + oneLine(component.errorString()) }
        var obj = component.createObject(host, entry.props)
        if (obj === null)
            return { name: entry.name, ok: false, detail: "create: " + oneLine(component.errorString()) }
        obj.destroy()
        return { name: entry.name, ok: true, detail: "loaded and instantiated" }
    }

    // Surfaces: one shim PanelWindow per screen, each hosting the Glyph leaf.
    Variants {
        id: surfaces
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                objectName: "surface"
                screen: modelData
                width: 200
                height: 60
                Loader {
                    id: glyphHost
                    source: Qt.resolvedUrl("gen/Glyph.qml")
                }
            }
        }
    }

    function surfaceResult() {
        var hosted = 0
        var total = 0
        for (var i = 0; i < surfaces.children.length; i++) {
            var s = surfaces.children[i]
            if (s.objectName !== "surface") continue
            total++
            if (s.children.length > 0 && s.children[0].status !== undefined && s.children[0].status === Loader.Ready)
                hosted++
        }
        return { name: "Shim PanelWindow hosting Glyph", ok: total > 0 && hosted === total,
                 detail: "surfaces " + total + ", hosting Glyph " + hosted + ", screens " + Quickshell.screens.length }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            var failures = 0
            var leafOk = 0
            var lines = []
            for (var i = 0; i < host.leaves.length; i++) {
                var r = host.check(host.leaves[i])
                if (r.ok) leafOk++
                else failures++
                lines.push("LEAF " + (r.ok ? "PASS " : "FAIL ") + r.name + ": " + r.detail)
            }
            for (var j = 0; j < host.probes.length; j++) {
                var p = host.check(host.probes[j])
                lines.push("PROBE " + (p.ok ? "INSTANTIATED (see warnings above) " : "FAILED ") + p.name + ": " + p.detail)
            }
            var s = host.surfaceResult()
            if (!s.ok) failures++
            lines.push("SURFACE " + (s.ok ? "PASS " : "FAIL ") + s.name + ": " + s.detail)
            for (var k = 0; k < lines.length; k++) console.log(lines[k])
            console.log("SUMMARY leaves " + leafOk + " ok of " + host.leaves.length + ", surface check " + (s.ok ? "ok" : "failed") + ", probes are not counted")
            Qt.exit(failures === 0 ? 0 : 1)
        }
    }
}
