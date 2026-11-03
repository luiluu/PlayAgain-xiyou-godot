'use strict';
// 【cc·八戒·未经审查】成长装备期二b：魔冠「"头顶"」7940（installNativeDemonCrownRuntime，冻结 v0.28 main.js 第 151 行装载）。
// ① D.next／D.display；② 得到（gainItem 数据库那件→账本发实例：名字、说明、图标、品质、成长行、八项 code21 特性）；
// ③ 战斗：穿着且活着、仍在出战、没换过装备的胜利 +(1−b/1000)，失败／逃跑不涨，每场一次（遭遇序号），死亡（战斗中按人按次、战斗外按世界序号）减半；
// ④ 掉落：Map162、敌群 539～542、不朽的未知战斗（来源 57／59），开战掷 Math.random，胜利且 <3% 发一件；
// ⑤ 账本防回滚：读早先的档，成长、掉落、移除照账本重放；同一遭遇序号重打不重掷，换了敌群不算；失去（卖出）记移除；旧档没编号的收编。
// 账本文件落在参照沙盒的存档目录（hboot 把 localFileDirectoryPath 指到 __sandboxSave）。
// 产物 .sandbox/demon_crown.json，拷成 tests/fixtures/demon_crown_oracle.json（不进同步），专项 xiyou_demon_crown。
const fs = require('fs'), path = require('path');
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const D = w.CodexDemonCrown;
if (!D || !D.grant || !D.replay) throw new Error('魔冠模块未安装');
const LEDGER = () => path.join(w.StorageManager.localFileDirectoryPath(), 'crown_progress_v1.json');
const toasts = [];
if (!w.$) w.$ = {};
w.$.toaster = o => toasts.push(o && o.message);
const stub = new Proxy({}, {get: () => () => {}});
const PARTY = [1, 8, 9, 10];
const fresh = () => {
  try { fs.unlinkSync(LEDGER()); } catch (e) { /* 没有就算了 */ }
  newGame(); toasts.length = 0;
  w.eval('$gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  for (const id of PARTY) { const a = w.$gameActors.actor(id); a._level = 60; a.refresh(); a.recoverAll(); }
};
const crowns = () => {
  const out = w.$gameParty.armors().filter(D.isGear);
  for (const id of PARTY) out.push(...w.$gameActors.actor(id).equips().filter(D.isGear));
  return out;
};
const grant = () => { w.$gameParty.gainItem(w.$dataArmors[7940], 1, false); const l = w.$gameParty.armors().filter(D.isGear); return l[l.length - 1]; };
const equip = (a, it) => { a.changeEquip(a.equipSlots().indexOf(it.etypeId), it); a.need_refresh = true; a.refresh(); };
const wearing = a => { const g = D.gear(a); return g ? round(D.bonus(g)) : null; };
const ledger = () => { const p = D.record(); if (!p) return null;
  return {items: Object.keys(p.items).map(k => [round(p.items[k].bonus), p.items[k].removed]),
    battles: Object.keys(p.battles).sort().map(k => { const r = p.battles[k]; return [k, r.troop, r.map, r.eligible, r.roll == null ? null : round(r.roll), r.wears.length, Object.keys(r.deaths).length, r.settled, r.result == null ? null : r.result, !!r.dropUid]; }),
    worldDeaths: Object.keys(p.worldDeaths).length}; };
const pos = note => (String(note).match(/<pos=APs text=成长[^>]*?size=/g) || []);
const snap = it => ({name: it.name, baseName: it.baseItemName, description: it.description, icon: it.iconIndex, quality: it.meta.quality, ici: it.meta.ici,
  uid: !!it._codexCrownUid, bonus: round(D.bonus(it)), pos: pos(it.note), crown: it.traits.filter(t => t._codexCrown).map(t => [t.code, t.dataId, round(t.value)])});
function battle(troop, roll, map, origin) {
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  if (map) w.$gameMap._mapId = map;
  if (origin !== undefined) w.$gameMap._yunUnknownOrigin = origin;
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(troop, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  w.Math.random = () => roll == null ? 0.5 : roll;
  bm.startBattle();
  w.Math.random = () => 0.5;
  return bm;
}
const fight = (result, opts) => { const o = opts || {}, bm = battle(o.troop || 3, o.roll, o.map, o.origin); if (o.during) o.during(bm); bm.endBattle(result); return bm; };
const seq = () => w.$gameSystem._codexCrownEncounterSeq;
const cases = [];

// ① 公式
cases.push(makeCase('next', {}, () => {
  const chain = []; let b = 0;
  for (let i = 0; i < 5; i++) { b = D.next(b); chain.push(round(b)); }
  return {chain, at: [0, 1, 499.5, 999, 999.9, 1000, 1200, -5].map(v => round(D.next(v))), display: [0, 0.4, 0.5, 1.49, 2.5, 99.99].map(v => D.display(v))};
}));

// ② 得到
cases.push(makeCase('grant', {}, () => {
  fresh();
  const it = grant(), two = (w.$gameParty.gainItem(w.$dataArmors[7940], 2, false), crowns().length);
  const a = w.$gameActors.actor(1), before = [0, 2, 3, 4].map(i => a.param(i));
  equip(a, it);
  return {item: snap(it), count: two, ledger: ledger(), seq: seq(), params: [before, [0, 2, 3, 4].map(i => a.param(i))], toasts: toasts.slice()};
}));

// 说明行（growth3）：RJO.HE.getDescParams 包装，describe 后带小数的数字按 D.display 取整
cases.push(makeCase('help', {bonus: 12.3456}, () => {
  fresh();
  const it = grant();
  it._codexCrownBonus = 12.3456;
  D.describe(it);
  const v = w.JsonEx.makeDeepCopy(it);
  delete v.descParams;
  w.RJO.HE.getDescParams(v, 2);
  return {note: it.note, rows: v.descParams.map(r => String(r[0]))};
}));

// ③ 战斗成长
cases.push(makeCase('battle.win', {}, () => {
  fresh();
  const a = w.$gameActors.actor(1), it = grant(); equip(a, it);
  const rows = [];
  for (const r of [0, 0, 0, 1, 2, 0]) { fight(r); rows.push([r, wearing(a), seq()]); }
  return {rows, ledger: ledger(), item: snap(D.gear(a)), atk: a.param(2), toasts: toasts.slice()};
}));
cases.push(makeCase('battle.bigbonus', {}, () => {
  fresh();
  const a = w.$gameActors.actor(1), it = grant(); equip(a, it);
  const before = [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
  const f = LEDGER(), l = JSON.parse(fs.readFileSync(f, 'utf8'));
  for (const p of Object.values(l.profiles)) for (const r of Object.values(p.items)) r.bonus = 999.4;
  fs.writeFileSync(f, JSON.stringify(l));
  D.replay();  // 内存里的账本没变：replay 照旧
  const same = [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
  return {before, same, item: snap(D.gear(a))};
}));
cases.push(makeCase('battle.death', {}, () => {
  fresh();
  const a = w.$gameActors.actor(1), it = grant(); equip(a, it);
  for (let i = 0; i < 4; i++) fight(0);
  const rows = [['won4', wearing(a)]];
  fight(0, {during: () => { a.addState(1); rows.push(['died', wearing(a)]); a.addState(1); rows.push(['again', wearing(a)]); }});
  rows.push(['deadwin', wearing(a), a.isDead()]);
  a.removeState(1); a.setHp(1); a.clearResult();
  fight(0, {during: () => { a.addState(1); rows.push(['died2', wearing(a)]); a.removeState(1); a.setHp(1); a.clearResult(); a.addState(1); rows.push(['died3', wearing(a)]); a.removeState(1); a.setHp(1); a.clearResult(); }});
  rows.push(['revivedwin', wearing(a)]);
  a.addState(1); rows.push(['world', wearing(a)]);
  a.removeState(1); a.setHp(1); a.clearResult(); a.addState(1); rows.push(['world2', wearing(a)]);
  const other = w.$gameActors.actor(8); other.addState(1);
  rows.push(['otherdied', wearing(a)]);
  return {rows, ledger: ledger(), worldSeq: w.$gameSystem._codexCrownWorldDeathSeq};
}));
cases.push(makeCase('battle.swap', {}, () => {
  fresh();
  const a = w.$gameActors.actor(1), it = grant(); equip(a, it);
  const slot = a.equipSlots().indexOf(it.etypeId), rows = [];
  fight(0, {during: () => { a.changeEquip(slot, null); a.changeEquip(slot, it); }});
  rows.push(['swapback', wearing(a)]);
  fight(0); rows.push(['plain', wearing(a)]);
  fight(0, {during: () => { a.changeEquip(slot, null); }}); rows.push(['off', wearing(a), round(D.bonus(it))]);
  const b = w.$gameActors.actor(8); equip(b, it);
  w.eval('$gameParty._battleMembers=[1,9,10,0];');
  fight(0); rows.push(['reserve', round(D.bonus(it))]);
  w.eval('$gameParty._battleMembers=[1,8,9,10];');
  fight(0); rows.push(['member', round(D.bonus(it))]);
  return {rows, ledger: ledger()};
}));

// ④ 掉落
const DROP = [['drop', 539, 0.02, 162, 57, 0], ['edge', 542, 0.03, 162, 59, 0], ['under', 540, 0.0299, 162, 59, 0], ['origin', 539, 0.01, 162, 38, 0],
  ['troop', 543, 0.01, 162, 57, 0], ['map', 539, 0.01, 4, 57, 0], ['lose', 541, 0.01, 162, 57, 1], ['escape', 541, 0.01, 162, 57, 2]];
for (const [tag, troop, roll, map, origin, result] of DROP) cases.push(makeCase(`drop.${tag}`, {troop, roll, map, origin, result}, () => {
  fresh();
  fight(result, {troop, roll, map, origin});
  return {count: crowns().length, item: crowns().length ? snap(crowns()[0]) : null, ledger: ledger(), seq: seq(), toasts: toasts.slice()};
}));
cases.push(makeCase('drop.legacy107', {}, () => {
  fresh();
  w.$gameVariables.setValue(107, 2);
  fight(0, {troop: 539, roll: 0.01, map: 162, origin: null});
  return {count: crowns().length, ledger: ledger()};
}));

// ⑤ 账本防回滚
cases.push(makeCase('scum', {}, () => {
  fresh();
  const a = w.$gameActors.actor(1), it = grant(); equip(a, it);
  const save0 = host.encode(), rows = [];
  fight(0); fight(0); rows.push(['won2', wearing(a), seq()]);
  host.restore(save0);
  const a2 = w.$gameActors.actor(1);
  rows.push(['reloaded', wearing(a2), seq(), crowns().length]);
  fight(0); rows.push(['refight', wearing(a2), seq()]);
  const save1 = host.encode();
  fight(0, {troop: 539, roll: 0.01, map: 162, origin: 57}); rows.push(['drop', crowns().length, wearing(a2)]);
  host.restore(save1);
  rows.push(['reloaded2', crowns().length, seq()]);
  fight(0, {troop: 539, roll: 0.9, map: 162, origin: 57}); rows.push(['samekey', crowns().length, wearing(w.$gameActors.actor(1)), seq()]);
  host.restore(save1);
  fight(0, {troop: 3, roll: 0.9}); rows.push(['otherkey', crowns().length, wearing(w.$gameActors.actor(1)), seq()]);
  return {rows, ledger: ledger(), toasts: toasts.slice()};
}));
cases.push(makeCase('lose', {}, () => {
  fresh();
  const it = grant(), save0 = host.encode(), rows = [];
  w.$gameParty.loseItem(it, 1, false);
  rows.push(['sold', crowns().length, ledger().items]);
  host.restore(save0);
  rows.push(['reloaded', crowns().length]);
  const it2 = grant(), a = w.$gameActors.actor(1); equip(a, it2);
  rows.push(['equipped', crowns().length, ledger().items]);
  a.changeEquip(a.equipSlots().indexOf(it2.etypeId), null);
  rows.push(['unequipped', crowns().length, ledger().items]);
  w.$gameParty.loseItem(w.$dataArmors[7940], 1, false);
  rows.push(['bybase', crowns().length, ledger().items]);
  host.restore(host.encode());
  rows.push(['bybase.reload', crowns().length]);
  return {rows};
}));
cases.push(makeCase('adopt', {}, () => {
  fresh();
  const it = grant(), uid = it._codexCrownUid;
  const save = JSON.parse(host.encode().replace(new RegExp('"_codexCrownUid":"' + uid + '",?', 'g'), ''));
  for (const k of ['_codexCrownProfile', '_codexCrownEncounterSeq', '_codexCrownWorldDeathSeq']) delete save.system[k];
  try { fs.unlinkSync(LEDGER()); } catch (e) { /* 没有就算了 */ }
  const text = host.encode().replace(/"_codexCrownBonus":0/g, '"_codexCrownBonus":37.5').replace(/"_codexCrownUid":"[^"]*",?/g, '').replace(/"_codexCrown(Profile|EncounterSeq|WorldDeathSeq)":[^,}]*,?/g, '');
  host.restore(text);
  const got = crowns();
  return {count: got.length, item: got.length ? snap(got[0]) : null, ledger: ledger(), profile: !!w.$gameSystem._codexCrownProfile, seq: seq(), stripped: !!save};
}));

process.exit(finish(host, 'demon_crown.json', {hostScope: '真实 BattleManager.setup／startBattle／endBattle（不跑回合）、真实 JsonEx 往返；Math.random 0.5（开战掷点另设）', cases}) ? 0 : 1);
