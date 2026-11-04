'use strict';
// dsPassiveSkill SvPngFd（角色战斗立绘放大）参照（bailong-visual1）：census＝全库谁带 SvPngFd；
// scale＝穿上/脱下/加状态后 _passiveCache.SvPngFd 与 Sprite_Actor._mainSprite.scale 的读数（含"脱下后是否还原"）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
function battle() {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame(); w.eval('$gameParty._actors=[];'); w.$gameParty.addActor(1);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.BattleManager.setup(2, true, true);
  return w.$gameActors.actor(1);
}
function spriteFor(a) {
  const p0 = new w.Sprite(), p1 = new w.Sprite(), sp = new w.Sprite_Actor(a);
  p0.addChild(p1); p1.addChild(sp);
  for (let i = 0; i < 3; i++) sp.update();
  return sp;
}
const cases = [];
cases.push(makeCase('census', {}, () => {
  newGame();
  const out = {};
  for (const [name, table] of [['skills', w.$dataSkills], ['items', w.$dataItems], ['weapons', w.$dataWeapons], ['armors', w.$dataArmors], ['states', w.$dataStates], ['actors', w.$dataActors], ['classes', w.$dataClasses], ['enemies', w.$dataEnemies]]) {
    out[name] = table.filter(o => o && o.meta && o.meta.SvPngFd !== undefined).map(o => ({id: o.id, name: o.name, value: o.meta.SvPngFd, etype: o.etypeId, atype: o.atypeId}));
  }
  return out;
}));
// Scene_Battle.start 的顺序：initPassiveCache → （开战状态）→ refreshPassiveCache；之后 SvPngFd 一直是这个读数，战斗中换装／加状态不再刷新
function begin(a) { a.initPassiveCache(); a.refreshPassiveCache(); }
function scaleOf(a) { const sp = spriteFor(a); return {cache: a._passiveCache.SvPngFd, mainScale: [sp._mainSprite.scale.x, sp._mainSprite.scale.y]}; }
function wear(a, arm) { const slot = a.equipSlots().indexOf(arm.etypeId); a._equips[slot].setObject(arm); return a.equips().some(e => e && e.id === arm.id && e.atypeId !== undefined); }
cases.push(makeCase('scale', {}, () => {
  const out = {};
  out.base = (() => { const a = battle(); begin(a); return scaleOf(a); })();
  out.armors = w.$dataArmors.filter(o => o && o.meta && o.meta.SvPngFd !== undefined).map(arm => {
    const a = battle(); const equipped = wear(a, arm); begin(a);
    return Object.assign({id: arm.id, value: arm.meta.SvPngFd, etypeId: arm.etypeId, equipped}, scaleOf(a));
  });
  const st = w.$dataStates.find(s => s && s.meta && s.meta.SvPngFd !== undefined);
  const a1 = battle(); a1.addState(st.id); a1.refresh(); begin(a1);
  out.state = Object.assign({id: st.id, value: st.meta.SvPngFd, has: a1.isStateAffected(st.id)}, scaleOf(a1));
  // 开战后再脱下／加上：不刷新
  const a2 = battle(); const arm = w.$dataArmors[5203]; wear(a2, arm); begin(a2);
  const before = scaleOf(a2); a2._equips[a2.equipSlots().indexOf(arm.etypeId)].setObject(null); // no refresh
  out.unequipMidBattle = {before: before.cache, after: scaleOf(a2).cache};
  const a3 = battle(); begin(a3); a3.addState(st.id); a3.refresh();
  out.stateMidBattle = {has: a3.isStateAffected(st.id), cache: scaleOf(a3).cache};
  // 同时多件：后面的装备槽（equips 顺序）覆盖，不取最大
  const a4 = battle(); const ring = w.$dataArmors[4279], big = w.$dataArmors[5200];
  const w1 = wear(a4, ring), w2 = wear(a4, big); begin(a4);
  out.combo = {order: a4.equips().filter(Boolean).map(e => e.id), worn: [w1, w2], cache: scaleOf(a4).cache};
  const a5 = battle(); const w3 = wear(a5, w.$dataArmors[5203]), w4 = wear(a5, w.$dataArmors[2937]); begin(a5);
  out.combo2 = {order: a5.equips().filter(Boolean).map(e => e.id), worn: [w3, w4], cache: scaleOf(a5).cache};
  return out;
}));
process.exit(finish(host, 'svpng.json', {scope: 'dsPassiveSkill SvPngFd actor sprite scale on frozen source', cases}) ? 0 : 1);
