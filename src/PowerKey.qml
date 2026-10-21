pragma Singleton
import QtQuick
import Quickshell

// The power key menu: a tap opens it, the volume keys move, power picks. Spec: docs/POWER-KEY-2026-10.md.
QtObject {
    id:pk
    property bool open:false
    property var screen:null
    // "key" opens from the hardware key and may count down to sleep; "shortcut" and "controller" never count down.
    property string source:"key"
    // Submenu nodes from the root down. The rows of each level are resolved again whenever live state changes.
    property var stack:[]
    property int index:0
    // 0..1 while Sleep counts down, -1 otherwise.
    property real countdown:-1
    // Set by the backend: whether this device hands its power key to Opal, the key positions, and live device state.
    property var device:({enabled:false,handset:false,power:{edge:"right",at:.36},volume:{edge:"right",at:.22}})
    property var live:({airplane:false,hotspot:false,recording:false,feedback:false})
    property var contacts:[]
    // An action picked on the lock screen that needs the session unlocked first.
    property var pendingUnlock:null
    signal unlockRequested()

    readonly property var defaults:[{action:"displays"},{action:"contacts"},{action:"sleep"},{action:"power"},{action:"media"},{action:"switch-user"}]
    readonly property var tree:Array.isArray(Hub.prefs.powerMenu)&&Hub.prefs.powerMenu.length ? Hub.prefs.powerMenu : defaults
    readonly property string startAction:Hub.prefs.powerMenuStart||"sleep"
    readonly property int countdownMs:typeof Hub.prefs.powerMenuCountdown==="number" ? Hub.prefs.powerMenuCountdown : 2000
    readonly property var presses:Hub.prefs.powerPress||({})
    readonly property var rows:levelRows(stack)
    readonly property var current:rows[Math.max(0,Math.min(rows.length-1,index))]||null

    // Every action the menu can hold. "secure" rows need an unlocked session; "sub" rows open a submenu.
    readonly property var catalog:[
        {id:"sleep",icon:"bedtime",label:"Sleep",group:"Power"},
        {id:"power",icon:"power_settings_new",label:"Power",group:"Power",sub:true},
        {id:"lock",icon:"lock",label:"Lock",group:"Power"},
        {id:"switch-user",icon:"switch_account",label:"Switch user",group:"Power",secure:true},
        {id:"displays",icon:"devices",label:"Displays",group:"Media & people",sub:true,secure:true},
        {id:"contacts",icon:"contacts",label:"Contacts",group:"Media & people",sub:true,secure:true},
        {id:"media",icon:"play_circle",label:"Media",group:"Media & people",sub:true},
        {id:"flashlight",icon:"flashlight_on",label:"Flashlight",group:"Device",toggle:true},
        {id:"rotation-lock",icon:"screen_rotation",label:"Rotation lock",group:"Device",toggle:true},
        {id:"airplane",icon:"airplanemode_active",label:"Airplane mode",group:"Device",toggle:true,secure:true},
        {id:"dnd",icon:"do_not_disturb_on",label:"Do not disturb",group:"Device",toggle:true},
        {id:"hotspot",icon:"wifi_tethering",label:"Hotspot",group:"Device",toggle:true,secure:true},
        {id:"keep-awake",icon:"coffee",label:"Keep awake",group:"Device",toggle:true},
        {id:"screenshot",icon:"screenshot_region",label:"Screenshot",group:"Capture"},
        {id:"record",icon:"screen_record",label:"Record screen",group:"Capture",toggle:true,secure:true},
        {id:"camera",icon:"photo_camera",label:"Camera",group:"Capture",secure:true},
        {id:"assistant",icon:"auto_awesome",label:"Ask Claude",group:"Shell",secure:true},
        {id:"search",icon:"search",label:"Search",group:"Shell",secure:true},
        {id:"notifications",icon:"notifications",label:"Notifications",group:"Shell",secure:true},
        {id:"quick-settings",icon:"tune",label:"Quick settings",group:"Shell",secure:true},
        {id:"clipboard",icon:"content_paste",label:"Clipboard",group:"Shell",secure:true},
        {id:"game-mode",icon:"sports_esports",label:"Game mode",group:"Shell",secure:true},
        {id:"app",icon:"apps",label:"Open app…",group:"Yours",secure:true,custom:true},
        {id:"command",icon:"terminal",label:"Run command…",group:"Yours",secure:true,custom:true},
        {id:"link",icon:"link",label:"Open link…",group:"Yours",secure:true,custom:true},
        {id:"folder",icon:"folder",label:"Submenu…",group:"Yours",sub:true,custom:true}]
    readonly property var catalogIndex:{const map={};catalog.forEach(c=>map[c.id]=c);return map;}

    function entry(node) {return catalogIndex[node&&node.action]||null;}
    function nodeLabel(node) {
        const e=entry(node);
        if(node.label)return node.label;
        if(node.action==="app"){const app=Hub.appIndex[String(node.app||"").toLowerCase()];return app ? app.name : "App";}
        return e ? e.label.replace("…","") : String(node.action||"");
    }
    function nodeIcon(node) {
        if(node.icon)return node.icon;
        const e=entry(node);
        return e ? e.icon : "radio_button_unchecked";
    }

    // One row for a stored node, with live state in its detail line.
    function row(node) {
        const e=entry(node)||{};
        const r={id:node.action,node:node,icon:nodeIcon(node),label:nodeLabel(node),detail:"",sub:!!e.sub||node.action==="folder",secure:!!e.secure,on:undefined,danger:false,group:""};
        const s=Hub.status, l=pk.live;
        switch(node.action) {
        case "displays": r.detail=modeName(Hub.prefs.mode)+(Quickshell.screens.length>1 ? " · "+Quickshell.screens.length+" screens" : "");break;
        case "contacts": {const n=favourites().length;r.detail=n ? n+(n===1 ? " favourite" : " favourites") : pk.contacts.length ? pk.contacts.length+" contacts" : "";break;}
        case "media": r.detail=s.track ? s.track+(s.artist ? " · "+s.artist : "") : "Nothing playing";break;
        case "flashlight": r.on=PhoneState.torch.on;r.detail=!PhoneState.torch.available ? "Not on this device" : r.on ? "On" : "Off";break;
        case "rotation-lock": r.on=Hub.prefs.autoRotate===false;r.detail=r.on ? "Locked" : "Auto-rotate";break;
        case "airplane": r.on=!!l.airplane;r.detail=r.on ? "On" : "Off";break;
        case "dnd": r.on=Hub.dnd;r.detail=r.on ? "On" : "Off";break;
        case "hotspot": r.on=!!l.hotspot;r.detail=r.on ? "Sharing" : "Off";break;
        case "keep-awake": r.on=Hub.keepAwake;r.detail=r.on ? "On" : "Off";break;
        case "record": r.on=!!l.recording;r.detail=r.on ? "Recording · pick to stop" : "Whole screen";break;
        case "screenshot": r.detail="Whole screen";break;
        case "switch-user": r.detail="Keep this session running";break;
        case "command": r.detail=String(node.command||"");break;
        case "link": r.detail=String(node.url||"");break;
        case "folder": r.detail=(node.items||[]).length+" actions";break;
        }
        return r;
    }
    function modeName(m) {return ({phone:"Phone",desktop:"Desktop",console:"Game",auto:"Automatic"})[m]||"Automatic";}
    function back() {return {id:"back",node:{action:"back"},icon:"arrow_back",label:"Back",detail:"",sub:false,secure:false,group:""};}
    function plain(id,icon,label,detail,extra) {return Object.assign({id:id,node:{action:id},icon:icon,label:label,detail:detail||"",sub:false,secure:false,group:""},extra||{});}

    // Rows of the level at the top of the stack. Built-in submenus fill themselves from live state.
    function levelRows(path) {
        if(!path.length)return pk.tree.map(row);
        const node=path[path.length-1];
        const s=Hub.status;
        let list=[];
        switch(node.action) {
        case "power":
            list=[plain("reboot","restart_alt","Restart"),plain("poweroff","power_settings_new","Shut down","",{danger:true}),plain("logout","logout","Log out","",{secure:true}),plain("lock","lock","Lock")];
            break;
        case "media":
            list=s.track ? [plain("play-pause",s.playing ? "pause" : "play_arrow",s.playing ? "Pause" : "Play",s.track),plain("next","skip_next","Next"),plain("previous","skip_previous","Previous")]
                         : [plain("media-none","music_off","Nothing playing","Start something in an app")];
            break;
        case "displays": {
            const modes=[["phone","smartphone","Phone"],["desktop","desktop_windows","Desktop"],["console","sports_esports","Game"],["auto","auto_mode","Automatic"]];
            list=modes.map((m,i)=>plain("mode-"+m[0],m[1],m[2],"",{on:(Hub.prefs.mode||"auto")===m[0],group:i===0 ? "Mode" : ""}));
            if(Hub.dockScreen) {
                const out=Hub.dockScreen.name;
                list=list.concat([plain("out-mirror","screen_share","Mirror","",{on:Hub.dockMirrored,group:"Outputs · "+out}),
                                  plain("out-extend","splitscreen_right","Extend","",{on:Hub.docked&&!Hub.dockMirrored}),
                                  plain("out-only","phonelink_off","This screen only")]);
            }
            break;
        }
        case "contacts": {
            const fav=favourites();
            list=fav.map(c=>contactRow(c));
            if(pk.contacts.length>fav.length)list.push(plain("contacts-all","group","All contacts",pk.contacts.length+" people",{sub:true}));
            if(!pk.contacts.length)list=[plain("contacts-none","person_off","No contacts yet","Add vCards or an address book")];
            break;
        }
        case "contacts-all": list=pk.contacts.map(c=>contactRow(c));break;
        case "contact": {
            const c=pk.contacts.find(x=>x.uid===node.uid)||{name:"",phones:[],emails:[]};
            const phone=(c.phones||[])[0]||"", email=(c.emails||[])[0]||"";
            const via=pk.device.handset ? "" : "Through your linked phone";
            if(phone)list.push(plain("call","call","Call",phone+(via ? " · "+via : ""),{target:phone}));
            if(phone)list.push(plain("text","sms","Text",phone,{target:phone}));
            if(email)list.push(plain("email","mail","Email",email,{target:email}));
            if(email)list.push(plain("share-shot","screenshot_region","Send a screenshot",email,{target:email}));
            if(phone)list.push(plain("copy","content_copy","Copy number",phone,{target:phone}));
            list.push(plain("open-contact","person","Open contact card",c.name,{target:c.uid}));
            break;
        }
        case "folder": list=(node.items||[]).map(row);break;
        }
        return [back()].concat(list);
    }
    function favourites() {
        const pinned=Hub.prefs.powerContacts||[];
        const byPin=pinned.map(uid=>pk.contacts.find(c=>c.uid===uid)).filter(Boolean);
        return byPin.length ? byPin : pk.contacts.filter(c=>c.favourite);
    }
    function contactRow(c) {
        return {id:"contact",node:{action:"contact",uid:c.uid},icon:"person",label:c.name,detail:(c.phones||[])[0]||(c.emails||[])[0]||"",sub:true,secure:true,group:"",avatar:c.avatar||""};
    }

    // ---------- Opening and moving ----------
    function show(from,onScreen) {
        if(Hub.page!==""&&!Hub.locked)Hub.close();
        source=from||"key";screen=onScreen||Hub.internalScreen||Hub.chooseScreen();
        stack=[];
        const start=pk.rows.findIndex(r=>r.id===pk.startAction);
        index=start>=0 ? start : 0;
        open=true;
        Hub.command({action:"powerkey-grab",on:true});
        Hub.command({action:"powerkey-refresh"});
        PhoneState.refreshTorch();
        if(source==="key"&&countdownMs>0&&pk.current&&pk.current.id==="sleep")startCountdown();
    }
    function close() {
        if(!open)return;
        open=false;stopCountdown();stack=[];
        Hub.command({action:"powerkey-grab",on:false});
    }
    function toggle(from,onScreen) {if(open)close();else show(from,onScreen);}
    function move(delta) {
        stopCountdown();
        const next=Math.max(0,Math.min(rows.length-1,index+delta));
        if(next!==index){index=next;haptic("step");}
    }
    function select(i) {stopCountdown();index=Math.max(0,Math.min(rows.length-1,i));}
    function goBack() {
        stopCountdown();
        if(!stack.length){close();return;}
        const parent=stack.slice(0,-1), left=stack[stack.length-1];
        stack=parent;
        const i=rows.findIndex(r=>r.node===left||r.id===left.action&&(left.uid===undefined||r.node.uid===left.uid));
        index=i>=0 ? i : 0;
    }
    function pick() {
        stopCountdown();
        const r=current;if(!r)return;
        if(r.id==="back"){goBack();haptic("step");return;}
        if(Hub.locked&&r.secure){pendingUnlock=r;close();unlockRequested();return;}
        haptic("pick");
        if(r.sub){stack=stack.concat([r.node]);index=Math.min(1,rows.length-1);return;}
        close();
        run(r);
    }

    // ---------- Countdown to sleep ----------
    property Timer countdownTimer:Timer {interval:30;repeat:true
        property double started:0
        onTriggered:{
            const t=(Date.now()-started)/Math.max(1,pk.countdownMs);
            if(t>=1){stop();pk.countdown=-1;if(pk.open&&pk.current&&pk.current.id==="sleep"){pk.close();pk.run(pk.current||{id:"sleep",node:{action:"sleep"}});}}
            else pk.countdown=t;
        }}
    function startCountdown() {countdownTimer.started=Date.now();countdown=0;countdownTimer.start();}
    function stopCountdown() {countdownTimer.stop();countdown=-1;}

    // ---------- The physical key ----------
    // The backend forwards key edges after it has dropped presses that only woke the screen.
    property double downAt:0
    property bool holdFired:false
    property bool tapPending:false
    property Timer holdTimer:Timer {interval:550;onTriggered:{pk.holdFired=true;pk.runPress(pk.presses.hold);}}
    property Timer doubleTimer:Timer {interval:300;onTriggered:{pk.tapPending=false;pk.show("key");}}
    function keyEdge(down) {
        if(down) {
            // With the menu open, the key picks. The grab normally routes it to the menu surface instead.
            if(open){pick();return;}
            downAt=Date.now();holdFired=false;
            if(presses.hold)holdTimer.restart();
            else if(!presses.double)show("key");
            return;
        }
        holdTimer.stop();
        if(holdFired||open&&!presses.double&&!presses.hold)return;
        if(presses.double) {
            if(tapPending){doubleTimer.stop();tapPending=false;runPress(presses.double);}
            else {tapPending=true;doubleTimer.restart();}
        } else if(!open) show("key");
    }
    function chord() {holdTimer.stop();holdFired=true;if(presses.chord)runPress(presses.chord);}
    function runPress(node) {if(!node||!node.action)return;const r=row(node);if(Hub.locked&&r.secure){pendingUnlock=r;unlockRequested();return;}if(r.sub){show("key");stack=[node];index=Math.min(1,rows.length-1);return;}run(r);}

    property Connections lockWatch:Connections {target:Hub
        function onLockedChanged() {if(!Hub.locked&&pk.pendingUnlock){const r=pk.pendingUnlock;pk.pendingUnlock=null;if(r.sub){pk.show("key");pk.stack=[r.node];pk.index=Math.min(1,pk.rows.length-1);}else pk.run(r);}}}

    function haptic(kind) {if(live.feedback)Hub.command({action:"powerkey-haptic",kind:kind});}

    // ---------- Running a row ----------
    function run(r) {
        const n=r.node||{}, id=r.id;
        switch(id) {
        case "sleep": Hub.command({action:"power",verb:"suspend"});break;
        case "reboot": case "poweroff": Hub.command({action:"power",verb:id});break;
        case "logout": Hub.command({action:"power",verb:"logout"});break;
        case "lock": Hub.lock();break;
        // This session locks first, then another login screen starts on a new VT.
        case "switch-user": Hub.lock();Hub.command({action:"switch-user"});break;
        case "play-pause": case "next": case "previous": Hub.media(id);break;
        case "flashlight": if(PhoneState.torch.available)PhoneState.setTorch(!PhoneState.torch.on);break;
        case "airplane": Hub.command({action:"powerkey-toggle",what:"airplane",on:!live.airplane});break;
        case "hotspot": Hub.command({action:"powerkey-toggle",what:"hotspot",on:!live.hotspot});break;
        case "record": Hub.command({action:"powerkey-toggle",what:"record",on:!live.recording});break;
        case "rotation-lock": Hub.set("autoRotate",Hub.prefs.autoRotate===false);break;
        case "dnd": Hub.set("dnd",!Hub.dnd);break;
        case "keep-awake": Hub.keepAwake=!Hub.keepAwake;break;
        case "screenshot": Hub.command({action:"screenshot"});break;
        case "camera": Hub.command({action:"powerkey-camera"});break;
        case "assistant": Hub.openAssistant("");break;
        case "search": Hub.targetScreen=pk.screen||Hub.chooseScreen();Hub.openSearch();break;
        case "notifications": Hub.targetScreen=pk.screen||Hub.chooseScreen();Hub.toggle("notifications");break;
        case "quick-settings": Hub.targetScreen=pk.screen||Hub.chooseScreen();Hub.toggle("controls");break;
        case "clipboard": Hub.targetScreen=pk.screen||Hub.chooseScreen();Hub.toggleClipboard();break;
        case "game-mode": Hub.mode(Hub.prefs.mode==="console" ? "auto" : "console");break;
        case "app": {const app=Hub.appIndex[String(n.app||"").toLowerCase()];if(app)Hub.launch(app);break;}
        case "command": if(n.command)Hub.command({action:"powerkey-run",command:String(n.command)});break;
        case "link": if(n.url)Hub.command({action:"powerkey-open",url:String(n.url)});break;
        case "mode-phone": case "mode-desktop": case "mode-console": case "mode-auto": Hub.targetScreen=pk.screen;Hub.mode(id.slice(5));break;
        case "out-mirror": Hub.applyDock({mode:"mirror",phoneMode:"trackpad"});break;
        case "out-extend": Hub.applyDock({mode:"desktop",phoneMode:"phone"});break;
        case "out-only": if(Hub.dockScreen)Hub.command({action:"powerkey-output-off",name:Hub.dockScreen.name});break;
        case "call": case "text": case "email": case "share-shot": case "copy": case "open-contact":
            Hub.command({action:"powerkey-contact",verb:id,target:String(r.target||"")});break;
        }
    }

    // Edge and position of a key on the screen after the panel's rotation. at runs top to bottom, or left to right.
    // Rows follow the Wayland transform: 1 turns the image a quarter turn counter-clockwise.
    function keyPlace(key) {
        const k=key||device.power, t=Hub.orientation>0 ? Hub.orientation%4 : 0, right=k.edge!=="left";
        return [right ? {edge:"right",at:k.at} : {edge:"left",at:k.at},
                right ? {edge:"top",at:1-k.at} : {edge:"bottom",at:1-k.at},
                right ? {edge:"left",at:1-k.at} : {edge:"right",at:1-k.at},
                right ? {edge:"bottom",at:k.at} : {edge:"top",at:k.at}][t];
    }
}
