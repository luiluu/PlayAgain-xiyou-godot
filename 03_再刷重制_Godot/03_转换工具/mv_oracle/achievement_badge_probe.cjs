'use strict';
// 成就 142「本质高手」／143「kyo专属」专用徽章与特殊样式（installWeakChallengeRuntime／installKyoAchievementRuntime）：
// 列表行（Window_AchievementBookIndex.drawItem）与弹窗（Window_AchievementPopup）的实际绘制调用，记到 canvas 级别
// （位置、尺寸、透明度、字号、字色、描边、阴影、渐变停点、填充条），不再只留前几屏。
// 徽章图用 256×256 的空 Bitmap 代替（只看 drawImage 的目标位置／尺寸与 globalAlpha）；时间固定为 2026-01-02 03:04:05，配置只在内存。
// 只写 .sandbox/achievement_badges.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});Graphics.width=1280;Graphics.height=720;Graphics.boxWidth=1280;Graphics.boxHeight=720;'+
  'var __D=Date;Date=function(){return arguments.length?new (Function.prototype.bind.apply(__D,[null].concat([].slice.call(arguments))))():new __D(2026,0,2,3,4,5);};Date.now=function(){return new Date().getTime();};');
const S=w.Star.AchievementSystem,M=w.Star.Achievement.Manager;
w.Scene_Boot.prototype.start.call({});
w.SceneManager._scene=new w.Scene_Base();
// 徽章图：不走磁盘，直接给 256×256 的就绪位图
const badges={};
const loadBitmap=w.ImageManager.loadBitmap;
w.ImageManager.loadBitmap=function(folder,file){
  if(String(folder).indexOf('codex_achievements')>=0){return badges[file]||(badges[file]=new w.Bitmap(256,256));}
  return loadBitmap.apply(this,arguments);};
const norm=v=>typeof v==='number'?+v.toFixed(6):(typeof v==='string'||typeof v==='boolean'||v===null||v===undefined)?v:'<obj>';
const SETS=['font','lineWidth','strokeStyle','fillStyle','shadowColor','shadowBlur','textAlign','textBaseline','lineJoin','globalAlpha'];
// 记 contents 的 2D 上下文：函数调用（含 globalAlpha）与属性赋值；渐变记停点
function tap(win,log){
  const b=win.contents,orig=b._context;
  const p=new Proxy(orig,{
    get(o,k){const v=o[k];
      if(typeof v!=='function'||k==='measureText'||k==='save'||k==='restore'||k==='clearRect'||k==='setTransform')return v;
      if(k==='createLinearGradient')return(...a)=>{const rec={op:k,args:a.map(norm),stops:[]};log.push(rec);v.apply(o,a);return{addColorStop:(off,c)=>rec.stops.push([norm(off),c]),__rec:rec};};
      return(...a)=>{log.push({op:k,args:a.map(norm),alpha:norm(o.globalAlpha)});return v.apply(o,a);};},
    set(o,k,v){if(SETS.indexOf(k)>=0)log.push({set:k,value:v&&v.__rec?'gradient':norm(v)});o[k]=v;return true;}});
  b.__context=p;return()=>{b.__context=orig;};}
const win=x=>({x:x.x,y:x.y,width:x.width,height:x.height,opacity:x.opacity,contentsOpacity:x.contentsOpacity,padding:x.standardPadding(),fontSize:x.standardFontSize(),lineHeight:x.lineHeight()});
const out={sourceIdentity:identity,cases:[]};
// 列表行：全局记录里有 142／143（owned）与没有（unowned）各量一行；类型取「光辉事迹」
const OWN=[[true,true],[false,false]];
for(const id of [142,143]){
  for(const owned of [true,false]){
    w.ConfigManager.SAchievementS={};w.DataManager.setupNewGame();
    if(owned){w.ConfigManager.SAchievementS[id]=true;w.ConfigManager.SAchievementS[id+'Time']='2026/01/02 03:04:05';}
    w.SceneManager._scene=null;
    const scene=new w.Scene_AchievementBook();w.SceneManager._scene=scene;scene.create();
    const types=S.AchievementTypeList,t=types.indexOf('光辉事迹');
    scene._indexTypeWindow.select(t);scene.update();
    const iw=scene._indexWindow,idx=iw._list.findIndex(a=>a.id===id);
    const log=[],calls=[];
    iw.contents.clear();
    const un=tap(iw,log);
    const dt=iw.drawText,dx=iw.drawTextEx,di=iw.drawIcon;
    // 方法级再记一层（已有的 text/icon 语义），不替换实际绘制：包一层先记后调
    iw.drawText=function(...a){calls.push({f:'text',t:String(a[0]),x:a[1],y:a[2],w:a[3],align:a[4]||'left',size:this.contents.fontSize});return dt.apply(this,a);};
    iw.drawTextEx=function(...a){calls.push({f:'textEx',t:String(a[0]),x:a[1],y:a[2]});return dx.apply(this,a);};
    iw.drawIcon=function(...a){calls.push({f:'icon',id:a[0],x:a[1],y:a[2],scale:a[3]||1});return di.apply(this,a);};
    iw.drawItem(idx);
    delete iw.drawText;delete iw.drawTextEx;delete iw.drawIcon;un();
    out.cases.push({id:'list.'+id+(owned?'.owned':'.unowned'),kind:'list',ach:id,owned,index:idx,rect:(({x,y,width,height})=>({x,y,width,height}))(iw.itemRectForText(idx)),
      lineHeight:iw.lineHeight(),itemHeight:iw.itemHeight?iw.itemHeight():null,window:win(iw),calls,canvas:log});
  }
}
// 弹窗：条目与 Manager 推送的一致（id／icon／title）
for(const id of [142,143]){
  const def=S.Achievement[id];
  const item={id,icon:Number(def.AcIconId),title:def.AcName};
  const pw=new w.Star.Achievement.Window_AchievementPopup(item);
  // 构造时 refresh 已画过一次：清空后重画一次并记录
  const log=[],calls=[];
  const un=tap(pw,log);
  const dt=pw.drawText,dx=pw.drawTextEx,di=pw.drawIcon;
  pw.drawTextEx=function(...a){calls.push({f:'textEx',t:String(a[0]),x:a[1],y:a[2]});return dx.apply(this,a);};
  pw.drawIcon=function(...a){calls.push({f:'icon',id:a[0],x:a[1],y:a[2],scale:a[3]||1});return di.apply(this,a);};
  pw.refresh();
  delete pw.drawTextEx;delete pw.drawIcon;un();
  out.cases.push({id:'popup.'+id,kind:'popup',ach:id,window:Object.assign(win(pw),{windowWidth:pw.windowWidth(),contentsWidth:pw.contentsWidth(),contentsHeight:pw.contentsHeight()}),calls,canvas:log});
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/achievement_badges.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify(out.cases.map(c=>({id:c.id,calls:c.calls.length,canvas:c.canvas.length}))));
process.exit(0);
