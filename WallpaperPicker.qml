import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id:w
    property string draftPath:Hub.prefs.wallpaperPath||""
    property int draftArt:Hub.prefs.wallpaper||0
    property string draftFit:Hub.prefs.wallpaperFit||"crop"
    property real draftDim:Hub.prefs.wallpaperDim||0
    property string tab:Hub.prefs.wallpaperPath ? "images" : "art"
    property string folder:""
    property string browsing:""
    readonly property var browser:browserLoader.item
    readonly property bool small:width<450||height<720
    readonly property bool wide:width>=900
    readonly property var names:["Bloom","Orbit","Play","Quiet"]
    readonly property string selectionName:draftPath ? decodeURIComponent(draftPath.split("/").pop()) : names[draftArt]
    readonly property bool changed:draftPath!==(Hub.prefs.wallpaperPath||"")||draftArt!==(Hub.prefs.wallpaper||0)||draftFit!==(Hub.prefs.wallpaperFit||"crop")||Math.abs(draftDim-(Hub.prefs.wallpaperDim||0))>.001
    function reset(){draftPath=Hub.prefs.wallpaperPath||"";draftArt=Hub.prefs.wallpaper||0;draftFit=Hub.prefs.wallpaperFit||"crop";draftDim=Hub.prefs.wallpaperDim||0;}
    Component.onCompleted:Hub.browseWallpapers("")
    ColumnLayout {
        visible:w.browsing===""
        anchors.fill:parent;anchors.margins:w.small ? 16 : 24;spacing:w.small ? 8 : 16
        RowLayout {Layout.fillWidth:true
            ColumnLayout {Layout.fillWidth:true;spacing:3
                MText {text:"WALLPAPER STUDIO";font.pixelSize:10;font.letterSpacing:2;color:Theme.primary;Layout.fillWidth:true}
                MText {text:"Make yourself at home";font.pixelSize:w.small ? 22 : 28;font.weight:Font.DemiBold;Layout.fillWidth:true}
            }
            MButton {icon:"close";tooltip:"Leave without applying preview";onClicked:Hub.page="appearance"}
        }
        GridLayout {
            columns:w.wide ? 2 : 1;columnSpacing:24;rowSpacing:10
            Layout.fillWidth:true;Layout.fillHeight:true
            ColumnLayout {
                Layout.preferredWidth:w.wide ? w.width*.42 : -1
                Layout.fillWidth:true;Layout.fillHeight:w.wide;spacing:10
                Rectangle {
                    Layout.fillWidth:true;Layout.preferredHeight:w.wide ? width*9/16 : w.small ? 140 : 220
                    radius:20;color:Theme.base;clip:true
                    Wallpaper {id:wallpaperPreview;anchors.fill:parent;showWidgets:false;imagePath:w.draftPath;composition:w.draftArt;fit:w.draftFit;dim:w.draftDim}
                    Surface {anchors.left:parent.left;anchors.top:parent.top;anchors.margins:12;width:previewLabel.implicitWidth+24;height:30;radius:15;translucency:.85
                        MText {id:previewLabel;anchors.centerIn:parent;text:w.changed ? "Preview · not applied" : "Current wallpaper";font.pixelSize:11}
                    }
                    Surface {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:12;width:160;height:36;radius:18;translucency:Hub.prefs.glass
                        Row {anchors.centerIn:parent;spacing:16
                            Glyph {name:"apps";color:Theme.primary}
                            Glyph {name:"folder";color:Theme.secondary}
                            Glyph {name:"web";color:Theme.tertiary}
                            Glyph {name:"settings";color:Theme.text}
                        }
                    }
                }
                MText {visible:w.wide;Layout.fillWidth:true;text:w.selectionName;font.pixelSize:18;font.weight:Font.DemiBold;maximumLineCount:2;wrapMode:Text.WordWrap}
                MText {visible:w.wide;Layout.fillWidth:true;text:"Try a new backdrop. Your desktop stays unchanged until you apply it.";font.pixelSize:12;color:Theme.subtext;wrapMode:Text.WordWrap}
                RowLayout {Layout.fillWidth:true;spacing:6
                    MButton {text:"Fill";compact:true;enabled:!!w.draftPath;filled:w.draftFit==="crop";tooltip:"Crop to fill the display";onClicked:w.draftFit="crop"}
                    MButton {text:"Fit";compact:true;enabled:!!w.draftPath;filled:w.draftFit==="fit";tooltip:"Show the whole image";onClicked:w.draftFit="fit"}
                    MText {visible:!w.wide;text:"Dim";font.pixelSize:11;color:Theme.subtext}
                    ExpressiveSlider {visible:!w.wide;Layout.fillWidth:true;enabled:!!w.draftPath;opacity:enabled ? 1 : .4;from:0;to:80;value:w.draftDim*100;icon:"moon";onMoved:w.draftDim=Math.round(value)/100}
                }
                MText {visible:w.wide;text:"Image dimming · "+Math.round(w.draftDim*100)+"%";font.pixelSize:12;color:Theme.subtext}
                ExpressiveSlider {visible:w.wide;Layout.fillWidth:true;enabled:!!w.draftPath;opacity:enabled ? 1 : .4;from:0;to:80;value:w.draftDim*100;icon:"moon";onMoved:w.draftDim=Math.round(value)/100}
                Item {visible:w.wide;Layout.fillHeight:true}
            }
            ColumnLayout {
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:120;spacing:10
                RowLayout {Layout.fillWidth:true;spacing:6
                    MButton {text:"Collection";compact:true;filled:w.tab==="art";onClicked:w.tab="art"}
                    MButton {text:"Your images";compact:true;filled:w.tab==="images";onClicked:w.tab="images"}
                    Item {Layout.fillWidth:true}
                    MButton {icon:"restart";compact:true;tooltip:"Refresh images";visible:w.tab==="images";enabled:!Hub.wallpaperLibraryBusy;onClicked:Hub.browseWallpapers(w.folder)}
                }
                RowLayout {Layout.fillWidth:true;spacing:6
                    MButton {Layout.fillWidth:true;text:"Open image";icon:"add";compact:true;tonal:true;onClicked:w.browsing="image"}
                    MButton {Layout.fillWidth:true;text:"Browse folders";icon:"folder";compact:true;tonal:true;onClicked:w.browsing="folder"}
                }
                MText {visible:w.tab==="images";Layout.fillWidth:true;text:w.folder ? decodeURIComponent(w.folder.replace(/^file:\/\//,"")) : "Pictures & system wallpapers";font.pixelSize:11;color:Theme.subtext}
                GridView {
                    id:gallery;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;cacheBuffer:0
                    cellWidth:width/Math.max(2,Math.floor(width/190));cellHeight:w.small ? 116 : cellWidth*9/16+38
                    model:w.tab==="art" ? [0,1,2,3] : Hub.wallpaperLibrary
                    boundsBehavior:Flickable.StopAtBounds
                    ScrollBar.vertical:ScrollBar {}
                    delegate:Item {
                        id:tile
                        required property var modelData
                        required property int index
                        readonly property bool art:w.tab==="art"
                        readonly property bool chosen:art ? !w.draftPath&&w.draftArt===index : w.draftPath===modelData.path
                        function choose(){if(art){w.draftPath="";w.draftArt=index;}else w.draftPath=modelData.path;}
                        width:gallery.cellWidth;height:gallery.cellHeight
                        Rectangle {
                            anchors.fill:parent;anchors.margins:4;radius:16
                            color:tile.chosen ? Theme.primaryContainer : pick.containsMouse ? Theme.surfaceHigh : Theme.alpha(Theme.surfaceHigh,.5)
                            border.width:tile.chosen ? 2 : 1;border.color:tile.chosen ? Theme.primary : Theme.outline
                            Item {anchors.fill:parent;anchors.margins:5;anchors.bottomMargin:32;clip:true
                                Loader {anchors.fill:parent;active:tile.art;sourceComponent:Component {Wallpaper {showWidgets:false;imagePath:"";composition:tile.index}}}
                                Image {id:thumbnail;anchors.fill:parent;visible:!tile.art;source:tile.art ? "" : tile.modelData.path;fillMode:Image.PreserveAspectCrop;sourceSize.width:480;sourceSize.height:270;asynchronous:true;autoTransform:true}
                                Glyph {anchors.centerIn:parent;visible:!tile.art&&thumbnail.status!==Image.Ready;name:thumbnail.status===Image.Error ? "close" : "palette";color:Theme.subtext}
                            }
                            MText {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.leftMargin:10;anchors.rightMargin:tile.chosen ? 32 : 10;anchors.bottomMargin:10;text:tile.art ? w.names[tile.index] : tile.modelData.name;font.pixelSize:11;color:tile.chosen ? Theme.onContainer : Theme.text}
                            Glyph {visible:tile.chosen;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:8;name:"check";font.pixelSize:18;color:Theme.onContainer}
                            MouseArea {id:pick;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:tile.choose()}
                            activeFocusOnTab:true
                            Keys.onReturnPressed:tile.choose()
                            Keys.onSpacePressed:tile.choose()
                            Accessible.role:Accessible.Button
                            Accessible.name:tile.art ? w.names[tile.index] : tile.modelData.name
                            Accessible.onPressAction:tile.choose()
                        }
                    }
                    MText {anchors.centerIn:parent;width:parent.width-24;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;visible:w.tab==="images"&&(Hub.wallpaperLibraryBusy||Hub.wallpaperLibrary.length===0);text:Hub.wallpaperLibraryBusy ? "Finding local images…" : Hub.wallpaperLibraryError||"Your next backdrop goes here.\nBrowse a folder or open an image.";color:Theme.subtext;font.pixelSize:13}
                }
                MText {visible:w.tab==="images";Layout.fillWidth:true;text:Hub.wallpaperLibrary.length+" images · local only";font.pixelSize:10;color:Theme.muted}
            }
        }
        RowLayout {Layout.fillWidth:true;spacing:8
            MButton {text:"Reset preview";tonal:true;compact:w.small;enabled:w.changed;onClicked:w.reset()}
            Item {visible:w.wide;Layout.fillWidth:true}
            MButton {Layout.fillWidth:!w.wide;icon:"check";text:w.changed ? "Apply wallpaper" : "Applied";filled:true;compact:w.small;enabled:w.changed&&wallpaperPreview.imageReady;onClicked:Hub.command({action:"wallpaper",path:w.draftPath,wallpaper:w.draftArt,wallpaperFit:w.draftFit,wallpaperDim:w.draftDim})}
        }
    }
    Loader {
        id:browserLoader
        anchors.fill:parent;anchors.margins:w.small ? 16 : 24
        active:w.browsing!=="";visible:active
        sourceComponent:Component {LocalImageBrowser {
            folderMode:w.browsing==="folder";initialFolder:w.folder
            onCanceled:w.browsing=""
            onImageChosen:path=>{w.draftPath=path;w.tab="images";w.browsing="";}
            onFolderChosen:path=>{w.folder=path;w.tab="images";Hub.browseWallpapers(path);w.browsing="";}
        }}
    }
}
