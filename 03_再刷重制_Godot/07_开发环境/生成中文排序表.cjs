#!/usr/bin/env node
// 生成 Godot 用的中文排序表 core/zh_collate_data.gd（rules-passive-order1）。
// 原版状态格（installEquipmentStatusRuntime stateRows）同类按 a.name.localeCompare(b.name,'zh-Hans') 排；
// Godot 没有 ICU 排序，这里用 Node 的 Intl.Collator('zh-Hans')（ICU 拼音序，汉字排在拉丁字母前）给单字定序：
//   每个字记「一级序」（sensitivity:'base' 相等的同组）和「三级序」（默认比较相等的同组），可忽略字（比较等于空串）单列。
// XZhCollate 先逐字比一级序、再比长度，然后逐字比三级序——单字无扩展时与 ICU 的整串分级比较一致。
// 自检：用同样的算法给原版全部状态名＋强弱化名排序，必须与 Intl.Collator 的排序逐项相同，否则不写文件。
// 用法：node 生成中文排序表.cjs [app.nw 路径]   （默认 02_内容与素材/冻结正式源/app.nw）
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const APP = path.resolve(process.argv[2] || path.join(ROOT, '02_内容与素材/冻结正式源/app.nw'));
const OUT = path.join(ROOT, '01_Godot工程/core/zh_collate_data.gd');
const FIXTURE = path.join(ROOT, '01_Godot工程/tests/fixtures/zh_collate_names.json');

const full = new Intl.Collator('zh-Hans');
const base = new Intl.Collator('zh-Hans', { sensitivity: 'base' });

// 收字：常用区段＋原版数据里所有名字出现过的字
const chars = new Set();
const ranges = [[0x20, 0x7e], [0xa0, 0x24f], [0x2000, 0x206f], [0x2100, 0x21ff], [0x2460, 0x24ff], [0x2500, 0x27bf],
  [0x3000, 0x30ff], [0x4e00, 0x9fff], [0xff00, 0xffef]];
for (const [a, b] of ranges) for (let c = a; c <= b; c++) chars.add(String.fromCodePoint(c));
const data = f => JSON.parse(fs.readFileSync(path.join(APP, 'data', f), 'utf8'));
for (const f of ['States.json', 'Skills.json', 'Items.json', 'Weapons.json', 'Armors.json', 'Actors.json', 'Enemies.json']) {
  for (const o of data(f)) if (o && o.name) for (const ch of o.name) chars.add(ch);
}
// 原版状态格强弱化名：params[id]+(level>0?'强化':'弱化')
const PARAMS = ['生命', '魔法', '物攻', '物防', '魔攻', '魔防', '敏捷', '幸运'];
const buffNames = [];
for (const p of PARAMS) buffNames.push(p + '强化', p + '弱化');
for (const n of buffNames) for (const ch of n) chars.add(ch);

const all = [...chars];
const ignorable = all.filter(ch => full.compare(ch, '') === 0);
const order = all.filter(ch => full.compare(ch, '') !== 0).sort((a, b) => full.compare(a, b) || (a.codePointAt(0) - b.codePointAt(0)));
const pstep = [], tstep = [];
for (let i = 0; i < order.length; i++) {
  pstep.push(i > 0 && base.compare(order[i - 1], order[i]) !== 0 ? 1 : 0);
  tstep.push(i > 0 && full.compare(order[i - 1], order[i]) !== 0 ? 1 : 0);
}

// 同一算法的 JS 版，自检用
const rank = new Map();
let p = 0, t = 0;
order.forEach((ch, i) => { p += pstep[i]; t += tstep[i]; rank.set(ch, [p, t]); });
const ign = new Set(ignorable);
const BIG = 1 << 24;
const keys = s => [...s].filter(ch => !ign.has(ch)).map(ch => rank.get(ch) || [BIG + ch.codePointAt(0), BIG + ch.codePointAt(0)]);
function cmp(a, b) {
  const ka = keys(a), kb = keys(b);
  for (const lv of [0, 1]) {
    for (let i = 0; i < Math.min(ka.length, kb.length); i++) if (ka[i][lv] !== kb[i][lv]) return ka[i][lv] - kb[i][lv];
    if (ka.length !== kb.length) return ka.length - kb.length;
  }
  return 0;
}
const names = [...new Set(data('States.json').filter(s => s && s.name).map(s => s.name).concat(buffNames))];
const want = names.slice().sort((a, b) => a.localeCompare(b, 'zh-Hans'));
const got = names.slice().sort(cmp);
const bad = want.findIndex((n, i) => n !== got[i] && full.compare(n, got[i]) !== 0);
if (bad >= 0) {
  console.error('自检失败：第', bad, '项 ICU', JSON.stringify(want[bad]), '本表', JSON.stringify(got[bad]));
  process.exit(1);
}

const esc = s => [...s].map(ch => {
  const c = ch.codePointAt(0);
  if (ch === '"' || ch === '\\' || c < 0x20 || (c >= 0x7f && c < 0xa0) || (c >= 0x2000 && c <= 0x200f) || (c >= 0x2028 && c <= 0x202f)
      || (c >= 0x2060 && c <= 0x206f) || c === 0xfeff || (c >= 0xfff0)) {
    return c > 0xffff ? '\\U' + c.toString(16).padStart(6, '0') : '\\u' + c.toString(16).padStart(4, '0');
  }
  return ch;
}).join('');
const chunk = (s, n) => { const a = [...s], out = []; for (let i = 0; i < a.length; i += n) out.push(a.slice(i, i + n).join('')); return out; };
const lines = (name, s, n) => `const ${name} := ` + chunk(s, n).map(x => `"${esc(x)}"`).join(' \\\n\t\t+ ') + '\n';
const src = '# 由 07_开发环境/生成中文排序表.cjs 生成，别手改（ICU ' + process.versions.icu + '，Node ' + process.versions.node + '）。\n'
  + '# ORDER：按 Intl.Collator(\'zh-Hans\') 排好的字；PSTEP／TSTEP：该字开始新的一级／三级同组记 1；IGNORE：可忽略的字。\n'
  + 'class_name XZhCollateData\n\n'
  + lines('ORDER', order.join(''), 200) + lines('PSTEP', pstep.join(''), 400) + lines('TSTEP', tstep.join(''), 400)
  + lines('IGNORE', ignorable.join(''), 200);
fs.writeFileSync(OUT, src);
fs.mkdirSync(path.dirname(FIXTURE), { recursive: true });
// 状态格类别参照：从原版 installEquipmentStatusRuntime.js 原样取出 stateKind 函数，对全部状态算「在 _states 里」时的类别
// （passive 为真时恒为「常驻」，不用列）。XSideStatus.state_kind 要逐个相同。
const rt = fs.readFileSync(path.join(APP, 'js/codex/runtime/installEquipmentStatusRuntime.js'), 'utf8');
const m = /function stateKind\(s, passive\) \{[\s\S]*?\n    \}/.exec(rt);
if (!m) { console.error('原版 stateKind 没找到'); process.exit(1); }
const stateKind = new Function(m[0] + '\nreturn stateKind;')();
const kinds = {};
for (const st of data('States.json')) if (st) kinds[st.id] = stateKind(st, false);
// 测试样本：原版全部状态名＋强弱化名按 ICU 排好的顺序（XZhCollate 排出来要逐项相同）
fs.writeFileSync(FIXTURE, JSON.stringify({ icu: process.versions.icu, names: want, kinds }) + '\n');
console.log('写好', path.relative(ROOT, OUT), '字', order.length, '可忽略', ignorable.length, '；样本', want.length, '个名字');
process.exit(0);
