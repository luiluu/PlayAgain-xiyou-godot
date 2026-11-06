'use strict';
// 敌人调用「读装备等级」公式（user.equips 不存在）时原版整条公式出错归零：对每个带 read.equipment_instance_level 的技能，
// 以敌人 1 为使用者、角色 8 为目标量 evalDamageFormula 的值与 Yanfly 公式报错。
// 原夹具（沙僧 10-19，8e5adec4）没留探针；CQ 换源时补上。产物 .sandbox/formula_equipment_enemy.json，
// 复制为 01_Godot工程/tests/fixtures/formula_equipment_enemy_oracle.json（tests/xiyou_formula_equipment 读，不进同步）。
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {start} = require('./shared/host.cjs');
const host = start(), w = host.w; host.newGame();
w.eval('CodexZones.ENABLED=false;');
const generated = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');
const skills = JSON.parse(fs.readFileSync(path.join(generated, 'db/Skills.json'), 'utf8'));
const manifest = JSON.parse(fs.readFileSync(path.join(generated, 'manifest.json'), 'utf8'));
const cases = [];
for (const sk of skills) {
  if (!sk || !sk.damage.formulaProgram.capabilities.includes('read.equipment_instance_level')) continue;
  const source = w.$dataSkills[sk.id];
  const a = new w.Game_Enemy(1, 0, 0), b = w.$gameActors.actor(8);
  w.$gameTroop._enemies = [a];  // Game_Action 按敌群下标取使用者，敌人得在敌群里
  const diagnostics = [], original = w.Yanfly.Util.displayError;
  w.Yanfly.Util.displayError = (error, _code, label) => diagnostics.push({label, message: error.message});
  w.Math.random = () => 0.5;
  let value;
  try {
    const action = new w.Game_Action(a); action.setSkill(sk.id); value = action.evalDamageFormula(b);
  } finally { w.Yanfly.Util.displayError = original; }
  cases.push({skill: sk.id, value: Number.isFinite(value) ? value : 0, hasEquips: typeof a.equips === 'function', diagnostics,
    formulaSHA256: crypto.createHash('sha256').update(source.damage.formula).digest('hex')});
}
const out = {schemaVersion: 1, sourceIdentity: {releaseVersion: manifest.releaseVersion, inputs: manifest.inputs, runtimeInputs: manifest.runtimeInputs}, cases};
const dir = path.resolve(__dirname, '.sandbox'); fs.mkdirSync(dir, {recursive: true});
fs.writeFileSync(path.join(dir, 'formula_equipment_enemy.json'), JSON.stringify(out, null, 1) + '\n');
console.log(JSON.stringify({file: 'formula_equipment_enemy.json', cases: cases.length}));
process.exit(0);
