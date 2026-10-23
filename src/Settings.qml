import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Settings, Android style: a search pill and connected card groups, then one page with a large title that collapses as it scrolls.
// Wide screens show both panes; a small tablet keeps both with a slim list; a phone shows one pane; console mode is large and controller first.
Item {
    id:settings
    property real arrival:0
    opacity:Math.min(1,arrival)
    transform:Translate {y:(1-settings.arrival)*12}
    Component.onCompleted:enter.restart()
    NumberAnimation {id:enter;target:settings;property:"arrival";from:0;to:1;duration:Theme.motion(360);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
    readonly property bool gaming:Hub.prefs.mode==="console"
    readonly property bool narrow:width<600
    readonly property bool compact:!narrow&&!gaming&&width<880
    readonly property bool twoPane:!narrow
    readonly property real navWidth:gaming ? 400 : compact ? 268 : 360
    // Section tree. Each group is one card of connected rows; a section's tint follows its group.
    readonly property var groups:[
        [{id:"network",title:"Network & internet",icon:"wifi",detail:Hub.status.wifi ? "Wi-Fi · "+Hub.status.network : "Wi-Fi is off or not connected"},
         {id:"devices",title:"Connected devices",icon:"bluetooth",detail:"Bluetooth, Opal Link, controllers"}],
        [{id:"apps",title:"Apps & windows",icon:"select_window",detail:Hub.prefs.floatingMode ? "Floating windows, app switcher" : "Tiling, app switcher, file dialogs"},
         {id:"notifications",title:"Notifications",icon:"notifications",detail:Hub.dnd ? "Do not disturb is on" : Hub.inbox.length+" in your inbox"},
         {id:"power",title:"Battery & power",icon:"battery_5_bar",detail:Hub.status.battery>=0 ? Hub.status.battery+"% · "+(Hub.status.profile||"power") : "Profiles, keep awake, power key"},
         {id:"sound",title:"Sound",icon:"volume_up",detail:Hub.status.muted ? "Muted" : "Volume "+Hub.status.volume+"%"}],
        [{id:"displays",title:"Displays",icon:"monitor",detail:"Arrangement and what each screen becomes"},
         {id:"style",title:"Wallpaper & style",icon:"palette",detail:"Colours, themes and the Look"},
         {id:"home",title:"Home & shelf",icon:"dock_to_bottom",detail:"Layout, shelf, widgets, weather"},
         {id:"phone",title:"Phone & gestures",icon:"swipe",detail:"Navigation, edge gestures, keyboard"},
         {id:"games",title:"Games & controller",icon:"sports_esports",detail:"Button order and Quick Access"}],
        [{id:"routines",title:"Modes & routines",icon:"routine",detail:"Night light, schedules, profiles"},
         {id:"accessibility",title:"Accessibility",icon:"accessibility_new",detail:"Motion and readable surfaces"},
         {id:"system",title:"System",icon:"system_update",detail:"Updates, storage and temperatures"},
         {id:"about",title:"About this device",icon:"info",detail:"Opal"+(Hub.status.uptime ? " · up "+Hub.status.uptime : "")}]
    ]
    // Pages that open from a row inside another page.
    readonly property var subpages:({
        bluetooth:{title:"Bluetooth",icon:"bluetooth",detail:"Pair and connect",parent:"devices"},
        link:{title:"Opal Link",icon:"devices",detail:"Your phone and other Opal devices",parent:"devices"},
        powerkey:{title:"Power key",icon:"power_settings_new",detail:"The menu behind the power button",parent:"power"},
        look:{title:"Look",icon:"layers",detail:"Glass, Mixed or Material",parent:"style"},
        apptheme:{title:"Theme for apps",icon:"format_paint",detail:"GTK, Kitty, Qt and window borders",parent:"style"},
        profiles:{title:"Profiles",icon:"style",detail:"Save and switch whole setups",parent:"routines"}
    })
    readonly property var sections:groups.reduce((all,g)=>all.concat(g),[])
    function info(id) {return sections.find(s=>s.id===id)||(subpages[id] ? Object.assign({id:id},subpages[id]) : null);}
    function groupOf(id) {const top=subpages[id] ? subpages[id].parent : id;return groups.findIndex(g=>g.some(s=>s.id===top));}
    function tint(id) {return [Theme.primaryContainer,Theme.secondaryContainer,Theme.tertiaryContainer,Theme.level(5)][Math.max(0,groupOf(id))%4];}
    function tintInk(id) {return [Theme.onContainer,Theme.onSecondaryContainer,Theme.onTertiaryContainer,Theme.text][Math.max(0,groupOf(id))%4];}
    readonly property var selected:info(Hub.settingsSection)
    // The top-level section that is highlighted in the list.
    readonly property string topSection:subpages[Hub.settingsSection] ? subpages[Hub.settingsSection].parent : Hub.settingsSection
    function back() {
        if(subpages[Hub.settingsSection]){Hub.settingsSection=subpages[Hub.settingsSection].parent;return true;}
        if(Hub.settingsSection!==""){Hub.settingsSection="";return true;}
        return false;
    }
    // Controller: LB and RB step through sections. B goes up one level first.
    function controllerTab(delta) {const ids=sections.map(s=>s.id);const i=ids.indexOf(topSection);Hub.settingsSection=ids[i<0 ? (delta>0 ? 0 : ids.length-1) : (i+delta+ids.length)%ids.length];}
    function controllerBack() {return back();}

    // Deep search: every setting a page shows, by its row title. A hit opens the page and highlights that row.
    readonly property var index:[
        {s:"network",t:"Wi-Fi",k:"wireless network internet ssid"},
        {s:"bluetooth",t:"Bluetooth",k:"pair headphones devices"},
        {s:"link",t:"Opal Link",k:"kde connect phone sync"},
        {s:"devices",t:"Controllers",k:"gamepad joystick"},
        {s:"apps",t:"Window mode",k:"tiling floating titlebars snap"},
        {s:"apps",t:"Alt+Tab shows",k:"app switcher windows workspace"},
        {s:"apps",t:"Live previews",k:"app switcher thumbnails"},
        {s:"apps",t:"Opal file dialogs",k:"file picker portal open save"},
        {s:"notifications",t:"Do not disturb",k:"dnd silence quiet"},
        {s:"notifications",t:"Notification inbox",k:"history"},
        {s:"power",t:"Power profile",k:"performance saver balanced"},
        {s:"power",t:"Keep awake",k:"caffeine sleep inhibit"},
        {s:"power",t:"Power key",k:"button drum menu"},
        {s:"powerkey",t:"Power key menu",k:"button drum actions"},
        {s:"sound",t:"Output volume",k:"speakers loudness"},
        {s:"sound",t:"Mute output",k:"silent"},
        {s:"sound",t:"Mute microphone",k:"mic input"},
        {s:"sound",t:"Sound drawer",k:"outputs apps players"},
        {s:"sound",t:"Advanced mixer",k:"pavucontrol"},
        {s:"displays",t:"This screen becomes",k:"monitor resolution scale arrangement convergence dock"},
        {s:"style",t:"Wallpaper",k:"background image"},
        {s:"style",t:"Colours from wallpaper",k:"matugen dynamic palette"},
        {s:"style",t:"Dark theme",k:"night mode light"},
        {s:"style",t:"Themes",k:"omarchy gallery palette"},
        {s:"style",t:"App icons",k:"icon style backplate themed"},
        {s:"style",t:"Look",k:"glass material transparency blur solid"},
        {s:"look",t:"Look preset",k:"glass mixed material solid transparency"},
        {s:"look",t:"Compositor blur",k:"blur"},
        {s:"look",t:"Glass edges & sheen",k:"rim highlight"},
        {s:"look",t:"Elevation shadows",k:"shadow depth"},
        {s:"look",t:"App transparency",k:"kitty opacity terminal see-through"},
        {s:"look",t:"Glass density",k:"opacity translucency"},
        {s:"apptheme",t:"Theme for apps",k:"gtk qt kitty kvantum"},
        {s:"home",t:"Layout",k:"desktop phone console automatic mode"},
        {s:"home",t:"Bar style",k:"shelf islands dock split edge taskbar"},
        {s:"home",t:"Hide the shelf automatically",k:"autohide taskbar"},
        {s:"home",t:"Center apps",k:"taskbar"},
        {s:"home",t:"Window labels",k:"taskbar titles"},
        {s:"home",t:"Date beside the clock",k:"taskbar"},
        {s:"home",t:"Desktop widgets",k:"home glance"},
        {s:"home",t:"Weather city",k:"forecast temperature"},
        {s:"home",t:"Hide the home under apps",k:"icons fade transparent"},
        {s:"home",t:"Desktop files on the tablet home",k:"desktop folder"},
        {s:"phone",t:"Navigation",k:"gestures three buttons nav bar"},
        {s:"phone",t:"Edge gestures",k:"swipe back actions"},
        {s:"phone",t:"App drawer columns",k:"grid"},
        {s:"phone",t:"On-screen keyboard",k:"osk borealis"},
        {s:"games",t:"Controller button order",k:"nintendo xbox abxy"},
        {s:"games",t:"Guide button opens Quick Access",k:"steam guide button"},
        {s:"routines",t:"Night light",k:"warm blue light schedule sunset"},
        {s:"routines",t:"Dark theme",k:"schedule sunset automatic"},
        {s:"routines",t:"Do not disturb",k:"quiet hours schedule"},
        {s:"profiles",t:"Profiles",k:"setups save switch"},
        {s:"accessibility",t:"Reduce motion",k:"animation transitions"},
        {s:"accessibility",t:"Solid surfaces",k:"opaque material transparency readability"},
        {s:"accessibility",t:"Surface opacity",k:"glass density"},
        {s:"system",t:"Updates",k:"pacman flatpak upgrade"},
        {s:"system",t:"Storage",k:"disk space"},
        {s:"system",t:"Temperatures",k:"heat sensors"},
        {s:"about",t:"About this device",k:"version system cpu memory"}
    ]
    property string query:""
    readonly property string q:query.trim().toLowerCase()
    readonly property var hits:q==="" ? [] : index.filter(e=>(e.t+" "+e.k).toLowerCase().indexOf(q)>=0).slice(0,14)
    readonly property var sectionHits:q==="" ? [] : sections.filter(s=>(s.title+" "+s.detail).toLowerCase().indexOf(q)>=0)
    function where(id) {const sp=subpages[id];return sp ? info(sp.parent).title+" › "+sp.title : (info(id)||{title:""}).title;}

    // ---------- Layout ----------

    RowLayout {
        anchors.fill:parent;anchors.margins:settings.narrow ? 12 : 20;anchors.bottomMargin:settings.gaming ? 76 : anchors.margins;spacing:settings.compact ? 16 : 24
        // List pane.
        ColumnLayout {
            id:listPane
            visible:settings.twoPane||Hub.settingsSection===""
            Layout.fillWidth:!settings.twoPane;Layout.preferredWidth:settings.twoPane ? settings.navWidth : -1;Layout.maximumWidth:settings.twoPane ? settings.navWidth : 100000;Layout.fillHeight:true;spacing:8
            RowLayout {
                Layout.fillWidth:true;Layout.leftMargin:8
                MText {text:"Settings";font.pixelSize:settings.compact ? 30 : 36;font.weight:Font.Medium;font.variableAxes:({"wdth":110,"ROND":60});Layout.fillWidth:true}
                MButton {visible:!settings.twoPane;icon:"close";contained:true;compact:true;implicitWidth:44;implicitHeight:44;tooltip:"Close settings";onClicked:Hub.close()}
            }
            SearchField {id:search;Layout.fillWidth:true;Layout.topMargin:4;onTextChanged:settings.query=text}
            Flickable {
                id:listFlick
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.topMargin:6;clip:true;contentHeight:list.implicitHeight+12;boundsBehavior:Flickable.StopAtBounds
                ScrollBar.vertical:ScrollBar {}
                ColumnLayout {
                    id:list;width:parent.width;spacing:2
                    // Search results: single settings first, with where they live, then whole sections.
                    SettingsGroup {
                        visible:settings.q!=="";title:settings.hits.length ? settings.hits.length+(settings.hits.length===1 ? " setting" : " settings") : ""
                        Repeater {
                            model:settings.hits
                            SettingRow {
                                required property var modelData
                                badge:true;icon:(settings.info(modelData.s)||{icon:"tune"}).icon;badgeColor:settings.tint(modelData.s);badgeInk:settings.tintInk(modelData.s)
                                title:modelData.t;description:settings.where(modelData.s)
                                current:Hub.settingsSection===modelData.s&&Hub.settingsFound===modelData.t
                                onActivated:Hub.findSetting(modelData.s,modelData.t)
                            }
                        }
                    }
                    SettingsGroup {
                        visible:settings.q!==""&&settings.sectionHits.length>0;title:"Sections"
                        Repeater {
                            model:settings.sectionHits
                            SettingRow {required property var modelData;badge:true;icon:modelData.icon;badgeColor:settings.tint(modelData.id);badgeInk:settings.tintInk(modelData.id);title:modelData.title;description:modelData.detail;onActivated:Hub.settingsSection=modelData.id}
                        }
                    }
                    MText {visible:settings.q!==""&&!settings.hits.length&&!settings.sectionHits.length;Layout.fillWidth:true;Layout.topMargin:24;horizontalAlignment:Text.AlignHCenter;text:"No settings match “"+settings.query.trim()+"”";color:Theme.subtext}
                    // The section list.
                    Repeater {
                        model:settings.q==="" ? settings.groups : []
                        SettingsGroup {
                            id:grp
                            required property var modelData
                            required property int index
                            Layout.bottomMargin:12
                            Repeater {
                                model:grp.modelData
                                SettingRow {
                                    required property var modelData
                                    badge:true;icon:modelData.icon;badgeColor:settings.tint(modelData.id);badgeInk:settings.tintInk(modelData.id)
                                    title:modelData.title;description:settings.compact ? "" : modelData.detail
                                    implicitHeight:settings.gaming ? 80 : settings.compact ? 56 : 68
                                    current:settings.twoPane&&settings.topSection===modelData.id
                                    onActivated:Hub.settingsSection=modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
        // Page pane.
        ColumnLayout {
            visible:settings.twoPane||Hub.settingsSection!==""
            Layout.fillWidth:true;Layout.fillHeight:true;spacing:0
            // Flexible top app bar: back and actions on one row, then a large title that collapses into the row as the page scrolls.
            readonly property real scrolled:page.item&&page.item.contentY!==undefined ? page.item.contentY : 0
            readonly property bool collapsed:scrolled>48||settings.narrow&&scrolled>24
            RowLayout {
                Layout.fillWidth:true;Layout.preferredHeight:52;spacing:8
                MButton {visible:!settings.twoPane||!!settings.subpages[Hub.settingsSection];icon:"back";contained:true;compact:true;implicitWidth:44;implicitHeight:44;tooltip:"Back";onClicked:settings.back()}
                MText {
                    Layout.fillWidth:true;text:settings.selected ? settings.selected.title : "Overview";role:"title"
                    opacity:parent.parent.collapsed ? 1 : 0;Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durShort)}}
                }
                MButton {visible:settings.twoPane;icon:"close";contained:true;compact:true;implicitWidth:44;implicitHeight:44;tooltip:"Close settings";onClicked:Hub.close()}
            }
            Item {
                Layout.fillWidth:true
                Layout.preferredHeight:parent.collapsed ? 0 : bigTitle.implicitHeight+12
                Behavior on Layout.preferredHeight {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}}
                clip:true
                ColumnLayout {
                    id:bigTitle;width:parent.width;spacing:4
                    opacity:parent.parent.collapsed ? 0 : 1;Behavior on opacity {NumberAnimation {duration:Theme.motion(Theme.durShort)}}
                    MText {Layout.fillWidth:true;text:settings.selected ? settings.selected.title : "Overview";font.pixelSize:settings.gaming ? 44 : settings.narrow ? 32 : 40;font.weight:Font.Medium;font.variableAxes:({"wdth":110,"ROND":60});wrapMode:Text.Wrap;maximumLineCount:2}
                    MText {Layout.fillWidth:true;text:settings.selected ? settings.selected.detail : "Your device at a glance";role:"body";color:Theme.subtext}
                }
            }
            Loader {
                id:page
                Layout.fillWidth:true;Layout.fillHeight:true
                readonly property string sec:Hub.settingsSection
                sourceComponent:({"":overviewPage,network:networkPage,bluetooth:bluetoothPage,devices:devicesPage,link:linkPage,apps:appsPage,notifications:notificationsPage,power:powerPage,powerkey:powerKeyPage,sound:soundPage,displays:screensPage,style:stylePage,look:lookPage,apptheme:appThemePage,home:homePage,phone:phonePage,games:gamesPage,routines:routinesPage,profiles:profilesPage,accessibility:accessibilityPage,system:systemPage,about:aboutPage})[sec]||overviewPage
                // A new page slides in from the side; going back slides the other way.
                onLoaded:pageIn.restart()
                ParallelAnimation {
                    id:pageIn
                    NumberAnimation {target:page;property:"opacity";from:0;to:1;duration:Theme.motion(200)}
                    NumberAnimation {target:pageShift;property:"x";from:20;to:0;duration:Theme.motion(320);easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.emphasizedDecelerate}
                }
                transform:Translate {id:pageShift}
            }
        }
    }
    // Console mode: what the controller buttons do here.
    Row {
        visible:settings.gaming
        anchors.bottom:parent.bottom;anchors.bottomMargin:20;anchors.right:parent.right;anchors.rightMargin:28;spacing:26
        Repeater {
            model:[{b:"LB RB",t:"Sections"},{b:"A",t:"Select"},{b:"B",t:"Back"}]
            Row {
                required property var modelData
                spacing:8
                Rectangle {width:Math.max(32,bl.implicitWidth+16);height:32;radius:16;color:Theme.level(4);anchors.verticalCenter:parent.verticalCenter
                    MText {id:bl;anchors.centerIn:parent;text:modelData.b;role:"label";font.weight:Font.Bold}}
                MText {text:modelData.t;role:"titleS";anchors.verticalCenter:parent.verticalCenter}
            }
        }
    }

    // ---------- Pieces ----------

    // M3E search bar. Typing filters the list into results.
    component SearchField: Rectangle {
        property alias text:field.text
        implicitHeight:settings.gaming ? 64 : 56;radius:height/2
        color:Theme.light ? "#ffffff" : Theme.level(4)
        RowLayout {anchors.fill:parent;anchors.leftMargin:18;anchors.rightMargin:8;spacing:12
            Glyph {name:field.text ? "arrow_back" : "search";font.pixelSize:24;color:Theme.text
                MouseArea {anchors.fill:parent;enabled:field.text!=="";onClicked:field.text=""}}
            TextField {id:field;Layout.fillWidth:true;Layout.fillHeight:true;placeholderText:"Search settings";color:Theme.text;placeholderTextColor:Theme.subtext;font.family:Theme.font;font.pixelSize:settings.gaming ? 18 : 15;selectByMouse:true;background:Item {}
                onAccepted:if(settings.hits.length)Hub.findSetting(settings.hits[0].s,settings.hits[0].t)}
            MButton {visible:field.text!=="";icon:"close";compact:true;implicitWidth:40;implicitHeight:40;tooltip:"Clear";onClicked:field.text=""}
        }
    }

    // Device card: live state in one glance. Every value comes from the status adapter.
    component DeviceCard: Rectangle {
        id:card
        implicitHeight:176
        radius:28
        color:Theme.primaryContainer
        clip:true
        Flower {x:card.width-width*.7;y:-height*.25;width:card.height*1.3;height:width;lobes:9;depth:.1;fill:Theme.alpha(Theme.onContainer,.07)}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:20;spacing:4
            MText {text:Qt.formatDateTime(Hub.now,"HH:mm");font.pixelSize:44;font.weight:Font.Medium;color:Theme.onContainer}
            MText {text:Qt.formatDateTime(Hub.now,"dddd, d MMMM")+(Hub.status.uptime ? "  ·  up "+Hub.status.uptime : "");role:"bodyS";color:Theme.alpha(Theme.onContainer,.8)}
            Item {Layout.fillHeight:true}
            Flow {
                Layout.fillWidth:true;spacing:6
                Repeater {
                    model:[
                        {icon:Hub.status.wifi ? "wifi" : "wifiOff",text:Hub.status.wifi ? Hub.status.network : "Offline",show:true},
                        {icon:Hub.status.charging ? "charging" : "battery",text:Hub.status.battery+"%",show:Hub.status.battery>=0},
                        {icon:"bluetooth",text:"On",show:!!Hub.status.bluetooth},
                        {icon:Hub.status.muted ? "mute" : "volume",text:Hub.status.muted ? "Muted" : Hub.status.volume+"%",show:true}
                    ].filter(x=>x.show)
                    Rectangle {
                        required property var modelData
                        width:chipRow.implicitWidth+18;height:28;radius:14;color:Theme.alpha(Theme.onContainer,.1)
                        Row {id:chipRow;anchors.centerIn:parent;spacing:5
                            Glyph {name:modelData.icon;font.pixelSize:15;color:Theme.onContainer;anchors.verticalCenter:parent.verticalCenter}
                            MText {text:modelData.text;role:"labelS";color:Theme.onContainer;anchors.verticalCenter:parent.verticalCenter}
                        }
                    }
                }
            }
        }
    }

    // ---------- Pages ----------

    Component {id:overviewPage;SettingsPage {
        DeviceCard {Layout.fillWidth:true}
        SettingsGroup {title:"Quick settings"
            SettingToggle {icon:"dark_mode";title:"Dark theme";checked:!Theme.light;onToggled:Hub.set("light",!Theme.light)}
            SettingToggle {icon:"do_not_disturb_on";title:"Do not disturb";checked:Hub.dnd;onToggled:Hub.set("dnd",!Hub.dnd)}
            SettingToggle {icon:"coffee";title:"Keep awake";checked:Hub.keepAwake;onToggled:Hub.keepAwake=!Hub.keepAwake}
            SettingRow {icon:"layers";title:"Look";value:({glass:"Glass",mixed:"Mixed",material:"Material"})[Theme.look]+(Theme.lookCustom ? " · Custom" : "");chevron:true;onActivated:Hub.settingsSection="look"}
        }
    }}
    Component {id:networkPage;ConnectionPanel {kind:"wifi";embedded:true;backAction:()=>settings.back()}}
    Component {id:bluetoothPage;ConnectionPanel {kind:"bluetooth";embedded:true;backAction:()=>settings.back()}}
    Component {id:devicesPage;SettingsDevices {}}
    Component {id:linkPage;SettingsLink {}}
    Component {id:appsPage;SettingsApps {}}
    Component {id:notificationsPage;SettingsNotifications {}}
    Component {id:powerPage;SettingsPower {}}
    Component {id:powerKeyPage;SettingsPowerKey {}}
    Component {id:soundPage;SettingsSound {}}
    Component {id:screensPage;SettingsScreens {}}
    Component {id:stylePage;SettingsStyle {}}
    Component {id:lookPage;SettingsLook {}}
    Component {id:appThemePage;SettingsAppTheme {}}
    Component {id:homePage;SettingsHome {}}
    Component {id:phonePage;SettingsPhone {}}
    Component {id:gamesPage;SettingsGames {}}
    Component {id:routinesPage;SettingsRoutines {}}
    Component {id:profilesPage;SettingsProfiles {}}
    Component {id:accessibilityPage;SettingsAccessibility {}}
    Component {id:systemPage;SettingsSystem {}}
    Component {id:aboutPage;SettingsAbout {}}
}
