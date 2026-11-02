'use strict';
// 【cc·白龙_14·未经审查】共用来源护盾账本（js/codex/runtime/installSourceShieldLedgerRuntime.js，W.CodexShieldLedger）：
// grant（加成、同源取较高、期限、opts）、gainHp／setHp 包装的吸收（到期早先扣、击穿减半与原生护盾的分工、noHalve、skip）、
// absorbRaceDamage、roundEnd（到期、衰减、noDecay、同回合去重）、revoke／revokeOwner／clear、_codexShieldAbsorbed、lastAbsorbed。
// 不打真实战斗：新局后 $gameParty._inBattle=true，回合数写 $gameTroop._turnCount；受益者 1、8 号（最大生命补到 10000、生命 5000，其余能力值照新局）。
// 每步之后记两人的账本行、生命、原生护盾、累计挡下；产物 .sandbox/shield_ledger.json，拷成 tests/fixtures/shield_ledger_oracle.json（不进同步），专项 xiyou_shield_ledger。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const L = w.CodexShieldLedger;
if (!L || typeof L.grant !== 'function') throw new Error('护盾账本未安装');
const IDS = [1, 8];
let skipFlag = false;
function fresh() {
  newGame();
  w.$gameParty._inBattle = true;
  w.$gameTroop._turnCount = 1;
  L.clearAll();
  for (const id of IDS) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 10000 - a.paramBase(0); a.need_refresh = true; a.refresh(); a.recoverAll(); a._hp = 5000; a._shield = 0; }
}
function snap() {
  const out = {};
  for (const id of IDS) {
    const a = w.$gameActors.actor(id);
    out[id] = {hp: a._hp, shield: a._shield, total: a.shield, absorbed: a._codexShieldAbsorbed || 0,
      rows: L.rows(a).map(r => ({source: r.source, amount: r.amount, until: r.until, owner: r.owner, noDecay: r.noDecay, noHalve: r.noHalve,
        lastAbsorbed: r.lastAbsorbed || 0, absorbed: r.absorbed || 0}))};
  }
  return out;
}
// 一步：[op, …参数]；op：grant 目标 来源 量 回合 施加者 opts（skip:true 换成读 skipFlag）／hurt 目标 量（gainHp 负值）／
// set 目标 生命（setHp）／race 目标 量／native 目标 量（直接写原生护盾）／turn 回合数／end（roundEnd）／revoke 目标 来源／
// owner 施加者／clear 目标／skip 真假／state 目标 状态 id（加护盾效果加成）
function run(steps) {
  fresh();
  const log = [];
  for (const s of steps) {
    const [op, ...p] = s, a = typeof p[0] === 'number' ? w.$gameActors.actor(p[0]) : null;
    let ret = null;
    if (op === 'grant') {
      const o = Object.assign({}, p[5] || {});
      if (o.skip) o.skip = () => skipFlag;
      ret = L.grant(a, p[1], p[2], p[3], p[4], o);
    } else if (op === 'hurt') a.gainHp(-p[1]);
    else if (op === 'set') a.setHp(p[1]);
    else if (op === 'race') ret = L.absorbRaceDamage(a, p[1]);
    else if (op === 'native') a._shield = p[1];
    else if (op === 'turn') w.$gameTroop._turnCount = p[0];
    else if (op === 'end') L.roundEnd();
    else if (op === 'revoke') ret = L.revoke(a, p[1]);
    else if (op === 'owner') L.revokeOwner(p[0]);
    else if (op === 'clear') L.clear(a);
    else if (op === 'skip') skipFlag = !!p[0];
    else if (op === 'state') { a.addState(p[1]); a.refresh(); }
    else throw new Error('未知步骤 ' + op);
    log.push({step: s, ret, after: snap()});
  }
  skipFlag = false;
  return log;
}
const SCRIPTS = {
  // 加成：鼓点共鸣 1177（ShieldEffect 75）；noBonus 不吃
  bonus: [['state', 1, 1177], ['grant', 1, 'x.a', 101, 2, 8], ['grant', 1, 'x.b', 101, 2, 8, {noBonus: true}], ['grant', 8, 'x.a', 0.9, 1, 1]],
  // 同源：较高覆盖、较低不降、期限取较晚、owner 改写；turns 0／小数
  same: [['grant', 1, 'x.a', 300, 1, 8], ['grant', 1, 'x.a', 200, 3, 10], ['grant', 1, 'x.a', 500, 1, 9], ['turn', 4], ['grant', 1, 'x.b', 100, 0, 8],
    ['grant', 1, 'x.c', 100, 2.7, 8]],
  // 吸收顺序（到期早先扣）与击穿减半（原生护盾为 0 → 账本减半）
  order: [['grant', 1, 'x.late', 300, 3, 8], ['grant', 1, 'x.early', 200, 1, 8], ['hurt', 1, 100], ['hurt', 1, 500], ['hurt', 1, 400]],
  // 原生护盾还有 → 交给原生吸收并减半，账本不再减半
  native: [['native', 1, 150], ['grant', 1, 'x.a', 200, 2, 8], ['hurt', 1, 500], ['native', 8, 0], ['grant', 8, 'x.a', 200, 2, 1], ['set', 8, 4500],
    ['set', 8, 4000]],
  // noHalve：只有 noHalve 行挡下时不减半；混着普通行就减半
  nohalve: [['grant', 1, 'g', 200, 2, 8, {noHalve: true, noDecay: true, noBonus: true}], ['hurt', 1, 500], ['grant', 1, 'g', 200, 2, 8, {noHalve: true}],
    ['grant', 1, 'x', 100, 1, 8], ['hurt', 1, 500]],
  // skip：返回真时这一行跳过，别的行照扣
  skip: [['grant', 1, 'g', 300, 2, 8, {skip: true, noHalve: true}], ['grant', 1, 'x', 100, 2, 8], ['skip', true], ['hurt', 1, 250], ['skip', false],
    ['hurt', 1, 250]],
  // 回合末：到期撤销、衰减 floor(×decayRate)、noDecay 不衰减、同回合只做一次、衰减到 0 删掉
  round: [['grant', 1, 'a', 1000, 1, 8], ['grant', 1, 'b', 1000, 2, 8], ['grant', 1, 'c', 1000, 3, 8, {noDecay: true}], ['grant', 8, 'd', 1, 5, 1],
    ['end'], ['end'], ['turn', 2], ['end'], ['turn', 3], ['end'], ['turn', 4], ['end']],
  // 种族伤害：账本静默先扣，再原生护盾、减半
  race: [['grant', 1, 'x', 100, 2, 8], ['native', 1, 50], ['race', 1, 300], ['grant', 8, 'g', 100, 2, 1, {noHalve: true}], ['race', 8, 300],
    ['grant', 8, 'x', 100, 2, 1], ['race', 8, 300]],
  // 撤销
  revoke: [['grant', 1, 'a', 100, 2, 8], ['grant', 1, 'b', 200, 2, 9], ['grant', 8, 'a', 300, 2, 9], ['revoke', 1, 'a'], ['revoke', 1, 'zz'],
    ['owner', 9], ['grant', 1, 'c', 50, 2, 8], ['clear', 1]],
};
const cases = Object.entries(SCRIPTS).map(([id, steps]) => makeCase(id, {steps}, () => run(steps)));
cases.push(makeCase('params', {}, () => ({decayRate: L.decayRate, reduction: L.reduction})));
// 战斗外 grant 不记
cases.push(makeCase('outside', {}, () => { fresh(); w.$gameParty._inBattle = false; return {ret: L.grant(w.$gameActors.actor(1), 'x', 100, 2, 8), rows: L.rows(w.$gameActors.actor(1))}; }));
process.exit(finish(host, 'shield_ledger.json', {hostScope: '真实 CodexShieldLedger（grant、gainHp／setHp 包装、absorbRaceDamage、roundEnd、revoke 类），不打战斗', cases}) ? 0 : 1);
