'use strict';
// 【cc·悟空·未经审查】179 流萤技能说明按阶生成（v0.62.12 installLiuyingRuntime 第 15 节 L.skillLines／L.refreshText，v0.62.08）。
// 每个进阶次数（没建角色、0～3、超出 4）各一例：流萤 _AdvancedNum 设成该值后 refreshText(true)，记 10622、10623 的备注、
// customCostText 与 RJO.HE.getDescParams 的行（文字、字号、颜色）。产物 .sandbox/liuying_text.json → tests/fixtures/liuying_text_oracle.json。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node liuying_text_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const L = w.CodexLiuying;
if (!L || typeof L.refreshText !== 'function') throw new Error('流萤模块未安装');
const IDS = [10622, 10623];
const RANKS = [null, 0, 1, 2, 3, 4];
function measure() {
  L.refreshText(true);
  const out = {};
  for (const id of IDS) {
    const sk = w.$dataSkills[id];
    w.RJO.HE.getDescParams(sk, 3);
    out[id] = {note: sk.note, customCostText: sk.customCostText,
      rows: (sk.descParams || []).map(r => Array.isArray(r) ? r.slice(0, 3) : r)};
  }
  return out;
}
const cases = RANKS.map(r => makeCase(r == null ? 'rank.none' : 'rank.' + r, {rank: r}, () => {
  newGame();
  if (w.$gameActors._data[179]) delete w.$gameActors._data[179];
  if (r != null) w.$gameActors.actor(179)._AdvancedNum = r;
  return measure();
}));
process.exit(finish(host, 'liuying_text.json', {hostScope: '流萤技能说明按阶生成（v0.62.12 第 15 节）', cases}) ? 0 : 1);
