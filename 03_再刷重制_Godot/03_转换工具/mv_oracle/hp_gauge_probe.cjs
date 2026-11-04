'use strict';
// 审查 40 P3-8：敌人血条显隐（YEP_X_VisualHpGauge Game_Enemy.hpGaugeVisible）的真原版参照。
// 真实新游戏里逐个 new Game_Enemy(id)，读原版 hpGaugeVisible()（插件参数 Defeat First=false、Always Visible=false）：
// 普通＝visible、隐藏成员＝hidden。产物 .sandbox/hp_gauge.json，拷成 tests/fixtures/hp_gauge_oracle.json（不进同步），专项 xiyou_hp_gauge_visible。
// 不读伤害，无需 CodexZones 开关。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
newGame();
const cases = [];
cases.push(makeCase('enemies', {}, () => {
  const rows = [], maxId = w.$dataEnemies.length - 1;
  for (let id = 1; id <= maxId; id++) {
    if (!w.$dataEnemies[id]) continue;
    const e = new w.Game_Enemy(id, 0, 0);
    const visible = e.hpGaugeVisible();
    e._hidden = true;
    const hiddenVisible = e.hpGaugeVisible();
    const d = w.$dataEnemies[id];
    rows.push({id, visible, hiddenVisible, hideFlag: !!d.hideHpGauge, showFlag: !!d.showHpGauge});
  }
  return {rows, params: {defeatFirst: String(w.Yanfly.Param.VHGDefeatFirst), alwaysVisible: String(w.Yanfly.Param.VHGAlwaysVisible)}};
}));
process.exit(finish(host, 'hp_gauge.json', {hostScope: '真实 Game_Enemy.hpGaugeVisible（YEP_X_VisualHpGauge，$dataEnemies 的 hideHpGauge／showHpGauge 由插件原版备注解析写入）', cases}) ? 0 : 1);
