'use strict';
// 2e supplemental evidence only. Does not rerun/overwrite state_effects.json's
// preserved native22. The host keeps the frozen source read-only and all writes
// in .sandbox. No player saves, render loop, or production-method replacement.
const {start, makeCase: nativeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const evalErrors = [];
w.Yanfly.Util.displayError = error => evalErrors.push(String(error && error.stack || error));
function makeCase(id, setup, fn) {
  return nativeCase(id, setup, () => {
    const first = evalErrors.length, result = fn();
    if (evalErrors.length !== first) throw new Error(JSON.stringify(evalErrors.slice(first)));
    return result;
  });
}

function battle() {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame();
  w.BattleManager.setup(2, true, true);
  w.$gameParty._inBattle = true;
  return {actor: w.$gameActors.actor(1), enemy: w.$gameTroop.members()[0]};
}
function prepare(b, tp, hpZero = false, fixtureStates = []) {
  // Explicit fixture injection permits testing stale resisted states and 0 HP
  // without death. The operation under measurement is always the native method.
  b._states = fixtureStates.slice(); b._stateTurns = {};
  b.need_refresh = true; b.refresh(); b.states(); b.typestates('turnStartState');
  b._states = fixtureStates.slice(); b._stateTurns = {};
  b._tp = tp; b._hp = hpZero ? 0 : b.mhp; b._mp = b.mmp;
  b.clearResult();
  Object.assign(b.result(), {hpAffected: true, hpDamage: 17, mpDamage: 19, tpDamage: 23, success: true});
}
function snapshot(b) {
  const r = b.result();
  return {hp: b.hp, mp: b.mp, tp: b.tp, cap: b.maxTp(), states: Array.from(b._states),
    turns: Object.assign({}, b._stateTurns), dirty: !!b.need_refresh,
    result: {hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage,
      success: r.success, addedStates: Array.from(r.addedStates), removedStates: Array.from(r.removedStates)}};
}
function measure(fn) {
  let draws = 0;
  const old = w.Math.random;
  w.Math.random = () => { draws++; return 0.5; };
  try { return {value: fn(), draws: () => draws}; }
  finally { w.Math.random = old; }
}
function fixtureState(name, traits) {
  const s = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  Object.assign(s, {id: w.$dataStates.length, name, note: '', meta: {}, traits, priority: 50,
    minTurns: 1, maxTurns: 1, autoRemovalTiming: 0, removeAtBattleEnd: false});
  for (const k of Object.keys(s.customEffectEval)) s.customEffectEval[k] = '';
  w.$dataStates.push(s);
  return s.id;
}
const cases = [];
cases.push(makeCase('tp.guarded_apply', {states: [1334, 1336], tp: 199, hpZero: [false, true]}, () => {
  const pair = battle(), rows = [];
  for (const [kind, b] of Object.entries(pair)) for (const sid of [1334, 1336]) for (const hpZero of [false, true]) {
    prepare(b, 199, hpZero);
    const before = snapshot(b);
    const got = measure(() => {
      b.addState(sid); const first = snapshot(b);
      b.addState(sid); const second = snapshot(b);
      b.refresh(); const refreshed = snapshot(b);
      return {first, second, refreshed};
    });
    rows.push({kind, state: sid, hpZero, before, ...got.value, draws: got.draws()});
  }
  return {rows};
}));
cases.push(makeCase('tp.actor_custom_caps', {passiveEXTTP: [-160, 100], states: [607, 609, 857, 1334, 1336]}, () => {
  const rows = [];
  for (const extra of [-160, 100]) {
    const {actor: b} = battle();
    const skill = w.JsonEx.makeDeepCopy(w.$dataSkills[1]);
    Object.assign(skill, {id: w.$dataSkills.length, name: '测试·TP上限', note: `<passiveEXTTP:${extra}>`,
      meta: {passiveEXTTP: String(extra)}});
    w.$dataSkills.push(skill); b.learnSkill(skill.id); b.refreshPassiveSkillCache();
    const cap = 200 + extra;
    if (b.maxTp() !== cap) throw new Error('custom cap fixture mismatch: ' + b.maxTp());
    for (const sid of [607, 609, 857, 1334, 1336]) {
      for (const mode of sid >= 1334 ? ['direct', 'addState'] : ['direct']) {
        prepare(b, cap - 1);
        const before = snapshot(b);
        const got = measure(() => {
          if (mode === 'addState') b.addState(sid);
          else b.customEffectEval(sid, sid >= 1334 ? 'addState' : 'battle');
          return snapshot(b);
        });
        rows.push({extra, state: sid, mode, before, after: got.value, draws: got.draws()});
      }
    }
  }
  return {rows};
}));
cases.push(makeCase('tp.refresh_state_boundary', {effect: 'native 1334 apply25', staleResistedState: true}, () => {
  const victim = fixtureState('测试·待刷新抵抗状态', []);
  const resister = fixtureState('测试·抵抗另一状态', [{code: 14, dataId: victim, value: 1}]);
  const pair = battle(), rows = [];
  for (const [kind, b] of Object.entries(pair)) for (const mode of ['direct', 'addState']) {
    prepare(b, 199, false, [victim, resister]);
    const before = snapshot(b);
    const got = measure(() => {
      if (mode === 'addState') b.addState(1334);
      else b.customEffectEval(1334, 'addState');
      const after = snapshot(b);
      b.refresh();
      return {after, refreshed: snapshot(b)};
    });
    rows.push({kind, mode, before, ...got.value, draws: got.draws()});
  }
  return {victim, resister, rows};
}));
process.exit(finish(host, 'state_effects_tp_context.json', {
  hostScope: '补充2e：真实addState/refresh、合成技能passiveEXTTP上限、显式陈旧抵抗状态夹具；不重跑native22', cases,
}) ? 0 : 1);
