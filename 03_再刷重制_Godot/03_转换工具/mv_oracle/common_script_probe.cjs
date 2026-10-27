'use strict';
// 效果型公共事件里的几类脚本（八戒 2026-10-27，期一）：事件对照（event_probe）只能以「没有选中角色、玩家在大厅 0,0」跑这些公共事件，
// 脚本多半在第一行就出错退出；这里给出真实使用时的前提，逐例运行同一公共事件，记录提示／场景／预约公共事件与关心的状态。
// ① 遗忘技能类 CE637～648、1378～1380（$gameParty._targetActorId 选中角色 + hasSkill/forgetSkill/learnSkill）、CE83（Star.RunForgetSkill 打开遗忘界面）；
// ② 藏宝图 CE117、174～189、1381～1384（Star.RomGetItems.RunGetFun：不在目标格提示坐标，在目标格按预掷池挖宝，挖完一轮重置）；
// ③ 超强者招募 CE2501～2526（非地狱难度：提示后不入队，装备照给；已持有不重复给）；
// ④ CE367 牛头人酋长（indexOf(-33)==-1 才 push(-12)）。
// 每例：内存新游戏（host.cjs newGame：大厅、队伍 1/8/9/10、Math.random 0.5），难度 3，按 setup 预置后用 Game_Interpreter 跑完该公共事件。
// 只在内存，不读写存档；ConfigManager 只改内存（不 save）。产物 .sandbox/common_scripts.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;

let trace = [];
if (w.$) w.$.toaster = o => trace.push({t: 'toast', text: String(o && (o.message || o.title) || '')});
w.SceneManager.push = cls => trace.push({t: 'scene', name: cls && cls.name || String(cls)});
w.ConfigManager.save = function() {};
// 脚本与插件（MOG_TreasurePopup 等）读 SceneManager._scene：给一个地图场景替身，未知方法一律空操作（同 event_probe）
const sceneStub = new Proxy(Object.create(w.Scene_Map.prototype), {
  get(o, k) {
    if (k === 'constructor') return w.Scene_Map;
    if (typeof k === 'symbol' || Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    return function() {};
  },
  set(o, k, v) { o[k] = v; return true; }
});

function baseCount(table, data, id) {
  let n = 0;
  for (const k of Object.keys(table)) {
    const it = data[k], base = it && (it.originalBaseItemId || it.baseItemId) || Number(k);
    if (base === id) n += table[k];
  }
  return n;
}
function observe(spec) {
  const watch = spec.watch || {}, a = spec.target ? w.$gameActors.actor(spec.target) : null;
  return {
    trace: trace.slice(),
    variables: (watch.vars || []).map(id => { const v = w.$gameVariables.value(id); return typeof v === 'number' ? v : 0; }),
    items: (watch.items || []).map(id => w.$gameParty.numItems(w.$dataItems[id])),
    weapons: (watch.weapons || []).map(id => baseCount(w.$gameParty._weapons, w.$dataWeapons, id)),
    armors: (watch.armors || []).map(id => baseCount(w.$gameParty._armors, w.$dataArmors, id)),
    skills: a ? (watch.skills || []).filter(id => a.isLearnedSkill(id)) : [],
    party: w.$gameParty._actors.slice(),
    reserved: w.$gameTemp._commonEventId || 0,
    romGetNum: Number(w.$gameParty.RomGetNum || 0),
    dug: Object.keys(w.$gameParty.GameMapxy || {}).filter(k => w.$gameParty.GameMapxy[k]).map(Number).sort((x, y) => x - y),
    clothes: (watch.clothes || []).filter(id => w.ConfigManager.ChangeClothesLite.indexOf(id) >= 0)
  };
}
function run(spec) {
  newGame();
  w.$gameSystem._difficultyId = spec.difficulty || 3;
  w.Math.random = () => spec.random === undefined ? 0.5 : spec.random;
  w.ConfigManager.ChangeClothesLite = (spec.clothes || []).slice();
  if (spec.target) {
    const a = w.$gameActors.actor(spec.target);
    (spec.learn || []).forEach(id => a.learnSkill(id));
    w.$gameParty.setTargetActor(a);
  }
  Object.entries(spec.vars || {}).forEach(([k, v]) => w.$gameVariables.setValue(Number(k), v));
  Object.entries(spec.gainItems || {}).forEach(([k, v]) => w.$gameParty.gainItem(w.$dataItems[Number(k)], v));
  Object.entries(spec.gainWeapons || {}).forEach(([k, v]) => w.$gameParty.gainItem(w.$dataWeapons[Number(k)], v));
  Object.entries(spec.gainArmors || {}).forEach(([k, v]) => w.$gameParty.gainItem(w.$dataArmors[Number(k)], v));
  (spec.switches || []).forEach(id => w.$gameSwitches.setValue(id, true));
  if (spec.at) { w.$gameMap._mapId = spec.at[0]; w.$gamePlayer.setPosition(spec.at[1], spec.at[2]); }
  if (spec.rom) { w.$gameParty.RomGet = spec.rom.slice(); w.$gameParty.RomGetNum = spec.romNum || 0; }
  if (spec.dug) { w.$gameParty.GameMapxy = {}; spec.dug.forEach(id => { w.$gameParty.GameMapxy[id] = true; }); }
  w.$gameTemp.clearCommonEvent();
  w.SceneManager._scene = sceneStub;
  trace = [];
  const it = new w.Game_Interpreter();
  it.setup(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[spec.common].list), 0);
  for (let f = 0; f < 600 && it.isRunning(); f++) {
    w.Graphics.frameCount++;
    it.update();
    if (w.$gameMessage.isBusy()) { trace.push({t: 'msg', lines: w.$gameMessage._texts.slice()}); w.$gameMessage.clear(); }
  }
  if (it.isRunning()) throw new Error('公共事件没跑完');
  return observe(spec);
}

const P = w.Star.RomGetItems.GameMapxy;
const spot = id => [Number(P[id].mapId), Number(P[id].x), Number(P[id].y)];
const specs = [];
const add = (id, spec) => specs.push(Object.assign({id}, spec));
// ① 元素转换 637～644：遗忘 5068～5075 中已会的（变量 314＝1），再学本元素；选中角色 8（不是队首）
const ELEM = [5068, 5069, 5070, 5071, 5072, 5073, 5074, 5075];
for (let ce = 637; ce <= 644; ce++) {
  const watch = {vars: [314, 348, 350], skills: ELEM};
  add(`forget.${ce}.has`, {common: ce, target: 8, learn: [5068 + ((ce - 637 + 3) % 8)], watch});
  add(`forget.${ce}.none`, {common: ce, target: 8, watch});
}
add('forget.637.leader', {common: 637, target: 1, learn: [5070, 5071], watch: {vars: [314, 348, 350], skills: ELEM}});
// 小药丸 645～648：已会 i 或 k 才进阶（变量 347 随机 1～100，≥90 学高阶）；都不会则提示并返还药丸；副本里（变量 5≠0）提示并返还
const PILL = {645: [1240, 5091, 5095, 1043], 646: [1241, 5092, 5096, 1044], 647: [1242, 5093, 5097, 1045], 648: [1244, 5094, 5098, 1046]};
for (const [ce, [i, k, hi, item]] of Object.entries(PILL)) {
  const watch = {vars: [347, 348, 350], skills: [i, k, hi], items: [item]};
  add(`pill.${ce}.i`, {common: +ce, target: 8, learn: [i], watch});
  add(`pill.${ce}.k`, {common: +ce, target: 8, learn: [k], watch});
  add(`pill.${ce}.none`, {common: +ce, target: 8, watch});
  add(`pill.${ce}.high`, {common: +ce, target: 8, learn: [i], random: 0.95, watch});
  add(`pill.${ce}.dungeon`, {common: +ce, target: 8, learn: [i], vars: {5: 2}, watch});
}
// 滑稽拳 1378～1380：会前一级才换下一级，否则返还技能书并提示
const FIST = {1378: [2852, 2853, 1123], 1379: [2853, 2854, 1143], 1380: [2854, 2855, 1163]};
for (const [ce, [from, to, book]] of Object.entries(FIST)) {
  const watch = {skills: [from, to], items: [book]};
  add(`fist.${ce}.has`, {common: +ce, target: 8, learn: [from], watch});
  add(`fist.${ce}.none`, {common: +ce, target: 8, watch});
}
add('forget.83', {common: 83, target: 8, watch: {}});
// ② 藏宝图：不在目标格（大厅 0,0）；在目标格按预掷值走四类（物品／防具／武器／公共事件）；已挖过的跳到下一个；一轮挖完重置
const MAPS = {117: [1, 10], 174: [11, 14], 175: [15, 18], 176: [19, 22], 177: [23, 25], 178: [26, 28], 179: [29, 32], 180: [33, 36],
  181: [37, 40], 182: [41, 44], 183: [45, 48], 184: [49, 53], 185: [54, 57], 186: [58, 61], 187: [62, 65], 188: [66, 69], 189: [1, 10],
  1381: [76, 79], 1382: [80, 83], 1383: [84, 87], 1384: [88, 91]};
const ROM = v => Array(20).fill(v);
for (const [ce, [a, b]] of Object.entries(MAPS)) {
  const it = Number(P[a].ItID), watch = {items: [it, ...P[a].item.slice(0, 3)], weapons: P[a].Weapons.slice(0, 3), armors: P[a].Armors.slice(0, 3)};
  add(`map.${ce}.away`, {common: +ce, gainItems: {[it]: 1}, watch});
  add(`map.${ce}.item`, {common: +ce, gainItems: {[it]: 1}, at: spot(a), rom: ROM(1), watch});
  add(`map.${ce}.next`, {common: +ce, gainItems: {[it]: 1}, at: spot(a + 1), rom: ROM(2), dug: [a], watch});
}
const T = 11, it174 = Number(P[T].ItID), w174 = {items: [it174, ...P[T].item.slice(0, 4)], weapons: P[T].Weapons.slice(0, 4), armors: P[T].Armors.slice(0, 4)};
add('map.174.armor', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(22), watch: w174});
add('map.174.weapon', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(43), watch: w174});
add('map.174.event', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(61), watch: w174});
add('map.174.romnum', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(1), romNum: 7, watch: w174});
add('map.174.refresh', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(1), romNum: 16, watch: w174});
add('map.174.short', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: Array(35).fill(1), watch: w174});
add('map.174.alldug', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(1), dug: [11, 12, 13, 14], watch: w174});
add('map.174.alldug-away', {common: 174, gainItems: {[it174]: 1}, rom: ROM(1), dug: [11, 12, 13, 14], watch: w174});
add('map.174.dug-here', {common: 174, gainItems: {[it174]: 1}, at: spot(T), rom: ROM(1), dug: [11], watch: w174});
add('map.174.noitem', {common: 174, at: spot(T), rom: ROM(1), watch: w174});
// ③ 超强者招募：非地狱（难度 3）提示后不入队；挑战开关 2494 打开时入队；已持有装备不重复给
const recruits = [];
for (let ce = 2501; ce <= 2526; ce++) {
  const list = w.$dataCommonEvents[ce].list, add129 = list.find(c => c.code === 129);
  const code = list.filter(c => c.code === 355 || c.code === 655).map(c => String(c.parameters[0])).join('\n');
  const weapons = [...code.matchAll(/\$dataWeapons\[(\d+)\]/g)].map(m => +m[1]), armors = [...code.matchAll(/\$dataArmors\[(\d+)\]/g)].map(m => +m[1]);
  recruits.push(ce);
  const watch = {weapons: [...new Set(weapons)], armors: [...new Set(armors)]};
  add(`super.${ce}.d3`, {common: ce, watch});
  add(`super.${ce}.open`, {common: ce, switches: [2494], watch});
  if (add129) add(`super.${ce}.held`, {common: ce, switches: [2494], gainWeapons: Object.fromEntries(watch.weapons.map(id => [id, 1])),
    gainArmors: Object.fromEntries(watch.armors.map(id => [id, 1])), watch});
}
// ④ CE367：变量 100 掷到 1 才解锁（Math.random 0 → 1）；-33 已在表里时不写 -12
add('clothes.367.none', {common: 367, random: 0, watch: {clothes: [-12, -33]}});
add('clothes.367.has33', {common: 367, random: 0, clothes: [-33], watch: {clothes: [-12, -33]}});
add('clothes.367.has12', {common: 367, random: 0, clothes: [-12], watch: {clothes: [-12, -33]}});
add('clothes.367.miss', {common: 367, watch: {clothes: [-12, -33]}});

const cases = specs.map(spec => makeCase(spec.id, spec, () => run(spec)));
process.exit(finish(host, 'common_scripts.json', {scope: 'Effect common events with script calls: forget/learn on $gameParty._targetActorId, Star.RomGetItems.RunGetFun treasure maps, super-strong recruit horns, CE367 costume unlock. Native Game_Interpreter; toaster/scene recorded.', cases}) ? 0 : 1);
