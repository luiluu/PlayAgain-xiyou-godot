'use strict';
// 异化隐藏参照（正式 v0.58 installAlienationHide，O-283）：同一套用例在装隐藏模块（正式默认）和不装（start({skipModules})）的两个引擎里各量一次。
// ① menu：主菜单指令名（Window_MenuCommand.makeCommandList）有没有「异化工坊」。
// ② gain：新局里六件物品各 gainItem 一件，记背包原始容器里的数量、items()／weapons()／armors() 列出的件数、hasItem。
// ③ raw：直接写进背包原始容器（绕过 gainItem，模拟旧档）后列表里看不看得见、hasItem。
// ④ equip：同类普通武器、残刃实例、残刃本体各问一次 canEquip（找新局里能穿同类武器的人）；changeEquip 残刃后身上是什么。
// ⑤ shop：Window_ShopBuy.makeItemList 用含六件与一件普通物品的商品表，列出哪些。
// ⑥ migrate：背包放能量 3、异化石 2、普通物品 1 件，背包里一件异化普通武器（1042 逆骨）、一件残刃、一件异化防具，身上武器栏穿残杖，
//    存档再读档（extractSaveContents 包装跑迁移），记背包、身上、归档字段、标记与还原后的名字。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/alien_hide.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const LEVEL = 30;
const ITEMS = [2872, 2873], WEAPONS = [3980, 3981], ARMORS = [7980, 7981];
const J = x => JSON.parse(JSON.stringify(x === undefined ? null : x));

function measure(host, mode) {
  const {w, newGame} = host, A = w.CodexAlienation, P = () => w.$gameParty;
  if (!A) throw new Error('异化模块未安装');
  const H = w.CodexAlienationHide || null;
  if ((mode === 'hide') !== !!H) throw new Error('隐藏模块安装状态不符：' + mode);
  const base = i => Number(i && (i.originalBaseItemId || i.baseItemId || i.id));
  const rawGear = (key, ids) => Object.keys(P()[key] || {}).filter(id => P()[key][id] > 0)
    .map(id => (key === '_weapons' ? w.$dataWeapons : w.$dataArmors)[id]).filter(i => i && ids.indexOf(base(i)) >= 0).length;
  const listed = () => ({
    items: P().items().filter(i => ITEMS.indexOf(i.id) >= 0).map(i => i.id),
    weapons: P().weapons().filter(i => WEAPONS.indexOf(base(i)) >= 0).map(base),
    armors: P().armors().filter(i => ARMORS.indexOf(base(i)) >= 0).map(base)});
  const cases = [];
  const uncap = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const c = (id, setup, fn) => cases.push(makeCase(mode + '.' + id, setup, fn));

  c('menu', {}, () => {
    newGame();
    const win = Object.create(w.Window_MenuCommand.prototype);
    win._list = [];
    win.makeCommandList();
    return {names: win._list.map(x => x.name), hasWorkshop: win._list.some(x => x.symbol === 'alienation' || x.name === '异化工坊')};
  });

  c('gain', {items: ITEMS, weapons: WEAPONS, armors: ARMORS}, () => {
    newGame();
    P()._items = {}; P()._weapons = {}; P()._armors = {};
    ITEMS.forEach(id => P().gainItem(w.$dataItems[id], 1));
    WEAPONS.forEach(id => P().gainItem(w.$dataWeapons[id], 1));
    ARMORS.forEach(id => P().gainItem(w.$dataArmors[id], 1));
    return {raw: {items: ITEMS.map(id => P()._items[id] || 0), weapons: rawGear('_weapons', WEAPONS), armors: rawGear('_armors', ARMORS)},
      listed: listed(), has: ITEMS.map(id => P().hasItem(w.$dataItems[id]))};
  });

  c('raw', {items: {2872: 3, 2873: 2}}, () => {
    newGame();
    P()._items = {2872: 3, 2873: 2};
    return {listed: listed().items, has: ITEMS.map(id => P().hasItem(w.$dataItems[id])), counts: ITEMS.map(id => P().numItems(w.$dataItems[id]))};
  });

  // 新局角色 1 穿不了残响的武器／防具类型：给 $dataActors[1] 补上这些类型的装备特性（51 武器、52 防具）、等级升到 30（残响 <req_level:25>），残响本该能穿，看隐藏模块挡不挡
  const wearable = [];
  const allow = (code, id) => { const tr = w.$dataActors[1].traits; if (!tr.some(x => x.code === code && x.dataId === id)) { tr.push({code, dataId: id, value: 1}); wearable.push([code, id]); } };
  WEAPONS.forEach(id => allow(51, w.$dataWeapons[id].wtypeId));
  ARMORS.forEach(id => allow(52, w.$dataArmors[id].atypeId));
  c('equip', {actor: 1, hidden: 3980, traits: wearable}, () => {
    newGame();
    const a = w.$gameActors.actor(1);
    uncap(); a.changeLevel(LEVEL, false);  // 残响带 <req_level:25>
    const shard = A.create('w', 3980, 'mob', '');
    const r = {level: a.level, canEquipShard: !!a.canEquip(shard), canEquipShardBase: !!a.canEquip(w.$dataWeapons[3980]), canEquipArmorBase: ARMORS.map(id => !!a.canEquip(w.$dataArmors[id]))};
    P()._weapons[shard.id] = 1;
    a.changeEquip(0, shard);
    const now = a.equips()[0];
    r.afterChange = now ? base(now) : 0;
    return r;
  });

  c('shop', {goods: [[0, 2872], [0, 2873], [1, 3980], [1, 3981], [2, 7980], [2, 7981], [0, 1]]}, () => {
    newGame();
    const win = Object.create(w.Window_ShopBuy.prototype);
    win._shopGoods = [[0, 2872, 0, 0], [0, 2873, 0, 0], [1, 3980, 0, 0], [1, 3981, 0, 0], [2, 7980, 0, 0], [2, 7981, 0, 0], [0, 1, 0, 0]];
    win._money = 0;
    win.makeItemList();
    return {listed: (win._data || []).map(i => (w.DataManager.isItem(i) ? 'i:' : w.DataManager.isWeapon(i) ? 'w:' : 'a:') + base(i))};
  });

  c('migrate', {actor: 1}, () => {
    newGame();
    P()._items = {2872: 3, 2873: 2, 1: 1};
    const a = w.$gameActors.actor(1);
    uncap(); a.changeLevel(LEVEL, false);
    const alienBag = A.create('w', 1042, 'mob', 'inversebone'), shardBag = A.create('w', 3980, 'mob', '');
    // 背包里另放一件异化防具：取第一个有完整随机池、不是残甲残环的防具本体（异化防具本体都要高等级，新局角色穿不上，不放身上）
    const armorKey = Object.keys(A.config.pools).find(k => k.indexOf('a:') === 0 && ARMORS.indexOf(+k.slice(2)) < 0 && A.config.pools[k].length >= 3);
    const alienArmor = A.create('a', +armorKey.slice(2), 'boss', ''), shardWorn = A.create('w', 3981, 'mob', '');
    [alienBag, shardBag].forEach(i => { P()._weapons[i.id] = 1; });
    P()._armors[alienArmor.id] = 1;
    const plainNames = {bag: A.mark(alienBag).plainName, armor: A.mark(alienArmor).plainName};
    a._equips[0].setObject(shardWorn);
    if (w.$gameSystem._alienHiddenV058) delete w.$gameSystem._alienHiddenV058;
    const json = host.encode();
    host.restore(json);
    const ids = Object.keys(P()._weapons).filter(id => P()._weapons[id] > 0).map(id => w.$dataWeapons[id]).filter(Boolean);
    const b = w.$gameActors.actor(1);
    return {
      items: {2872: P()._items[2872] || 0, 2873: P()._items[2873] || 0, 1: P()._items[1] || 0},
      marker: !!w.$gameSystem._alienHiddenV058,
      weaponsListed: P().weapons().map(i => ({base: base(i), alien: !!i._alien, plain: i.name === plainNames.bag})),
      rawShards: ids.filter(i => WEAPONS.indexOf(base(i)) >= 0).length,
      slot0: b.equips()[0] ? base(b.equips()[0]) : 0,
      armorBase: +armorKey.slice(2),
      armorsListed: P().armors().filter(i => base(i) === +armorKey.slice(2)).map(i => ({base: base(i), alien: !!i._alien, plain: i.name === plainNames.armor})),
      stashItems: J(P()._codexAlienHiddenItems), stashEquip: (P()._codexAlienHiddenEquip || []).map(e => ({actorId: e.actorId, slot: e.slot, baseId: e.baseId}))};
  });
  return cases;
}

const hide = start(), plain = start({skipModules: ['installAlienationHide']});
const cases = measure(hide, 'hide').concat(measure(plain, 'plain'));
process.exit(finish(hide, 'alien_hide.json', {hostScope: '新游戏（Math.random 0.5）；装与不装 installAlienationHide 各量一次：主菜单、六件物品得到／可见／装备／商店、读档迁移', cases}) ? 0 : 1);
