'use strict';
// 【cc·哪吒·未经审查】xuan1 璇的星谱（js/codex/runtime/installNativeXuanRuntime.js 第 52～69、428～445、513～561、576～578 行：
// chart／markLevel／syncMarkSkills、learn／refund／equip、胜利星砂、openStarchart 的各页）。
// ① ops：新局招募璇，改到指定等级与星砂后，按序列做 learn／refund／equip，每步记返回值或报错原文、星谱快照、已学星纹技能、markLevel。
// ② gate：璇 1～60 级各阶段，每个星纹 learn／equip 是否放行（开槽等级 10／20／30）。
// ③ sand：胜利一场（普通敌群、含 Boss 的敌群）、逃跑、失败，星砂各加多少；璇不在出战队时不加。
// ④ flow：openStarchart 的各页行文（stub CodexBinding.openMenu／CodexYunshang.choose，按行文点选），含自律开关、并轨副宿主、命主名册、同调元素。
// 真实新游戏，只在内存；产物 .sandbox/xuan_chart.json，拷成 tests/fixtures/xuan_chart_oracle.json，专项 xiyou_xuan_chart。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const X = w.CodexXuan, B = w.CodexBinding, D = w.CodexBossDifficulty;
if (!X || !B || !D || !w.CodexYunshang) throw new Error('璇／绑定／Boss 难度／云裳模块未安装');
if (!w.$) w.$ = {};
const toasts = [];
w.$.toaster = o => { toasts.push(o && o.message); };
const ID = 177;
const sorted = a => a.slice().sort((x, y) => x - y);
const J = v => JSON.parse(JSON.stringify(v === undefined ? null : v));

function setup(level, sand, prep) {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameActors._data[ID] = null;
  const a = w.$gameActors.actor(ID);
  X.recruit();
  a.changeLevel(level, false);
  X.chart(a).sand = sand;
  if (prep) prep(a);
  return a;
}
function snap(a) {
  const markSkills = X.MARKS.map(m => X.ids().skill['mark.' + m]);
  return {chart: J(X.chart(a)), marks: sorted(a._skills.filter(s => markSkills.includes(s))), markLevel: X.MARKS.map(m => X.markLevel(a, m)),
    control: a._codexXuanControl === undefined ? null : a._codexXuanControl};
}
function tryDo(fn) {
  try { return {ret: fn()}; } catch (e) { return {error: String(e && e.message || e)}; }
}
const cases = [];

// ① 序列
const OPS = {
  basic: [['learn', 'yuhui'], ['learn', 'yuhui'], ['learn', 'yuhui'], ['learn', 'yuhui'], ['refund', 'yuhui'], ['refund', 'yuhui'],
    ['learn', 'dingxing'], ['equip', 'dingxing'], ['learn', 'xianzhao'], ['learn', 'dingxing'], ['equip', 'yuhui'], ['refund', 'dingxing'], ['equip', 'xianzhao']],
  slots: [['equip', 'fenguang'], ['learn', 'fenguang'], ['equip', 'fenguang'], ['learn', 'shihui'], ['learn', 'shihui'], ['equip', 'shihui'], ['equip', 'tongdiao'],
    ['learn', 'binggui'], ['learn', 'liuhui'], ['learn', 'liuhui'], ['equip', 'liuhui'], ['refund', 'liuhui'], ['refund', 'binggui'], ['equip', 'yiguang']],
};
for (const [name, level, sand] of [['basic', 60, 200], ['basic.poor', 60, 20], ['slots', 60, 500], ['slots.lv25', 25, 500]]) {
  cases.push(makeCase(`ops.${name}`, {level, sand}, () => {
    const a = setup(level, sand);
    const steps = [];
    for (const [op, m] of OPS[name.split('.')[0]]) {
      const r = tryDo(() => X[op](a, m));
      steps.push({op, m, ...r, ...snap(a)});
    }
    return {start: snap(setup(level, sand)), steps};
  }));
}

// ② 各等级放行
cases.push(makeCase('gate.levels', {}, () => {
  const rows = [];
  for (const lv of [1, 9, 10, 19, 20, 29, 30, 60]) {
    const a = setup(lv, 1000);
    const learn = {}, equip = {};
    for (const m of X.MARKS) learn[m] = tryDo(() => X.learn(a, m));
    for (const m of X.MARKS) equip[m] = tryDo(() => X.equip(a, m));
    rows.push({level: lv, learn, equip, ...snap(a)});
  }
  return {rows};
}));

// ③ 胜利星砂
function troops() {
  const out = {boss: 0, plain: 0};
  for (let t = 1; t < w.$dataTroops.length && !(out.boss && out.plain); t++) {
    const tr = w.$dataTroops[t];
    if (!tr || !tr.members.length) continue;
    w.BattleManager.setup(t, true, false);
    const boss = w.$gameTroop.members().some(e => D.isBoss(e));
    if (boss && !out.boss) out.boss = t;
    if (!boss && !out.plain) out.plain = t;
  }
  return out;
}
const T = troops();
function battle(tid, result, front) {
  const a = setup(60, 0);
  if (front === false) { // 璇留在后备（不在出战）
    w.eval('$gameParty._actors=[1,8,9,10,2,3,4,5,6,7,' + ID + '];$gameParty._battleMembers=[1,8,9,10];');
  } else {
    w.eval('$gameParty._actors=[' + ID + ',1,8,9];$gameParty._battleMembers=[' + ID + ',1,8,9];');
  }
  w.BattleManager.setup(tid, true, false);
  w.BattleManager.startBattle();
  const inBattle = w.$gameParty.battleMembers().includes(a);
  const before = X.chart(a).sand;
  w.BattleManager.endBattle(result);
  return {troop: tid, result, inBattle, before, after: X.chart(a).sand};
}
cases.push(makeCase('sand.troops', {}, () => T));
for (const [name, tid, result, front] of [['plain.win', T.plain, 0, true], ['boss.win', T.boss, 0, true], ['plain.escape', T.plain, 1, true], ['plain.lose', T.plain, 2, true],
  ['boss.escape', T.boss, 1, true], ['plain.win.bench', T.plain, 0, false]]) {
  cases.push(makeCase(`sand.${name}`, {tid, result, front}, () => battle(tid, result, front)));
}
cases.push(makeCase('sand.twice', {}, () => {
  const a = setup(60, 0);
  w.eval('$gameParty._actors=[' + ID + ',1,8,9];$gameParty._battleMembers=[' + ID + ',1,8,9];');
  const rows = [];
  for (const [tid, result] of [[T.plain, 0], [T.boss, 0], [T.plain, 0]]) {
    w.BattleManager.setup(tid, true, false); w.BattleManager.startBattle(); w.BattleManager.endBattle(result);
    rows.push(X.chart(a).sand);
  }
  return {rows};
}));

// ④ 各页
let screens = [], cur = null;
w.CodexYunshang.choose = function (scene, rows, ok, cancel, info) {
  cur = {rows, ok, cancel, info};
  screens.push({info: J(info || []), rows: rows.map(x => ({label: x.label, enabled: x.enabled !== false}))});
};
let home = null;
B.openMenu = function (fn) { home = fn; return true; };
const scene = {popScene() { screens.push({popped: true}); }};
function pick(label) {
  const r = label[0] === '@' ? cur.rows[Number(label.slice(1))] : cur.rows.find(x => x.label === label);
  if (!r) throw new Error('找不到行 ' + label + ' 现有 ' + cur.rows.map(x => x.label).join('|'));
  cur.ok(r);
}
function flow(name, level, sand, adv, prep, steps) {
  cases.push(makeCase(`flow.${name}`, {level, sand, adv, steps}, () => {
    const a = setup(level, sand, x => { x._AdvancedNum = adv; if (prep) prep(x); });
    screens = []; toasts.length = 0; home = null;
    const opened = X.openStarchart();
    if (home) home(scene);
    for (const s of steps) { if (s === '<') cur.cancel(); else pick(s); }
    return {opened: opened === undefined ? null : opened, homed: !!home, steps, screens, toasts: toasts.slice(), ...snap(a),
      roster: J(X.chart(a).roster), partner: X.chart(a).partner, element: X.chart(a).element === undefined ? null : X.chart(a).element};
  }));
}
flow('open.lv60', 60, 100, 0, null, ['<']);
flow('slot', 60, 100, 0, null, ['@1', '@0', '<', '<', '<']);
flow('learn-equip', 60, 100, 0, null, ['@1', '@1', '@1', '@1', '@0', '<', '<']);
flow('poor', 60, 5, 0, null, ['@1', '@2', '@1', '<', '<', '<']);
flow('lv5', 5, 100, 0, null, ['@1', '<']);
flow('auto-locked', 60, 100, 2, null, ['@0', '<']);
flow('auto-on', 60, 100, 3, null, ['@0', '@0', '<']);
flow('partner', 60, 100, 0, null, ['@4', '@0', '@4', '<', '<']);
flow('roster0', 60, 100, 0, null, ['@5', '<']);
flow('roster2', 60, 100, 2, null, ['@5', '@0', '@5', '@1', '@5', '@0', '<', '<']);
flow('element', 60, 100, 0, null, ['@6', '@0', '@6', '<', '<']);
flow('not-in-party', 60, 100, 0, () => { w.$gameParty.removeActor(ID); }, []);

process.exit(finish(host, 'xuan_chart.json', {cases, troops: T}) ? 0 : 1);
