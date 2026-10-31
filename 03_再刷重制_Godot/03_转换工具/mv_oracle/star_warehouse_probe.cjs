'use strict';
// 通用仓库参照（Star_Warehouse：Scene_StarSaveWarehouse 存放、Scene_StarWarehouse 取出，黄金大厅 Map041 EV1）。
// 不建画面：真实 Window_StarItemList.makeItemList 出列表，真实 Scene_*.onItemOk（this 只换成带 item()／_itemWindow 的替身）做存取；
// $.toaster 换成记录。新局、背包四件独立装备（皮甲 3、指虎 6、1044、带 <PushDct> 的 52，按这个顺序入手）、三只宠物（敌人 1／2／3，
// 第二只出战）。背包的 weapons()／armors() 按本体编号排（入手是 6、1044、52，列出来是 6、52、1044）。步骤：①存放列表；②存皮甲、存 PushDct 的 52、存第一只宠物、点出战宠物；③setupNewGame 换局（ConfigManager 不清）后
// 取出列表、取出装备第 1 件与宠物第 1 只。记装备的本体编号（baseItemId 追到数据库）与种类、宠物的敌人编号与是否出战、提示。
// 只在内存；产物 .sandbox/star_warehouse.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];

const rootId = o => { const data = w.DataManager.isWeapon(o) ? w.$dataWeapons : w.$dataArmors;
  while (o.baseItemId && o.baseItemId !== o.id && data[o.baseItemId]) o = data[o.baseItemId]; return o.id; };
const gearOf = o => ({kind: w.DataManager.isWeapon(o) ? 'weapon' : 'armor', base: rootId(o), name: o.name});
const petOf = p => ({enemy: p.enemyId(), war: p === w.$gameParty.GTWar});
function list(Save, category) {
  const win = Object.create(w.Window_StarItemList.prototype);
  win.Save = Save; win._category = category; win._data = [];
  win.makeItemList();
  return win._data.slice();
}
function lists(Save) {
  return {equip: list(Save, 'equip').map(gearOf), pets: list(Save, 'Pet').map(petOf)};
}
let toasts = [];
// onItemOk：替身 this（item() 返回 data[i]，_itemWindow 的 refresh／activate 空跑）
function ok(Scene, Save, category, i) {
  const data = list(Save, category);
  const self = {item: () => data[i] === undefined ? null : data[i], _itemWindow: {_category: category, refresh() {}, activate() {}}};
  Scene.prototype.onItemOk.call(self);
}
function bag() {
  return {equip: w.$gameParty.armors().concat(w.$gameParty.weapons()).map(gearOf), pets: (w.$gameParty.Pets || []).map(petOf)};
}
const stored = () => ({equip: w.ConfigManager.GetEq.map(gearOf), pets: w.ConfigManager.GetPet.map(p => ({enemy: p._enemyId}))});

cases.push(makeCase('deposit_withdraw', {gear: [['armor', 3], ['weapon', 6], ['weapon', 1044], ['weapon', 52]], pets: [1, 2, 3], war: 1}, () => {
  newGame();
  w.$ = w.$ || {}; w.$.toaster = o => toasts.push(o.message);
  // 数组要用游戏窗口里的 Array（rpg_core 给它加了 remove）
  w.ConfigManager.GetEq = new w.Array(); w.ConfigManager.GetPet = new w.Array();
  w.$gameParty.gainItem(w.$dataArmors[3], 1); w.$gameParty.gainItem(w.$dataWeapons[6], 1);
  w.$gameParty.gainItem(w.$dataWeapons[1044], 1); w.$gameParty.gainItem(w.$dataWeapons[52], 1);
  const pets = [1, 2, 3].map(id => new w.Game_Enemy(id, 0, 0));
  w.$gameParty.Pets = w.Array.from(pets); w.$gameParty.GTWar = pets[1];
  const rows = [];
  rows.push({step: 'save_lists', lists: lists(true)});
  ok(w.Scene_StarSaveWarehouse, true, 'equip', 0);  // 皮甲 3（防具在前）
  rows.push({step: 'deposit_armor', bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  const pushIndex = list(true, 'equip').findIndex(o => rootId(o) === 52);
  ok(w.Scene_StarSaveWarehouse, true, 'equip', pushIndex);
  rows.push({step: 'deposit_pushdct', index: pushIndex, bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  ok(w.Scene_StarSaveWarehouse, true, 'Pet', 0);
  rows.push({step: 'deposit_pet', bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  ok(w.Scene_StarSaveWarehouse, true, 'Pet', 0);  // 现在第 1 只是出战的那只
  rows.push({step: 'deposit_war_pet', bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  ok(w.Scene_StarSaveWarehouse, true, 'equip', 99);  // 空格：没有反应
  rows.push({step: 'deposit_empty', bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  w.$gameParty.GTWar = null; w.$gameParty.Pets = new w.Array();  // 换局时宠物系统的 TeamALearn 会读旧队伍的出战宠物
  const keep = [w.ConfigManager.GetEq, w.ConfigManager.GetPet];  // 配置跨局保留（探针的 newGame 会重置 ConfigManager）
  newGame(); w.$gameParty.Pets = new w.Array(); [w.ConfigManager.GetEq, w.ConfigManager.GetPet] = keep;
  rows.push({step: 'withdraw_lists', lists: lists(false), bag: bag()});
  ok(w.Scene_StarWarehouse, false, 'equip', 0);
  ok(w.Scene_StarWarehouse, false, 'Pet', 0);
  rows.push({step: 'withdraw', bag: bag(), stored: stored(), toasts: toasts.splice(0)});
  return {rows};
}));

process.exit(finish(host, 'star_warehouse.json', {hostScope: '新游戏（Math.random 0.5）；真实 makeItemList／onItemOk，画面换成替身', cases}) ? 0 : 1);
