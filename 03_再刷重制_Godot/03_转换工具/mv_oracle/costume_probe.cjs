'use strict';
// 角色换装（installCostumePreferencesRuntime，冻结 v0.28）：设置页「角色换装」开的是每个角色的换装卡外观开关（与衣橱 ChangeClothes 无关）。
// - 换装卡登记：技能 6801～6858 备注 <StartPushStateN:…>，状态 N 备注里 var battlerName = '…' 的才算；名字去掉「变身——」。
// - C.enabled：actor._codexCostumeEnabled !== false（默认启用，随局内存档）；C.cards：该角色学会的卡；C.ownedActors：_actors＋_saveactors 去重。
// - 战斗中（inBattle）角色有卡状态：启用时 battlerName() 是卡图，关闭时是自身形态（_prevBattlerName 或数据库 battlerName）。
// - 设置页：C.canOpen＝已进游戏（$gameSystem._codexGmReady）且不在战斗；状态文字「打开」／「进入游戏」。
// 产物 .sandbox/costume.json，复制进 01_Godot工程/tests/fixtures/costume_oracle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, encode, restore} = host;
const C = w.CodexCostumes;
const cases = [];
cases.push(makeCase('registry', {skills: '6801..6858'}, () => {
  // 登记在 DataManager.isDatabaseLoaded 包装里第一次调用时做
  w.DataManager.isDatabaseLoaded();
  const out = [];
  for (let id = 6801; id <= 6858; id++) {
    const sm = w.$dataSkills[id] && w.$dataSkills[id].note.match(/<StartPushState(\d+)\s*:/i);
    const card = sm && C.current({_states: [Number(sm[1])]});
    out.push(card ? [id, card.stateId, card.image, card.name] : [id, null]);
  }
  return {cards: out};
}));
function battlerName(a, inBattle) {
  w.$gameParty._inBattle = inBattle;
  try { return a.battlerName(); } finally { w.$gameParty._inBattle = false; }
}
cases.push(makeCase('actor', {actor: 1, learn: [6801, 6803], state: 1201}, () => {
  newGame();
  const a = w.$gameActors.actor(1), rows = [];
  const snap = tag => rows.push({tag, enabled: C.enabled(a), cards: C.cards(a).map(c => c.name), current: C.current(a) && C.current(a).stateId,
    active: C.active(a), map: battlerName(a, false), battle: battlerName(a, true)});
  snap('fresh');
  a.learnSkill(6801); a.learnSkill(6803);
  snap('learned');
  // 卡状态的 Custom Apply Effect 记下 _prevBattlerName 再 setBattlerImage（战斗里由技能开场推上）
  w.$gameParty._inBattle = true; a.addState(1201); w.$gameParty._inBattle = false;
  snap('state');
  C.setEnabled(a, false);
  snap('disabled');
  const json = encode(); restore(json);
  const b = w.$gameActors.actor(1);
  rows.push({tag: 'reloaded', enabled: C.enabled(b), saved: b._codexCostumeEnabled});
  C.setEnabled(b, true);
  rows.push({tag: 'reenabled', enabled: C.enabled(b), battle: battlerName(b, true)});
  return {rows};
}));
// 战斗外观（八戒_71 期一）：卡状态加上／去掉（Custom Remove Effect 还原）、阵亡清状态（不跑 Remove Effect，靠 stale 分支回自身形态）、
// 启用卡图时 Mx.SuperSVMetaProvider 去掉角色自身的 sv／SVspeed／SVzs／Cfdz／YCyy 标签（角色 174 云裳带这些标签）。
cases.push(makeCase('battle_image', {actors: [1, 174], learn: 6801, state: 1201}, () => {
  newGame();
  w.BattleManager._actionBattlers = new w.Array(); w.BattleManager._nextTurnActionBattlers = new w.Array();
  w.BattleManager.otbDisplayWindow = function () { return {createReturnedBattlerSprite: function () {}, createBattlerSprite: function () {}, addBattlerSprite: function () {}}; };  // 只测外观，不画行动条
  const rows = [];
  const svKeys = a => Object.keys(w.Mx.SuperSVMetaProvider(a, a.actor().meta) || {}).filter(k => /^(sv|SVspeed|SVzs\d+|Cfdz\d+|YCyy)$/i.test(k)).sort();
  [1, 174].forEach(id => {
    const a = w.$gameActors.actor(id);
    a.learnSkill(6801);
    w.$gameParty._inBattle = true;
    const snap = tag => rows.push({actor: id, tag, battle: a.battlerName(), sv: svKeys(a), states: a._states.slice()});
    snap('plain');
    a.addState(1201); snap('card');
    C.setEnabled(a, false); snap('card_disabled');
    C.setEnabled(a, true);
    a.removeState(1201); snap('removed');
    a.addState(1201); a.addState(1); snap('dead');
    a.removeState(1); a.recoverAll(); snap('revived');
    w.$gameParty._inBattle = false;
    rows.push({actor: id, tag: 'map', battle: a.battlerName(), sv: svKeys(a), states: a._states.slice()});
  });
  return {rows};
}));
cases.push(makeCase('owned', {party: [1, 8, 9], saveactors: [10, 8, 29]}, () => {
  newGame();
  w.$gameParty._actors = w.JSON.parse('[1,8,9]');
  w.$gameParty._saveactors = w.JSON.parse('[10,8,29]');
  [1, 8, 9, 10, 29].forEach(id => w.$gameActors.actor(id));
  return {owned: C.ownedActors().map(a => a.actorId())};
}));
cases.push(makeCase('options', {}, () => {
  newGame();
  const status = () => w.Window_Options.prototype.statusText.call({commandSymbol: () => 'codexCostumes'}, 0);
  const rows = [];
  delete w.$gameSystem._codexGmReady;
  rows.push({tag: 'title', canOpen: C.canOpen(), status: status()});
  Object.defineProperty(w.$gameSystem, '_codexGmReady', {value: true, configurable: true});
  rows.push({tag: 'game', canOpen: C.canOpen(), status: status()});
  w.$gameParty._inBattle = true;
  rows.push({tag: 'battle', canOpen: C.canOpen(), status: status()});
  w.$gameParty._inBattle = false;
  return {rows};
}));
process.exit(finish(host, 'costume.json', {hostScope: '新游戏（Math.random 0.5）；角色换装：换装卡登记、每角色开关、战斗外观、设置页状态', cases}) ? 0 : 1);
