'use strict';
// 增量同步的分片合并（incremental_sync.SHARDS）：本次只跑了部分单元（敌群／地图）的探针产物，
// 与上次的完整产物按全量运行时的顺序拼回一份。只读 generated/oracle 与 .sandbox，不碰正式源和存档。
// 用 Node 合并、按探针原样 JSON.stringify，保证与全量产物逐字节一致。
// 用法：node oracle_shard_merge.cjs <spec.json>
//   spec = {kind: 'troops'|'events'|'slice-actors', order: [单元…], ran: [本次跑了的单元…],
//           files: [{old: 上次产物, fresh: 本次产物或 null, out: 写到哪, indent: 1|null}]}
// slice-actors 的 order：先 a<角色>，再每个敌群依次 t<敌群>、t<敌群>:a<角色>、t<敌群>:enemy。
// 调用者必须先校验共同输入与出状态；本工具只恢复原列表顺序，不据此假定角色测量互相独立。
const fs = require('fs');
const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ran = new Set(spec.ran), order = spec.order;
const unitOf = {
  troops: r => String(r.troop),
  events: r => r.kind === 'common' ? 'ce' + r.common : 'm' + r.map,
  'slice-actors': r => {
    if (!Number.isInteger(r.troop)) throw new Error('角色伤害行缺敌群');
    if (Number.isInteger(r.actor)) return 't' + r.troop + ':a' + r.actor;
    if (Number.isInteger(r.enemy) && r.target === 9) return 't' + r.troop + ':enemy';
    throw new Error('未知角色伤害行（敌方固定目标须为 9）');
  },
}[spec.kind];
if (!unitOf) throw new Error('未知分片类型：' + spec.kind);
// 各类产物里按单元分组的列表／字典
const LISTS = {troops: ['cases', 'damage'], events: ['cases'], 'slice-actors': ['damage']}[spec.kind];
const DICTS = {troops: ['enemies'], events: [], 'slice-actors': ['actors', 'enemies']}[spec.kind];
const dictKey = (name, unit) => {
  if (spec.kind !== 'slice-actors') return unit;
  const match = unit.match(name === 'actors' ? /^a(\d+)$/ : /^t(\d+)$/);
  return match ? match[1] : null;
};
if (spec.kind === 'slice-actors') {
  if (new Set(order).size !== order.length || ran.size !== spec.ran.length) throw new Error('角色分片单元重复');
  const actors = [], troops = [];
  for (const u of order) {
    if (/^a\d+$/.test(u)) actors.push(u.slice(1));
    else if (/^t\d+$/.test(u)) troops.push(u.slice(1));
  }
  const expected = actors.map(a => 'a' + a);
  for (const t of troops) expected.push('t' + t, ...actors.map(a => 't' + t + ':a' + a), 't' + t + ':enemy');
  if (JSON.stringify(expected) !== JSON.stringify(order)) throw new Error('角色分片顺序不符合全量顺序');
  if ([...ran].some(u => !order.includes(u))) throw new Error('本次角色分片不在全量顺序中');
}

function group(list) {
  const out = new Map();
  for (const r of list) {
    const u = unitOf(r);
    if (!out.has(u)) out.set(u, []);
    out.get(u).push(r);
  }
  return out;
}

for (const f of spec.files) {
  const old = JSON.parse(fs.readFileSync(f.old, 'utf8'));
  const fresh = f.fresh ? JSON.parse(fs.readFileSync(f.fresh, 'utf8')) : null;
  // 非分片部分（来源身份、开局设定、行动序列等）取本次运行；没跑探针时沿用上次
  const merged = Object.assign({}, fresh || old);
  for (const name of LISTS) {
    if (!Array.isArray(old[name]) && !(fresh && Array.isArray(fresh[name]))) continue;
    const a = group(old[name] || []), b = group(fresh ? fresh[name] || [] : []);
    merged[name] = [];
    // 单元在列表里可以没有记录（如无事件的地图），所以这里不查缺失；字典每个单元必有一项，下面查
    for (const u of order) merged[name].push(...((ran.has(u) ? b : a).get(u) || []));
  }
  for (const name of DICTS) {
    if (!old[name] && !(fresh && fresh[name])) continue;
    merged[name] = {};
    for (const u of order) {
      const key = dictKey(name, u);
      if (key === null) continue;
      const src = ran.has(u) ? (fresh[name] || {}) : old[name];
      if (Object.prototype.hasOwnProperty.call(src, key)) merged[name][key] = src[key];
      else if (spec.kind === 'slice-actors') throw new Error('角色分片产物缺单元 ' + u + '（' + name + '）');
      else if (!ran.has(u)) throw new Error('上次产物缺单元 ' + u + '（' + name + '）');
    }
  }
  fs.writeFileSync(f.out, f.indent ? JSON.stringify(merged, null, f.indent) : JSON.stringify(merged));
}
