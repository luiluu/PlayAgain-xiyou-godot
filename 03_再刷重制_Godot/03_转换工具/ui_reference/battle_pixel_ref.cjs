'use strict';
// 战斗画面像素对照（rules-battle-pixel，八戒）：无头 Chrome 打开 serve.py 的只读服务（127.0.0.1:8766，冻结正式源），
// 照 mac-preload-shim 的「战斗夹具 4 人」建内存新局（难度 3、队伍 1/8/9/10、地图 5、Math.random 0.5），但敌群换成 4（【守层者】里德，
// 敌人 6 在 MOG_BossHP 名单里），截 Boss 血条、状态图标（右侧状态格、Boss 状态面板、选敌名字旁）、伤害数字三类场面，
// 每张截图同时记场景显示树里看得见的节点（构造名、全局矩形、不透明度）。只建内存新局，不读写存档。
// 用法：python3 -I serve.py <app.nw> <输出目录> &  然后  node battle_pixel_ref.cjs <输出目录>/bp_ref.json
// 截图写进 serve.py 的输出目录（bp_*.png），读数写 <输出.json>。
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const outFile = path.resolve(process.argv[2] || 'bp_ref.json');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-bp-'));
const dbg = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

const PAGE = `(async function(){
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const until=async(f,ms=60000)=>{const t=performance.now();while(!f()){if(performance.now()-t>ms)throw new Error('超时 '+f);await sleep(20);}};
  await until(()=>window.DataManager&&DataManager.isDatabaseLoaded()&&window.$gameSystem&&SceneManager._scene&&!(SceneManager._scene instanceof Scene_Boot)&&SceneManager._scene.isActive(),120000);
  await sleep(1500);
  // 夹具（同 mac-preload-shim fixture(4)，敌群改 4）
  if (SceneManager._scene instanceof Scene_Map) { SceneManager._scene.update=function(){};SceneManager._scene.isBusy=function(){return false;}; }
  SceneManager.goto(Scene_Base);
  ConfigManager.applyData({}); DataManager.setupNewGame();
  $gameSystem.setDifficultyId(3);
  for (var i=1;i<5000;i++) $gameVariables._data[i]=0;
  $gameParty._actors=[1,8,9,10]; $gameParty._battleMembers=$gameParty._actors.slice();
  Game_Map.prototype.updateInterpreter=function(){};
  $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo(); $gamePlayer.refresh();
  $gameParty.members().forEach(function(a){
    [6168,5980,5548].concat([1,2,3,4,5,6,7,52].indexOf(a.actorId())>=0?[2571,2786]:[]).forEach(function(id){a.learnSkill(id);});
    a.initPassiveCache(); a.refreshPassiveCache(); a.recoverAll();
  });
  $gameParty.gainItem($dataItems[1],5);
  DataManager.loadMapData(5);
  await until(()=>DataManager.isMapLoaded());
  $gameMap.setup(5); $gamePlayer.locate(10,10); $gamePlayer.setDirection(2);
  SceneManager.goto(Scene_Map);
  await until(()=>{if(SceneManager._scene instanceof Scene_Map)$gameMessage.clear();return SceneManager._scene instanceof Scene_Map&&ImageManager.isReady();});
  SceneManager._scene.isBusy=function(){return false;}; $gameMessage.clear();
  Math.random=function(){return 0.5;};
  BattleManager.setup(4,true,false);
  SceneManager.push(Scene_Battle);
  await until(()=>SceneManager._scene instanceof Scene_Battle&&SceneManager._scene._actorCommandWindow&&SceneManager._scene._actorCommandWindow.active,60000);
  // 无头 Chrome 一次 rAF 会补跑好几次 updateScene，从外面等帧数不准；所有动作与截图都排进 updateScene 包装里，在指定帧当场做
  // 步骤排成队：每步「上一步之后第 k 帧」做，在包装里接着排下一步，所以帧数不受 await 延迟影响
  let n=0;const out={shots:{},nodes:{},info:{}};const queue=[];let due=0,fail=null,ended=null;
  const up=SceneManager.updateScene;SceneManager.updateScene=function(){n++;up.apply(this,arguments);
    while(queue.length&&n>=due){const st=queue[0];if(st.k>0&&n<due)break;queue.shift();try{st.fn();}catch(e){fail=e;queue.length=0;}
      if(queue.length){due=n+queue[0].k;if(queue[0].k>0)break;}else if(ended)ended();}};
  const at=(k,fn)=>{queue.push({k,fn});if(queue.length===1)due=n+k;};
  const run=()=>new Promise((ok,ng)=>{ended=()=>fail?ng(fail):ok();if(!queue.length)ok();}).then(()=>{if(fail)throw fail;});
  const s=SceneManager._scene, ss=s._spriteset;
  // 背景涂黑（背景是上一场景快照，Godot 那边是地图快照，不能比）
  [ss._backgroundSprite,ss._back1Sprite,ss._back2Sprite].forEach(x=>{if(x)x.visible=false;});
  // 显示树：看得见的节点（worldVisible、worldAlpha>0、有大小），全局矩形取 getBounds
  const tree=()=>{const rows=[];const walk=(o,p,d)=>{if(!o||!o.worldVisible||d>9)return;
      let r=null;try{const b=o.getBounds();r=[+b.x.toFixed(1),+b.y.toFixed(1),+b.width.toFixed(1),+b.height.toFixed(1)];}catch(e){}
      const name=(o.constructor&&o.constructor.name)||'?';
      const url=o.bitmap&&o.bitmap._url?o.bitmap._url.replace(/^.*\\/img\\//,''):'';
      if(r&&r[2]>0&&r[3]>0&&o.worldAlpha>0)rows.push({p,name,r,a:+o.worldAlpha.toFixed(3),url,
        f:o._frame?[o._frame.x,o._frame.y,o._frame.width,o._frame.height]:null,
        open:o.openness!==undefined?o.openness:null});
      (o.children||[]).forEach((c,i)=>walk(c,p+'/'+i,d+1));};
    walk(s,'',0);return rows;};
  const shot=name=>{__refShot(name);out.shots[name]=n;out.nodes[name]=tree();};
  const bmInfo=bm=>bm&&{font:bm.fontFace,size:bm.fontSize,color:bm.textColor,outline:[bm.outlineColor,bm.outlineWidth],w:bm.width,h:bm.height};
  const n0=n;
  at(60,()=>shot('bp_boss_input'));
  const boss=$gameTroop.members()[0], a1=$gameParty.members()[0], a2=$gameParty.members()[1];
  const bh=s._bosshp_sprites||ss._bosshp_sprites;
  at(0,()=>{out.info.boss={id:boss.enemyId(),hp:boss.hp,mhp:boss.mhp,name:boss.name(),number:bh&&bh._hp_data[6],red:bh&&bh._hp_data[2],flow:bh&&[bh._hp_meter_blueFlow[3],bh._hp_meter_redFlow[3]],nameBm:bh&&bmInfo(bh._name.bitmap)};});
  out.info.order=s.children.map(c=>c===ss?'spriteset':c===s._windowLayer?'windowLayer':(c.constructor&&c.constructor.name));
  out.info.spriteset=ss.children.map(c=>c===ss._baseSprite?'base':c===ss._pictureContainer?'pictures':c===ss._timerSprite?'timer':c===ss._flashSprite?'flash':c===ss._fadeSprite?'fade':(c.constructor&&c.constructor.name)+(c.bitmap&&c.bitmap._url?':'+c.bitmap._url.replace(/^.*\\/img\\//,''):''));
  // 字体：伤害数字字体族、是否真载入、38 号下三段文字的宽度
  const cx=document.createElement('canvas').getContext('2d');cx.font='38px '+(window.LGP&&LGP.Param.BDPfontFamily);
  out.info.font={lgp:window.LGP&&LGP.Param.BDPfontFamily,userLoaded:document.fonts.check('38px CodexUserUI'),
    widths:['1.23万','321','暴击  4567  ！','500万','【守层者】里德'].map(x=>[x,+cx.measureText(x).width.toFixed(2)])};
  // 状态：Boss 沉默（6）、第一位角色黑暗（5），回合数都定成 4；等过一轮 20 帧轮换和 1.4 秒（84 帧）的状态格轮换
  at(1,()=>{boss.addState(6); boss._stateTurns[6]=4; a1.addState(5); a1._stateTurns[5]=4; boss.refresh(); a1.refresh();});
  at(90,()=>shot('bp_states'));
  at(0,()=>{out.info.states={boss:boss.states().map(x=>x.id),a1:a1.states().map(x=>x.id),turns:[boss._stateTurns[6],a1._stateTurns[5]]};});
  // 选敌：普通攻击 → 敌人窗（Olivia 名字＋状态图标）
  const cw=s._actorCommandWindow;
  at(1,()=>{cw.selectSymbol('attack'); cw.processOk();});
  at(40,()=>{shot('bp_enemy_select');out.info.enemyWin={active:s._enemyWindow.active,index:s._enemyWindow.index()};
    const sp=bh&&ss._enemySprites&&ss._enemySprites[0]&&ss._enemySprites[0]._weaknessWindow&&ss._enemySprites[0]._weaknessWindow._stateIconSprite;
    out.info.enemyIcon=sp&&{icon:sp._iconIndex,ready:sp.bitmap&&sp.bitmap.isReady(),url:sp.bitmap&&sp.bitmap._url,frame:[sp._frame.x,sp._frame.y,sp._frame.width,sp._frame.height],tex:sp.texture&&sp.texture.frame&&[sp.texture.frame.x,sp.texture.frame.y,sp.texture.frame.width,sp.texture.frame.height],texValid:sp.texture&&sp.texture.valid,base:sp.texture&&sp.texture.baseTexture&&[sp.texture.baseTexture.width,sp.texture.baseTexture.height],op:sp.opacity,vis:sp.visible,alpha:sp.worldAlpha,blend:sp._blendColor,tone:sp._colorTone,cache:sp._iconindex2};});
  at(1,()=>{s._enemyWindow.processCancel?s._enemyWindow.processCancel():s.onEnemyCancel();});
  // 伤害数字：Boss 受 12345（→ 1.23万）、第一位角色受 321、第二位角色暴击 4567；在 k0 帧的场景更新之后请求
  const pop=(b,v,crit)=>{const r=b.result();r.clear();r.used=true;r.hpAffected=true;r.hpDamage=v;r.critical=!!crit;b.startDamagePopup();};
  let k0=0;
  at(30,()=>{pop(boss,12345,false); pop(a1,321,false); pop(a2,4567,true);k0=n;});
  out.info.popupTrack=[];
  const dmgs=()=>ss.children.filter(c=>c.constructor&&c.constructor.name==='Sprite_Damage');
  const trk=()=>out.info.popupTrack.push([n-k0].concat(dmgs().map(d=>{const c=d.children[0];return [d.x,d.y,c?[+c.x.toFixed(2),+c.y.toFixed(2),c.opacity,+c.scale.x.toFixed(2)]:null];})));
  for(let q=1;q<=48;q++){at(1,()=>{trk();if(q===6||q===20||q===40)shot('bp_popup_f'+q);
    if(q===6)out.info.popups=dmgs().map(d=>({x:d.x,y:d.y,kids:(d.children||[]).map(c=>({x:c.x,y:c.y,ax:c.anchor&&c.anchor.x,ay:c.anchor&&c.anchor.y,sc:[c.scale.x,c.scale.y],op:c.opacity,bm:bmInfo(c.bitmap)}))}));});}
  await run();
  out.n=n;out.errors=window.__refErrors||[];
  return out;
})()`;
async function connect() {
  for (let i = 0; i < 100; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${dbg}/json/list`)).json();
      const page = list.find(t => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (e) { /* 等 Chrome 起来 */ }
    await sleep(200);
  }
  throw new Error('Chrome 调试端口未就绪');
}

async function main() {
  const ws = new WebSocket(await connect());
  await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
  let id = 0; const wait = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); } };
  const send = (method, params = {}) => new Promise(ok => { const n = ++id; wait.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  await send('Page.enable');
  await send('Page.navigate', {url: 'http://127.0.0.1:8766/index.html'});
  await sleep(3000);
  const r = await send('Runtime.evaluate', {expression: PAGE, awaitPromise: true, returnByValue: true, timeout: 600000});
  if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
  fs.writeFileSync(outFile, JSON.stringify(r.result.result.value) + '\n');
  console.log('ok', outFile);
}

main().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  chrome.kill();
  setTimeout(() => { fs.rmSync(profile, {recursive: true, force: true}); process.exit(); }, 1000);
});
