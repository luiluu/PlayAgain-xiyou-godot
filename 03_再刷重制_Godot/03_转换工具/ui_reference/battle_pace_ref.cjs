'use strict';
// 战斗节奏逐帧（rules-pace1）：无头 Chrome 打开 serve.py 的只读服务（127.0.0.1:8766，冻结正式源），战斗夹具 4 人、敌群 2，
// 角色指令窗一出就普通攻击敌人 1（同 battle_pace_oracle）。记每次 makeActionOrders 前后各人的 agi／speed／行动、
// startAction／endAction 的 updateScene 帧、行动序列逐条（帧、行动者、指令名）、对战斗者放的动画；frames／calls（ui-pace2）
// 逐帧记 BattleManager 阶段、日志窗等待与方法队列、各种 isBusy，以及本帧调到的 BattleManager 方法。只建内存新局，不读写存档。
// 用法：python3 -I serve.py <app.nw> <输出目录> &  然后  node battle_pace_ref.cjs <输出.json>
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const outFile = path.resolve(process.argv[2] || 'battle_pace_ref.json');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-pace-'));
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
  const btn=t=>[...document.querySelectorAll('button')].find(b=>b.textContent===t);
  btn('战斗夹具 4 人').click();
  await until(()=>SceneManager._scene instanceof Scene_Battle,60000);
  ConfigManager.battleAniSpeed=4;ConfigManager.CombatSkillAnimation=false;
  let n=0;const tag=b=>!b?null:b.isActor()?'a'+b.actorId():'e'+b.index();
  const out={orders:[],log:[],seq:[],anims:[]};
  const up=SceneManager.updateScene;
  SceneManager.updateScene=function(){n++;const s=SceneManager._scene;
    if(s instanceof Scene_Battle&&s._actorCommandWindow&&s._actorCommandWindow.active){const e=$gameTroop.members()[1];out.log.push([n,'input',tag(BattleManager.actor())]);s._actorCommandWindow.deactivate();s.commandAttack();s._enemyWindow.select(1);s._enemyWindow.deactivate();s.onEnemyOk();}
    up.apply(this,arguments);};
  const all=()=>$gameParty.members().concat($gameTroop.members());
  const snap=()=>all().map(b=>[tag(b),b.agi,b._speed,b._actions.length,b._actions.map(a=>a.item()&&a.item().id)]);
  const mo=BattleManager.makeActionOrders;
  BattleManager.makeActionOrders=function(){const before=snap();const r=mo.apply(this,arguments);out.orders.push({n,before,after:snap(),cur:(this._actionBattlers||[]).map(tag),next:(this._nextTurnActionBattlers||[]).map(tag)});return r;};
  const sa=BattleManager.startAction,ea=BattleManager.endAction;
  BattleManager.startAction=function(){out.log.push([n,'start',tag(this._subject),this._subject.currentAction()&&this._subject.currentAction().item()&&this._subject.currentAction().item().id]);return sa.apply(this,arguments);};
  BattleManager.endAction=function(){out.log.push([n,'end',tag(this._subject)]);return ea.apply(this,arguments);};
  const pas=BattleManager.processActionSequence;
  BattleManager.processActionSequence=function(name,args){out.seq.push([n,tag(this._subject),name,(args||[]).join(',').slice(0,60)]);return pas.apply(this,arguments);};
  const sanim=Game_Battler.prototype.startAnimation;
  Game_Battler.prototype.startAnimation=function(id,m,d){out.anims.push([n,tag(BattleManager._subject),tag(this),id]);return sanim.apply(this,arguments);};
  // 逐帧状态（ui-pace2）：BattleManager 阶段、是否忙、谁让它忙（日志窗等待／方法队列、精灵组、消息），以及本帧调到的 BattleManager 方法
  out.frames=[];out.calls=[];
  ['startTurn','endTurn','updateTurnEnd','updateTurn','processTurn','getNextSubject','updateEvent','startInput','updateAction','makeActionOrders','isBusy'].forEach(k=>{
    const f=BattleManager[k];if(typeof f!=='function')return;
    BattleManager[k]=function(){const r=f.apply(this,arguments);if(k!=='isBusy'||r)out.calls.push([n,k,k==='getNextSubject'?tag(r):(k==='isBusy'?1:null)]);return r;};});
  const up2=SceneManager.updateScene;
  SceneManager.updateScene=function(){up2.apply(this,arguments);const s=SceneManager._scene;if(!(s instanceof Scene_Battle))return;
    const lw=s._logWindow,ss=s._spriteset;
    out.frames.push([n,BattleManager._phase,lw._waitMode,lw._waitCount,lw._methods.map(m=>m.name).join('/'),lw.isBusy()?1:0,ss.isBusy()?1:0,$gameMessage.isBusy()?1:0,
      ss.isAnimationPlaying()?1:0,ss.isAnyoneMoving()?1:0,ss.isEffecting?(ss.isEffecting()?1:0):-1,tag(BattleManager._subject),$gameTroop.isEventRunning()?1:0,s._statusWindow&&s._statusWindow.isClosing&&s._statusWindow.isClosing()?1:0]);};
  for(const e of $gameTroop.members()){e._paramPlus[0]+=1000000;e.need_refresh=true;e.refresh();e.recoverAll();}
  await until(()=>out.log.filter(r=>r[1]==='end').length>=21||n>4000,600000);
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
  await send('Page.navigate', {url: 'http://127.0.0.1:8766/index.html?battle_ref=1'});
  await sleep(3000);
  const runs = [];
  const r = await send('Runtime.evaluate', {expression: PAGE, awaitPromise: true, returnByValue: true, timeout: 600000});
  if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
  runs.push(r.result.result.value);
  fs.writeFileSync(outFile, JSON.stringify(runs[0]) + '\n');
  console.log('ok', outFile);
}

main().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  chrome.kill();
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 1000);
});
