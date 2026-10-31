'use strict';
// 【cc·悟空·未经审查】飞艇状态与表现定向参照（75% 审查建议：xiyou_airship_state／view 原来只有读码断言）。
// ① state：新局三种载具（loadSystemSettings）、条件分支 13（走路／乘飞艇）、四处原版事件里写飞艇的 202（Map003 EV4、CE240、CE1002、CE10）
//    逐条执行后飞艇的图号与坐标、202 变量指定＋323 改图＋140 改 BGM＋不存在的载具号。
// ② view：高度 0～48 每档的 screenY／shadowX／shadowY 相对停地时的偏移、shadowOpacity、screenZ（乘上与停着），带「!」的物件图同列一份；
//    getOn 后逐帧 update 的高度序列（到 isHighest）、getOff 后到 isLowest 的序列。
// 真实冻结插件、全内存新局；只写 .sandbox/airship.json，拷成 tests/fixtures/airship_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const J = o => o == null ? null : w.JSON.parse(w.JSON.stringify(o));
const view = v => ({mapId: v._mapId, x: v._x, y: v._y, direction: v._direction, characterName: v._characterName, characterIndex: v._characterIndex,
  bgm: J(v._bgm), altitude: v._altitude, driving: !!v._driving});
function interp() { const it = new w.Game_Interpreter(); it._list = w.JSON.parse('[{"code":111,"indent":0,"parameters":[]},{"code":0,"indent":0,"parameters":[]}]'); it._index = 0; it._indent = 0; it._branch = w.eval('({})'); return it; }
function exec(code, params) { const it = interp(); it._params = w.JSON.parse(JSON.stringify(params)); it['command' + code](); return it; }
const cases = [];
cases.push(makeCase('state.new', {}, () => {
  newGame();
  return {vehicleType: w.$gamePlayer._vehicleType, vehicles: [0, 1, 2].map(i => view(w.$gameMap.vehicle(i)))};
}));
cases.push(makeCase('state.cond13', {}, () => {
  newGame(); const out = {};
  for (const type of ['walk', 'airship']) {
    w.$gamePlayer._vehicleType = type;
    out[type] = [0, 1, 2].map(i => exec(111, [13, i])._branch[0]);
  }
  return out;
}));
// 原版事件里改飞艇位置的 202（载具 2）：按出现顺序逐条执行，记每条参数与执行后的飞艇
function events() {
  w.DataManager.loadMapData(3); const map3 = w.$dataMap;
  return [['map3.ev4', map3.events[4].pages[0].list], ['ce240', w.$dataCommonEvents[240].list], ['ce1002', w.$dataCommonEvents[1002].list], ['ce10', w.$dataCommonEvents[10].list]];
}
for (const [id, list] of events()) {
  const cmds = list.filter(c => c.code === 202 && c.parameters[0] === 2).map(c => JSON.parse(JSON.stringify(c.parameters)));
  cases.push(makeCase(`state.event.${id}`, {commands: cmds}, () => {
    newGame(); const v = w.$gameMap.airship();
    return cmds.map(p => { exec(202, p); return {params: p, after: view(v)}; });
  }));
}
cases.push(makeCase('state.vars', {vars: {901: 186, 902: 12, 903: 34}}, () => {
  newGame(); w.$gameVariables.setValue(901, 186); w.$gameVariables.setValue(902, 12); w.$gameVariables.setValue(903, 34);
  const bgm = {name: 'Theme_Amara', pan: 0, pitch: 100, volume: 80};
  exec(202, [2, 1, 901, 902, 903]); exec(323, [2, 'SF_Vehicle', 5]); exec(140, [2, bgm]); exec(202, [7, 0, 1, 1, 1]);
  return {vehicles: [0, 1, 2].map(i => view(w.$gameMap.vehicle(i)))};
}));
// ---- ② 表现 ----
function rows(v) {
  const out = [];
  v._altitude = 0; const y0 = v.screenY(), x0 = v.screenX();
  for (let alt = 0; alt <= v.maxAltitude(); alt++) {
    v._altitude = alt;
    out.push({alt, dy: v.screenY() - y0, shadowDx: v.shadowX() - x0, shadowDy: v.shadowY() - y0, shadowOpacity: v.shadowOpacity(), screenZ: v.screenZ()});
  }
  v._altitude = 0;
  return out;
}
for (const [id, name, index] of [['walk', null, null], ['object', '!Flame', 0]]) {
  cases.push(makeCase(`view.rows.${id}`, {image: name}, () => {
    newGame(); const v = w.$gameMap.airship();
    v._mapId = w.$gameMap.mapId(); v.setPosition(5, 5); if (name) v.setImage(name, index);
    v._driving = false; v.refresh(); const parked = {priorityType: v._priorityType, screenZ: v.screenZ(), shiftY: v.shiftY()};
    v._driving = true; v.refresh();
    return {maxAltitude: v.maxAltitude(), parked, flying: {priorityType: v._priorityType, screenZ: v.screenZ()}, rows: rows(v)};
  }));
}
cases.push(makeCase('view.rise_fall', {}, () => {
  newGame(); const v = w.$gameMap.airship();
  v._mapId = w.$gameMap.mapId(); v.setPosition(5, 5); v.refresh();
  const rise = [v._altitude]; v.getOn();
  for (let i = 0; i < 200 && !v.isHighest(); i++) { v.updateAirshipAltitude(); rise.push(v._altitude); }
  const canMoveHigh = v.canMove(); const fall = [v._altitude]; v.getOff();
  for (let i = 0; i < 200 && !v.isLowest(); i++) { v.updateAirshipAltitude(); fall.push(v._altitude); }
  return {rise, fall, canMoveHigh, canMoveLow: v.canMove()};
}));
process.exitCode = finish(host, 'airship.json', {scope: 'airship vehicle state, event 202 targets, altitude view rows, rise/fall', cases}) ? 0 : 1;
process.exit();
