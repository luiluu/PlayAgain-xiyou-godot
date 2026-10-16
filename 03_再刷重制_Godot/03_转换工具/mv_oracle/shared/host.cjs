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
  const newGame = () => {
    w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};Graphics.frameCount=0;for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
    w.Input.clear();
    w.DataManager.loadMapData(4); w.$gameMap.setup(4); w.$gamePlayer.clearTransferInfo();
    w.eval('$gameParty._actors=[];[1,8,9,10].forEach(function(id){$gameParty.addActor(id);});');
  };
  const restore = json => { w.DataManager.createGameObjects(); w.DataManager.extractSaveContents(w.JsonEx.parse(json)); };
  return {w, identity, newGame, restore, encode:() => w.JsonEx.stringify(w.DataManager.makeSaveContents())};
}
function makeCase(id, setup, measure) {
  try { return {id, setup, observed:measure(), errors:[]}; }
  catch(e) { return {id, setup, observed:null, errors:[String(e && e.stack || e).slice(0,1500)]}; }
}
function finish(host, name, data) {
  if (JSON.stringify(host.identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
  const out = {schemaVersion:1, sourceIdentity:host.identity, ...data};
  fs.mkdirSync(path.resolve(__dirname,'../.sandbox'), {recursive:true});
  fs.writeFileSync(path.resolve(__dirname,'../.sandbox',name), JSON.stringify(out,null,1)+'\n');
  const bad = out.cases.filter(c=>c.errors.length);
  console.log(JSON.stringify({file:name,cases:out.cases.length,errors:bad.map(c=>({id:c.id,errors:c.errors}))}));
  return bad.length === 0;
}
module.exports = {APP, start, makeCase, finish, round};
