pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: deck
    required property var backend
    property var preferences: ({})
    property bool light: !!preferences.light
    property bool reduceMotion: !!preferences.reduceMotion
    property bool privateInput: backend.sensitive
    property string mode: "letters"
    property int shiftState: 0
    property bool control: false
    property bool alt: false
    property int handed: 0
    property bool selecting: false
    property int emojiPage: 0
    property string gestureHint: ""
    property var recentEmoji: []
    property bool autoCapitalize: true
    property bool handheld: false
    required property var suggestions
    property string lastChar: ""
    property real lastSpaceTime: 0
    property var focusedKey: null
    property var keyRegistry: []
    readonly property bool controllerActive: handheld || typeof gamepad !== "undefined" && gamepad !== null && gamepad.connected
    readonly property string layoutClass: width < 600 ? (width > availableHeight ? "phone-landscape" : "phone") : width < 1000 ? "tablet" : "desktop"
    readonly property bool wideLayout: width >= 720
    readonly property bool splitLayout: handed === 3 && wideLayout
    readonly property bool suggestionVisible: !privateInput && (mode === "letters" || mode === "symbols") && !terminalPurpose
    readonly property bool utilityRowVisible: mode === "emoji" || mode === "edit" || terminalPurpose
    readonly property var emojiTabs: recentEmoji.length > 0 ? ["Faces", "Hands", "Life", "Recent"] : ["Faces", "Hands", "Life"]
    readonly property var emojiPages: [
        [["😀","😊","😂","🥰","😎","🤔","😭","🙃"], ["😍","😘","😅","🤣","😴","😮","😬","🥹"], ["😇","🤗","😏","😤","😢","🫠","🫡","⌫"]],
        [["👍","👎","👏","🙏","👋","🤝","💪","🫶"], ["💜","❤️","🧡","💛","💚","💙","🖤","🤍"], ["🔥","✨","🎉","✅","👀","💯","💔","⌫"]],
        [["☕","🌙","☀️","🌧️","🌈","🌸","🌻","🌿"], ["🐈","🐕","🍕","🍰","🍓","🍜","🥐","🍵"], ["💡","🚀","🎵","🎮","🏠","📱","💻","⌫"]]
    ]
    property int generation: backend.generation
    property real shiftTime: 0
    property real availableHeight: 800
    property bool compact: availableHeight < 600
    readonly property bool shortLayout: availableHeight < 500
    readonly property bool showNumberRow: mode === "letters" || mode === "symbols"
    readonly property real contentWidth: handed === 1 || handed === 2 ? Math.min(420, width * 0.82) : layoutClass === "desktop" ? Math.min(width - 32, 1120) : layoutClass === "tablet" ? Math.min(width - 24, 940) : Math.min(width - (width < 400 ? 8 : 16), 860)
    readonly property real keyHeight: shortLayout ? 38 : compact ? 48 : 60
    property alias previewLayer: previews
    property int purpose: backend.purpose
    readonly property string fontFamily: "Google Sans Flex"
    readonly property var accents: ({a:["a","à","á","â","ä","æ","ã","å"], e:["e","è","é","ê","ë"], i:["i","ì","í","î","ï"], o:["o","ò","ó","ô","ö","œ","ø"], u:["u","ù","ú","û","ü"], c:["c","ç"], n:["n","ñ"], s:["s","ß","š"], y:["y","ý","ÿ"], ".":[".","…","·"], "-":["-","–","—"], "$": ["$","£","€","¥","₹"], "?": ["?","¿"], "!": ["!","¡"]})
    readonly property var selectedPalette: [
        {dark:"#17141f",light:"#f7f0ff",primary:"#cfbdff",seed:"#7355ad",ink:"#31205f",secondary:"#c6d6ae",tertiary:"#efb8c8"},
        {dark:"#101b1b",light:"#ecf8f3",primary:"#9ddbd0",seed:"#006b5d",ink:"#00382f",secondary:"#c3caff",tertiary:"#f0c39a"},
        {dark:"#211711",light:"#fff2e9",primary:"#ffc09e",seed:"#95512d",ink:"#54220a",secondary:"#d5c1f0",tertiary:"#c8dba5"},
        {dark:"#131923",light:"#eff3ff",primary:"#b3ccff",seed:"#435f91",ink:"#13305f",secondary:"#d4c4ef",tertiary:"#a6dfc2"}
    ][preferences.palette || 0] || ({dark:"#17141f",light:"#f7f0ff",primary:"#cfbdff",seed:"#7355ad",ink:"#31205f",secondary:"#c6d6ae",tertiary:"#efb8c8"})
    readonly property var generated: preferences.dynamicColors && preferences.dynamicPalette ? preferences.dynamicPalette[light ? "light" : "dark"] || {} : ({})
    function alpha(value, amount) { const color = Qt.color(value); return Qt.rgba(color.r, color.g, color.b, amount); }
    readonly property color primary: generated.primary || (light ? selectedPalette.seed : selectedPalette.primary)
    readonly property color primaryInk: generated.on_primary || (light ? "#ffffff" : selectedPalette.ink)
    readonly property color primaryContainer: generated.primary_container || (light ? selectedPalette.primary : selectedPalette.ink)
    readonly property color primaryContainerInk: generated.on_primary_container || (light ? selectedPalette.ink : selectedPalette.primary)
    readonly property color secondary: generated.secondary || selectedPalette.secondary
    readonly property color secondaryContainer: generated.secondary_container || Qt.tint(backgroundColor, alpha(secondary, light ? 0.30 : 0.22))
    readonly property color secondaryContainerInk: generated.on_secondary_container || (light ? selectedPalette.ink : selectedPalette.light)
    readonly property color tertiary: generated.tertiary || selectedPalette.tertiary
    readonly property color tertiaryContainer: generated.tertiary_container || Qt.tint(backgroundColor, alpha(tertiary, light ? 0.34 : 0.24))
    readonly property color tertiaryContainerInk: generated.on_tertiary_container || foreground
    readonly property color backgroundColor: generated.background || (light ? selectedPalette.light : selectedPalette.dark)
    readonly property color deckSurfaceColor: generated.surface_container || Qt.tint(backgroundColor, alpha(primary, 0.04))
    readonly property color previewSurfaceColor: generated.surface_container_low || Qt.tint(backgroundColor, alpha(primary, 0.03))
    readonly property color specialColor: generated.surface_container_high || Qt.tint(backgroundColor, alpha(primary, 0.12))
    readonly property color keyColor: generated.surface_container_highest || Qt.tint(backgroundColor, alpha(primary, light ? 0.09 : 0.18))
    readonly property color keyHoverColor: Qt.tint(keyColor, alpha(foreground, 0.08))
    readonly property color foreground: generated.on_surface || (light ? "#211d29" : "#f0e9f7")
    readonly property color secondaryText: generated.on_surface_variant || (light ? "#635c6d" : "#c5bccf")
    readonly property color outlineColor: alpha(generated.outline_variant || (light ? "#604e75" : "#ede1ff"), 0.14)
    readonly property bool numericPurpose: purpose >= 2 && purpose <= 4 || purpose >= 9 && purpose <= 11
    readonly property bool phonePurpose: purpose === 4
    readonly property bool terminalPurpose: purpose === 12
    readonly property bool email: purpose === 6
    readonly property bool url: purpose === 5
    function emojiRows(page) {
        const tab = emojiTabs[page];
        if (tab === "Recent") {
            const chunks = [];
            for (let index = 0; index < recentEmoji.length; index += 8) chunks.push(recentEmoji.slice(index, index + 8).concat(index + 8 >= recentEmoji.length ? ["⌫"] : []));
            return chunks.length > 0 ? chunks : [["⌫"]];
        }
        return emojiPages[tab === "Faces" ? 0 : tab === "Hands" ? 1 : 2];
    }
    readonly property var rows: mode === "emoji" ? emojiRows(emojiPage) : mode === "digits" ? [["1","2","3"],["4","5","6"],["7","8","9"],[phonePurpose ? "+" : purpose === 2 ? "0" : ".", phonePurpose ? "0" : purpose === 2 ? "⌫" : "0", phonePurpose ? "⌫" : "⌫"]] : mode === "edit" ? [
        ["Escape","Tab","Home","Up","End"], ["Ctrl","Alt","Left","Down","Right"], ["Select all","Cut","Copy","Paste","Delete"]
    ] : mode === "numbers" ? [
        ["1","2","3","4","5","6","7","8","9","0"], ["@","#","$","%","&","*","-","+","(",")"], ["Symbols","!","\"","'",":",";","/","⌫"]
    ] : mode === "symbols" ? [
        ["~","`","|","•","√","π","÷","×","{","}"], ["£","€","¥","^","°","=","_","\\","[","]"], ["Numbers","<",">","?","!","—","…","⌫"]
    ] : ["qwertyuiop".split(""),"asdfghjkl".split(""),["Shift"].concat("zxcvbnm".split("")).concat(["⌫"]) ]
    readonly property real heightBudget: layoutClass === "phone-landscape" ? availableHeight * 0.78 : layoutClass === "phone" ? availableHeight * 0.60 : Math.min(540, availableHeight * 0.58)
    readonly property real headerHeight: shortLayout ? 36 : 48
    readonly property real suggestionHeight: shortLayout ? 32 : 44
    readonly property real numberHeight: shortLayout ? 30 : 42
    readonly property real utilityHeight: 36
    readonly property int gridRows: rows.length + 1
    readonly property int stableRows: 4
    // Reserve the letter-grid rows in every mode, so a mode change cannot resize the deck.
    readonly property real modeSpacerHeight: Math.max(0, suggestionHeight + numberHeight - (suggestionVisible ? suggestionHeight : 0) - (showNumberRow ? numberHeight : 0) - (utilityRowVisible ? utilityHeight : 0) - Math.max(0, gridRows - stableRows) * keyHeight)
    readonly property real stableHeight: 20 + headerHeight + suggestionHeight + numberHeight + (controllerActive ? 22 : 0) + stableRows * keyHeight
    implicitHeight: Math.min(Math.max(layoutClass === "phone-landscape" ? 210 : 224, heightBudget), stableHeight)
    color: deckSurfaceColor
    signal cancelInput()
    function reset() {
        cancelInput(); shiftState = 0; control = false; alt = false; selecting = false; gestureHint = "";
        mode = (purpose >= 2 && purpose <= 4 || purpose >= 9 && purpose <= 11) ? "digits" : "letters";
    }
    function switchMode(next) { cancelInput(); mode = next; }
    function keyLabel(value) {
        const names = {WordLeft:"← word", WordRight:"word →", __select:selecting ? "Selecting" : "Select", Insert:"Ins", PageUp:"PgUp", PageDown:"PgDn", Shift:shiftState === 2 ? "⇪" : "⇧", Symbols:"=\\<", Numbers:"123", Return:"↵", Left:"←", Right:"→", Up:"↑", Down:"↓", Home:"Home", End:"End", Escape:"Esc", Delete:"Del", "Select all":"All"};
        return names[value] || (shiftState && value.length === 1 ? value.toUpperCase() : value);
    }
    function alternatives(value) {
        if (["👍","👎","👏","🙏","👋","💪"].indexOf(value) >= 0) return [value, value + "🏻", value + "🏼", value + "🏽", value + "🏾", value + "🏿"];
        let values = accents[value] || [];
        const digit = "qwertyuiop".indexOf(value);
        if (mode === "letters" && digit >= 0) values = [String((digit + 1) % 10)].concat(values.length ? values : [value]);
        return shiftState ? values.map(v => v.toUpperCase()) : values;
    }
    function registerKey(item) { keyRegistry = keyRegistry.concat([item]); if (controllerActive && !focusedKey) focusFirstKey(); }
    function unregisterKey(item) {
        const next = keyRegistry.slice();
        const at = next.indexOf(item);
        if (at < 0) return;
        next.splice(at, 1); keyRegistry = next;
        if (focusedKey === item) focusedKey = null;
    }
    function focusFirstKey() {
        for (const item of keyRegistry) if (item.revealable) { focusedKey = item; return; }
    }
    function controllerMove(dx, dy) {
        const from = focusedKey && focusedKey.revealable ? focusedKey : null;
        if (!from) { focusFirstKey(); return; }
        const origin = from.mapToItem(deck, from.width / 2, from.height / 2);
        let best = null, bestScore = Infinity;
        for (const candidate of keyRegistry) {
            if (candidate === from || !candidate.revealable) continue;
            const point = candidate.mapToItem(deck, candidate.width / 2, candidate.height / 2);
            const forward = (point.x - origin.x) * dx + (point.y - origin.y) * dy;
            const sideways = Math.abs((point.x - origin.x) * dy) + Math.abs((point.y - origin.y) * dx);
            if (forward < 4) continue;
            const score = forward + sideways * 3;
            if (score < bestScore) { bestScore = score; best = candidate; }
        }
        if (best) focusedKey = best;
    }
    function controllerActivate() { if (focusedKey && focusedKey.revealable) focusedKey.activate(); }
    function controllerBack() { backend.key("Backspace", generation, false, false, false); }
    function moveCursor(value) {
        backend.key(value, generation, control, alt, selecting || !!shiftState);
    }
    function dispatch(value) {
        if (value === "__select") { selecting = !selecting; return; }
        if (value.indexOf("__category") === 0) { cancelInput(); emojiPage = Number(value.slice(10)); focusedKey = null; return; }
        if (value === "WordLeft" || value === "WordRight") {
            backend.key(value === "WordLeft" ? "Left" : "Right", generation, true, false, selecting); return;
        }
        if (["Left","Right","Up","Down","Home","End","PageUp","PageDown"].indexOf(value) >= 0) { moveCursor(value); return; }
        if (value === "__hide") { cancelInput(); backend.hide(); return; }
        if (value === "__edit") { switchMode(mode === "edit" ? "letters" : "edit"); return; }
        if (value === "__hand") { cancelInput(); handed = wideLayout ? (handed + 1) % 4 : (handed + 1) % 3; return; }
        if (value === "__layout") { switchMode(mode === "letters" ? "numbers" : "letters"); return; }
        if (value === "__emoji") { switchMode(mode === "emoji" ? "letters" : "emoji"); return; }
        if (value === "Shift") {
            const now = Date.now();
            shiftState = shiftState === 1 && now - shiftTime < 350 ? 2 : shiftState ? 0 : 1;
            shiftTime = now; return;
        }
        if (value === "Ctrl") { control = !control; return; }
        if (value === "Alt") { alt = !alt; return; }
        if (value === "Symbols" || value === "Numbers") { switchMode(value.toLowerCase()); return; }
        if (value === "⌫") value = "Backspace";
        const shortcuts = {"Select all":"a", Cut:"x", Copy:"c", Paste:"v", Undo:"z", Redo:"y"};
        if (value === " ") {
            const now = Date.now();
            const sentence = autoCapitalize && !control && !alt && ".!?".indexOf(lastChar) >= 0;
            if (autoCapitalize && lastChar === " " && now - lastSpaceTime < 280) {
                backend.key("Backspace", generation, false, false, false);
                backend.text(". ", generation, false, false);
                lastChar = " "; lastSpaceTime = 0; shiftState = 1;
            } else {
                backend.text(" ", generation, control, alt);
                lastChar = " "; lastSpaceTime = now;
                if (sentence) shiftState = 1;
            }
            control = false; alt = false; selecting = false; return;
        }
        if (shortcuts[value]) backend.text(shortcuts[value], generation, true, false);
        else if (["Backspace","Delete","Insert","Return","Tab","Escape","Left","Right","Up","Down","Home","End","PageUp","PageDown"].indexOf(value) >= 0) {
            if (value === "Backspace" && !control && !alt && !shiftState) backend.backspace(generation);
            else backend.key(value, generation, control, alt, !!shiftState);
            if (value === "Backspace" || value === "Delete") lastChar = "";
        } else {
            const committed = shiftState ? value.toUpperCase() : value;
            backend.text(committed, generation, control, alt);
            if (mode === "emoji" && value.length > 1) recentEmoji = [value].concat(recentEmoji.filter(entry => entry !== value)).slice(0, 24);
            lastChar = committed;
        }
        const autoCaps = autoCapitalize && mode === "letters" && ".!?".indexOf(lastChar) >= 0;
        if (shiftState === 1) shiftState = 0;
        if (autoCaps) shiftState = 1;
        control = false; alt = false; selecting = false;
    }
    function acceptSuggestion(value) {
        if (!value || privateInput) return;
        backend.replaceCurrentWord(value + " ", generation, suggestions.currentPrefixBytes);
        suggestions.noteAccepted(value);
        shiftState = 0; control = false; alt = false; selecting = false; lastChar = " "; lastSpaceTime = Date.now();
    }
    onGenerationChanged: reset()
    onPurposeChanged: reset()
    onVisibleChanged: if (!visible) cancelInput()
    onWidthChanged: cancelInput()
    onHeightChanged: cancelInput()
    Component.onCompleted: if (numericPurpose) mode = "digits"
    onControllerActiveChanged: { if (controllerActive) { cancelInput(); focusFirstKey(); } else focusedKey = null; }
    Connections {
        target: typeof gamepad !== "undefined" ? gamepad : null
        function onAction(name) {
            if (!deck.controllerActive) return;
            cancelInput();
            if (name === "left") deck.controllerMove(-1, 0);
            else if (name === "right") deck.controllerMove(1, 0);
            else if (name === "up") deck.controllerMove(0, -1);
            else if (name === "down") deck.controllerMove(0, 1);
            else if (name === "accept") deck.controllerActivate();
            else if (name === "back") deck.controllerBack();
            else if (name === "space") deck.dispatch(" ");
            else if (name === "shift") deck.dispatch("Shift");
            else if (name === "mode") deck.dispatch("__layout");
            else if (name === "emoji") deck.dispatch("__emoji");
            else if (name === "hide") deck.dispatch("__hide");
            deck.focusFirstKey();
        }
    }
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: deck.outlineColor }
    ColumnLayout {
        id: body
        width: deck.contentWidth
        x: deck.handed === 1 ? 6 : deck.handed === 2 ? deck.width - width - 6 : (deck.width - width) / 2
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 8; anchors.bottomMargin: 12
        spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: deck.headerHeight; spacing: 4
            Text { Layout.leftMargin: 8; text: "keyboard"; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: deck.primary }
            Text { text: "Borealis"; color: deck.secondaryText; font.family: deck.fontFamily; font.weight: Font.DemiBold; font.pixelSize: 12 }
            Text { visible: deck.controllerActive; Layout.leftMargin: 10; Layout.alignment: Qt.AlignVCenter; text: "sports_esports"; font.family: "Material Symbols Rounded"; font.pixelSize: 17; color: deck.primary }
            Text { visible: body.width > 700; Layout.leftMargin: 12; Layout.fillWidth: true; elide: Text.ElideRight; text: deck.controllerActive ? "Controller: move · A type · B erase · X space · Y shift" : deck.gestureHint || (deck.privateInput ? "Private input" : deck.selecting ? "Move arrows or slide space to select" : "Hold for accents · slide space to move"); color: deck.secondaryText; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            Key { keyboard: deck; toolbar: true; icon: true; Layout.preferredWidth: 48; Layout.fillHeight: true; label: deck.mode === "edit" ? "keyboard" : "edit"; description: "Editing tools"; value: "__edit"; special: true }
            Key { keyboard: deck; toolbar: true; icon: true; Layout.preferredWidth: 48; Layout.fillHeight: true; label: deck.splitLayout ? "vertical_split" : deck.handed === 1 ? "align_horizontal_left" : deck.handed === 2 ? "align_horizontal_right" : "view_week"; description: "Cycle full, one-hand, and split layouts"; value: "__hand"; special: true }
            Key { keyboard: deck; toolbar: true; icon: true; Layout.preferredWidth: 48; Layout.fillHeight: true; label: "keyboard_hide"; description: "Hide keyboard"; value: "__hide"; special: true }
        }
        Item { Layout.fillWidth: true; Layout.preferredHeight: deck.modeSpacerHeight; visible: deck.modeSpacerHeight > 0 }
        SuggestionStrip { keyboard: deck; engine: deck.suggestions; Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.suggestionHeight : 0 }
        RowLayout {
            visible: deck.controllerActive && body.width <= 700
            Layout.fillWidth: true; Layout.preferredHeight: 22; spacing: 6
            Text { text: "sports_esports"; font.family: "Material Symbols Rounded"; font.pixelSize: 15; color: deck.primary; Layout.alignment: Qt.AlignVCenter }
            Text { text: "Stick or d-pad moves · A type · B erase · X space · Y shift"; color: deck.secondaryText; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
        }
        RowLayout {
            visible: deck.utilityRowVisible
            Layout.fillWidth: true; Layout.preferredHeight: deck.utilityHeight; spacing: 0
            Repeater {
                model: deck.mode === "emoji" ? deck.emojiTabs.map((entry, index) => "__category" + index) : deck.mode === "edit" ? ["Undo","Redo","__select","WordLeft","WordRight"] : ["Ctrl","Alt","Tab","Escape","Left","Right"]
                Key {
                    required property string modelData
                    keyboard: deck; Layout.fillWidth: true; Layout.fillHeight: true
                    label: modelData.indexOf("__category") === 0 ? deck.emojiTabs[Number(modelData.slice(10))] : deck.keyLabel(modelData); value: modelData; special: true
                    toggled: modelData === "__select" && deck.selecting || modelData === "__category" + deck.emojiPage || modelData === "Ctrl" && deck.control || modelData === "Alt" && deck.alt
                    repeating: modelData === "Left" || modelData === "Right"
                }
            }
        }
        RowLayout {
            visible: deck.showNumberRow
            Layout.fillWidth: true; Layout.preferredHeight: deck.numberHeight; spacing: 0
            Repeater {
                model: "1234567890".split("")
                Key { required property string modelData; required property int index; keyboard: deck; dense: true; label: modelData; Layout.fillWidth: true; Layout.fillHeight: true; Layout.leftMargin: deck.splitLayout && index === 5 ? 28 : 0 }
            }
        }
        Repeater {
            model: deck.rows
            RowLayout {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.leftMargin: deck.mode === "letters" && index === 1 ? body.width * 0.05 : 0
                Layout.rightMargin: Layout.leftMargin
                spacing: 0
                z: 4 - index
                Repeater {
                    model: row.modelData
                    Key {
                        required property string modelData
                        required property int index
                        keyboard: deck
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.preferredWidth: modelData === "Shift" || modelData === "⌫" || modelData === "Symbols" || modelData === "Numbers" ? 1.5 : 1
                        Layout.leftMargin: deck.splitLayout && index === Math.ceil(row.modelData.length / 2) ? 28 : 0
                        label: modelData === "Shift" ? (deck.shiftState === 2 ? "keyboard_capslock" : "shift") : modelData === "⌫" ? "backspace" : deck.keyLabel(modelData); value: modelData
                        icon: modelData === "Shift" || modelData === "⌫"
                        description: modelData === "⌫" ? "Backspace" : modelData === "Shift" ? "Shift; double tap for caps lock" : label
                        alternatives: deck.alternatives(modelData)
                        hint: ""
                        special: modelData.length > 2 || modelData === "⌫"
                        toggled: modelData === "Shift" && deck.shiftState > 0 || modelData === "Ctrl" && deck.control || modelData === "Alt" && deck.alt
                        repeating: modelData === "⌫" || modelData === "Delete"
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 1.35; Layout.fillHeight: true; label: deck.mode === "letters" ? "?123" : "ABC"; value: "__layout"; special: true; description: "Switch letters and symbols" }
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true; label: "mood"; icon: true; value: "__emoji"; special: true; description: "Emoji"; toggled: deck.mode === "emoji" }
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 0.8; Layout.fillHeight: true; label: deck.terminalPurpose ? "|" : deck.email ? "@" : deck.url ? "/" : "," }
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 4.4; Layout.fillHeight: true; label: deck.gestureHint || (deck.selecting ? "Slide to select" : deck.control ? "Ctrl + space" : deck.alt ? "Alt + space" : "English"); value: " "; spacebar: true; description: "Space; slide to move cursor" }
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 0.8; Layout.fillHeight: true; label: deck.terminalPurpose ? "~" : "."; alternatives: deck.terminalPurpose ? [] : deck.alternatives(".") }
            Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 1.5; Layout.fillHeight: true; label: "keyboard_return"; icon: true; value: "Return"; accent: true; special: true; description: "Enter" }
        }
    }
    Item { id: previews; anchors.fill: parent; z: 1000 }
}
