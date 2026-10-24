import QtQuick
import QtQuick.Layouts
// Apps and windows: window mode, the app switcher, file dialogs and Waydroid Android subsystem.
SettingsPage {
    id:page
    Component.onCompleted:Hub.command({action:"waydroid-status",refresh:true})
    SettingsLabel {text:"Window mode"}
    SegmentedButtons {Layout.fillWidth:true;current:!!Hub.prefs.floatingMode
        options:[{value:false,label:"Tiling",icon:"grid_view"},{value:true,label:"Floating",icon:"select_window"}]
        onPicked:value=>Hub.set("floatingMode",value)}
    MText {Layout.fillWidth:true;Layout.leftMargin:16;Layout.topMargin:6;text:Hub.prefs.floatingMode ? "Title bars, snap layouts and minimize. Turning it off tiles every window again." : "Windows tile side by side. Floating mode adds title bars and snap layouts.";role:"bodyS";color:Theme.subtext;wrapMode:Text.Wrap}
    SettingToggle {visible:!!Hub.prefs.floatingMode;first:true;last:true;icon:"select_window";title:"Respect window side decorations";description:"Do not add titlebars to windows that have client-side decorations (Chrome, GNOME)";checked:Hub.prefs.respectCsd!==false;onToggled:Hub.set("respectCsd",!(Hub.prefs.respectCsd!==false))}
    SettingsGroup {title:"App switcher"
        SettingRow {icon:"tab";title:"Alt+Tab shows";description:"Super+Tab keeps the switcher open without holding a key"
            SegmentedButtons {width:260;buttonHeight:40;current:Hub.prefs.switcherScope==="workspace" ? "workspace" : "all"
                options:[{value:"all",label:"All windows"},{value:"workspace",label:"This workspace"}]
                onPicked:value=>Hub.set("switcherScope",value)}
        }
        SettingToggle {icon:"preview";title:"Live previews";description:"Off shows app icons only, which is lighter on old GPUs";checked:Hub.prefs.switcherPreviews!==false;onToggled:Hub.set("switcherPreviews",!checked)}
    }
    SettingsGroup {title:"File dialogs"
        SettingRow {icon:"folder_open";title:"Opal file dialogs";description:"Apps' Open and Save dialogs, once “opal portal on” has run"}
    }
    SegmentedButtons {Layout.fillWidth:true;Layout.topMargin:8;current:Hub.prefs.portalPicker||"touch"
        options:[{value:"touch",label:"Phone & tablet",icon:"phone"},{value:"always",label:"Everywhere",icon:"devices"},{value:"never",label:"Never",icon:"block"}]
        onPicked:value=>Hub.set("portalPicker",value)}

    SettingsGroup {title:"Android (Waydroid)"
        SettingRow {
            icon:"smartphone"
            title:!Hub.waydroid.installed ? "Android apps are not set up"
                : Hub.waydroid.session==="running" ? "Android session is running"
                : "Android session is stopped"
            description:!Hub.waydroid.installed ? "Opal installs Waydroid and Android for you, then Android apps open in their own windows"
                : Hub.waydroid.session==="running" ? ((Hub.waydroid.appCount||0)+" Android apps"+(Hub.waydroid.ip ? " · "+Hub.waydroid.ip : ""))
                : "Apps start Android automatically when opened, or start the session below"
            Row {
                spacing:6
                MButton {
                    visible:!Hub.waydroid.installed||!Hub.waydroid.initialized
                    text:"Set up";icon:"download";filled:true;compact:true
                    onClicked:{Hub.close();Hub.openAndroid("setup");}
                }
                MButton {
                    visible:Hub.waydroid.installed&&Hub.waydroid.initialized
                    text:"Get apps";icon:"storefront";tonal:true;compact:true
                    onClicked:{Hub.close();Hub.openAndroid("store");}
                }
                MButton {
                    visible:Hub.waydroid.installed
                    text:Hub.waydroid.session==="running" ? "Stop" : "Start"
                    icon:Hub.waydroid.session==="running" ? "stop" : "play_arrow"
                    filled:Hub.waydroid.session!=="running";tonal:Hub.waydroid.session==="running";compact:true
                    onClicked:Hub.command({action:"waydroid-session",verb:Hub.waydroid.session==="running" ? "stop" : "start"})
                }
                MButton {
                    visible:Hub.waydroid.installed
                    text:"Full UI";icon:"open_in_new";tonal:true;compact:true
                    tooltip:"Open the full Android home screen"
                    onClicked:Hub.command({action:"waydroid-session",verb:"full-ui"})
                }
                MButton {
                    visible:Hub.waydroid.installed&&Hub.waydroid.session==="running"
                    icon:"refresh";compact:true;implicitWidth:36;implicitHeight:36
                    tooltip:"Restart Android session"
                    onClicked:Hub.command({action:"waydroid-session",verb:"restart"})
                }
            }
        }
        // Without adb Opal cannot send the back key, dark mode or read app versions; setup adds it.
        SettingRow {
            visible:Hub.waydroid.installed&&Hub.waydroid.adb===false
            icon:"cable";title:"Opal can't reach Android yet"
            description:"Add adb so the back key, dark mode sync and app updates work"
            MButton {text:"Add";icon:"download";tonal:true;compact:true;onClicked:Hub.command({action:"waydroid-setup-install",image:"VANILLA",arm:false})}
        }
        SettingToggle {
            visible:Hub.waydroid.installed
            icon:"select_window";title:"Multi-window mode"
            description:"Open Android apps in separate desktop windows instead of one full-screen container"
            checked:Hub.waydroid.multiWindows!==false
            onToggled:Hub.command({action:"waydroid-prop",key:"multiWindows",value:!(Hub.waydroid.multiWindows!==false)})
        }
        SettingToggle {
            visible:Hub.waydroid.installed
            icon:"bedtime";title:"Suspend container when idle"
            description:"Freeze Android in the background when no Android windows are open"
            checked:!!Hub.waydroid.suspend
            onToggled:Hub.command({action:"waydroid-prop",key:"suspend",value:!Hub.waydroid.suspend})
        }
        SettingToggle {
            icon:"dark_mode";title:"Sync dark mode with Opal"
            description:"Switch Android between light and dark theme whenever Opal changes"
            checked:Hub.prefs.waydroidSyncTheme!==false
            onToggled:Hub.set("waydroidSyncTheme",!(Hub.prefs.waydroidSyncTheme!==false))
        }
        SettingToggle {
            icon:"badge";title:"Show Android badge on app icons"
            description:"Mark Waydroid apps in Start, the app drawer and the shelf"
            checked:Hub.prefs.waydroidBadge!==false
            onToggled:Hub.set("waydroidBadge",!(Hub.prefs.waydroidBadge!==false))
        }
        SettingRow {
            visible:Hub.waydroid.installed
            icon:"folder_shared";title:"Android files & APK packages"
            description:"Open shared Android storage or double-click any .apk file to install it"
            MButton {
                text:"Shared folder";icon:"folder_open";tonal:true;compact:true
                onClicked:Hub.command({action:"open-path",path:Hub.waydroid.sharedFolder||""})
            }
        }
    }
}
