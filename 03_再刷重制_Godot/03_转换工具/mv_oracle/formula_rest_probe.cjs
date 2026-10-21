'use strict';
// Plan 12 census and production-entry supplement. Read the frozen engine's
// processed custom formula blocks, including both ATK branches. Output stays
// inside .sandbox; copy the reviewed result to tests/fixtures explicitly.
const crypto = require('crypto');
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), w = host.w;
host.newGame();
const custom = w.$dataSkills.filter(s => s && /<damage formula>/i.test(s.note));
const inventory = custom.map(s => ({id: s.id, formula: s.damage.formula,
  sha256: crypto.createHash('sha256').update(s.damage.formula).digest('hex')}));
const cases = [];
const slots = b => {const r = b.result(); return {hpAffected: r.hpAffected, hpDamage: r.hpDamage,
  mpDamage: r.mpDamage, tpDamage: r.tpDamage, success: r.success,
  addedStates: Array.from(r.addedStates), removedStates: Array.from(r.removedStates)};};
for (const source of custom) {
  const query = source.damage.formula.match(/var\s+baseEquipId\s*=\s*(\d+)/);
  const base = query ? Number(query[1]) : null;
  // Equal ATK covers the false branch; greater and lower distinguish > from >=.
  const relations = /user\.atk\s*>\s*target\.atk/.test(source.damage.formula) ? [-1, 0, 1] : [0];
  for (const mode of (base ? ['none', 'first', 'zero', 'nonmagic'] : ['none'])) for (const relation of relations) {
    const setup = {skill: source.id, mode, relation, paramsA: [10000, 1000, 100 + relation, 40, 90, 30, 70, 60],
      paramsB: [12000, 800, 100, 50, 60, 40, 65, 55], resourcesA: [9000, 700, 55], resourcesB: [10000, 600, 101],
      mastery: 7, elementRate: 1.25, criticalRate: 0.1, variables: {'1165': 1000}, equipment: []};
    const armor = (level, magic = true) => ({kind: 'armor', baseItemId: base, level,
      meta: magic ? {'Magic Weapon': true} : {}});
    if (mode === 'first') setup.equipment = [armor(3), armor(99)];
    if (mode === 'zero') setup.equipment = [armor(0)];
    if (mode === 'nonmagic') setup.equipment = [armor(22, false)];
    cases.push(makeCase(`s${source.id}.${mode}.${relation}`, setup, () => {
      const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
      const rows = new w.Array();
      setup.equipment.forEach((row, i) => {
        const id = 61000 + i;
        const item = {...w.$dataArmors[base], id, baseItemId: base, meta: row.meta, level: row.level};
        delete item._isMagicWeaponCache;
        w.$dataArmors[id] = item; rows.push(item);
      });
      a.equips = () => rows; b.equips = () => new w.Array();
      a.param = i => setup.paramsA[i]; b.param = i => setup.paramsB[i];
      for (const x of [a, b]) {
        x._states = new w.Array(); x._stateTurns = {}; x._buffs.fill(0); x._buffTurns.fill(0);
        x.xparam = i => i === 2 ? setup.criticalRate : 0;
        x.sparam = () => 1;
        x.elementRate = () => setup.elementRate;
        x.skillMasteryLevel = () => setup.mastery;
        x.maxTp = () => 200;
        x.clearResult();
      }
      [a._hp, a._mp, a._tp] = setup.resourcesA;
      [b._hp, b._mp, b._tp] = setup.resourcesB;
      for (const [k, v] of Object.entries(setup.variables)) w.$gameVariables._data[Number(k)] = v;
      let draws = 0;
      w.Math.random = () => {draws++; return 0.5;};
      const diagnostics = [], originalError = w.Yanfly.Util.displayError;
      w.Yanfly.Util.displayError = (error, _code, label) => diagnostics.push({label, message: error.message});
      try {
        const action = new w.Game_Action(a); action.setSkill(source.id);
        const value = action.evalDamageFormula(b);
        if (diagnostics.length) throw new Error('unexpected formula diagnostic: ' + JSON.stringify(diagnostics));
        return {value: Number.isFinite(value) ? value : 0,
          valueKind: Number.isNaN(value) ? 'nan' : Number.isFinite(value) ? 'finite' : 'infinity',
          resourcesA: [a.hp, a.mp, a.tp], resourcesB: [b.hp, b.mp, b.tp],
          resultA: slots(a), resultB: slots(b), randomDraws: draws, diagnostics,
          formulaSHA256: crypto.createHash('sha256').update(source.damage.formula).digest('hex')};
      } finally {w.Yanfly.Util.displayError = originalError;}
    }));
  }
}
process.exit(finish(host, 'formula_rest.json', {hostScope: 'plan12-custom-formula-execution', inventory, cases}) ? 0 : 1);
