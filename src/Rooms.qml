pragma Singleton
import QtQuick
import Quickshell

// Rooms model: workspaces with their windows and real tiling, plus the Ladder and Earlier lists. Phone, tablet and desktop share it.
Singleton {
    id:rooms
    readonly property bool live:!!Hub.status.hypr
    readonly property int current:Number(Hub.status.workspace)||1
    readonly property var monitors:Hub.status.monitors||[]

    // Logical monitor size, with rotation and scale applied.
    function logical(m) {
        if(!m||!m.width)return {x:0,y:0,w:1920,h:1080};
        const s=m.scale||1;const turned=(m.transform||0)%2===1;
        return {x:m.x||0,y:m.y||0,w:(turned ? m.height : m.width)/s,h:(turned ? m.width : m.height)/s};
    }
    // Steam games have no desktop entry, so their window class maps to the game library; the title is the last fallback.
    function appName(w) {
        const a=Hub.appForWindow(w);if(a)return a.name;
        const c=String(w.className||"");const steam=c.match(/^steam_app_(\d+)$/);
        if(steam){const g=(Hub.games||[]).find(x=>x.id==="steam:"+steam[1]);return g ? g.title : (w.title||"Game");}
        return w.title||c||"App";
    }
    function nameFor(id,windows) {
        const saved=(Hub.prefs.roomNames||{})[String(id)];
        if(saved)return saved;
        if(!windows.length)return "Empty";
        // The app with the most windows names the room.
        const count={};windows.forEach(w=>{const n=appName(w);count[n]=(count[n]||0)+1;});
        return Object.keys(count).sort((a,b)=>count[b]-count[a])[0];
    }
    // Tiles are fractions of the room's monitor, so any card size can draw them.
    function tilesFor(windows,monitor) {
        const g=logical(monitor);
        return windows.map(w=>{
            const at=w.at||[g.x,g.y];const size=w.size||[g.w,g.h];
            const full=(w.fullscreen||0)>0;
            const x=full ? 0 : Math.max(0,Math.min(1,(at[0]-g.x)/g.w));
            const y=full ? 0 : Math.max(0,Math.min(1,(at[1]-g.y)/g.h));
            return {window:w,app:Hub.appForWindow(w),title:w.title||appName(w),address:w.address||"",floating:!!w.floating,
                    x:x,y:y,w:full ? 1 : Math.max(.08,Math.min(1-x,size[0]/g.w)),h:full ? 1 : Math.max(.08,Math.min(1-y,size[1]/g.h))};
        });
    }
    // Without Hyprland there is one room; its windows share the card equally.
    function gridTiles(windows) {
        const n=windows.length;if(!n)return [];
        const cols=n<=2 ? n : 2;const rows=Math.ceil(n/cols);
        return windows.map((w,i)=>({window:w,app:Hub.appForWindow(w),title:w.title||appName(w),address:w.address||"",floating:false,
            x:(i%cols)/cols,y:Math.floor(i/cols)/rows,w:1/cols,h:1/rows}));
    }
    readonly property var list:{
        const windows=Hub.windows||[];
        if(!live)return [{id:1,name:"Here",windows:windows,tiles:gridTiles(windows),monitor:"",aspect:16/9}];
        const ids=(Hub.status.workspaces||[]).slice();
        if(ids.indexOf(current)<0&&current>0)ids.push(current);
        ids.sort((a,b)=>a-b);
        return ids.map(id=>{
            const own=windows.filter(w=>w.workspace===id);
            const onMonitor=own.length ? own[0].monitor : ((monitors.find(m=>m.workspace===id)||{}).name||"");
            const m=monitors.find(x=>x.name===onMonitor)||monitors[0]||null;
            const g=logical(m);
            return {id:id,name:nameFor(id,own),windows:own,tiles:tilesFor(own,m),monitor:onMonitor,aspect:g.w/g.h};
        });
    }
    readonly property var currentRoom:list.find(r=>r.id===current)||list[0]||null
    function enter(room) {if(room&&live)Hub.workspace(room.id);}
    function focus(tile) {if(tile&&tile.window)Hub.focusWindow(tile.window);}
    function newRoom() {if(live)Hub.command({action:"workspace-empty"});}
    function rename(id,name) {const next=Object.assign({},Hub.prefs.roomNames||{});if(name)next[String(id)]=name;else delete next[String(id)];Hub.set("roomNames",next);}

    // Ladder: what you were just doing, newest last (nearest the room). Media, then windows in other rooms, then the last file.
    readonly property var ladder:{
        const out=[];
        const files=(PhoneState.activity.files||[]);
        if(files.length)out.push({kind:"file",title:files[0].title,meta:"File · "+(files[0].when||"recent"),path:files[0].path,glyph:"description"});
        const others=list.filter(r=>r.id!==current&&r.windows.length).slice(0,2);
        others.forEach(r=>{const w=r.windows[0];out.push({kind:"window",title:w.title||appName(w),meta:(appName(w)===w.title ? "" : appName(w)+" · ")+"room "+r.id,window:w,app:Hub.appForWindow(w),room:r});});
        if(Hub.status.track)out.push({kind:"media",title:Hub.status.track,meta:(Hub.status.artist||"Media")+" · "+(Hub.status.playing ? "playing" : "paused"),glyph:"music_note"});
        return out.slice(-3);
    }
    // Earlier: finished things as chips. Recent games that are not running, then older files.
    readonly property var earlier:{
        const running=(Hub.windows||[]).map(w=>String(w.className||"").toLowerCase());
        const games=(PhoneState.activity.games||[]).filter(g=>!running.some(c=>c.indexOf(String(g.id).replace(/^steam:/,"steam_app_"))>=0)).slice(0,3)
            .map(g=>({kind:"game",title:g.title,game:g,glyph:"sports_esports"}));
        const files=(PhoneState.activity.files||[]).slice(1,3).map(f=>({kind:"file",title:f.title,path:f.path,glyph:"description"}));
        return games.concat(files);
    }
    function open(item) {
        if(!item)return;
        if(item.kind==="file"&&item.path)Quickshell.execDetached(["xdg-open",item.path]);
        else if(item.kind==="game"){const full=Hub.games.find(x=>x.id===item.game.id);if(full)Hub.launchGame(full);}
        else if(item.kind==="window")Hub.focusWindow(item.window);
        else if(item.kind==="media")Hub.media("play-pause");
    }
}
