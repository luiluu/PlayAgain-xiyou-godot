'use strict';
// 【cc·八戒·未经审查】条件分支 111 类型 4（角色）定向参照（interp7 盘点）：
// 队伍 6 人、出战栏 [1,8,10,9,0]（13、14 在后备），在地图上（$gameParty._inBattle=false）与战斗中（true）各问一遍
// 「在队」0、「技能」3、「状态」6 三种子类型；原版 command111 用 $gameParty.members()，战斗中只是出战成员。
// 真实冻结插件、全内存新局；只写 .sandbox/cond111.json，拷成 tests/fixtures/cond111_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
function interp() { const it = new w.Game_Interpreter(); it._list = w.JSON.parse('[{"code":111,"indent":0,"parameters":[]},{"code":0,"indent":0,"parameters":[]}]'); it._index = 0; it._indent = 0; it._branch = w.eval('({})'); return it; }
function cond(params) { const it = interp(); it._params = w.JSON.parse(JSON.stringify(params)); it.command111(); return it._branch[0] === true; }
const PARTY = [1, 8, 10, 9, 13, 14], SLOTS = [1, 8, 10, 9, 0];
const QUERIES = {
  party1: [4, 1, 0], party9: [4, 9, 0], party13: [4, 13, 0], party14: [4, 14, 0], party2: [4, 2, 0], partyMissing: [4, 99999, 0],
  skill1_319: [4, 1, 3, 319], skill1_320: [4, 1, 3, 320], skill13_319: [4, 13, 3, 319],
  state1_692: [4, 1, 6, 692], state1_693: [4, 1, 6, 693], state13_692: [4, 13, 6, 692], stateMissing: [4, 99999, 6, 692],
};
function setup() {
  newGame();
  w.$gameParty._actors = w.Array.from([]);
  PARTY.forEach(id => w.$gameParty.addActor(id));
  w.$gameParty._battleMembers = w.Array.from(SLOTS);
  for (const id of [1, 13]) { w.$gameActors.actor(id).learnSkill(319); w.$gameActors.actor(id).addState(692); }
}
function ask() { const out = {}; for (const k in QUERIES) out[k] = cond(QUERIES[k]); return out; }
const cases = [];
cases.push(makeCase('map', {party: PARTY, slots: SLOTS}, () => {
  setup(); w.$gameParty._inBattle = false;
  return {members: w.$gameParty.members().map(a => a.actorId()), answers: ask()};
}));
cases.push(makeCase('battle', {party: PARTY, slots: SLOTS}, () => {
  setup(); w.$gameParty._inBattle = true;
  const out = {members: w.$gameParty.members().map(a => a.actorId()), answers: ask()};
  w.$gameParty._inBattle = false;
  return out;
}));
process.exitCode = finish(host, 'cond111.json', {scope: 'conditional branch 111 actor in-party/skill/state on map vs in battle with reserve members', queries: QUERIES, cases}) ? 0 : 1;
process.exit();
