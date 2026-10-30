'use strict';
// 【Claude·白龙_5·未经审查】兑换大厅 Map132 商店追加伙伴号角／专属法宝的参照：shop_buy_probe 不设地图（$gameMap.mapId()＝0），
// 各 installNative…Runtime 只在 Map132 改商品表，那里量不到。这里把 Map132 每家店（事件指令 302＋605）在 mapId＝132 与对照
// mapId＝131 下各跑一次正式 Scene_Shop.prepare 整条链，记整理前后的商品表 [类型, ID, 价格类型, 指定价]。
// 只写 .sandbox/map132_shops.json。用法：node map132_shop_probe.cjs
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const MAP = 132, CONTROL = 131;
const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();');
const map = JSON.parse(fs.readFileSync(path.join(APP, 'data', `Map${String(MAP).padStart(3, '0')}.json`), 'utf8'));
const cases = [];
for (const ev of map.events || []) if (ev) ev.pages.forEach((page, p) => {
  for (let i = 0; i < page.list.length; i++) {
    const c = page.list[i];
    if (c.code !== 302) continue;
    const raw = [c.parameters.slice(0, 4).map(Number)];
    for (let j = i + 1; j < page.list.length && page.list[j].code === 605; j++) raw.push(page.list[j].parameters.slice(0, 4).map(Number));
    for (const mapId of [MAP, CONTROL]) {
      w.$gameMap._mapId = mapId;
      const sc = Object.create(w.Scene_Shop.prototype);
      sc.prepare(raw.map(x => x.slice()), !!c.parameters[4]);
      cases.push({id: `ev${ev.id}_p${p}_i${i}_m${mapId}`, event: ev.id, page: p, index: i, mapId, raw,
        prepared: sc._goods.map(x => x.slice(0, 4).map(Number))});
    }
  }
});
w.$gameMap._mapId = 0;
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/map132_shops.json'), JSON.stringify({sourceIdentity: identity, cases}, null, 1));
console.log(JSON.stringify({cases: cases.length, changed: cases.filter(x => JSON.stringify(x.raw) !== JSON.stringify(x.prepared)).length}));
process.exit(0);
