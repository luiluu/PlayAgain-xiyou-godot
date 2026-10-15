'use strict';
// Codex_SmartBattleAI 探针：在正式引擎里按切片开局状态（普通难度、出战 1/8/9/10、10 级）摆出几种战况，
// 记录 CodexSmartAI.choose 的选择（技能/物品、目标）、前 6 名候选分数，以及 safeDamage 的伤害估算。
// 不加载存档，只写 .sandbox/smart_ai.json；验收后由资料库侧复制到 generated/oracle。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded() || !w.CodexSmartAI) throw new Error('参照引擎启动失败');
const DIFFICULTY = 3, PARTY = [1, 8, 9, 10], LEVEL = 10;
const ITEMS = {1: 5, 2: 5, 137: 2};
const battleRefresh = a => { if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); } };
const r6 = x => typeof x === 'number' ? +x.toFixed(6) : x;

function setup(troop) {
  w.eval('ConfigManager.applyData({}); ConfigManager.codexSmartAI = true; DataManager.setupNewGame(); $gameSystem.setDifficultyId(' + DIFFICULTY + ');');
  w.eval('for (var i = 1; i < 5000; i++) if ($gameVariables._data[i] === undefined) $gameVariables._data[i] = 0;');
  // 与 slice_probe 相同的开局被动与开战状态（普通难度）
  const passives = [6168, 5980, 5548], starters = [1, 2, 3, 4, 5, 6, 7, 52], startStates = [995, 1691, 1631];
  w.eval('$gameParty._actors = []; ' + JSON.stringify(PARTY) + '.forEach(function(id){ $gameParty.addActor(id); });');
  for (const id of PARTY) {
    const a = w.$gameActors.actor(id);
    passives.concat(starters.includes(id) ? [2571, 2786] : []).forEach(s => a.learnSkill(s));
    a.changeLevel(LEVEL, false);
    battleRefresh(a);
    startStates.forEach(s => a.addState(s));
    a.refresh(); battleRefresh(a); a.recoverAll(); startStates.forEach(s => a.addState(s)); a.refresh(); battleRefresh(a);
  }
  w.$gameParty._items = w.JSON.parse(JSON.stringify(ITEMS));
  w.Math.random = () => 0.99;
  w.$gameTroop.setup(troop);
  w.Math.random = () => 0.5;
  w.$gameTroop.members().forEach(e => e.refreshPassiveCache && e.refreshPassiveCache());
  w.$gameParty._inBattle = true;
  w.$gameTroop._turnCount = 1;
}

const SCENES = {
  full: () => {},
  ally_low: () => { const a = w.$gameActors.actor(9); a.setHp(Math.max(1, Math.floor(a.mhp * 0.2))); },
  ally_dead: () => { w.$gameActors.actor(9).addState(1); },
  no_mp: () => PARTY.forEach(id => w.$gameActors.actor(id).setMp(0)),
  foes_low: () => w.$gameTroop.members().forEach(e => e.setHp(Math.max(1, Math.floor(e.mhp * 0.1)))),
};

const out = {sourceIdentity: identity, difficulty: DIFFICULTY, party: PARTY, level: LEVEL, items: ITEMS, cases: [], damage: []};
for (const troop of SLICE.troops) {
  for (const [scene, apply] of Object.entries(SCENES)) {
    setup(troop);
    apply();
    const state = {actors: PARTY.map(id => { const a = w.$gameActors.actor(id); return {id, hp: a.hp, mp: a.mp, tp: a.tp, mhp: a.mhp, mmp: a.mmp, dead: a.isDead(), skills: a.skills().map(s => s.id)}; }),
      enemies: w.$gameTroop.members().map(e => ({id: e.enemyId(), hp: e.hp, mhp: e.mhp, alive: e.isAlive()}))};
    for (const id of PARTY) {
      const a = w.$gameActors.actor(id);
      if (!a.canMove()) { out.cases.push({troop, scene, actor: id, skipped: true}); continue; }
      a._codexLastAIDecision = null;
      const act = w.CodexSmartAI.choose(a);
      const dec = a._codexLastAIDecision || {};
      out.cases.push({troop, scene, actor: id, state,
        chosen: act ? {id: act.item().id, item: w.DataManager.isItem(act.item()), target: act._targetIndex} : null,
        score: r6(dec.score), candidates: (dec.candidates || []).map(c => ({id: c.id, item: c.item, score: c.score, target: c.target}))});
    }
    if (scene === 'full') {
      for (const id of PARTY) {
        const a = w.$gameActors.actor(id);
        const skills = [w.$dataSkills[a.attackSkillId()]].concat(a.skills().filter(s => s.damage && s.damage.type > 0));
        w.$gameTroop.members().forEach((e, ti) => skills.forEach(s => {
          const action = new w.Game_Action(a); action.setSkill(s.id);
          w.Math.random = () => 0.5;
          out.damage.push({troop, actor: id, skill: s.id, target: ti, safe: r6(w.CodexSmartAI.safeDamage(a, e, s, action)),
            hit: r6(action.itemHit(e)), eva: r6(action.itemEva(e)), cri: r6(s.damage.critical ? action.itemCri(e) : 0)});
        }));
      }
    }
  }
}
// 行动序列段数（sequenceHits）：切片角色各技能＋攻击，另记 YEP 解析后的 whole/target 步骤
out.sequence = [];
setup(SLICE.troops[0]);
for (const id of PARTY) {
  const a = w.$gameActors.actor(id);
  const ids = [1, 2].concat(a.skills().map(s => s.id)).concat([160, 161, 162, 163, 164, 165, 169, 2770, 3635, 3641, 3644]);
  for (const sid of [...new Set(ids)]) {
    const s = w.$dataSkills[sid];
    out.sequence.push({actor: id, skill: sid, hits: w.CodexSmartAI.sequenceHits(a, s),
      whole: (s.wholeActions || []).map(x => [String(x[0]), (x[1] || []).map(String)]), target: (s.targetActions || []).map(x => [String(x[0]), (x[1] || []).map(String)])});
  }
}
// 通用公式边界：随机预览按 choose 的0.5，不抽实战随机数。
setup(SLICE.troops[0]);
out.edgeDamage=[];
for(const [type,formula] of [[1,'a.atk * Math.random()'],[3,'a.mat * 2']]){
  const rec=w.JSON.parse(JSON.stringify(w.$dataSkills[160]));rec.damage.type=type;rec.damage.formula=formula;
  const actor=w.$gameActors.actor(1),target=w.$gameTroop.members()[0];
  w.Math.random=()=>0.5;
  const action=new w.Game_Action(actor);action.setSkill(160);
  out.edgeDamage.push({type,formula,value:r6(w.CodexSmartAI.safeDamage(actor,target,rec,action))});
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/smart_ai.json'), JSON.stringify(out, null, 1));
process.stdout.write(JSON.stringify({cases: out.cases.length, damage: out.damage.length, errors: r.errors}) + '\n');
process.exit(0);
