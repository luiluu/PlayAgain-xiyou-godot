'use strict';
// death_admission 量具（tools CR，2026-11-06 补；原夹具是手搭量具测的，库里没有探针）：敌人 1 号，HP0 加死亡状态的准入、
// 复活后结果槽里的 removedStates 挡住再加死亡、clearResult 后 refresh 才再死、die＋refresh。用例与 tests/xiyou_death_admission.gd 一一对应。
// 夹具每条用例的错误写在 issues（不是 errors），所以不用 host.finish，自己按同样格式写 .sandbox/death_admission.json，
// 拷成 tests/fixtures/death_admission_oracle.json（不接入全量同步）。
const fs = require('fs'), path = require('path');
const {start, makeCase} = require('./shared/host.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const host = start(), {w, newGame} = host;
const row = (label, e) => {
  const r = e.result();
  return {label, hp: e._hp, states: Array.from(e._states), turns: {...e._stateTurns}, alive: e.isAlive(), dead: e.isDead(), hidden: e.isHidden(),
          removed: Array.from(r.removedStates), added: Array.from(r.addedStates)};
};
const fresh = () => { newGame(); const e = new w.Game_Enemy(1, 0, 0); e.clearResult(); return e; };
const cases = [];
for (const hidden of [false, true]) cases.push(makeCase('zero_hp_add_death.' + hidden, {hidden}, () => {
  const e = fresh();
  e._hp = 0; e._states = new w.Array(); e._stateTurns = {}; e._hidden = hidden;
  const rows = [row('before', e)];
  e.addState(1); rows.push(row('add', e));
  return {rows};
}));
cases.push(makeCase('revive_then_death_result', {}, () => {
  const e = fresh(), rows = [];
  e.addState(1); rows.push(row('death', e));
  e.setHp(1); rows.push(row('revive', e));
  e.addState(1); rows.push(row('readd', e));
  e.setHp(1); e.setHp(0); rows.push(row('death_again', e));
  e.clearResult(); e.refresh(); rows.push(row('death_after_clear', e));
  return {rows};
}));
cases.push(makeCase('native_die_refresh', {}, () => {
  const e = fresh(), rows = [];
  e._hp = 0; e.die(); rows.push(row('die', e));
  e.refresh(); rows.push(row('refresh', e));
  return {rows};
}));
if (JSON.stringify(host.identity) !== JSON.stringify(sourceIdentity(require('./shared/host.cjs').APP))) throw new Error('测量期间来源改变');
const out = {schemaVersion: 1, sourceIdentity: host.identity, scope: 'new minimal death admission and retained result cases; no save IO',
             cases: cases.map(({id, setup, observed, errors}) => ({id, setup, observed, issues: errors}))};
fs.mkdirSync(path.resolve(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.resolve(__dirname, '.sandbox/death_admission.json'), JSON.stringify(out, null, 1) + '\n');
const bad = out.cases.filter(c => c.issues.length);
console.log(JSON.stringify({file: 'death_admission.json', cases: out.cases.length, errors: bad.map(c => ({id: c.id, errors: c.issues}))}));
process.exit(bad.length ? 1 : 0);
