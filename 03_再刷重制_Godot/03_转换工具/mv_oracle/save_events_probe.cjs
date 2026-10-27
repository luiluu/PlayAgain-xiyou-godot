'use strict';
// 存读档后的地图事件状态（八戒_77）：冻结 v0.28 的 DataManager.makeSaveContents → JsonEx → extractSaveContents，
// 再照 Scene_File.reloadMapIfUpdated（YEP_SaveCore）：版本号相同不重设地图，事件对象原样还原；版本号不同就同图重载、事件回初始。
// Map004 大厅（只用切片保留的事件）：72 改位置＋朝向、7 强制路线走到一半、65 临时消除、73 路线改不透明度／穿透／图像、36 开自开关 A。
// 新局、不读玩家存档；唯一产物 .sandbox/save_events.json，抄进 tests/fixtures/save_events_oracle.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (!w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const MAP = 4, IDS = [7, 36, 65, 72, 73];
const FIELDS = ['_x', '_y', '_realX', '_realY', '_direction', '_pageIndex', '_erased', '_moveRouteForcing', '_moveRouteIndex',
  '_opacity', '_through', '_characterName', '_characterIndex', '_moveSpeed', '_moveFrequency', '_directionFix', '_transparent',
  '_priorityType', '_stopCount', '_waitCount', '_starting', '_locked'];
const snap = () => Object.fromEntries(IDS.map(id => {
  const e = w.$gameMap.event(id);
  return [id, Object.fromEntries(FIELDS.map(k => [k, e[k] === undefined ? null : e[k]]).concat(
    [['routeLength', e._moveRoute ? e._moveRoute.list.length : null], ['selfA', w.$gameSelfSwitches.value([MAP, id, 'A'])]]))];
}));
const C = (code, parameters) => ({code, parameters: parameters || [], indent: null});

w.eval('ConfigManager.applyData({}); DataManager.setupNewGame();');
w.eval('DataManager.loadMapData(' + MAP + ');');
w.eval('$gameMap.setup(' + MAP + ');');
w.$gamePlayer.locate(14, 14);
const initial = snap();
const m = w.$gameMap;
m.event(72).locate(22, 15); m.event(72).setDirection(8);
m.event(7).forceMoveRoute({list: [C(1), C(1), C(1), C(1), C(0)], repeat: false, skippable: false, wait: false});
for (let i = 0; i < 20; i++) m.event(7).update();          // 走到中途：路线索引 > 0、仍在强制
m.event(73).forceMoveRoute({list: [C(42, [128]), C(37), C(41, ['People1', 3]), C(0)], repeat: false, skippable: true, wait: false});
for (let i = 0; i < 4; i++) m.event(73).update();
m.event(65).erase();
w.$gameSelfSwitches.setValue([MAP, 36, 'A'], true); m.event(36).refresh();
const before = snap();
const mapKeys = Object.keys(m).sort(), eventKeys = Object.keys(m.event(72)).sort();

w.$gameSystem.onBeforeSave();   // DataManager.saveGameWithoutRescue：先记版本号再 makeSaveContents
const json = w.JsonEx.stringify(w.DataManager.makeSaveContents());
w.eval('DataManager.setupNewGame();');
w.DataManager.extractSaveContents(w.JsonEx.parse(json));
// 版本号相同：reloadMapIfUpdated 什么都不做
const sameVersion = w.$gameSystem.versionId() === w.$dataSystem.versionId;
const loaded = snap();
// 版本号不同：同图 reserveTransfer＋requestMapReload → performTransfer 里 $gameMap.setup（事件全部重建）
w.$gamePlayer.reserveTransfer(w.$gameMap.mapId(), w.$gamePlayer.x, w.$gamePlayer.y);
w.$gamePlayer.requestMapReload();
w.$gamePlayer.performTransfer();
const reloaded = snap();

const out = {source: 'rpg_objects Game_Map／Game_Event ＋ YEP_SaveCore reloadMapIfUpdated', sourceIdentity: identity, map: MAP, ids: IDS,
  saveVersionMatches: sameVersion, mapKeys, eventKeys, initial, before, loaded, reloaded, errors: r.errors.slice(0, 5)};
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox', 'save_events.json'), JSON.stringify(out, null, 1));
const diff = (a, b) => Object.fromEntries(IDS.map(id => [id, Object.keys(a[id]).filter(k => JSON.stringify(a[id][k]) !== JSON.stringify(b[id][k]))]));
console.log(JSON.stringify({sameVersion, changedBySetup: diff(initial, before), lostOnLoad: diff(before, loaded), resetOnReload: diff(before, reloaded)}));
process.exit(0);
