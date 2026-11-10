#!/usr/bin/env node
// 生成状态详情面板的参照（ui-pixel4）：从原版 installEquipmentStatusRuntime 原样取出 text／pct／traitDescription／
// stateDescription／visibleState，对全部状态算「能不能进状态详情」和说明文字，写 tests/fixtures/state_detail_oracle.json。
// Godot 的 XPartyStatusPanel.description 与 XSideStatus.visible_state 逐个对照（xiyou_party_status_panel）。
// 用法：node 生成状态详情参照.cjs [app.nw 路径]   （默认 02_内容与素材/冻结正式源/app.nw）
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const APP = path.resolve(process.argv[2] || path.join(ROOT, '02_内容与素材/冻结正式源/app.nw'));
const OUT = path.join(ROOT, '01_Godot工程/tests/fixtures/state_detail_oracle.json');
const src = fs.readFileSync(path.join(APP, 'js/codex/runtime/installEquipmentStatusRuntime.js'), 'utf8');
const data = f => JSON.parse(fs.readFileSync(path.join(APP, 'data', f), 'utf8'));
function grab(name) {
  const at = src.indexOf('function ' + name + '(');
  if (at < 0) throw new Error('找不到 ' + name);
  let i = src.indexOf('{', at), depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}' && --depth === 0) break;
  }
  return src.slice(at, i + 1);
}
function grabVar(name) {
  const m = new RegExp('var ' + name + '\\s*=\\s*(\\[[^\\]]*\\])').exec(src);
  if (!m) throw new Error('找不到 var ' + name);
  return 'var ' + name + '=' + m[1] + ';';
}
const $dataStates = data('States.json'), $dataSystem = data('System.json'), $dataSkills = data('Skills.json');
const code = [grabVar('params'), grabVar('xparams'), ...['text', 'pct', 'traitDescription', 'stateDescription', 'visibleState'].map(grab),
  'return {stateDescription, visibleState};'].join('\n');
const api = new Function('$dataStates', '$dataSystem', '$dataSkills', 'window', code)($dataStates, $dataSystem, $dataSkills, {});
const out = {};
for (const s of $dataStates) {
  if (!s) continue;
  out[s.id] = [!!api.visibleState(s), api.stateDescription(s)];
}
fs.writeFileSync(OUT, JSON.stringify({ source: path.basename(path.dirname(APP)), states: out }) + '\n');
console.log('写入', OUT, Object.keys(out).length, '个状态');
process.exit(0);
