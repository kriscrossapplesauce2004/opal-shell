import QtQuick
import QtQuick.Layouts

// Quick Settings tiles in a four-column grid: round 1×1, wide 2×1 and big 2×2 tiles with a live control. Edit mode reorders, resizes, adds and removes.
ColumnLayout {
    id:deck
    property bool editing:false
    readonly property var defaults:["wifi","bluetooth","dnd","awake","theme","saver","mic","keyboard"]
    readonly property var tiles:[
        {id:"wifi",title:"Internet",icon:"wifi"}, {id:"bluetooth",title:"Bluetooth",icon:"bluetooth"},
        {id:"dnd",title:"Do not disturb",icon:"quiet"}, {id:"awake",title:"Keep awake",icon:"coffee"},
        {id:"theme",title:"Dark theme",icon:"moon"}, {id:"saver",title:"Battery saver",icon:"battery"},
        {id:"mic",title:"Microphone",icon:"mic"}, {id:"keyboard",title:"Keyboard",icon:"keyboard"},
        {id:"motion",title:"Reduced motion",icon:"spark"}, {id:"capture",title:"Screenshot",icon:"capture"},
        {id:"autohide",title:"Auto-hide shelf",icon:"desktop"}, {id:"clipboard",title:"Clipboard",icon:"clipboard"},
        {id:"focus",title:"Focus timer",icon:"timer"}, {id:"convergence",title:"Displays",icon:"convergence"},
        {id:"android",title:"Android",icon:"android"},
        {id:"media",title:"Now playing",icon:"music_note"}, {id:"devices",title:"Device batteries",icon:"devices"}
    ]
    readonly property var order:(Hub.prefs.quickTiles||defaults).filter(id=>tiles.some(t=>t.id===id))
    // Tiles that a visible sheet section already shows. They stay in the order and come back in edit mode.
    property var suppressed:[]
    readonly property var shown:order.filter(id=>editing||suppressed.indexOf(id)<0).map(id=>tiles.find(t=>t.id===id))
    // Without a system battery the saver tile is about power use, not battery life.
    function titleFor(tile) {return tile.id==="saver"&&Hub.status.battery<0 ? "Power saver" : tile.title;}
    function iconFor(tile) {return tile.id==="saver"&&Hub.status.battery<0 ? "energy_savings_leaf" : tile.icon;}
    // The Android tile shows the live session, so it asks for a fresh status when the sheet opens.
    Component.onCompleted:if(order.indexOf("android")>=0)Hub.command({action:"waydroid-status"})
    // A tile with a page asks the sheet to grow that page out of the tile.
    signal pageRequested(string id, Item source)
    function openPage(id,source) {deck.pageRequested(id,source);}
    function state(id) {
        switch(id) {
        case "wifi":return !!Hub.status.wifi;
        case "bluetooth":return !!Hub.status.bluetooth;
        case "dnd":return Hub.dnd;
        case "awake":return Hub.keepAwake||Hub.gameSession;
        case "theme":return !Theme.light;
        case "saver":return Hub.status.profile==="power-saver";
        case "mic":return !Hub.status.micMuted;
        case "keyboard":return Hub.systemOskVisible;
        case "motion":return Theme.reduceMotion;
        case "capture":return Hub.recordingActive;
        case "autohide":return !!Hub.prefs.taskbarAutoHide;
        case "focus":return Hub.focusRunning;
        case "android":return Hub.waydroid.session==="running";
        default:return false;
        }
    }
    function subtitle(id) {
        if(id==="wifi")return Hub.status.wifi ? Hub.status.network : "Off";
        if(id==="bluetooth") {const device=Hub.connectivity.bluetooth.items.find(d=>d.active);return device ? device.name : state(id) ? "On" : "Off";}
        if(id==="keyboard")return Hub.systemOskAvailable ? state(id) ? "Visible" : "Ready" : "Unavailable";
        if(id==="saver"&&!Hub.status.profile)return "Unavailable";
        if(id==="capture")return Hub.recordingActive ? "Recording · Stop" : "Studio & recorder";
        if(id==="clipboard")return Hub.clipboardItems.length+" items";
        if(id==="convergence")return "Layout & docking";
        if(id==="focus")return Math.ceil(Hub.focusSeconds/60)+" minutes";
        if(id==="media"){const m=Activities.byId["media"];return m ? m.title : "Nothing playing";}
        if(id==="devices")return HomeData.devices.length ? HomeData.devices.map(d=>d.percent+"%").join(" · ") : "None";
        if(id==="android")return !(Hub.waydroid.installed&&Hub.waydroid.initialized) ? "Set up" : state(id) ? (Hub.waydroid.appCount||0)+" apps · On" : "Off";
        return state(id) ? "On" : "Off";
    }
    function toggle(id) {
        switch(id) {
        case "wifi":Hub.connection("wifi","power",{enabled:!(Hub.connectivity.wifi.powered||Hub.status.wifi)});break;
        case "bluetooth":Hub.connection("bluetooth","power",{enabled:!(Hub.connectivity.bluetooth.powered||Hub.status.bluetooth)});break;
        case "dnd":if(Hub.gameSession)Hub.toggleGameSession();else Hub.set("dnd",!Hub.dnd);break;
        case "awake":if(Hub.gameSession)Hub.toggleGameSession();else Hub.keepAwake=!Hub.keepAwake;break;
        case "theme":Hub.set("light",!Theme.light);break;
        case "saver":if(Hub.status.profile)Hub.command({action:"profile",value:state(id) ? "balanced" : "power-saver"});break;
        case "mic":Hub.command({action:"mic"});break;
        case "keyboard":if(Hub.systemOskAvailable)Hub.systemOsk("toggle");break;
        case "motion":Hub.set("reduceMotion",!Theme.reduceMotion);break;
        case "capture":Hub.openCapture();break;
        case "autohide":Hub.set("taskbarAutoHide",!Hub.prefs.taskbarAutoHide);break;
        case "clipboard":Hub.toggleClipboard();break;
        case "focus":Hub.timerToggle();break;
        case "convergence":Hub.openSettings("displays");break;
        case "media":Hub.media("play-pause");break;
        case "devices":Hub.openSettings("bluetooth");break;
        case "android":if(Hub.waydroid.installed&&Hub.waydroid.initialized)Hub.command({action:"waydroid-session",verb:state(id) ? "stop" : "start"});else Hub.openAndroid("setup");break;
        }
    }
    function change(id) {let next=order.slice();const index=next.indexOf(id);if(index>=0)next.splice(index,1);else next.push(id);Hub.set("quickTiles",next);}
    function moveTo(id,dest) {let next=order.slice();const index=next.indexOf(id);if(index<0)return;dest=Math.max(0,Math.min(next.length-1,dest));if(dest===index)return;next.splice(index,1);next.splice(dest,0,id);Hub.set("quickTiles",next);}
    // Sizes: any tile can be round or wide; tiles with a live control can also be big.
    readonly property var bigTiles:["media","devices","focus"]
    function allowed(id) {return id==="media"||id==="devices" ? ["wide","big"] : bigTiles.indexOf(id)>=0 ? ["round","wide","big"] : ["round","wide"];}
    function sizeOf(id) {
        const chosen=(Hub.prefs.quickTileSizes||{})[id];
        if(allowed(id).indexOf(chosen)>=0)return chosen;
        return id==="media"||id==="devices" ? "big" : order.indexOf(id)<4 ? "wide" : "round";
    }
    function cycleSize(id) {const list=allowed(id),next=list[(list.indexOf(sizeOf(id))+1)%list.length];const sizes=Object.assign({},Hub.prefs.quickTileSizes||{});sizes[id]=next;Hub.set("quickTileSizes",sizes);}
    function enabledFor(id) {return !(id==="keyboard"&&!Hub.systemOskAvailable||id==="saver"&&!Hub.status.profile);}
    // Tiles with a detail sheet grow into it on long-press or right-click.
    function pageFor(id) {return id==="wifi" ? "wifi" : id==="bluetooth" ? "bluetooth" : id==="convergence" ? "displays" : "";}
    readonly property real gap:8
    readonly property real rowH:64
    readonly property real unit:(grid.width-3*gap)/4
    // First-fit packing into four columns. Wide and big tiles start on column 0 or 2.
    readonly property var rects:{
        const used=[],out=[];
        const free=(r,c,w,h)=>{for(let y=r;y<r+h;y++)for(let x=c;x<c+w;x++)if(x>3||(used[y]&&used[y][x]))return false;return true;};
        const take=(r,c,w,h)=>{for(let y=r;y<r+h;y++){used[y]=used[y]||[];for(let x=c;x<c+w;x++)used[y][x]=true;}};
        for(const tile of deck.shown){
            const size=deck.sizeOf(tile.id),w=size==="round" ? 1 : 2,h=size==="big" ? 2 : 1;
            let placed=false;
            for(let r=0;!placed&&r<64;r++)for(let c=0;c<4&&!placed;c+=(w===2 ? 2 : 1))if(free(r,c,w,h)){take(r,c,w,h);out.push({x:c*(unit+gap),y:r*(rowH+gap),w:w*unit+(w-1)*gap,h:h*rowH+(h-1)*gap,size:size,row:r+h});placed=true;}
        }
        return out;
    }
    readonly property real gridHeight:rects.reduce((m,r)=>Math.max(m,r.y+r.h),0)
    spacing:12
    Item {
        id:grid
        Layout.fillWidth:true
        // Edit badges sit outside the tiles, so the grid steps in to keep them inside the sheet.
        Layout.topMargin:deck.editing ? 10 : 0;Layout.leftMargin:deck.editing ? 10 : 0;Layout.rightMargin:deck.editing ? 10 : 0
        Layout.preferredHeight:deck.gridHeight
        property int dragging:-1
        Repeater {
            model:deck.shown
            Item {
                id:cell
                required property var modelData
                required property int index
                readonly property var rect:deck.rects[index]||{x:0,y:0,w:deck.unit,h:deck.rowH,size:"round"}
                readonly property bool lifted:grid.dragging===index
                x:rect.x;y:rect.y;width:rect.w;height:rect.h
                z:lifted ? 5 : 0
                scale:lifted ? 1.05 : 1
                Behavior on x {enabled:!cell.lifted;NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
                Behavior on y {enabled:!cell.lifted;NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
                Behavior on width {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
                Behavior on height {NumberAnimation {duration:Theme.motion(Theme.durMedium);easing.type:Easing.OutCubic}}
                Behavior on scale {NumberAnimation {duration:Theme.motion(Theme.durShort)}}
                readonly property bool big:deck.bigTiles.indexOf(modelData.id)>=0&&(rect.size==="big"||modelData.id!=="focus")
                ShadeTile {
                    id:tile
                    visible:!cell.big
                    anchors.fill:parent
                    dense:true;iconOnly:cell.rect.size==="round"
                    icon:deck.iconFor(cell.modelData);title:deck.titleFor(cell.modelData);subtitle:deck.subtitle(cell.modelData.id);active:deck.state(cell.modelData.id)
                    settings:deck.pageFor(cell.modelData.id)!==""&&!deck.editing
                    enabled:deck.enabledFor(cell.modelData.id)||deck.editing
                    opacity:deck.enabledFor(cell.modelData.id) ? 1 : .45
                    onToggled:if(!deck.editing)deck.toggle(cell.modelData.id)
                    onClicked:if(!deck.editing){if(deck.pageFor(cell.modelData.id)!=="")deck.pageRequested(deck.pageFor(cell.modelData.id),cell);else deck.toggle(cell.modelData.id);}
                    onOpenSettings:deck.pageRequested(deck.pageFor(cell.modelData.id),cell)
                }
                QuickBigTile {visible:cell.big;anchors.fill:parent;kind:cell.modelData.id;wide:cell.rect.size==="wide"}
                // Right-click opens the sheet, like a long press.
                TapHandler {enabled:!deck.editing&&deck.pageFor(cell.modelData.id)!=="";acceptedButtons:Qt.RightButton;onTapped:deck.pageRequested(deck.pageFor(cell.modelData.id),cell)}
                // Edit mode: drag anywhere to move, the corner badge removes, the corner handle changes the size.
                Rectangle {visible:deck.editing;anchors.fill:parent;anchors.margins:-3;radius:cell.rect.size==="round" ? height/2+3 : 24;color:"transparent";border.width:2;border.color:Theme.alpha(Theme.primary,cell.lifted ? 1 : .45)}
                MouseArea {
                    visible:deck.editing;anchors.fill:parent;cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;preventStealing:true
                    drag.target:deck.editing ? cell : null
                    onPressed:grid.dragging=cell.index
                    onReleased:{
                        const cx=cell.x+cell.width/2,cy=cell.y+cell.height/2;let best=cell.index,dist=1e9;
                        deck.rects.forEach((r,i)=>{const d=Math.hypot(r.x+r.w/2-cx,r.y+r.h/2-cy);if(d<dist){dist=d;best=i;}});
                        grid.dragging=-1;cell.x=Qt.binding(()=>cell.rect.x);cell.y=Qt.binding(()=>cell.rect.y);
                        deck.moveTo(cell.modelData.id,best);
                    }
                    Accessible.role:Accessible.Button;Accessible.name:"Move "+cell.modelData.title
                }
                Rectangle {
                    visible:deck.editing;x:-8;y:-8;width:26;height:26;radius:13;color:Theme.level(5);border.width:1;border.color:Theme.outline
                    Glyph {anchors.centerIn:parent;name:"remove";font.pixelSize:16}
                    TapHandler {onTapped:deck.change(cell.modelData.id)}
                    Accessible.role:Accessible.Button;Accessible.name:"Remove "+cell.modelData.title
                }
                Rectangle {
                    visible:deck.editing&&deck.allowed(cell.modelData.id).length>1;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:-7
                    width:sizeText.implicitWidth+16;height:26;radius:13;color:Theme.secondaryContainer
                    MText {id:sizeText;anchors.centerIn:parent;text:cell.rect.size==="round" ? "1×1" : cell.rect.size==="wide" ? "2×1" : "2×2";role:"labelS";font.weight:Font.Bold;color:Theme.onSecondaryContainer}
                    TapHandler {onTapped:deck.cycleSize(cell.modelData.id)}
                    Accessible.role:Accessible.Button;Accessible.name:"Change the size of "+cell.modelData.title
                }
            }
        }
    }
    // Spare tiles: tap to add.
    ColumnLayout {
        visible:deck.editing&&spare.length>0;Layout.fillWidth:true;spacing:8
        readonly property var spare:deck.tiles.filter(t=>deck.order.indexOf(t.id)<0)
        MText {text:"Spare tiles";role:"titleS";Layout.leftMargin:4}
        MText {text:"Tap one to add it. Drag tiles to move them; the size badge changes their size.";role:"labelS";color:Theme.subtext;wrapMode:Text.Wrap;Layout.fillWidth:true;Layout.leftMargin:4}
        GridLayout {
            Layout.fillWidth:true;columns:2;columnSpacing:8;rowSpacing:8
            Repeater {
                model:parent.parent.spare
                ShadeTile {
                    required property var modelData
                    Layout.fillWidth:true;Layout.preferredHeight:56;dense:true
                    icon:deck.iconFor(modelData);title:deck.titleFor(modelData);subtitle:"Add"
                    onClicked:deck.change(modelData.id);onToggled:deck.change(modelData.id)
                }
            }
        }
    }
}
