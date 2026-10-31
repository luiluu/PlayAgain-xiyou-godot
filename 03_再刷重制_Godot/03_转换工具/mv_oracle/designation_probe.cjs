'use strict';
// 【cc·悟空·未经审查】称号系统（Star_Designation）定向参照：称号表（插件参数 Designation 1～100 → $dataStarDesignationOpt，
// 含 kyo 专属 31 号的登记）、ConfigManager.DesignationN（全局配置，makeData／applyData 往返）、事件脚本「ConfigManager.DesignationN[N] = true」、
// 条件分支脚本「ConfigManager.DesignationN[N]」、选择称号公共事件（Star.Designation.ComLen）的选项列表与选中后 $gamePlayer 的
// DesignationName／Icon／Color（取消、选到 ???、选到已解锁），以及存档往返（$gamePlayer 进存档）。
// 真实冻结插件、全内存新局；只写 .sandbox/designation.json，拷成 tests/fixtures/designation_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const J = o => o == null ? null : w.JSON.parse(w.JSON.stringify(o));
const cases = [];
// 选择称号公共事件：照 Scene_Title.initialize 里拼的那条 CE，四段脚本（建列表、拼选项文字、弹选项、按 _branch 设称号）
// 正式版在标题画面 initialize 里把这条 CE 接到 $dataCommonEvents 末尾；参照引擎不进标题画面，原样调一次（父类 initialize 换成空函数）
function ensureCe() {
  if (w.Star.Designation.ComLen != null && w.$dataCommonEvents[w.Star.Designation.ComLen]) return;
  const parent = w.Star.Designation.STitle_initialize; w.Star.Designation.STitle_initialize = function () {};
  try { w.Scene_Title.prototype.initialize.call(Object.create(w.Scene_Title.prototype)); } finally { w.Star.Designation.STitle_initialize = parent; }
}
const ce = () => { ensureCe(); return w.$dataCommonEvents[w.Star.Designation.ComLen]; };
function scripts() {
  const out = []; let cur = null;
  for (const c of ce().list) {
    if (c.code === 355) { cur = [c.parameters[0]]; out.push(cur); } else if (c.code === 655 && cur) cur.push(c.parameters[0]);
  }
  return out.map(lines => lines.join('\n'));
}
function choose(unlocked, branch) {
  newGame(); w.ConfigManager.DesignationN = {};
  for (const id of unlocked) w.ConfigManager.DesignationN[id] = true;
  const [build, options, , apply] = scripts();   // 第三段是 setupChoices（弹选项窗），参照里跳过、直接给 _branch
  const it = new w.Game_Interpreter(); it._indent = 0; it._branch = {};
  w.eval('(function(){' + build + '})').call(it); w.eval('(function(){' + options + '})').call(it);
  const choices = J(w.$gamePlayer.Designationsx);
  it._branch[0] = branch;
  // 第三段末尾 RefUserDesignation 画头顶，参照引擎没有地图精灵：换成空函数
  const ref = w.Star.Designation.RefUserDesignation; w.Star.Designation.RefUserDesignation = function () {};
  try { w.eval('(function(){' + apply + '})').call(it); } finally { w.Star.Designation.RefUserDesignation = ref; }
  return {choices, player: {name: w.$gamePlayer.DesignationName, icon: w.$gamePlayer.DesignationIcon, color: w.$gamePlayer.DesignationColor}};
}
cases.push(makeCase('table', {}, () => {
  newGame();
  if (w.CodexKyo && w.CodexKyo.syncDesignation) w.CodexKyo.syncDesignation();
  return {showText: w.Star.Designation.ShowText, offsetY: w.PluginManager.parameters('Star_Designation').offsetY, comLen: (ensureCe(), w.Star.Designation.ComLen), ceLength: ce().list.length,
    list: J(w.$dataStarDesignationOpt).map((d, i) => d ? {id: d.id, name: d.Name, icon: d.Icon, color: d.Color} : null).filter(Boolean)};
}));
cases.push(makeCase('config', {}, () => {
  newGame(); w.ConfigManager.DesignationN = {3: true, 21: true};
  const data = w.ConfigManager.makeData();
  w.ConfigManager.applyData(J(data)); const restored = J(w.ConfigManager.DesignationN);
  w.ConfigManager.applyData({}); const empty = J(w.ConfigManager.DesignationN);
  return {made: J(data.DesignationN), restored, empty};
}));
cases.push(makeCase('script.unlock', {code: 'ConfigManager.DesignationN[16] = true; '}, () => {
  newGame(); w.ConfigManager.DesignationN = {};
  const it = new w.Game_Interpreter(); it._params = ['ConfigManager.DesignationN[16] = true; ']; it._list = [{code: 355, indent: 0, parameters: it._params}, {code: 0, indent: 0, parameters: []}]; it._index = 0;
  it.command355();
  return {after: J(w.ConfigManager.DesignationN)};
}));
cases.push(makeCase('cond.script', {}, () => {
  newGame(); const out = {};
  for (const has of [false, true]) {
    w.ConfigManager.DesignationN = has ? {5: true} : {};
    const it = new w.Game_Interpreter(); it._list = w.JSON.parse('[{"code":111,"indent":0,"parameters":[12,"ConfigManager.DesignationN[5]"]},{"code":0,"indent":0,"parameters":[]}]'); it._index = 0; it._indent = 0; it._branch = {};
    it._params = it._list[0].parameters; it.command111(); out[has ? 'unlocked' : 'locked'] = it._branch[0];
  }
  return out;
}));
for (const [id, unlocked, branch] of [['cancel', [1, 2], -1], ['locked', [1], 1], ['pick', [1, 3, 31], 2], ['pickFirst', [1], 0]]) {
  cases.push(makeCase(`choose.${id}`, {unlocked, branch}, () => choose(unlocked, branch)));
}
cases.push(makeCase('save', {}, () => {
  const picked = choose([4], 3);
  const json = host.encode(); host.restore(json);
  return {picked: picked.player, restored: {name: w.$gamePlayer.DesignationName, icon: w.$gamePlayer.DesignationIcon, color: w.$gamePlayer.DesignationColor}};
}));
process.exitCode = finish(host, 'designation.json', {scope: 'Star_Designation table, ConfigManager.DesignationN, unlock script, condition script, choose common event, save roundtrip', cases}) ? 0 : 1;
process.exit();
