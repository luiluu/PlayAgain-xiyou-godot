// T210 原版对照：直接执行 v0.62.12 YEP_BattleEngineCore＋YEP_X_VisualStateFX 的 Sprite_Actor.refreshMotion 源码（加载顺序同 plugins.js），
// 角色用存根，状态用原版 States.json 记录，排序照 MV Game_BattlerBase.sortStates（优先级降序、同级 ID 升序）。
const fs = require('fs');
const J = process.argv[2];
const bec = fs.readFileSync(J + '/js/plugins/YEP_BattleEngineCore.js', 'utf8').split('\n');
const vsfx = fs.readFileSync(J + '/js/plugins/YEP_X_VisualStateFX.js', 'utf8').split('\n');
const States = JSON.parse(fs.readFileSync(J + '/data/States.json', 'utf8'));
const pick = (lines, a, b) => lines.slice(a - 1, b).join('\n');
var Yanfly = {BEC: {}, VSFX: {}}, BattleManager = {isInputting: () => false};
function Sprite_Actor() {}
Sprite_Actor.MOTIONS = {guard: {index: 'guard'}};
Sprite_Actor.prototype.refreshMotion = function() { throw 'base'; };
Sprite_Actor.prototype.startMotion = function(m) { this.out = m; };
function Game_BattlerBase() {}
eval(pick(bec, 3196, 3222));   // BEC refreshMotion
eval(pick(vsfx, 266, 274));    // stateMotionIndex
eval(pick(vsfx, 433, 447));    // VSFX refreshMotion
function actor(o) {
  const ids = (o.states || []).slice().sort((a, b) => (States[b].priority - States[a].priority) || (a - b));
  const a = Object.create(Game_BattlerBase.prototype);
  Object.assign(a, {
    states: () => ids.map(i => States[i]), isInputting: () => !!o.input, isActing: () => false,
    isChanting: () => false, isGuard: () => !!o.guard, isGuardWaiting: () => false,
    isDying: () => !!o.dying, isUndecided: () => false,
    idleMotion: () => 'walk', deadMotion: () => 'dead', sleepMotion: () => 'sleep', chantMotion: () => 'chant',
    guardMotion: () => 'guard', abnormalMotion: () => 'abnormal', dyingMotion: () => 'dying', waitMotion: () => 'wait',
    customStateMotion: () => 'custom'});
  return a;
}
const cases = [
  ['低血＋防御', {dying: 1, guard: 1}],
  ['中毒 4', {states: [4]}],
  ['中毒 4＋低血', {states: [4], dying: 1}],
  ['中毒 4＋防御', {states: [4], guard: 1}],
  ['睡眠 10＋中毒 4＋防御', {states: [4, 10], guard: 1}],
  ['中毒 4＋炎爆暴击 96（同优先级）', {states: [4, 96]}],
  ['破阵 1043＋中毒 4', {states: [4, 1043]}],
  ['中毒 4＋低血＋轮到输入', {states: [4], dying: 1, input: 1}],
];
for (const [name, o] of cases) {
  const s = new Sprite_Actor(); s._actor = actor(o); s._motion = null; s.refreshMotion();
  console.log(name + ' → ' + s.out);
}
process.exit(0);
