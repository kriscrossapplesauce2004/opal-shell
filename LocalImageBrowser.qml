import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell

// An embedded browser: no portal/toplevel can open behind a layer-shell panel.
Item {
    id:browser
    property bool folderMode:false
    property string initialFolder:""
    property string error:""
    property string folderPath:""
    readonly property string home:Quickshell.env("HOME")
    property alias currentFolder:files.folder
    property alias folderButton:useFolder
    property alias entries:listing
    signal imageChosen(string path)
    signal folderChosen(string path)
    signal canceled()
    function localUrl(path) {
        path=path.trim();
        if(path==="~")path=home;
        else if(path.startsWith("~/"))path=home+path.slice(1);
        if(path.startsWith("file:///"))return path;
        if(!path.startsWith("/"))return "";
        return "file://"+path.split("/").map(encodeURIComponent).join("/");
    }
    function navigate(path) {
        const url=localUrl(path);
        if(!url){error="Enter an absolute local folder path or ~/folder.";return;}
        error="";files.folder=url;folderPath=decodeURIComponent(files.folder.toString().replace(/^file:\/\//,""));listing.currentIndex=-1;
    }
    Component.onCompleted:{navigate(initialFolder||home);listing.forceActiveFocus();}
    FolderListModel {
        id:files
        showDirs:true;showFiles:!browser.folderMode;showDotAndDotDot:false
        showHidden:false;showDirsFirst:true;showOnlyReadable:true
        nameFilters:["*.png","*.jpg","*.jpeg","*.webp","*.bmp","*.PNG","*.JPG","*.JPEG","*.WEBP","*.BMP"]
        sortField:FolderListModel.Name
    }
    ColumnLayout {
        anchors.fill:parent;spacing:12
        RowLayout {Layout.fillWidth:true
            MText {text:browser.folderMode ? "Choose a wallpaper folder" : "Choose an image";font.pixelSize:22;font.weight:Font.DemiBold;Layout.fillWidth:true;wrapMode:Text.WordWrap}
            MButton {icon:"close";tooltip:"Cancel browsing";onClicked:browser.canceled()}
        }
        RowLayout {Layout.fillWidth:true;spacing:6
            MButton {icon:"back";compact:true;tooltip:"Parent folder";enabled:files.parentFolder.toString()!==files.folder.toString();onClicked:browser.navigate(files.parentFolder.toString())}
            TextField {
                id:address;Layout.fillWidth:true;Layout.preferredHeight:40;selectByMouse:true;font.family:Theme.font;font.pixelSize:13;color:Theme.text;placeholderTextColor:Theme.subtext
                text:browser.folderPath
                placeholderText:"/path/to/folder";onAccepted:browser.navigate(text)
                background:Rectangle {radius:12;color:Theme.surfaceHigh;border.width:address.activeFocus ? 1 : 0;border.color:Theme.primary}
            }
            MButton {icon:"next";compact:true;tooltip:"Go to folder";onClicked:browser.navigate(address.text)}
        }
        RowLayout {Layout.fillWidth:true;spacing:6
            MButton {text:"Home";icon:"home";tonal:true;compact:true;onClicked:browser.navigate(browser.home)}
            MButton {text:"Pictures";icon:"folder";tonal:true;compact:true;onClicked:browser.navigate(browser.home+"/Pictures")}
        }
        MText {visible:browser.error!=="";text:browser.error;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:Theme.tertiary;font.pixelSize:12}
        ListView {
            id:listing;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:files;spacing:4
            boundsBehavior:Flickable.StopAtBounds
            ScrollBar.vertical:ScrollBar {}
            delegate:ItemDelegate {
                id:entry
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                required property int index
                width:listing.width;height:48
                highlighted:listing.currentIndex===index
                onClicked:{listing.currentIndex=index;if(fileIsDir)browser.navigate(fileUrl.toString());else browser.imageChosen(fileUrl.toString());}
                contentItem:RowLayout {spacing:12
                    Glyph {name:entry.fileIsDir ? "folder" : "palette";color:Theme.primary}
                    MText {text:entry.fileName;Layout.fillWidth:true;font.pixelSize:13}
                    Glyph {visible:entry.fileIsDir;name:"next";font.pixelSize:18;color:Theme.subtext}
                }
                background:Rectangle {radius:12;color:entry.highlighted ? Theme.primaryContainer : entry.hovered ? Theme.surfaceHigh : "transparent"}
                Accessible.name:fileName
            }
            Keys.onReturnPressed:{if(currentIndex>=0){const url=files.get(currentIndex,"fileUrl").toString();if(files.isFolder(currentIndex))browser.navigate(url);else browser.imageChosen(url);}}
            MText {anchors.centerIn:parent;width:parent.width-24;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;visible:files.count===0&&files.status!==FolderListModel.Loading;text:"No readable "+(browser.folderMode ? "subfolders" : "images or folders")+" here.\nTry another path.";color:Theme.subtext}
        }
        RowLayout {Layout.fillWidth:true
            MButton {text:"Cancel";onClicked:browser.canceled()}
            Item {Layout.fillWidth:true}
            MButton {id:useFolder;visible:browser.folderMode;text:"Use this folder";icon:"check";filled:true;enabled:files.status===FolderListModel.Ready;onClicked:browser.folderChosen(files.folder.toString())}
        }
    }
    Keys.onEscapePressed:event=>{browser.canceled();event.accepted=true;}
}
