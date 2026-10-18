'use strict';
// 修行指引第二阶段（installNativeGuidanceRuntime v2）的冻结 v0.28 参照：区段表 G.ATLAS、楼层→区段、区段里程碑对话文字与指令列、
// 已看过标记随存档、方桌大厅「商店向导」→「下一步建议」（G.adviceTexts）。修行页与战力条文字已在 zhenqi_probe 的 page.*。
// 「战力短板」一段来自 CodexZones（五乘区预算，按数值平衡不移植，O-044／O-050）：每例另测一份去掉 CodexZones 的文字供 Godot 逐段比对。
// Boss 预告原版关闭（G.PREVIEW_ENABLED=false，无调用处），不测。只在内存里跑：新局与 JsonEx 往返；不渲染、不写存档。
const fs = require('fs'), path = require('path');
const {APP, start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, encode, restore} = host, Z = w.CodexZhenqi, G = w.CodexGuide;
const cases = [];
const ROUTE_SWITCHES = [2500, 2494, 2489, 2461, 2487, 2462, 2483, 2463];
const actor = id => w.$gameActors.actor(id);
const setData = (a, d) => { a._codexZhenqi = Object.assign({qi: 0, firsts: {}, realm: 0, pending: [], daofa: {}, spec: {}}, JSON.parse(JSON.stringify(d))); return a; };
const fresh = () => { newGame(); for (const id of ROUTE_SWITCHES) w.$gameSwitches.setValue(id, false); delete w.$gameSystem._codexGuideSeen; };
function setupWorld(opts) {
  if (opts.route) w.$gameSwitches.setValue(opts.route, true);
  if (opts.progress !== undefined) w.$gameVariables.setValue(20, opts.progress + 1);
  if (opts.extra) for (const id of opts.extra) w.$gameParty.addActor(id);
  for (const [id, d] of Object.entries(opts.data || {})) setData(actor(+id), d);
  if (opts.supplyFirst) w.$gameSystem._codexRaceSupply = {counts: {}, first: Object.fromEntries(opts.supplyFirst.map(k => [k, true])), inbox: {}};
}
const noZones = fn => { const K = w.CodexZones; w.CodexZones = undefined; try { return fn(); } finally { w.CodexZones = K; } };
const pagesOf = texts => { const L = []; texts.forEach(t => { L.push({code: 101, indent: 0, parameters: ['', 0, 0, 2]}, {code: 401, indent: 0, parameters: ['<WordWrap>' + t]}); }); L.push({code: 0, indent: 0, parameters: []}); return L; };

// 区段表与楼层→区段（floorNow＝修行进度层 Z.progressFloor）
cases.push(makeCase('atlas', {}, () => JSON.parse(JSON.stringify(G.ATLAS))));
cases.push(makeCase('segment.floors', {}, () => { fresh(); const out = [];
  for (let v = 0; v <= 36; v++) { w.$gameVariables.setValue(20, v); const f = Z.progressFloor(), seg = G.segmentOf(f); out.push([v, f, seg ? seg.key : null]); }
  return out; }));

// 区段里程碑：每段的文字与原版插入的指令列（每页 101＋401 <WordWrap>，末尾结束指令）
for (const seg of G.ATLAS) cases.push(makeCase('milestone.' + seg.key, {segment: seg.key}, () => { fresh(); const t = G.milestoneTexts(seg); return {texts: t, list: pagesOf(t)}; }));
// Scene_Map.update 的判定：当前区段与是否已看过（看过就不再弹）
cases.push(makeCase('milestone.pick', {}, () => { const out = [];
  for (const [label, progress, seen] of [['new', 0, []], ['seenA', 0, ['seg:a']], ['f7', 7, ['seg:a']], ['f7.fresh', 7, []], ['f33', 33, []], ['f36', 36, []]]) {
    fresh(); w.$gameVariables.setValue(20, progress + 1); for (const k of seen) G.seen(k, true);
    const seg = G.segmentOf(Z.progressFloor()); out.push([label, seg ? seg.key : null, seg ? G.seen('seg:' + seg.key) : null]);
  }
  return out; }));
// 已看过标记在 $gameSystem._codexGuideSeen，随存档
cases.push(makeCase('milestone.save', {}, () => { fresh(); G.seen('seg:a', true); G.seen('seg:b', true); const json = encode(); fresh(); const before = G.seen('seg:a'); restore(json);
  return {beforeRestore: before, a: G.seen('seg:a'), b: G.seen('seg:b'), c: G.seen('seg:c'), raw: JSON.parse(JSON.stringify(w.$gameSystem._codexGuideSeen || null))}; }));

// 「下一步建议」：完整文字（含 CodexZones 战力短板）与去掉 CodexZones 的文字
const A = (id, opts) => cases.push(makeCase('advice.' + id, opts, () => {
  fresh(); setupWorld(opts); const full = G.adviceTexts(); const plain = noZones(() => G.adviceTexts());
  return {texts: plain, full, list: pagesOf(plain)}; }));
A('default', {});
A('f3', {progress: 3});
A('f7.pending', {progress: 7, data: {1: {qi: 3000, realm: 1, pending: [1]}, 8: {qi: 700}}});
A('f12.capOnly', {progress: 12, data: {1: {qi: 700}, 8: {qi: 700}, 9: {qi: 700}, 10: {qi: 700}}});
A('f6.capped', {progress: 6, data: {1: {qi: 700}}});
A('f20.hard', {progress: 20, route: 2500, data: {1: {qi: 26000, realm: 4}}});
A('f25.supplyFirst', {progress: 25, supplyFirst: ['2', '3', '4', '5']});
A('f16.supplyFirst', {progress: 16, supplyFirst: ['4']});
A('f33', {progress: 33});
A('calamity.f10', {progress: 10, route: 2461});
A('many', {progress: 7, extra: [2, 3, 4, 5, 6], data: {1: {pending: [1], realm: 1, qi: 3000}, 2: {pending: [1], realm: 1, qi: 3000}, 3: {pending: [1], realm: 1, qi: 3000},
  4: {pending: [1], realm: 1, qi: 3000}, 5: {pending: [1], realm: 1, qi: 3000}, 6: {pending: [1], realm: 1, qi: 3000}, 8: {pending: [1], realm: 1, qi: 3000}, 9: {qi: 700}, 10: {qi: 700}}});
A('manyCap', {progress: 7, extra: [2, 3, 4, 5, 6], data: {1: {qi: 700}, 2: {qi: 700}, 3: {qi: 700}, 4: {qi: 700}, 5: {qi: 700}, 6: {qi: 700}}});

// 方桌大厅「商店向导」（Map004 事件 73）的指令列：Godot 测试用它跑完整流程
cases.push(makeCase('shopGuide.event', {map: 4, event: 73}, () => {
  const m = JSON.parse(fs.readFileSync(path.join(APP, 'data', 'Map004.json'), 'utf8')), ev = m.events[73];
  return {name: ev.name, note: ev.note, x: ev.x, y: ev.y, list: ev.pages[0].list}; }));
cases.push(makeCase('race.bands', {}, () => ({bands: w.$dataCodexRaces.bands, stones: w.$dataCodexRaces.stones.map(id => [id, w.$dataItems[id].name])})));

process.exit(finish(host, 'guide.json', {hostScope: '真实 CodexGuide（v2.1）与 CodexZhenqi、$dataCodexRaces、JsonEx；无渲染。advice.* 的 texts 去掉了 CodexZones（五乘区不移植），full 为原版完整文字', cases}) ? 0 : 1);
