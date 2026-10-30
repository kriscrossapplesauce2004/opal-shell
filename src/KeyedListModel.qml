import QtQuick

// Keyed diff of a JS array into rows. Roles: rowKey (string) and data (holder QObject; read the item from data.value).
ListModel {
    id:km
    // Field of each item that holds its identity. Items with a missing key are skipped; a repeated key keeps its first item.
    property string key:"id"
    // ListModel turns plain JS objects into sub-models, so each item sits in a QObject holder that keeps it as is.
    property Component holder:Component {QtObject {property var value}}
    // Diff: drop rows that left, keep the longest run of survivors in place (LIS), move the rest before their successor, insert the new, set changed data.
    function sync(items) {
        const next=[],seen=Object.create(null);
        (items||[]).forEach(item=>{
            const raw=item ? item[km.key] : undefined;
            if(raw===undefined||raw===null||raw==="")return;
            const id=String(raw);
            if(seen[id]===true)return;
            seen[id]=true;next.push({key:id,item:item});
        });
        for(let i=count-1;i>=0;i-=1)if(seen[get(i).rowKey]!==true){get(i).data.destroy();remove(i,1);}
        const pos=[],survivors=[];
        next.forEach(e=>{const p=indexOfKey(e.key);if(p>=0){pos.push(p);survivors.push(e.key);}});
        const stay=Object.create(null);
        lis(pos).forEach(i=>stay[survivors[i]]=true);
        // Walk from the end: each row lands directly before its successor, which is already placed.
        for(let t=next.length-1;t>=0;t-=1) {
            const e=next[t];
            const anchor=t+1<next.length ? indexOfKey(next[t+1].key) : count;
            let at=indexOfKey(e.key);
            if(at<0){const h=holder.createObject(km);h.value=e.item;insert(anchor,{rowKey:e.key,data:h});continue;}
            if(!stay[e.key]){const target=at<anchor ? anchor-1 : anchor;if(target!==at){move(at,target,1);at=target;}}
            const h=get(at).data;
            if(!same(h.value,e.item))h.value=e.item;
        }
    }
    function indexOfKey(k) {
        for(let i=0;i<count;i+=1)if(get(i).rowKey===k)return i;
        return -1;
    }
    // Indices of one longest strictly increasing run in seq.
    function lis(seq) {
        const len=seq.map(()=>1),prev=seq.map(()=>-1);
        let end=-1;
        for(let i=0;i<seq.length;i+=1){
            for(let j=0;j<i;j+=1)if(seq[j]<seq[i]&&len[j]+1>len[i]){len[i]=len[j]+1;prev[i]=j;}
            if(end<0||len[i]>len[end])end=i;
        }
        const run=[];
        for(let i=end;i>=0;i=prev[i])run.unshift(i);
        return run;
    }
    // Structural equality for plain data; QObjects and functions compare by identity.
    function same(a,b) {
        if(a===b)return true;
        if(!a||!b||typeof a!=="object"||typeof b!=="object")return false;
        const plain=v=>Array.isArray(v)||Object.getPrototypeOf(v)===Object.prototype;
        if(!plain(a)||!plain(b)||Array.isArray(a)!==Array.isArray(b))return false;
        const ka=Object.keys(a);
        if(ka.length!==Object.keys(b).length)return false;
        return ka.every(k=>Object.prototype.hasOwnProperty.call(b,k)&&same(a[k],b[k]));
    }
}
