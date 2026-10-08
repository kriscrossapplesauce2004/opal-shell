pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "EmojiData.js" as EmojiData

Rectangle {
    id: deck
    required property var backend
    required property var suggestions
    property var preferences: ({})
    // Opal clipboard history bridge and physical keyboard detector, both optional.
    property var clips: null
    property var physicalKeyboard: null
    property bool light: !!preferences.light
    property bool reduceMotion: !!preferences.reduceMotion
    property bool privateInput: backend.sensitive
    property string mode: "letters"
    // A panel replaces the keys: menu, edit, emoji, clipboard, trackpad, resize, languages or settings.
    property string panel: ""
    property int shiftState: 0
    property bool control: false
    property bool alt: false
    property int handed: 0
    property bool selecting: false
    property bool trackpadSelect: false
    property bool trackpadHold: false
    property int emojiPage: 1
    property string emojiQuery: ""
    property bool emojiSearching: false
    property string gestureHint: ""
    property var recentEmoji: []
    property bool autoCapitalize: true
    property bool handheld: false
    property bool terminalToggle: false
    property string keyStyleSession: ""
    property real heightScale: 1
    property bool floating: false
    property real floatX: 0
    property real floatY: 0
    property real floatWidth: 520
    property real hostWidth: width
    // Preview switch that forces the docked bar without a physical keyboard.
    property bool dockedPreview: false
    property bool fullRequested: false
    property string dockedSession: ""
    property string lastChar: ""
    property real lastSpaceTime: 0
    property var focusedKey: null
    property var keyRegistry: []
    property int suggestionFocus: -1
    property bool cursorHold: false
    property rect toolsOrigin: Qt.rect(0, 0, 48, 48)
    readonly property real menuProgress: progressValue
    property real progressValue: panel === "menu" ? 1 : 0
    Behavior on progressValue { NumberAnimation { duration: deck.reduceMotion ? 0 : 340; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    readonly property string keyStyle: keyStyleSession !== "" ? keyStyleSession : (preferences.keyboardKeyStyle === "borderless" ? "borderless" : "tonal")
    readonly property string dockedPreference: dockedSession !== "" ? dockedSession : (preferences.keyboardDocked || "auto")
    readonly property bool dockedWanted: !floating && !handheld && (dockedPreview || dockedPreference === "always" || (dockedPreference !== "never" && !!physicalKeyboard && physicalKeyboard.present))
    readonly property bool dockedBar: dockedWanted && !fullRequested
    readonly property bool canFloat: hostWidth >= 720
    readonly property bool terminalMode: terminalPurpose || terminalToggle
    readonly property var clipItems: privateInput || !clips ? [] : clips.items
    readonly property int clipCount: clipItems.length
    readonly property bool clipAvailable: !!clips && clips.available
    readonly property var emojiResults: EmojiData.search(emojiQuery)
    readonly property var emojiTabs: EmojiData.categories
    readonly property bool controllerActive: handheld || typeof gamepad !== "undefined" && gamepad !== null && gamepad.connected
    readonly property string layoutClass: width < 600 ? (width > availableHeight ? "phone-landscape" : "phone") : width < 1000 ? "tablet" : "desktop"
    readonly property bool wideLayout: width >= 720
    readonly property bool splitLayout: handed === 3 && wideLayout && !floating
    readonly property bool suggestionVisible: !privateInput && (mode === "letters" || mode === "symbols") && !terminalMode
    readonly property var candidates: {
        const list = suggestions.suggestions;
        return list.length >= 3 ? [list[1], list[0], list[2]] : list;
    }
    readonly property var suggestionChips: privateInput ? [] : terminalMode ? [{label: "Paste", action: "__paste"}, {label: "Ctrl C", action: "__ctrlc"}, {label: "Tab", action: "Tab"}]
        : suggestionVisible ? candidates.map(word => ({label: word, action: word})) : []
    property int generation: backend.generation
    property real shiftTime: 0
    property real availableHeight: 800
    property bool compact: availableHeight < 600
    readonly property bool shortLayout: availableHeight < 500
    readonly property bool showNumberRow: mode === "letters" || mode === "symbols"
    readonly property real floatScale: Math.max(0.8, Math.min(1.35, floatWidth / 520))
    readonly property real contentWidth: floating ? width - 16 : splitLayout ? width - 16 : handed === 1 || handed === 2 ? Math.min(420, width * 0.82) : layoutClass === "desktop" ? Math.min(width - 32, 1120) : layoutClass === "tablet" ? Math.min(width - 24, 940) : Math.min(width - (width < 400 ? 8 : 16), 860)
    readonly property real baseKeyHeight: shortLayout ? 38 : compact ? 48 : floating ? 46 * floatScale : 56
    readonly property real keyHeight: baseKeyHeight * heightScale * (controllerActive ? 1.25 : 1)
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
    function emojiRows(page) { return page === 0 ? recentEmoji : EmojiData.glyphs(page); }
    readonly property var rows: mode === "digits" ? [["1","2","3"],["4","5","6"],["7","8","9"],[phonePurpose ? "+" : purpose === 2 ? "0" : ".", phonePurpose ? "0" : purpose === 2 ? "⌫" : "0", "⌫"]]
        : mode === "numbers" ? [
        ["1","2","3","4","5","6","7","8","9","0"], ["@","#","$","%","&","*","-","+","(",")"], ["Symbols","!","\"","'",":",";","/","⌫"]
    ] : mode === "symbols" ? [
        ["~","`","|","•","√","π","÷","×","{","}"], ["£","€","¥","^","°","=","_","\\","[","]"], ["Numbers","<",">","?","!","—","…","⌫"]
    ] : ["qwertyuiop".split(""),"asdfghjkl".split(""),["Shift"].concat("zxcvbnm".split("")).concat(["⌫"]) ]
    readonly property real heightBudget: layoutClass === "phone-landscape" ? availableHeight * 0.78 : layoutClass === "phone" ? availableHeight * 0.60 : Math.min(540, availableHeight * 0.58)
    readonly property real suggestionHeight: shortLayout ? 32 : 44
    readonly property real numberHeight: shortLayout ? 30 : 42
    readonly property real hintHeight: controllerActive ? 38 : 0
    readonly property real topInset: floating ? 22 : 8
    readonly property int gridRows: rows.length + 1
    readonly property int stableRows: 4
    // Reserve the letter-grid rows in every mode, so a mode change cannot resize the deck.
    readonly property real modeSpacerHeight: Math.max(0, numberHeight - (showNumberRow ? numberHeight : 0) - Math.max(0, gridRows - stableRows) * keyHeight)
    readonly property real stableHeight: topInset + 12 + suggestionHeight + numberHeight + hintHeight + stableRows * keyHeight
    // Panels need room for three tool rows, so they may grow the deck a little on tall screens.
    readonly property real panelFloor: shortLayout ? 0 : 296
    readonly property real dockedHeight: 68
    implicitHeight: dockedBar ? dockedHeight : Math.min(Math.max(layoutClass === "phone-landscape" ? 210 : 224, heightBudget, panelFloor), Math.max(stableHeight, panelFloor))
    color: dockedBar ? "transparent" : deckSurfaceColor
    radius: floating && !dockedBar ? 28 : 0
    border.width: floating && !dockedBar ? 1 : 0
    border.color: outlineColor
    signal cancelInput()
    function reset() {
        cancelInput(); shiftState = 0; control = false; alt = false; selecting = false; gestureHint = ""; panel = ""; emojiSearching = false; emojiQuery = ""; trackpadHold = false; fullRequested = false; cursorHold = false;
        mode = (purpose >= 2 && purpose <= 4 || purpose >= 9 && purpose <= 11) ? "digits" : "letters";
    }
    function switchMode(next) { cancelInput(); panel = ""; mode = next; }
    function openPanel(name) {
        cancelInput(); focusedKey = null; emojiSearching = false; emojiQuery = "";
        if (name === "menu" && menuButton) toolsOrigin = menuButton.mapToItem(deck, 0, 0, menuButton.width, menuButton.height);
        if ((name === "clipboard" || name === "menu") && clips) clips.refresh();
        panel = name;
        if (controllerActive) Qt.callLater(focusFirstKey);
    }
    property var menuButton: null
    function startFloating() {
        if (!canFloat) return;
        panel = ""; floatWidth = Math.min(520, hostWidth - 32);
        floatX = (hostWidth - floatWidth) / 2; floatY = Math.max(8, availableHeight - implicitHeight - 40);
        floating = true; fullRequested = true;
    }
    function moveFloat(x, y) {
        floatX = Math.max(0, Math.min(hostWidth - width, x));
        floatY = Math.max(0, Math.min(availableHeight - height, y));
    }
    function resizeFloat(w) {
        floatWidth = Math.max(340, Math.min(Math.min(hostWidth - 16, 760), w));
        floatX = Math.min(floatX, hostWidth - floatWidth);
    }
    function startEmojiSearch() { cancelInput(); panel = ""; mode = "letters"; emojiQuery = ""; emojiSearching = true; }
    function keyLabel(value) {
        const names = {WordLeft:"← word", WordRight:"word →", __select:selecting ? "Selecting" : "Select", Insert:"Ins", PageUp:"PgUp", PageDown:"PgDn", Shift:shiftState === 2 ? "⇪" : "⇧", Symbols:"=\\<", Numbers:"123", Return:"↵", Left:"←", Right:"→", Up:"↑", Down:"↓", Home:"Home", End:"End", Escape:"Esc", Delete:"Del", "Select all":"All"};
        return names[value] || (shiftState && value.length === 1 ? value.toUpperCase() : value);
    }
    function alternatives(value) {
        if (["👍","👎","👏","🙏","👋","💪"].indexOf(value) >= 0) return [value, value + "🏻", value + "🏼", value + "🏽", value + "🏾", value + "🏿"];
        if (terminalMode) {
            const shell = {"|":["|","\\","¦"], "~":["~","`","^"], "/":["/","\\"], "-":["-","_","="], "_":["_","$","*"]};
            if (shell[value]) return shell[value];
        }
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
        if (focusedKey && focusedKey.revealable) return;
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
    function controllerBack() { if (emojiSearching) dispatch("Backspace"); else backend.key("Backspace", generation, false, false, false); }
    // LB picks the first suggestion and RB the last one.
    function controllerPick(side) {
        const chips = suggestionChips;
        if (chips.length === 0) return;
        suggestionFocus = side < 0 ? 0 : chips.length - 1;
        pickFlash.restart();
        chipAction(chips[suggestionFocus].action);
    }
    function chipAction(action) {
        if (action === "__paste") backend.text(terminalMode ? "V" : "v", generation, true, false);
        else if (action === "__ctrlc") backend.text("c", generation, true, false);
        else if (action === "Tab") backend.key("Tab", generation, false, false, false);
        else acceptSuggestion(action);
    }
    function pasteClip(entry) {
        // Clipboard text is committed as text, never typed as key events. Images and cut-off text are skipped.
        if (privateInput || !entry || entry.kind === "image" || entry.tooLong || !entry.text) return;
        backend.text(entry.text, generation, false, false);
        lastChar = entry.text.slice(-1);
    }
    function beginTrackpad() { trackpadHold = true; }
    function endTrackpad() { trackpadHold = false; trackpadSelect = false; }
    function moveCursor(value) {
        backend.key(value, generation, control, alt, selecting || !!shiftState || trackpadSelect);
    }
    function editSearch(value) {
        if (value === "Backspace") emojiQuery = emojiQuery.slice(0, -1);
        else if (value === " ") emojiQuery += " ";
        else emojiQuery += value.toLowerCase();
    }
    function dispatch(value) {
        if (value === "__select") { selecting = !selecting; return; }
        if (value.indexOf("__category") === 0) { cancelInput(); emojiPage = Number(value.slice(10)); focusedKey = null; return; }
        if (value === "__tools") { openPanel(panel === "menu" ? "" : "menu"); return; }
        if (value === "__keys") { openPanel(""); return; }
        if (value === "__settings") { openPanel("settings"); return; }
        if (value.indexOf("__tool-") === 0) { tool(value.slice(7)); return; }
        if (value.indexOf("__set-") === 0) { setting(value.slice(6)); return; }
        if (value === "__dock-show") { fullRequested = true; return; }
        if (value === "__dock-emoji") { fullRequested = true; openPanel("emoji"); return; }
        if (value === "__dock-clipboard") { fullRequested = true; openPanel("clipboard"); return; }
        if (value === "__searchdone" || (emojiSearching && value === "Return")) { emojiSearching = false; emojiQuery = ""; panel = "emoji"; return; }
        if (value === "__paste" || value === "__ctrlc") { chipAction(value); return; }
        if (value === "WordLeft" || value === "WordRight") {
            backend.key(value === "WordLeft" ? "Left" : "Right", generation, true, false, selecting); return;
        }
        if (["Left","Right","Up","Down","Home","End","PageUp","PageDown"].indexOf(value) >= 0) { moveCursor(value); return; }
        if (value === "__hide") { cancelInput(); fullRequested = false; backend.hide(); return; }
        if (value === "__edit") { openPanel(panel === "edit" ? "" : "edit"); return; }
        if (value === "__hand") { cancelInput(); handed = wideLayout ? (handed + 1) % 4 : (handed + 1) % 3; return; }
        if (value === "__layout") { switchMode(mode === "letters" ? "numbers" : "letters"); return; }
        if (value === "__emoji") { openPanel(panel === "emoji" ? "" : "emoji"); return; }
        if (value === "Shift") {
            const now = Date.now();
            shiftState = shiftState === 1 && now - shiftTime < 350 ? 2 : shiftState ? 0 : 1;
            shiftTime = now; return;
        }
        if (value === "Ctrl") { control = !control; return; }
        if (value === "Alt") { alt = !alt; return; }
        if (value === "Symbols" || value === "Numbers") { switchMode(value.toLowerCase()); return; }
        if (value === "⌫") value = "Backspace";
        if (emojiSearching && (value.length === 1 && value.charCodeAt(0) < 128 || value === "Backspace")) { editSearch(value); return; }
        const shortcuts = {"Select all":"a", Cut:"x", Copy:"c", Paste:"v", Undo:"z", Redo:"y"};
        if (value === " ") {
            const now = Date.now();
            const sentence = autoCapitalize && !terminalMode && !control && !alt && ".!?".indexOf(lastChar) >= 0;
            if (autoCapitalize && !terminalMode && lastChar === " " && now - lastSpaceTime < 280) {
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
            if ((panel === "emoji" || emojiSearching) && value.length > 1) recentEmoji = [value].concat(recentEmoji.filter(entry => entry !== value)).slice(0, 24);
            lastChar = committed;
        }
        const autoCaps = autoCapitalize && !terminalMode && mode === "letters" && ".!?".indexOf(lastChar) >= 0;
        if (shiftState === 1) shiftState = 0;
        if (autoCaps) shiftState = 1;
        control = false; alt = false; selecting = false;
    }
    // Tools menu entries.
    function tool(name) {
        if (name === "clipboard") { if (!privateInput) openPanel("clipboard"); }
        else if (name === "emoji") openPanel("emoji");
        else if (name === "edit") openPanel("edit");
        else if (name === "trackpad") openPanel("trackpad");
        else if (name === "terminal") { terminalToggle = !terminalToggle; openPanel(""); }
        else if (name === "hand") { openPanel(""); handed = wideLayout ? (handed + 1) % 4 : (handed + 1) % 3; }
        else if (name === "float") { openPanel(""); startFloating(); }
        else if (name === "resize") openPanel("resize");
        else if (name === "languages") openPanel("languages");
        else if (name === "symbols") { switchMode("symbols"); }
        else if (name === "theme") keyStyleSession = keyStyle === "tonal" ? "borderless" : "tonal";
        else if (name === "settings") openPanel("settings");
    }
    function setting(name) {
        if (name === "tonal" || name === "borderless") keyStyleSession = name;
        else if (name === "autocaps") autoCapitalize = !autoCapitalize;
        else if (name === "docked") dockedSession = dockedPreference === "never" ? "auto" : "never";
        else if (name === "motion") { /* follows the shell preference */ }
    }
    function acceptSuggestion(value) {
        if (!value || privateInput) return;
        backend.replaceCurrentWord(value + " ", generation, suggestions.currentPrefixBytes);
        suggestions.noteAccepted(value);
        shiftState = 0; control = false; alt = false; selecting = false; lastChar = " "; lastSpaceTime = Date.now();
    }
    Timer { id: pickFlash; interval: 450; onTriggered: deck.suggestionFocus = -1 }
    onGenerationChanged: reset()
    onPurposeChanged: reset()
    onPrivateInputChanged: if (privateInput && panel === "clipboard") panel = ""
    onVisibleChanged: { if (!visible) cancelInput(); else if (clips && panel === "clipboard") clips.refresh(); }
    onWidthChanged: cancelInput()
    onHeightChanged: cancelInput()
    onPanelChanged: { focusedKey = null; if (controllerActive) Qt.callLater(focusFirstKey); }
    property string initialPanel: ""
    property bool floatAtStart: false
    property bool terminalAtStart: false
    Component.onCompleted: {
        if (numericPurpose) mode = "digits";
        if (terminalAtStart) terminalToggle = true;
        // Geometry settles first, so the tools button has its final place when the menu opens.
        if (initialPanel !== "" || floatAtStart) startup.start();
    }
    // The preview focus event resets the deck once, so the requested start state is applied after it.
    Timer { id: startup; interval: 200; onTriggered: { if (deck.initialPanel !== "") deck.openPanel(deck.initialPanel); if (deck.floatAtStart) deck.startFloating(); } }
    onControllerActiveChanged: { if (controllerActive) { cancelInput(); focusFirstKey(); } else focusedKey = null; }
    Connections {
        target: typeof gamepad !== "undefined" ? gamepad : null
        function onAction(name) {
            if (!deck.controllerActive) return;
            deck.cancelInput();
            if (name === "cursor-on") { deck.cursorHold = true; return; }
            if (name === "cursor-off") { deck.cursorHold = false; return; }
            const dir = {left: ["Left", -1, 0], right: ["Right", 1, 0], up: ["Up", 0, -1], down: ["Down", 0, 1]}[name];
            if (dir) { if (deck.cursorHold) deck.moveCursor(dir[0]); else deck.controllerMove(dir[1], dir[2]); }
            else if (name === "accept") deck.controllerActivate();
            else if (name === "back") deck.controllerBack();
            else if (name === "space") deck.dispatch(" ");
            else if (name === "shift") deck.dispatch("Shift");
            else if (name === "symbols" || name === "mode") deck.dispatch("__layout");
            else if (name === "prev-suggestion") deck.controllerPick(-1);
            else if (name === "next-suggestion") deck.controllerPick(1);
            else if (name === "emoji") deck.dispatch("__emoji");
            else if (name === "hide") deck.dispatch("__hide");
            deck.focusFirstKey();
        }
    }
    Rectangle { visible: !deck.floating && !deck.dockedBar; anchors.top: parent.top; width: parent.width; height: 1; color: deck.outlineColor }
    // Floating card: drag handle moves the card, double tap docks it.
    Item {
        id: grip
        objectName: "floatGrip"
        visible: deck.floating && !deck.dockedBar
        width: 140; height: 26; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; z: 6
        Accessible.role: Accessible.Button
        Accessible.name: "Move keyboard; double tap to dock"
        Rectangle { anchors.centerIn: parent; width: 36; height: 4; radius: 2; color: deck.secondaryText; opacity: 0.7 }
        DragHandler {
            id: gripDrag
            target: null
            property real startX: 0
            property real startY: 0
            onActiveChanged: if (active) { startX = deck.floatX; startY = deck.floatY; deck.cancelInput(); }
            onActiveTranslationChanged: if (active) deck.moveFloat(startX + activeTranslation.x, startY + activeTranslation.y)
        }
        TapHandler { onDoubleTapped: deck.floating = false }
    }
    Item {
        id: corner
        objectName: "floatCorner"
        visible: deck.floating && !deck.dockedBar
        width: 40; height: 40; anchors.right: parent.right; anchors.bottom: parent.bottom; z: 6
        Accessible.role: Accessible.Slider
        Accessible.name: "Resize keyboard"
        Grid {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8; columns: 3; spacing: 2
            Repeater { model: 9; Rectangle { required property int index; width: 3; height: 3; radius: 1.5; visible: index % 3 + Math.floor(index / 3) >= 2; color: deck.secondaryText; opacity: 0.7 } }
        }
        DragHandler {
            target: null
            property real startWidth: 0
            onActiveChanged: if (active) { startWidth = deck.floatWidth; deck.cancelInput(); }
            onActiveTranslationChanged: if (active) deck.resizeFloat(startWidth + activeTranslation.x)
        }
    }
    Item {
        id: frame
        objectName: "frame"
        width: deck.contentWidth
        x: deck.floating ? 8 : deck.handed === 1 ? 6 : deck.handed === 2 ? deck.width - width - 6 : (deck.width - width) / 2
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: deck.topInset; anchors.bottomMargin: 12
        readonly property real splitGap: width * 0.26
        ColumnLayout {
            id: body
            anchors.fill: parent
            spacing: 0
            visible: !deck.dockedBar && (deck.panel === "" || deck.panel === "menu" && deck.progressValue < 0.99)
            opacity: deck.trackpadHold ? 0.12 : 1
            Behavior on opacity { NumberAnimation { duration: deck.reduceMotion ? 0 : 160 } }
            SuggestionStrip {
                id: strip
                keyboard: deck
                visible: !deck.emojiSearching
                Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.suggestionHeight : 0
                Component.onCompleted: deck.menuButton = strip.toolsButton
            }
            EmojiSearchBar { keyboard: deck; visible: deck.emojiSearching; Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.suggestionHeight : 0 }
            Item { Layout.fillWidth: true; Layout.preferredHeight: deck.modeSpacerHeight; visible: deck.modeSpacerHeight > 0 }
            RowLayout {
                visible: deck.showNumberRow && !deck.terminalMode && !deck.emojiSearching
                Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.numberHeight : 0; spacing: 0
                Repeater {
                    model: "1234567890".split("")
                    Key { required property string modelData; keyboard: deck; dense: true; label: modelData; Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
            EmojiResults { keyboard: deck; visible: deck.emojiSearching; Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.numberHeight : 0 }
            RowLayout {
                visible: deck.showNumberRow && deck.terminalMode && !deck.emojiSearching
                objectName: "terminalRow"
                Layout.fillWidth: true; Layout.preferredHeight: visible ? deck.numberHeight : 0; spacing: 0
                Repeater {
                    model: [{v: "Escape"}, {v: "Tab"}, {v: "Ctrl"}, {v: "Alt"}, {v: "Left", i: "chevron_left"}, {v: "Down", i: "expand_more"}, {v: "Up", i: "expand_less"}, {v: "Right", i: "chevron_right"}]
                    Key {
                        required property var modelData
                        keyboard: deck; special: true; dense: true
                        icon: !!modelData.i; label: modelData.i || deck.keyLabel(modelData.v); value: modelData.v; description: modelData.v
                        latch: modelData.v === "Ctrl"
                        toggled: modelData.v === "Ctrl" && deck.control || modelData.v === "Alt" && deck.alt
                        repeating: !!modelData.i
                        Layout.fillWidth: true; Layout.fillHeight: true
                    }
                }
            }
            Repeater {
                model: deck.rows
                RowLayout {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.leftMargin: deck.mode === "letters" && index === 1 && !deck.splitLayout ? body.width * 0.05 : 0
                    Layout.rightMargin: Layout.leftMargin
                    spacing: 0
                    z: 4 - index
                    // Exact pixel widths keep the keys even when the split gap takes room.
                    function weight(name) { return name === "Shift" || name === "⌫" || name === "Symbols" || name === "Numbers" ? 1.5 : 1; }
                    readonly property real weightSum: modelData.reduce((sum, name) => sum + weight(name), 0)
                    readonly property real unit: Math.max(1, (width - (deck.splitLayout && deck.mode === "letters" ? frame.splitGap : 0)) / weightSum)
                    Repeater {
                        model: row.modelData
                        Key {
                            required property string modelData
                            required property int index
                            keyboard: deck
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.preferredWidth: row.weight(modelData) * row.unit
                            Layout.leftMargin: deck.splitLayout && deck.mode === "letters" && index === Math.ceil(row.modelData.length / 2) ? frame.splitGap : 0
                            label: modelData === "Shift" ? (deck.shiftState === 2 ? "keyboard_capslock" : "shift") : modelData === "⌫" ? "backspace" : deck.keyLabel(modelData); value: modelData
                            icon: modelData === "Shift" || modelData === "⌫"
                            description: modelData === "⌫" ? "Backspace" : modelData === "Shift" ? "Shift; double tap for caps lock" : label
                            alternatives: deck.alternatives(modelData)
                            hint: deck.terminalMode && row.index === 0 && deck.mode === "letters" ? String((index + 1) % 10) : ""
                            special: modelData.length > 2 || modelData === "⌫" || modelData === "Shift"
                            toggled: modelData === "Shift" && deck.shiftState > 0
                            repeating: modelData === "⌫"
                        }
                    }
                }
            }
            RowLayout {
                id: bottom
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                readonly property real spaceWeight: deck.splitLayout ? 2.6 : deck.terminalMode ? 3.4 : 4.4
                readonly property real weightSum: 1.35 + (deck.terminalMode ? 0 : 1) + (deck.terminalMode ? 3 : 1) * 0.8 + spaceWeight + (deck.terminalMode ? 2 : 1) * 0.8 + 1.5
                readonly property real unit: Math.max(1, (width - (deck.splitLayout ? frame.splitGap : 0)) / weightSum)
                Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 1.35 * bottom.unit; Layout.fillHeight: true; label: deck.terminalMode ? "!#1" : deck.mode === "letters" ? "?123" : "ABC"; value: "__layout"; special: true; description: "Switch letters and symbols" }
                Key { visible: !deck.terminalMode; keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: visible ? bottom.unit : 0; Layout.fillHeight: true; label: "mood"; icon: true; value: "__emoji"; special: true; description: "Emoji"; toggled: deck.panel === "emoji" }
                Repeater {
                    model: deck.terminalMode ? ["|", "~", "/"] : [deck.email ? "@" : deck.url ? "/" : ","]
                    Key { required property string modelData; keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 0.8 * bottom.unit; Layout.fillHeight: true; label: modelData; alternatives: deck.alternatives(modelData) }
                }
                Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: bottom.spaceWeight * bottom.unit; Layout.fillHeight: true; label: deck.gestureHint || (deck.selecting ? "Slide to select" : deck.control ? "Ctrl + space" : deck.alt ? "Alt + space" : deck.terminalMode ? "space" : "English"); value: " "; spacebar: true; description: "Space; slide to move cursor" }
                Repeater {
                    model: deck.terminalMode ? ["-", "_"] : ["."]
                    Key { required property string modelData; required property int index; keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 0.8 * bottom.unit; Layout.fillHeight: true; Layout.leftMargin: deck.splitLayout && index === 0 ? frame.splitGap : 0; label: modelData; alternatives: deck.alternatives(modelData) }
                }
                Key { keyboard: deck; Layout.fillWidth: true; Layout.preferredWidth: 1.5 * bottom.unit; Layout.fillHeight: true; label: "keyboard_return"; icon: true; value: "Return"; accent: true; special: true; description: "Enter" }
            }
            HintBar { visible: deck.controllerActive; keyboard: deck; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; Layout.preferredHeight: visible ? 32 : 0; Layout.preferredWidth: implicitWidth }
        }
        TrackpadSurface { visible: deck.trackpadHold; anchors.fill: parent; keyboard: deck; selecting: deck.selecting || deck.shiftState > 0; enabled: false; z: 3 }
        Loader { anchors.fill: parent; active: deck.panel === "edit" && !deck.dockedBar; sourceComponent: EditPanel { keyboard: deck } }
        Loader { anchors.fill: parent; active: deck.panel === "emoji" && !deck.dockedBar; sourceComponent: EmojiPanel { keyboard: deck } }
        Loader { anchors.fill: parent; active: deck.panel === "clipboard" && !deck.dockedBar; sourceComponent: ClipboardPanel { keyboard: deck } }
        Loader { anchors.fill: parent; active: deck.panel === "trackpad" && !deck.dockedBar; sourceComponent: TrackpadPanel { keyboard: deck } }
        Loader { anchors.fill: parent; active: deck.panel === "resize" && !deck.dockedBar; sourceComponent: ResizePanel { keyboard: deck } }
        Loader {
            anchors.fill: parent; active: deck.panel === "languages" && !deck.dockedBar
            sourceComponent: ChoicePanel { keyboard: deck; title: "Languages"; rows: [{label: "English (US)", value: "__keys", on: true}, {label: "Keyboard settings", value: "__settings", on: false}] }
        }
        Loader {
            anchors.fill: parent; active: deck.panel === "settings" && !deck.dockedBar
            sourceComponent: ChoicePanel {
                keyboard: deck; title: "Keyboard settings"
                rows: [
                    {label: "Tonal keys", value: "__set-tonal", on: deck.keyStyle === "tonal"},
                    {label: "Borderless keys", value: "__set-borderless", on: deck.keyStyle === "borderless"},
                    {label: "Auto-capitalise", value: "__set-autocaps", on: deck.autoCapitalize},
                    {label: "Slim bar with a physical keyboard", value: "__set-docked", on: deck.dockedPreference !== "never"}
                ]
            }
        }
    }
    ToolsSheet {
        id: sheet
        keyboard: deck
        progress: deck.progressValue
        origin: deck.toolsOrigin
        target: Qt.rect(frame.x, frame.y, frame.width, frame.height)
        z: 10
    }
    DockedBar {
        visible: deck.dockedBar
        keyboard: deck; engine: deck.suggestions
        width: Math.min(640, deck.width - 24); height: 52
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
    }
    Item { id: previews; anchors.fill: parent; z: 1000 }
}
