'use strict';
// 难度 6～9 整敌群对照（哪吒 diff2）：slice_probe 的敌群只到难度 6，且只建 Game_Troop.setup；difficulty_enemy_probe 只量单个敌人。
// 这里走原版 BattleManager.setup（Math.random 0.99，避开神话／等级浮动）＋startBattle（0.5），再照 dsPassiveSkill Scene_Battle.start
// 补开战加状态（StartPushState 给自己、StartAEPushState 给全体敌人、StartWTPushState 给全队；随机目标的三种只记有没有，不加），之后刷新被动，
// 记敌群每个成员：敌人号（含替换后的）、隐藏、神话、等级、HP／MP、状态、最终能力值（param／xparam／sparam／属性）、行动表。
// 队伍 [1,8,9,10] 1 级、只带新局技能（不跑难度开局事件：难度对敌人的影响只经 setDifficultyId；角色侧另有 difficulty_actor_probe）。
// 敌群：含 boss 备注敌人的敌群取首、中、尾（去重），其余从切片敌群等距补满 10 个；每难度×敌群一例、每例一次新局。
// 产物 .sandbox/difficulty_troop.json（generated/oracle/difficulty_troop.json，tests/xiyou_difficulty_troop 读）。
const fs = require('fs'), path = require('path');
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
if (w.$) w.$.toaster = () => {};
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const isBossTroop = t => w.$dataTroops[t] && w.$dataTroops[t].members.some(m => /boss/i.test((w.$dataEnemies[m.enemyId] || {}).note || ''));
const boss = SLICE.troops.filter(isBossTroop), plain = SLICE.troops.filter(t => w.$dataTroops[t] && !isBossTroop(t));
const troops = [...new Set([boss[0], boss[Math.floor(boss.length / 2)], boss[boss.length - 1]].filter(Boolean))];
const want = 10 - troops.length;
for (let i = 0; i < want; i++) troops.push(plain[Math.floor(i * (plain.length - 1) / (want - 1))]);
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const X = ['hit', 'eva', 'cri', 'cev', 'mev', 'mrf', 'cnt', 'hrg', 'mrg', 'trg'];
const S = ['tgr', 'grd', 'rec', 'pha', 'mcr', 'tcr', 'pdr', 'mdr', 'fdr', 'exr'];
const ELEMENTS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15];
const snap = b => ({param: P.map(k => round(b[k])), xparam: X.map(k => round(b[k])), sparam: S.map(k => round(b[k])), elementRates: ELEMENTS.map(e => round(b.elementRate(e)))});
const tags = (a, prefix, cb) => a.equips().concat(a.skills()).filter(Boolean).forEach(o => {
  for (const k in (o.meta || {})) if (k.startsWith(prefix) && /^\d+$/.test(k.slice(prefix.length))) {
    const pr = parseFloat(String(o.meta[k]).trim().replace('%', ''));
    if (!isNaN(pr) && 50 < pr) cb(Number(k.slice(prefix.length)));
  }
});
const cases = [];
for (let d = 6; d <= 9; d++) {
  for (const tid of troops) {
    cases.push(makeCase(`difftroop.d${d}.t${tid}`, {difficulty: d, troop: tid}, () => {
      newGame();
      w.$gameSystem.setDifficultyId(d);
      w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
      w.Math.random = () => 0.99;
      const bm = w.BattleManager; bm.setup(tid, false, false);
      bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
      w.Math.random = () => 0.5;
      bm.startBattle();
      const party = w.$gameParty.battleMembers(), random = [];
      party.forEach(a => {
        a.initPassiveCache();
        tags(a, 'StartPushState', sid => a.addState(sid));
        ['StartRomActPushState', 'StartRomEmePushState', 'StartRomPushState'].forEach(p => tags(a, p, sid => random.push([a.actorId(), p, sid])));
        tags(a, 'StartAEPushState', sid => w.$gameTroop.aliveMembers().forEach(e => e.addState(sid)));
        tags(a, 'StartWTPushState', sid => party.forEach(x => x.addState(sid)));
        a._passiveCache.okadd = true;
      });
      party.forEach(a => a.refreshPassiveCache());
      w.$gameTroop.members().forEach(e => e.refreshPassiveCache && e.refreshPassiveCache());
      const members = w.$gameTroop.members().map(e => ({id: e.enemyId(), hidden: !!e._hidden, elite: !!(e.isElite && e.isElite()), level: e.level,
        hp: round(e.hp), mp: round(e.mp), states: e._states.slice().sort((x, y) => x - y), ...snap(e),
        actions: e.enemy().actions.map(a => [a.skillId, a.rating, a.conditionType, round(a.conditionParam1), round(a.conditionParam2)])}));
      bm._phase = 'init'; w.$gameParty.onBattleEnd && w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd && w.$gameTroop.onBattleEnd();
      return {difficultyName: w.$gameSystem.difficultyName(), randomTargetTags: random, members};
    }));
  }
}
process.exit(finish(host, 'difficulty_troop.json', {hostScope: '正式 BattleManager.setup＋startBattle 后难度 6～9 的整敌群', troops, cases}) ? 0 : 1);
