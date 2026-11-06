'use strict';
// 等级不够的武器：强塞进武器槽后 refresh 会卸下，足级才保留；角色 10 另量 TP 9 时技能 3644 能不能用（要求装备）。
// 原夹具（995d42d6）没留探针；CQ 换源时补上。产物 .sandbox/equipment_admission.json，
// 复制为 01_Godot工程/tests/fixtures/equipment_admission_oracle.json（tests/xiyou_equipment_admission 读，不进同步）。
const fs = require('fs'), path = require('path');
const {start} = require('./shared/host.cjs');
const host = start(), w = host.w; host.newGame();
const generated = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');
const manifest = JSON.parse(fs.readFileSync(path.join(generated, 'manifest.json'), 'utf8'));
const setups = [[1, 56, 1], [1, 56, 3], [10, 14, 1], [10, 14, 10]];
const cases = [];
for (const [aid, wid, level] of setups) {
  const errors = [];
  let observed = null;
  try {
    const a = w.$gameActors.actor(aid);
    a.changeLevel(level, false);
    a._equips[0].setObject(w.$dataWeapons[wid]);
    const before = !!a.equips()[0] && a.equips()[0].id === wid;
    a.refresh();
    const after = !!a.equips()[0] && a.equips()[0].id === wid;
    let cold = null;
    // 3644 只能战斗中用（occasion 1），重制 XBattleLogic.can_use 量的是战斗中
    if (aid === 10) { a._tp = 9; w.$gameParty._inBattle = true; try { cold = a.canUse(w.$dataSkills[3644]); } finally { w.$gameParty._inBattle = false; } }
    observed = {before, after, canEquip: a.canEquip(w.$dataWeapons[wid]), level: a.level, canUseCold: cold};
  } catch (e) { errors.push(String(e && e.stack || e)); }
  cases.push({id: `equip.${aid}.${wid}.${level}`, setup: {aid, wid, level}, observed, errors});
}
const out = {schemaVersion: 1, sourceIdentity: {releaseVersion: manifest.releaseVersion, inputs: manifest.inputs, runtimeInputs: manifest.runtimeInputs},
  scope: 'Native equip req_level and canUse fixture admission; negative cases retained', cases};
const dir = path.resolve(__dirname, '.sandbox'); fs.mkdirSync(dir, {recursive: true});
fs.writeFileSync(path.join(dir, 'equipment_admission.json'), JSON.stringify(out, null, 2) + '\n');
console.log(JSON.stringify({file: 'equipment_admission.json', cases: cases.length, errors: cases.filter(c => c.errors.length).length}));
process.exit(0);
