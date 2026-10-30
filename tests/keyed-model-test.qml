import QtQuick
import QtQuick.Window
import Quickshell
import "src" as Opal

// KeyedListModel contract: sync() inserts, removes, moves and updates rows in place, and survivors keep their delegate.
ShellRoot {
    id:root
    Component.onCompleted:Quickshell.watchFiles=false
    Opal.KeyedListModel {id:km;key:"id"}
    Window {
        id:win
        width:400;height:120;visible:true;color:"#000"
        property int failures:0
        property int step:0
        property int phase:0
        property var snap:({})
        Item {
            anchors.fill:parent
            Repeater {id:rep;model:km;Item {required property var modelData;required property int index}}
        }
        function check(name,ok) {
            console.log((ok ? "PASS " : "FAIL ") + name);
            if(!ok)failures+=1;
        }
        function row(id,title) {return {id:id,title:title,windows:[{title:title+"-window"}],app:{name:id}};}
        function delegateOf(k) {
            for(let i=0;i<rep.count;i+=1){const d=rep.itemAt(i);if(d&&d.modelData.rowKey===k)return d;}
            return null;
        }
        function snapshot() {
            const out={};
            for(let i=0;i<rep.count;i+=1){const d=rep.itemAt(i);out[d.modelData.rowKey]=d;}
            return out;
        }
        function orderNow() {
            const out=[];
            for(let i=0;i<km.count;i+=1)out.push(km.get(i).rowKey);
            return out;
        }
        function verify(scene) {
            const name=scene.name;
            check(name+": order "+scene.order.join(","),orderNow().join(",")===scene.order.join(","));
            check(name+": row count "+km.count,km.count===scene.order.length&&rep.count===scene.order.length);
            let identity=true,present=true,titles=true;
            scene.order.forEach(k=>{
                const d=delegateOf(k);
                if(d===null){present=false;return;}
                if(snap[k]!==undefined&&d!==snap[k])identity=false;
                if(d.modelData.data.value.title!==scene.titles[k])titles=false;
            });
            Object.keys(snap).forEach(k=>{if(scene.order.indexOf(k)<0&&delegateOf(k)!==null)identity=false;});
            check(name+": every row has a delegate",present);
            check(name+": surviving delegates keep identity",identity);
            check(name+": delegates show the synced data",titles);
            let plain=true;
            for(let i=0;i<km.count;i+=1){const d=km.get(i).data.value;if(!Array.isArray(d.windows)||d.windows.length!==1)plain=false;}
            check(name+": nested windows stay arrays",plain);
        }
        // Each scene: the items to sync, the expected order, and the expected title per key.
        property var scenes:[
            {name:"insert-initial",items:[row("a","A"),row("b","B"),row("c","C")],order:["a","b","c"],titles:{a:"A",b:"B",c:"C"}},
            {name:"update-in-place",items:[row("a","A"),row("b","B2"),row("c","C")],order:["a","b","c"],titles:{a:"A",b:"B2",c:"C"}},
            {name:"insert-front",items:[row("x","X"),row("a","A"),row("b","B2"),row("c","C")],order:["x","a","b","c"],titles:{x:"X",a:"A",b:"B2",c:"C"}},
            {name:"remove-middle",items:[row("x","X"),row("b","B2"),row("c","C")],order:["x","b","c"],titles:{x:"X",b:"B2",c:"C"}},
            {name:"move-to-front",items:[row("c","C"),row("x","X"),row("b","B2")],order:["c","x","b"],titles:{c:"C",x:"X",b:"B2"}},
            {name:"reverse",items:[row("b","B2"),row("x","X"),row("c","C")],order:["b","x","c"],titles:{b:"B2",x:"X",c:"C"}},
            {name:"duplicate-and-missing-keys",items:[row("p","P1"),row("p","P2"),{title:"nokey"},null,row("q","Q")],order:["p","q"],titles:{p:"P1",q:"Q"}},
            {name:"empty",items:[],order:[],titles:{}}
        ].concat(stressScenes(40));
        function stressScenes(total) {
            let seed=12345;
            const rnd=n=>{let x=seed;x^=x<<13;x^=x>>>17;x^=x<<5;seed=x>>>0;return seed%n;};
            const out=[];
            for(let s=0;s<total;s+=1) {
                const pool=["a","b","c","d","e","f","g","h"];
                for(let i=pool.length-1;i>0;i-=1){const j=rnd(i+1);const t=pool[i];pool[i]=pool[j];pool[j]=t;}
                const items=pool.slice(0,rnd(pool.length+1)).map(k=>row(k,k+(rnd(2)===0 ? "" : "-"+s)));
                const titles={};items.forEach(it=>titles[it.id]=it.title);
                out.push({name:"stress-"+s,items:items,order:items.map(it=>it.id),titles:titles});
            }
            return out;
        }
        Timer {
            interval:60;repeat:true;running:true
            onTriggered:{
                if(win.phase===0) {
                    if(win.step>=win.scenes.length) {
                        console.log("KEYED_MODEL_TESTS", win.failures===0 ? "PASS" : "FAIL", "failures=" + win.failures);
                        Qt.exit(win.failures===0 ? 0 : 1);
                        return;
                    }
                    win.snap=win.snapshot();
                    km.sync(win.scenes[win.step].items);
                    win.phase=1;
                } else {
                    win.verify(win.scenes[win.step]);
                    win.step+=1;win.phase=0;
                }
            }
        }
    }
}
