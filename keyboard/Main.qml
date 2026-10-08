import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: window
    title: previewMode ? "Borealis Keyboard · typing playground" : "Borealis Keyboard"
    visible: false
    width: previewMode ? previewWidth : (screen ? screen.width : 980)
    height: previewMode ? previewHeight : keyboard.floating ? (screen ? screen.height : 800) : keyboard.height
    color: previewMode ? keyboard.backgroundColor : "transparent"
    // The visible card in window coordinates. The compositor surface accepts input only here when floating or docked.
    property rect inputRect: keyboard.dockedBar ? Qt.rect(keyboard.x + (keyboard.width - Math.min(640, keyboard.width - 24)) / 2, keyboard.y, Math.min(640, keyboard.width - 24), keyboard.height) : keyboard.floating ? Qt.rect(keyboard.x, keyboard.y, keyboard.width, keyboard.height) : Qt.rect(0, 0, width, height)
    property bool reserveSpace: !keyboard.floating
    property bool sparse: keyboard.floating || keyboard.dockedBar
    minimumWidth: 320
    minimumHeight: 320
    property bool privatePreview: typeof previewPurpose !== "undefined" && previewPurpose === 8
    property var purposeLabels: ["Text", "Digits", "Number", "Phone", "URL", "Email", "Password", "Date", "Time", "Terminal"]
    property var purposeValues: [0, 2, 3, 4, 5, 6, 8, 9, 10, 12]
    property int purposeIndex: Math.max(0, purposeValues.indexOf(typeof previewPurpose !== "undefined" ? previewPurpose : 0))
    function setPurpose(index) {
        purposeIndex = (index + purposeValues.length) % purposeValues.length;
        keyboard.purpose = purposeValues[purposeIndex];
        privatePreview = keyboard.purpose === 8;
        suggestionEngine.updateEditorContext(editor.text, editor.cursorPosition, privatePreview, keyboard.purpose);
        editor.forceActiveFocus();
    }
    Rectangle {
        visible: previewMode
        anchors.fill: parent
        anchors.bottomMargin: keyboard.visible ? keyboard.height : 0
        color: keyboard.backgroundColor
        ColumnLayout {
            anchors.fill: parent; anchors.margins: window.width < 500 ? 18 : 24; spacing: 12
            RowLayout {
                visible: window.height >= 500
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Borealis playground"; color: keyboard.foreground; font.pixelSize: window.width < 500 ? 22 : 27; font.weight: Font.DemiBold; font.family: keyboard.fontFamily }
                    Text { text: "Native Wayland input · isolated preview"; color: keyboard.secondaryText; font.pixelSize: 11; font.family: keyboard.fontFamily }
                }
                Rectangle {
                    Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
                    color: themeTap.pressed ? keyboard.secondaryContainer : keyboard.specialColor
                    Text { anchors.centerIn: parent; text: keyboard.light ? "dark_mode" : "light_mode"; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: keyboard.foreground }
                    TapHandler { id: themeTap; onTapped: keyboard.light = !keyboard.light }
                }
                Rectangle {
                    visible: !keyboard.visible
                    Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
                    color: showTap.pressed ? keyboard.secondaryContainer : keyboard.specialColor
                    Text { anchors.centerIn: parent; text: "keyboard"; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: keyboard.foreground }
                    TapHandler { id: showTap; onTapped: inputMethod.SetVisible(true) }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 24
                color: keyboard.previewSurfaceColor
                ScrollView {
                    anchors.fill: parent; anchors.margins: 18
                    TextArea {
                        id: editor
                        objectName: "previewEditor"
                        placeholderText: "Type something…"
                        color: keyboard.foreground; placeholderTextColor: keyboard.secondaryText
                        font.family: keyboard.fontFamily; font.pixelSize: 20
                        wrapMode: TextEdit.Wrap; selectByMouse: true
                        background: null
                        Component.onCompleted: { forceActiveFocus(); if (previewMode) suggestionEngine.updateEditorContext(text, cursorPosition, window.privatePreview, keyboard.purpose); }
                        onTextChanged: if (previewMode) suggestionEngine.updateEditorContext(text, cursorPosition, window.privatePreview, keyboard.purpose)
                        onCursorPositionChanged: if (previewMode) suggestionEngine.updateEditorContext(text, cursorPosition, window.privatePreview, keyboard.purpose)
                    }
                }
            }
            Rectangle {
                visible: window.height >= 650
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 21
                color: keyboard.specialColor
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17; color: previousPurpose.pressed ? keyboard.secondaryContainer : "transparent"
                        Text { anchors.centerIn: parent; text: "chevron_left"; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: keyboard.secondaryText }
                        TapHandler { id: previousPurpose; onTapped: window.setPurpose(window.purposeIndex - 1) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: window.purposeLabels[window.purposeIndex]; color: keyboard.foreground; font.family: keyboard.fontFamily; font.weight: Font.DemiBold; font.pixelSize: 13 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Input purpose"; color: keyboard.secondaryText; font.family: keyboard.fontFamily; font.pixelSize: 9 }
                    }
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17; color: nextPurpose.pressed ? keyboard.secondaryContainer : "transparent"
                        Text { anchors.centerIn: parent; text: "chevron_right"; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: keyboard.secondaryText }
                        TapHandler { id: nextPurpose; onTapped: window.setPurpose(window.purposeIndex + 1) }
                    }
                }
            }
            RowLayout {
                visible: window.height >= 600
                Layout.fillWidth: true; spacing: 6
                Text { text: "touch_app"; font.family: "Material Symbols Rounded"; font.pixelSize: 14; color: keyboard.primary }
                Text { Layout.fillWidth: true; text: "Hold for accents · double-tap Shift for caps · slide space to move"; color: keyboard.secondaryText; font.family: keyboard.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
            }
        }
    }
    Keyboard {
        id: keyboard
        objectName: "keyboard"
        preferences: preferenceStore.values; suggestions: suggestionEngine
        visible: inputMethod.Visible
        backend: inputMethod; clips: typeof clipboardBridge !== "undefined" ? clipboardBridge : null
        physicalKeyboard: typeof physicalKeyboardDetector !== "undefined" ? physicalKeyboardDetector : null
        hostWidth: window.width
        dockedPreview: previewMode && typeof previewDocked !== "undefined" && previewDocked
        width: floating ? floatWidth : window.width
        x: floating ? floatX : 0
        y: floating ? floatY : window.height - height
        height: implicitHeight
        availableHeight: previewMode ? window.height : (window.screen ? window.screen.height : 800)
        handheld: previewMode && typeof previewHandheld !== "undefined" && previewHandheld
        privateInput: previewMode ? window.privatePreview : inputMethod.sensitive
        purpose: previewMode && typeof previewPurpose !== "undefined" ? previewPurpose : inputMethod.purpose
        handed: previewMode && typeof previewPlacement !== "undefined" ? previewPlacement : 0
        mode: initialLayout === "emoji" || initialLayout === "edit" || initialLayout === "menu" || initialLayout === "clipboard" || initialLayout === "trackpad" ? "letters" : initialLayout
        initialPanel: ["emoji", "edit", "menu", "clipboard", "trackpad"].indexOf(initialLayout) >= 0 ? initialLayout : ""
        keyStyleSession: typeof previewKeyStyle !== "undefined" ? previewKeyStyle : ""
        floatAtStart: previewMode && typeof previewFloating !== "undefined" && previewFloating
        terminalAtStart: previewMode && typeof previewTerminal !== "undefined" && previewTerminal
    }
}
