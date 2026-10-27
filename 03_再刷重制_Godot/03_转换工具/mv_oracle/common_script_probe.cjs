'use strict';
// 效果型公共事件里的几类脚本（八戒 2026-10-27，期一）：事件对照（event_probe）只能以「没有选中角色、玩家在大厅 0,0」跑这些公共事件，
// 脚本多半在第一行就出错退出；这里给出真实使用时的前提，逐例运行同一公共事件，记录提示／场景／预约公共事件与关心的状态。
// ① 遗忘技能类 CE637～648、1378～1380（$gameParty._targetActorId 选中角色 + hasSkill/forgetSkill/learnSkill）、CE83（Star.RunForgetSkill 打开遗忘界面）；
// ② 藏宝图 CE117、174～189、1381～1384（Star.RomGetItems.RunGetFun：不在目标格提示坐标，在目标格按预掷池挖宝，挖完一轮重置）；
// ③ 超强者招募 CE2501～2526（非地狱难度：提示后不入队，装备照给；已持有不重复给）；
// ④ CE367 牛头人酋长（indexOf(-33)==-1 才 push(-12)）；
// ⑤ 专属角色号角 9002～9016 的超强者门槛（期三）；⑥⑦ 9011 天衣铺、9018 小猫试炼条件不够时的提示。
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
// 提速：只真开一局，把开局后的游戏对象序列化存下，之后每例重建游戏对象再换回开局副本（同 event_probe 的 NEW_GAME_SNAPSHOT）
const SNAPSHOT_GLOBALS = ['$gameSystem', '$gameScreen', '$gameTimer', '$gameSwitches', '$gameVariables', '$gameSelfSwitches', '$gameActors', '$gameParty', '$gameMap', '$gamePlayer'];
let newGameSave = null;
function freshGame() {
  if (!newGameSave) {
    newGame();
    const o = {independent: [w.DataManager._independentItems, w.DataManager._independentWeapons, w.DataManager._independentArmors]};
    for (const k of SNAPSHOT_GLOBALS) o[k] = w[k];
    newGameSave = w.JsonEx.stringify(o);
    return;
  }
  w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({}); DataManager.createGameObjects(); Graphics.frameCount = 0;');
  const saved = w.JsonEx.parse(newGameSave);
  for (const k of SNAPSHOT_GLOBALS) w[k] = saved[k];
  [w.DataManager._independentItems, w.DataManager._independentWeapons, w.DataManager._independentArmors] = saved.independent;
  w.DataManager.loadIndependentItems();
  w.Input.clear();
}
function run(spec) {
  freshGame();
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
  // 预先入队的角色与等级（开关之后加，超强者要先开 2494）
  (spec.actors || []).forEach(([id, lv]) => { w.$gameParty.addActor(id); if (lv) w.$gameActors.actor(id).changeLevel(lv, false); });
  // 原版开战／读档时 CodexBinding.syncSuperStrong 把备注 <CodexSuperStrong> 的 174／176／177 并入超强者名单；真实流程里早就并过了
  if (spec.sync) w.CodexBinding.syncSuperStrong();
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
    const m = w.$gameMessage;
    if (m.isBusy()) {
      // 选项取默认项（无默认取 0），同 event_probe 与 Godot 的记录替身
      if (m.isChoice()) { const pick = m.choiceDefaultType() >= 0 ? m.choiceDefaultType() : 0; trace.push({t: 'msg', lines: m._texts.slice(), choices: m.choices().slice(), pick}); m.onChoice(pick); }
      else if (m.hasText()) trace.push({t: 'msg', lines: m._texts.slice()});
      m.clear();
    }
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
// 其余读 $gameParty._targetActorId 的效果公共事件（技能书、心法、鲲拳、换装卡等）：按脚本里出现的技能编号预置，
// 「none」什么都不会、「all」全会、「first」只会第一个；战斗中才用的（Game_Action／BattleManager）不在这里
// 1561 迎天劫（全体角色学技能后接画面演出，帧上限内跑不完）不在这里
const covered = new Set([...Array(12)].map((_, i) => 637 + i).concat([1378, 1379, 1380, 1561]));
const scriptOf = list => list.filter(c => c.code === 355 || c.code === 655).map(c => String(c.parameters[0])).join('\n');
for (let ce = 1; ce < w.$dataCommonEvents.length; ce++) {
  const rec = w.$dataCommonEvents[ce];
  if (!rec || covered.has(ce)) continue;
  const code = scriptOf(rec.list);
  if (!code.includes('_targetActorId') || /Game_Action|BattleManager/.test(code)) continue;
  const skills = new Set();
  for (const m of code.matchAll(/(?:hasSkill|forgetSkill|learnSkill)\((\d+)\)|var\s+\w+\s*=\s*(\d+)\s*;/g)) skills.add(Number(m[1] || m[2]));
  for (const m of code.matchAll(/for\s*\(\s*var\s+\w+\s*=\s*(\d+)\s*;\s*\w+\s*<\s*(\d+)/g)) {
    if (Number(m[2]) - Number(m[1]) <= 80 && Number(m[1]) > 200) for (let i = Number(m[1]); i < Number(m[2]); i++) skills.add(i);
  }
  const ids = [...skills].filter(id => w.$dataSkills[id]).sort((a, b) => a - b);
  const vars = [...new Set([...code.matchAll(/setValue\((\d+)/g)].map(m => Number(m[1])).concat(rec.list.filter(c => c.code === 111 && c.parameters[0] === 1).map(c => c.parameters[1])))];
  const items = [...new Set([...code.matchAll(/\$dataItems\[(\d+)\]/g)].map(m => Number(m[1])).concat(rec.list.filter(c => c.code === 126).map(c => c.parameters[0])))];
  const watch = {vars, items, skills: ids};
  add(`gen.${ce}.none`, {common: ce, target: 8, watch});
  if (ids.length) add(`gen.${ce}.all`, {common: ce, target: 8, learn: ids, watch});
  if (ids.length > 1) add(`gen.${ce}.first`, {common: ce, target: 8, learn: [ids[0]], watch});
}
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
// ⑤ 专属角色号角（installBossDifficultyRuntime 给 D.recruitments 的 recruit() 包了一层超强者门槛）：难度 3 挡下（try 写法还号角）；
// 模块已移植的再测挑战开关 2494 放行入队、已在队（try 写法还号角）。都先 syncSuperStrong（见 run）
const HORNS = {9002: [167, 2902, 1], 9003: [168, 2904, 1], 9004: [169, 2931, 1], 9005: [170, 2932, 1], 9006: [171, 2936, 0], 9007: [172, 2938, 1],
  9009: [173, 2940, 1], 9010: [174, 2941, 0], 9012: [175, 2943, 0], 9013: [176, 2945, 0], 9016: [177, 2946, 0]};
for (const [ce, [actor, horn, ported]] of Object.entries(HORNS)) {
  const watch = {items: [horn]};
  add(`horn.${ce}.d3`, {common: +ce, sync: true, watch});
  if (ported) {
    add(`horn.${ce}.open`, {common: +ce, sync: true, switches: [2494], watch});
    add(`horn.${ce}.member`, {common: +ce, sync: true, switches: [2494], actors: [[actor, 0]], watch});
  }
}
// ⑥ 9011 天衣铺：174 云裳不在队、在队不到 20 级都只提示；⑦ 9018 小猫试炼：178 不在队、在队不到 35 级都只提示
add('ce.9011.none', {common: 9011, sync: true});
add('ce.9011.low', {common: 9011, sync: true, switches: [2494], actors: [[174, 19]]});
add('ce.9018.none', {common: 9018, sync: true});
add('ce.9018.low', {common: 9018, sync: true, actors: [[178, 34]]});

const cases = specs.map(spec => makeCase(spec.id, spec, () => run(spec)));
process.exit(finish(host, 'common_scripts.json', {scope: 'Effect common events with script calls: forget/learn on $gameParty._targetActorId, Star.RomGetItems.RunGetFun treasure maps, super-strong recruit horns, CE367 costume unlock, exclusive-actor horns and their gates (9002-9018). Native Game_Interpreter; toaster/scene recorded.', cases}) ? 0 : 1);
