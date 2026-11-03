'use strict';
// 所有新局、JsonEx往返与事件执行都只在内存。正式逻辑由受守卫保护的hboot载入。
const fs = require('fs'), path = require('path');
const {boot} = require('../hboot.cjs');
const {sourceIdentity} = require('../source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const round = v => { if(typeof v==='number'&&!Number.isFinite(v))throw new Error('非有限测量数值');return typeof v==='number'?+v.toFixed(6):v; };
function start() {
  const identity = sourceIdentity(APP), r = boot(APP, {tolerant:true, log:false}), w = r.window;
  if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败: '+JSON.stringify(r.errors));
  w.Star.Achievement.Manager.init();
  // 原版插件报错时常 SceneManager.terminate（正式游戏直接退出）；参照引擎里退出后，后面的用例常只报 location 未定义、看不出原因。
  // 这里先记一笔（host.terminated，finish 时在 stderr 打出是哪个用例、哪一步），再照原样调原来的 terminate，不改任何探针的产物。
  // 要照「报错被吞」继续跑的探针自己再覆盖（如 alien_affix_probe 记次数）
  const terminated = [], terminate = w.SceneManager.terminate;
  w.SceneManager.terminate = function () { terminated.push({caseId: current.id, stack: String(new Error('SceneManager.terminate').stack).slice(0, 800)}); return terminate.apply(this, arguments); };
  const newGame = () => {
    w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};Graphics.frameCount=0;for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
    w.Input.clear();
    w.DataManager.loadMapData(4); w.$gameMap.setup(4); w.$gamePlayer.clearTransferInfo();
    w.eval('$gameParty._actors=[];[1,8,9,10].forEach(function(id){$gameParty.addActor(id);});');
  };
  const restore = json => { w.DataManager.createGameObjects(); w.DataManager.extractSaveContents(w.JsonEx.parse(json)); };
  return {w, identity, newGame, restore, terminated, encode:() => w.JsonEx.stringify(w.DataManager.makeSaveContents())};
}
const current = {id: null};  // 正在测的用例（terminate 记录用）
function makeCase(id, setup, measure) {
  current.id = id;
  try { return {id, setup, observed:measure(), errors:[]}; }
  catch(e) { return {id, setup, observed:null, errors:[String(e && e.stack || e).slice(0,1500)]}; }
}
function finish(host, name, data) {
  if (JSON.stringify(host.identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
  const out = {schemaVersion:1, sourceIdentity:host.identity, ...data};
  fs.mkdirSync(path.resolve(__dirname,'../.sandbox'), {recursive:true});
  fs.writeFileSync(path.resolve(__dirname,'../.sandbox',name), JSON.stringify(out,null,1)+'\n');
  const bad = out.cases.filter(c=>c.errors.length);
  (host.terminated || []).forEach(t => console.error('⚠ SceneManager.terminate 在用例 ' + t.caseId + ' 被调用（原版这里退出游戏）\n' + t.stack));
  console.log(JSON.stringify({file:name,cases:out.cases.length,errors:bad.map(c=>({id:c.id,errors:c.errors}))}));
  return bad.length === 0;
}
// 「超强者参照」公用开关（O-050：用户 10-12 定不移植五乘区与超强者路线压制）。
// 去掉 route-suppress、zones-correction 两个伤害钩子，并关掉路线压制的三处：otherScale（其余倍率）、isSuper（锁定／和鸣／护阵往 1 收）、
// support（共宿伤害率 ×路线支援），让参照的伤害对得上重制。返回的 enableSuperSwitch() 开 2494（超强者可出战），newGame 会重置开关，所以每次新局后自己调。
// xuan_* 探针仍各自手写，等悟空 xuan 期做完再迁。
function superReference(w) {
  const hooks = w.CodexDamageHooks || [];
  for (const name of ['route-suppress', 'zones-correction']) {
    const i = hooks.findIndex(h => h.name === name);
    if (i < 0) throw new Error('伤害钩子 ' + name + ' 不在');
    hooks.splice(i, 1);
  }
  const R = w.CodexRouteSuppress;
  if (!R || typeof R.otherScale !== 'function') throw new Error('路线压制模块不在');
  R.otherScale = () => 1;
  R.isSuper = () => false;
  R.support = () => 1;
  return {enableSuperSwitch: () => w.$gameSwitches.setValue(2494, true)};
}
module.exports = {APP, start, makeCase, finish, round, superReference};
