'use strict';
// 定向参照：addParam 分层／小数、宠物加成与 TeamA 槽位刷新。真实冻结插件、全内存新局；仅 .sandbox 写入。
// 独立 tests/fixtures/actor_bonus_oracle.json，未接入全量同步，不改变 generated 参照。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const ids = [1, 8, 9, 10, 11], skills = [1365, 1475];
function fresh() {
  newGame();
  w.$gameParty._actors = w.Array.from([1,8,9,10]); w.$gameParty._battleMembers = w.Array.from([1,8,9,10,0]);
  w.$gameParty._saveactors = w.Array.from([11]); w.$gameParty.TeamATo = 0; w.$gameParty.GTWar = null;
  for (const id of ids) {
    const a = w.$gameActors.actor(id);
    a._equips.forEach(e=>e.setObject(null)); a._skills=new w.Array(); a._states=new w.Array();
    a._paramPlus=w.Array.from([0,0,0,0,0,0,0,0]); a.refresh(); a.recoverAll();
  }
}
function snap() {
  return ids.map(id=>{
    const a=w.$gameActors.actor(id);
    return {id, base:Array.from({length:8},(_,i)=>a.paramBase(i)), plus:Array.from({length:8},(_,i)=>a.paramPlus(i)),
      param:Array.from({length:8},(_,i)=>a.param(i)), traits:Array.from({length:10},(_,i)=>a.traitsSum(22,i)),
      xparam:Array.from({length:10},(_,i)=>a.xparam(i)), skills:skills.filter(s=>a.isLearnedSkill(s)), hp:a.hp,mp:a.mp};
  });
}
const cases=[];
cases.push(makeCase('permanent',{},()=>{
  fresh(); const a=w.$gameActors.actor(1); const rows=[snap()[0]];
  for(const [i,v] of [[0,10],[2,12.5],[2,-1.25],[0,-15]]) {a.addParam(i,v); rows.push(snap()[0]);}
  a.recoverAll(); rows.push(snap()[0]);
  const saved=host.encode(); host.restore(saved); rows.push(snap()[0]);
  return {rows};
}));
const pushes=[
  [100,20,3.5,4,5,6,7,8,0.11,0.12,0.13,0.14,0.15,0.16],
  [10,2,-1,0,0,0,0,0,0.21,0.22,0.23,0.24,0.25,0.26],
];
function pet(push) {
  const p=new w.Game_Enemy(1,0,0); p._paramPush=w.Array.from(push); p._skills=w.Array.from(skills.map(id=>w.$dataSkills[id]));
  return p;
}
function scene(index) {
  const s={_indexWindow:{index:()=>index,refresh:()=>{}},onCancel:()=>{}};
  w.SceneManager._scene=s; return s;
}
cases.push(makeCase('pet.lifecycle',{pushes,skills},()=>{
  fresh(); w.$gameParty.Pets=pushes.map(pet); const rows=[];
  const record=name=>rows.push({name,actors:snap()}); record('before');
  w.Scene_PetSystem.prototype.onGotowarOk.call(scene(0)); record('war');
  // 填满上限后原版 refreshGTWar 的临时撤回会截掉宠物额外生命。
  ids.forEach(id=>w.$gameActors.actor(id).recoverAll()); record('full');
  w.Star.PetSystem.refreshGTWar(); record('refresh');
  w.Star.PetSystem.TeamALearn();
  [w.$gameParty._battleMembers[0],w.$gameParty._battleMembers[1]]=[w.$gameParty._battleMembers[1],w.$gameParty._battleMembers[0]];
  w.$gameParty.rearrangeActors(); w.Star.PetSystem.TeamAForget(); record('swap');
  w.$gameParty.TeamATo=1; w.Star.PetSystem.refreshGTWar(); record('team');
  // 目标槽清空、重建五个出战槽；同槽重排仍需把被忘掉的共享技能重学回来。
  w.Star.PetSystem.TeamALearn(); w.$gameParty._battleMembers[1]=0;
  w.$gameParty.rearrangeActors(); w.Star.PetSystem.TeamAForget(); record('empty');
  w.$gameParty.initializeBattleMembers(); record('initialize');
  const target=w.$gameActors.actor(w.$gameParty._battleMembers[1]); target.forgetSkill(1475);
  w.Star.PetSystem.TeamALearn(); w.$gameParty.rearrangeActors(); w.Star.PetSystem.TeamAForget(); record('relearn');
  w.Scene_PetSystem.prototype.onGotowarOk.call(scene(1)); record('switch');
  w.Scene_PetSystem.prototype.onRestOk.call(scene(1)); record('rest');
  return {rows};
}));
cases.push(makeCase('pet.membership',{push:pushes[0], scope:'current party / warehouse plus newly recruited actor 9'},()=>{
  fresh(); w.$gameParty._actors=w.Array.from([1,8]); w.$gameParty._battleMembers=w.Array.from([1,8,0,0,0]);
  w.$gameParty.Pets=[pet(pushes[0])]; const rows=[];
  const record=name=>rows.push({name,actors:snap().filter(a=>a.id!==10)});
  w.Scene_PetSystem.prototype.onGotowarOk.call(scene(0)); record('war');
  w.$gameParty.addActor(9); record('add');
  w.Scene_PetSystem.prototype.onRestOk.call(scene(0)); record('rest');
  return {rows};
}));
cases.push(makeCase('pet.permanent',{push:pushes[0]},()=>{
  fresh();const a=w.$gameActors.actor(1);w.$gameParty.Pets=[pet(pushes[0])];const rows=[];
  a.addParam(2,12.5);rows.push(snap()[0]);
  w.Scene_PetSystem.prototype.onGotowarOk.call(scene(0)); rows.push(snap()[0]);
  a.addParam(2,1.25); rows.push(snap()[0]);
  w.Star.PetSystem.refreshGTWar(); rows.push(snap()[0]);
  w.Scene_PetSystem.prototype.onRestOk.call(scene(0)); rows.push(snap()[0]);
  return {rows};
}));
cases.push(makeCase('pet.mapping',{},()=>{
  fresh();const a=w.$gameActors.actor(1), enemy=new w.Game_Enemy(1,0,0);
  const before=snap()[0], e0=Array.from({length:10},(_,i)=>enemy.traitsSum(22,i));
  w.$gameParty.GTWar=pet(pushes[0]);
  // GTWar 直接赋值不标脏，不能读上一帧的 xparam 缓存当新加成。用原生学/忘/refresh 完成同出战的刷新。
  a.learnSkill(1365); a.forgetSkill(1365); a.refresh();
  return {before,after:snap()[0],enemyDelta:e0.map((v,i)=>enemy.traitsSum(22,i)-v)};
}));
process.exit(finish(host,'actor_bonus.json',{scope:'Frozen addParam / Star_PetSystem runtime; no real saves',cases})?0:1);
