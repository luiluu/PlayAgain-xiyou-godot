'use strict';
// 正式整队模型/窗口只在内存运行，不加载配置或玩家存档；证据只写 .sandbox/party.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant:true, log:false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Graphics.boxWidth=1280;Graphics.boxHeight=720;');
const sounds = [];
for (const [name, id] of Object.entries({playCursor:0, playOk:1, playCancel:2, playBuzzer:3, playEquip:4}))
  w.SoundManager[name] = () => sounds.push(id);
for (const id of [1,8,9,10,2,3,4]) w.$gameParty.addActor(id);
const scene = new w.Scene_Party(); w.SceneManager._scene = scene; scene.create(); scene.start(); scene.update();
const windows = {command:scene._commandWindow, slots:scene._partyWindow, list:scene._listWindow};
const out = {sourceIdentity:identity, keys:{}, layout:{}, trace:[], eligibility:[]};
out.characters = w.$gameParty.allMembers().map(a=>({id:a.actorId(),name:a.characterName(),index:a.characterIndex()}));
for (const [name, key] of Object.entries({Q:81,W:87,E:69,PageUp:33,PageDown:34})) out.keys[name] = w.Input.keyMapper[key];
for (const [name, win] of Object.entries(windows)) out.layout[name] = {rect:[win.x,win.y,win.width,win.height],padding:win.padding,opacity:win.opacity,lineHeight:win.lineHeight(),maxPageItems:win.maxPageItems()};
function snap(name) {
  out.trace.push({name,slots:Array.from(w.$gameParty._battleMembers),party:Array.from(w.$gameParty._actors),battle:w.$gameParty.battleMembers().map(a=>a.actorId()),leader:w.$gameParty.leader()?.actorId() || 0,sounds:sounds.splice(0)});
}
function run(name, fn) { sounds.length = 0; fn(); snap(name); }
snap('initial');
run('reserve_into_slot', () => {scene._partyWindow.select(0);scene._listWindow.select(scene._listWindow._data.indexOf(3));scene.onListOk();});
run('swap_existing', () => {scene._partyWindow.select(1);scene._listWindow.select(scene._listWindow._data.indexOf(10));scene.onListOk();});
run('remove_row', () => {scene._listWindow.select(0);scene.onListOk();});
run('page_wrap', () => {scene._partyWindow.select(0);scene._partyWindow.processPageup();});
run('remove_command', () => {scene._commandWindow.select(1);scene._partyWindow.select(2);scene.onPartyOk();});
run('revert', () => scene.commandRevert());
run('add_full', () => w.$gameParty.addActor(5));
run('remove_actor', () => w.$gameParty.removeActor(8));
run('fill_empty', () => w.$gameParty.addActor(8));
run('add_existing_reserve_to_empty', () => {w.$gameParty._battleMembers[0]=0;w.$gameParty.rearrangeActors();w.$gameParty.addActor(3);});
function eligible(name, slots, killAll, reviveReserve) {
  w.$gameParty._battleMembers = w.JSON.parse(JSON.stringify(slots));w.$gameParty.rearrangeActors();
  for (const a of w.$gameParty.allMembers()) {if(killAll)a.setHp(0);else a.recoverAll();}
  if(reviveReserve)w.$gameActors.actor(4).recoverAll();
  scene._commandWindow.refresh();
  out.eligibility.push({name,enabled:scene._commandWindow.isCancelEnabled(),cancelRow:scene._commandWindow._list.find(c=>c.symbol==='cancel').enabled});
}
eligible('empty', [0,0,0,0,0], false, false);
eligible('dead_all', [1,8,9,10,2], true, false);
eligible('dead_front_alive_reserve', [1,8,9,10,2], true, true);
eligible('one_member', [0,0,9,0,0], false, false);
out.listData = Array.from(scene._listWindow._data);
// Scene_Skill 的目标窗口沿用 Window_MenuActor：四行可见，但第五位与后备都能滚动选中。
const menuActor=new w.Window_MenuActor();menuActor.select(0);
for(let i=0;i<4;i++)menuActor.cursorDown(false);
out.menuActor={index:menuActor.index(),topRow:menuActor.topRow(),maxPageRows:menuActor.maxPageRows(),rect:[menuActor.x,menuActor.y,menuActor.width,menuActor.height]};
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname,'.sandbox/party.json'), JSON.stringify(out,null,2));
console.log(JSON.stringify({version:identity.releaseVersion,trace:out.trace.length,eligibility:out.eligibility,keys:out.keys}));
process.exit(0);
