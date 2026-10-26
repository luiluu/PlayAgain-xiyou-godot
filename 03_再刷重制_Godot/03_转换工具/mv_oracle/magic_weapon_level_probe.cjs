'use strict';
// 法宝等级与经验（CP_MagicWeapon 1.10+）与按等级学技能（CP_X_MagicWeaponLearnSkill），冻结 v0.28：
// ① catalog：全部 <Magic Weapon> 武器／防具载入后的初始等级、初始经验、等级上限、下一级所需、升级特性对象、学技能表、
//    战斗不得经验标记、有没有升级效果脚本；另记插件参数。
// ② formula：几件法宝在 1／2／10／100／887／888 级时的下一级所需（Game_Item.nextLevelExp）。
// ③ gain：大罗剑胎实例从 1 级起逐次 gainExp（法宝经验丹的 100／5000／1000000 等），每步后的等级与经验；满级后 levelUp 只把经验设成所需。
// ④ commands：解释器跑插件指令 MagicWeaponAllGainExp（经公共事件 1190 法宝经验丹）与 MagicWeaponLevelUp，全队各法宝的等级与经验。
// ⑤ victory：6 人队（第 6 人后备）各装一件法宝，敌群取首个带隐藏成员的，BattleManager.makeRewards＋gainRewards 后各法宝的等级与经验。
// ⑥ traits：天海麒麟星 142 装麒麟对剑（武器 73，<Equip LevelUp Trait Armor: 4409>）在 1／3／10 级时的特性对象数与 xparam。
// ⑦ learn：天虎令 104 装烽舞（防具 3550，<Magic Weapon Learn Skill 7510: 10, 19> 等）在各等级时 skills() 里的 7510～7513（含重复次数），
//    另有一行经 gainExp 升过 10 级（走 processLevelUpEffect 的 refresh）。
// 真实新游戏、Math.random 0.5，只在内存；产物 .sandbox/magic_weapon_level.json，
// 复制进 01_Godot工程/tests/fixtures/magic_weapon_level_oracle.json（tests/xiyou_magic_weapon_level.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const M = w.CP.MagicWeaponManager;
const J = o => w.JSON.parse(w.JSON.stringify(o));
const kindOf = e => w.DataManager.isWeapon(e) ? 'weapon' : 'armor';
function baseOf(e) {
  const db = w.DataManager.isWeapon(e) ? w.$dataWeapons : w.$dataArmors; let o = e;
  for (let n = 0; n < 20 && o; n++) { const b = o.originalBaseItemId || o.baseItemId; if (!b || b === o.id) return o.id; o = db[b]; }
  throw new Error('基础编号循环 ' + e.id);
}
// 量能力值前清 krz_state_re 的缓存（同 magic_weapon_probe）
function clearParamCache(a) {
  a._cacheBaseParam = {}; a._baseParamCache = []; a._ParamCache2 = []; a._xparamCache2 = []; a._sparamCache2 = []; a._cacheParamBuffRate = {};
  a.need_refresh_param = [1,1,1,1,1,1,1,1]; a.need_refresh_xparam = [1,1,1,1,1,1,1,1,1,1]; a.need_refresh_sparam = [1,1,1,1,1,1,1,1,1,1]; a.need_refresh = true; a.refresh();
}
// 新生成一件独立装备（背包里多出来的那件）
function make(kind, base) {
  const db = kind === 'weapon' ? w.$dataWeapons : w.$dataArmors, before = w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(db[base], 1);
  const item = w.$gameParty.equipItems().find(x => before.indexOf(x) < 0);
  if (!item) throw new Error('未生成装备 ' + kind + base);
  return item;
}
function wear(a, item) {
  const slot = a.equipSlots().indexOf(item.etypeId);
  if (slot < 0) throw new Error(a.actorId() + ' 没有装备类型 ' + item.etypeId);
  a.forceChangeEquip(slot, item);
  if (a.equips()[slot] !== item) throw new Error(a.actorId() + ' 没装上 ' + kindOf(item) + baseOf(item));
  return slot;
}
const gi = item => { const g = new w.Game_Item(); g.setObject(item); return g; };
const state = item => ({level: round(gi(item).level()), exp: round(gi(item).exp()), next: round(gi(item).nextLevelExp())});
function equipRows(a) {
  return a._equips.map((g, slot) => ({g, slot})).filter(x => x.g.isMagicWeapon())
    .map(({g, slot}) => ({slot, kind: kindOf(g.object()), base: baseOf(g.object()), level: round(g.level()), exp: round(g.exp())}));
}
const cases = [];
const params = {};
for (const k of ['INIT_LEVEL', 'INIT_EXP', 'EXP_FORMULA', 'MAX_LEVEL', 'ENEMY_MIN_EXP', 'USE_EXP', 'EXP_RATE_NOT_BATTLER']) params[k] = M[k];

cases.push(makeCase('catalog', {}, () => {
  const rows = [];
  for (const [kind, db] of [['weapon', w.$dataWeapons], ['armor', w.$dataArmors]]) {
    for (let i = 1; i < db.length; i++) {
      const e = db[i];
      if (!e || !M.isMagicWeapon(e)) continue;
      const g = gi(e), t = g.levelUpTraitObject();
      rows.push({kind, base: i, initLevel: round(e.initLevel), level: round(g.level()), exp: round(g.exp()), maxLevel: round(g.maxLevel()),
        next: round(g.nextLevelExp()), expFormula: e.meta['Exp Formula'] || null, useExp: round(g.useExp()),
        levelUpTraits: J(e.levelUpTraits), traitObjectTraits: t ? t.traits.length : null,
        learn: J(e.magicWeaponLearnSkill || []), cannotGainAfterVictory: !!e.cannotGainExpAfterVictory, hasLevelUpEffect: !!e.equipLevelUpEffect});
    }
  }
  return {params, rows};
}));

cases.push(makeCase('formula', {levels: [1, 2, 10, 100, 887, 888]}, () => {
  newGame();
  const rows = [];
  for (const [kind, base] of [['armor', 13], ['armor', 4518], ['armor', 3550], ['weapon', 73]]) {
    const item = make(kind, base);
    for (const lv of [1, 2, 10, 100, 887, 888]) { item.level = lv; rows.push({kind, base, level: lv, next: round(gi(item).nextLevelExp())}); }
  }
  return {rows};
}));

cases.push(makeCase('gain', {kind: 'armor', base: 13, steps: [0, 74, 1, 100, 5000, 1000000, 1000000000, 5]}, () => {
  newGame();
  const item = make('armor', 13), g = gi(item), rows = [Object.assign({step: 'init'}, state(item))];
  for (const x of [0, 74, 1, 100, 5000, 1000000, 1000000000, 5]) { g.gainExp(x); rows.push(Object.assign({step: x}, state(item))); }
  g.levelUp(); rows.push(Object.assign({step: 'levelUp_at_max'}, state(item)));
  return {rows};
}));

cases.push(makeCase('commands', {}, () => {
  newGame();
  const party = w.$gameParty.allMembers();
  const wearing = [[1, 'armor', 121], [8, 'armor', 3551], [9, 'armor', 3552], [10, 'armor', 4516]];
  for (const [aid, kind, base] of wearing) wear(w.$gameActors.actor(aid), make(kind, base));
  const run = list => {
    const it = new w.Game_Interpreter(); it.setup(list.concat([{code: 0, indent: 0, parameters: []}]), 0);
    for (let n = 0; n < 200 && it.isRunning(); n++) it.update();
    if (it.isRunning()) throw new Error('解释器未结束');
  };
  const snap = label => ({label, actors: party.map(a => ({actor: a.actorId(), equips: equipRows(a)}))});
  const rows = [snap('init')];
  run([{code: 117, indent: 0, parameters: [1190]}]); rows.push(snap('ce1190'));
  run([{code: 356, indent: 0, parameters: ['MagicWeaponAllGainExp 5000']}]); rows.push(snap('all5000'));
  const slot = w.$gameActors.actor(1).equipSlots().indexOf(13);
  run([{code: 356, indent: 0, parameters: ['MagicWeaponLevelUp 1 ' + slot + ' 3']}]); rows.push(snap('levelUp1x3'));
  run([{code: 356, indent: 0, parameters: ['MagicWeaponLevelUp 8 0 2']}]); rows.push(snap('levelUpEmptyOrPlain'));
  return {wearing, slot, ce1190: J(w.$dataCommonEvents[1190].list.map(c => [c.code, c.parameters])), rows};
}));

cases.push(makeCase('victory', {}, () => {
  newGame();
  for (const id of [2, 3]) w.$gameParty.addActor(id);
  const troopId = w.$dataTroops.findIndex(t => t && t.members.length >= 2 && t.members.some(m => m.hidden));
  if (troopId < 0) throw new Error('没有带隐藏成员的敌群');
  const wearing = [[1, 'armor', 121], [8, 'armor', 3551], [9, 'armor', 3552], [10, 'armor', 4516], [2, 'armor', 3553], [3, 'armor', 3554]];
  for (const [aid, kind, base] of wearing) wear(w.$gameActors.actor(aid), make(kind, base));
  w.BattleManager.setup(troopId, false, false);
  const members = w.$gameTroop.members().map(e => ({enemy: e.enemyId(), hidden: !!e.isHidden(), exp: e.magicWeaponExp()}));
  const before = w.$gameParty.allMembers().map(a => ({actor: a.actorId(), equips: equipRows(a)}));
  w.BattleManager.makeRewards();
  w.BattleManager.gainRewards();
  return {troopId, members, total: w.$gameTroop.magicWeaponExpTotal(), wearing,
    battle: w.$gameParty.battleMembers().map(a => a.actorId()), all: w.$gameParty.allMembers().map(a => a.actorId()),
    before, after: w.$gameParty.allMembers().map(a => ({actor: a.actorId(), equips: equipRows(a)}))};
}));

cases.push(makeCase('traits', {actor: 142, kind: 'weapon', base: 73, levels: [1, 3, 10]}, () => {
  newGame();
  w.$gameActors._data[142] = null;
  const a = w.$gameActors.actor(142), item = make('weapon', 73), slot = wear(a, item), rows = [];
  for (const lv of [1, 3, 10]) {
    item.level = lv; clearParamCache(a);
    const objs = a.traitObjects();
    rows.push({level: lv, slot, objects: objs.length, levelUpObjects: objs.filter(o => o === w.$dataArmors[4409]).length,
      xparams: Array.from({length: 10}, (_, i) => round(a.xparam(i))),
      equip: {params: Array.from(item.params), traits: J(item.traits)}});
  }
  return {rows};
}));

cases.push(makeCase('learn', {actor: 104, kind: 'armor', base: 3550}, () => {
  newGame();
  w.$gameActors._data[104] = null;
  const a = w.$gameActors.actor(104), item = make('armor', 3550), slot = wear(a, item), rows = [];
  const pick = () => { const ids = a.skills().filter(s => s && s.id >= 7510 && s.id <= 7513).map(s => s.id); return ids; };
  for (const lv of [1, 9, 10, 19, 20, 29, 30, 39, 40, 500]) { item.level = lv; a.refresh(); rows.push({level: lv, set: true, skills: pick()}); }
  item.level = 1; item.exp = 0; a.refresh(); pick();
  a._equips[slot].gainExp(2000); rows.push(Object.assign({set: false, skills: pick()}, state(item)));
  return {slot, base: J(a.skills().map(s => s && s.id).filter(id => id >= 7510 && id <= 7513)), rows};
}));

process.exit(finish(host, 'magic_weapon_level.json', {hostScope: '新游戏（Math.random 0.5）；法宝等级、经验、战斗结算、插件指令、升级特性与按等级学技能', cases}) ? 0 : 1);
