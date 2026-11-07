'use strict';
// module_equipment_view 摘取（tools CR，2026-11-06 补）：tests/fixtures/module_equipment_view.json 原是从 cat_probe 产物 stats.sword671 手摘的
// （小猫剑圣 178 带狼腹长剑 671，各等级元素加成 elementBonus，元素 1／2／3／8）。先跑 cat_probe.cjs（同一个 XIYOU_APP），再跑本脚本：
// 读 .sandbox/cat.json 摘出同格式，写 .sandbox/module_equipment_view.json，拷成 tests/fixtures/module_equipment_view.json（不接入全量同步）。
const fs = require('fs'), path = require('path'), crypto = require('crypto'), {execFileSync} = require('child_process');
const {APP} = require('./shared/host.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const file = path.resolve(__dirname, '.sandbox/cat.json'), raw = fs.readFileSync(file);
const cat = JSON.parse(raw), id = sourceIdentity(APP);
if (JSON.stringify(cat.sourceIdentity) !== JSON.stringify(id)) throw new Error('cat.json 不是当前 XIYOU_APP 测的，先重跑 cat_probe.cjs');
const c = cat.cases.find(x => x.id === 'stats.sword671');
if (!c || c.errors.length) throw new Error('cat.json 里 stats.sword671 缺失或有错误');
let commit = '';
try { commit = execFileSync('git', ['-C', __dirname, 'rev-parse', '--short', 'HEAD'], {encoding: 'utf8'}).trim(); } catch (e) {}
const out = {provenance: {probe: 'cat_probe.cjs', commit, sha256: crypto.createHash('sha256').update(raw).digest('hex'), case: c.id},
             runtimeInputs: cat.sourceIdentity.runtimeInputs, setup: c.setup, elementIds: [1, 2, 3, 8],
             rows: Object.fromEntries(Object.entries(c.observed.rows).map(([lv, r]) => [lv, r.elementBonus]))};
fs.writeFileSync(path.resolve(__dirname, '.sandbox/module_equipment_view.json'), JSON.stringify(out, null, 1) + '\n');
console.log(JSON.stringify({file: 'module_equipment_view.json', rows: Object.keys(out.rows).length}));
