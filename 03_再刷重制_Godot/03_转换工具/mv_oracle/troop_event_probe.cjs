'use strict';
// 敌群事件参照（扩楼层：一至三、五至九、十一至十二层守层者 4/5/8/28/39/52/53/67/109/110 、十层守层者 69（另有 333 给自己加状态 44）与十三至十九层守层者 111／118／138／172／173／174／333（变量 842 为 0 时先调公共事件 1398：334 完全回复、313 全队加状态、333 加状态，再强制 6069／6105／8111）、二十层守层者 456（842 为 0 时公共事件 1399 天道领域＋强制 6070／8111，否则 1400 天道领域*伪＋强制 6071；第 3 回合起每 3 回合随机 844 强制 6101～6104 与 8111）、二十一层守层者 457 与二十二层守层者 458（同 456；第 3 页生命≤20% 且变量 853＝1 的 101 对话与专属强制 3559／3560 首两回合参照不覆盖）、二十三层守层者 459（只有两页，不交礼开场比 456 多强制 6105／6107，没有第 3 页）、二十四层守层者 460（同 459）、二十五层守层者 461（同 459）、二十六层守层者 462（金角、银角两名守层者，同 459；另加玩家集火敌人 1 的两例）、二十七层守层者 463、二十八层守层者 464（同 459）与二十四层副本熊族桃园首领 526 雄霸（第 2 页第 1 回合 333 给自己状态 44、339 强制技能 3813）第 1 回合的强制行动 339 → 技能 8111「轮回模式·平衡伤害」→ 状态 1460「轮回困难v1」）。
// 二十九层太白金星 465 同 459；三十层玉皇大帝 466 不交礼开场另加强制 6101，另加 HP≤25% 的两例（hpRate：第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// 三十一至三十三层守层者 467 女娲／468 伏羲／469 鸿蒙老祖（四页：第 3 回合起每 3 回合随机强制、第 1 回合变量 842＝0 时公共事件 1397 霸者领域＋强制 6068／6055／6057／6051／8111、
// HP≤30% 第 3 页 101 对话＋1397、HP≤10% 第 4 页 101 对话＋336 变身 929／929／930＋1399）与三十层求道者门后 Map055 引路人 794（HP≤20% 第 4 页变身 922）：
// 各加 HP≤30%（hpRate 0.3）一例；HP≤10% 一例另预置第 3 页已执行（flags：第 3 页先回满会让第 4 页条件不再成立，实战是先过 30% 再过 10%）。
// 十三至十九层补已交见面礼（变量 842＝1）分支，确认不触发开场领域与强制行动。
// 十五层副本敌群 160（控尸者 HP≤1% 时两只丧尸附加状态 1）：开战前控尸者 HP 设 1（守层者那套两回合检查以 e0 为首领，不适用这个敌群）（preset，只到第 1 回合输入前）。
// 真实 BattleManager 跑前两回合（日志窗/精灵组用空代理，同 sequence_probe）：普通难度、开局队伍 1/8/9/10（1 级，开局被动），
// 角色输入一律普通攻击敌人 0；Math.random 敌群生成时 0.99（不出神话），之后 0.5（分散度为 0、不会心）。
// 记录：每次开始行动（回合数、行动者、技能、是否强制）、每次 invokeAction 的目标血量变化与伤害弹字（startDamagePopup 时的 hpDamage）、
// 行动者攻击/魔攻，以及战斗中的状态。只写 .sandbox/troop_events.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const PARTY = [1, 8, 9, 10], TROOPS = [4, 5, 8, 28, 39, 52, 53, 67, 69, 109, 110, 111, 118, 138, 172, 173, 174, 333, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 794, 526,
  // 三十一层七位可选首领的敌群 830／125／816／831／818／126／817（开场同 467，HP 页见下方 hpRate 例）
  125, 126, 816, 817, 818, 830, 831,
  // 二十七层副本墓池的二十八宿石像首领与四圣兽（607 角开场强制 8111；614／622／630／638 同 526：第 2 页第 1 回合给状态 44、强制 3813）
  607, 614, 622, 630, 638,
  // 二十九层副本太上老君藏身处的五位首领 733～737 与两位「太上老君」731／732（同 526）
  731, 732, 733, 734, 735, 736, 737,
  // 二十六层副本兜率宫·丹房的三位天尊投影 603／604／605（同 526）
  603, 604, 605,
  // 二十八层副本众分天的首领：Map208 恶·如来 695 与随机头目 696～704，Map209 善·无天 706 与随机头目 707～715（同 526）
  695, 696, 697, 698, 699, 700, 701, 702, 703, 704, 706, 707, 708, 709, 710, 711, 712, 713, 714, 715,
  // 深渊图的被封印者战斗（204～215、223～238、344～351、370／371、379～386、401～404、413～418：开场强制行动 339、状态 313／333、达摩变形条件）
  204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238,
  344, 345, 346, 347, 348, 349, 350, 351, 370, 371, 379, 380, 381, 382, 383, 384, 385, 386, 401, 402, 403, 404, 413, 414, 415, 416, 417, 418,
  // 妄语深渊 717～722、未知存在 724～729、副本协会主席 661、天道研究员 767、传承战 776～779／785（第 1 回合开场强制 339，同 526）
  661, 717, 718, 719, 720, 721, 722, 724, 725, 726, 727, 728, 729, 767, 776, 777, 778, 779, 785,
  // 轮回／求道者变体：求道者 747～766、超级嘤雄 769、狗逍遥·心魔 770、考验者马神投影 788～790、解放全力的里德 795、「我们联合」联合战 798～814
  747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 769, 770, 788, 789, 790, 795,
  798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811, 812, 813, 814,
  // 神魔战场 Map186：九个军团的精英小队与元帅、农田矿的守卫、超级 Boos 嘤族之光 739
  676, 677, 678, 679, 680, 681, 682, 683, 684, 685, 686, 687, 688, 689, 690, 691, 692, 693, 739,
  // 剧情／副本 Boss（cc 悟空 accept3，Boss战清单.py 挑的前 10 个还没开场对照的）：守护者 791 马神、792 霍格尔、793 九尾天狐、796 海拉、797 古代文明学者
  // （同 467：第 1 回合 842＝0 时 1397 霸者领域＋强制，第 3 回合起随机强制）、599 蛮荒圣人（同 466）、203 贝尔蒙特（开场强制 983）、
  // 593 马神牛神（开场强制 8111）、668 虚脱的主席（强制 3812＋状态 44）、165 海拉的幻影（回合变量 112 计数、回满）
  791, 792, 793, 796, 797, 599, 203, 593, 668, 165,
  // accept4（cc 悟空）：Boss战清单.py --pick 剩下的全部（嘤嘤怪 1、木桩 826 不算 Boss 跳过）：劫使 823～825、
  // 古神 528～537、木桩Ⅰ～Ⅵ与英雄级木桩 70～75／352～355、六耳猕猴 321、深渊被封印者 396～398／551～555／640～645、圣人投影 451、
  // 未知存在 454／455／470～474／539～548／570～589／647～659、旧古神 559～568、张三丰／张无忌心魔战 901／902
  824, 825, 528, 529, 530, 531, 532, 533, 534, 535, 536, 537, 70, 823, 71, 72, 73, 74, 75, 321, 352, 353, 354, 355,
  396, 397, 398, 451, 454, 455, 470, 471, 472, 473, 474, 539, 540, 541, 542, 544, 545, 546, 547, 548, 551, 552, 553, 554, 555,
  559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 570, 571, 572, 573, 574, 575, 577, 578, 579, 580, 581, 582,
  584, 585, 586, 587, 588, 589, 640, 641, 642, 643, 644, 645, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 901, 902,
  // 清单里还没开场对照的守层者／传承者：七层海明威 22、驯龙猎手 245、秃头男 270、传承者 772～775／780～784／786、求道者斯盖和齐格鲁德 787
  22, 245, 270, 772, 773, 774, 775, 780, 781, 782, 783, 784, 786, 787,
  // 新源 v0.62.12 新增的剧情／副本 Boss（cc 悟空 floor1，Boss战清单.py 在新源上列出的全部 24 个；嘤嘤怪 1、木桩 826 仍不算 Boss）：
  // 剑道争锋巅峰／巅峰突破 2001～2004、2020～2025，死神觉醒 2010～2019、2026、2027，心魔夏娜 2028，DOTA 肉山宝宝 2029
  2001, 2002, 2003, 2004, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026, 2027, 2028, 2029];
// floor1：上面新增敌群里开场随变量 842（见面礼）分支的，另跑已交礼一例（参照两例的行动不同才列）
const PAID_V062 = [2001, 2002, 2003, 2004, 2015, 2016, 2017, 2020, 2021, 2022, 2023, 2024, 2025, 2026, 2027, 2029];
// floor1：新增敌群的敌人 0 血线页（[hpRate, 预置已执行的页]）：每条血线一例，更低的血线把更高血线的页标成已执行（同 467 的 HP≤10% 例，
// 这些页多带 334 回满，不预置的话高血线页先回满、低血线页条件就不成立了）
const HP_V062 = {2011: [[0.1, []]], 2013: [[0.2, []], [0.1, [2]], [0.05, [2, 3]]], 2014: [[0.1, []], [0.05, [1]], [0.01, [1, 2]]],
  2015: [[0.2, []]], 2016: [[0.2, []]], 2017: [[0.1, []]], 2018: [[0.2, []], [0.1, [2]], [0.05, [2, 3]]],
  2019: [[0.1, []], [0.05, [1]], [0.01, [1, 2]]], 2026: [[0.2, []]], 2027: [[0.2, []]], 2029: [[0.1, []]]};
// floor1：新增敌群第 3 回合以后才成立的回合页（[敌群, 回合预置＝页的回合−1]），走 t1 变体（只比开战检查与下一回合的对话、强制行动）
// rules-gaps4：敌群页覆盖.py（新源）剩下没对照的敌人 0 血线页，每个敌群一例 [敌群, hpRate]（取页条件的门槛，向下取整后正好满足）。
// 敌人 1 的血线页（805～807 第 5 页 35%、814 第 5 页 40%）hpRate 只设敌人 0，不在这里
const HP_GAPS4 = [[270, 0.2], [417, 0.5], [418, 0.5], [456, 0.2], [457, 0.2], [458, 0.2], [661, 0.2], [755, 0.2], [756, 0.2], [757, 0.2],
  [765, 0.25], [791, 0.2], [792, 0.2], [793, 0.2], [795, 0.2], [796, 0.2], [797, 0.2], [805, 0.2], [806, 0.2], [807, 0.2], [814, 0.25]];
// rules-gaps5：敌人 1 的血线页（805～807 第 5 页 35%、814 第 5 页 40%）：[敌群, hpRate]，hpEnemy＝1 预置敌人 1 的 HP（玩家照旧打敌人 0）
const HP_ENEMY1 = [[805, 0.35], [806, 0.35], [807, 0.35], [814, 0.4]];
// rules-gaps5：血线页里「111 变量 853／1567 == 1」才走的对话＋强制（敌群页覆盖.py 里最多的页内变量门）：[敌群, hpRate, hpEnemy, 变量]，
// 开战前把该变量设 1（vars 字段），其余同血线例
const HP_VARS = [[456, 0.2, 0, 853], [457, 0.2, 0, 853], [458, 0.2, 0, 853], [755, 0.2, 0, 853], [756, 0.2, 0, 853], [757, 0.2, 0, 853],
  [805, 0.2, 0, 853], [806, 0.2, 0, 853], [807, 0.2, 0, 853], [805, 0.35, 1, 853], [806, 0.35, 1, 853], [807, 0.35, 1, 853],
  [2015, 0.2, 0, 1567], [2016, 0.2, 0, 1567], [2026, 0.2, 0, 1567], [2017, 0.1, 0, 1567]];
// rules-gaps6：敌群页覆盖.py 剩下的回合页（[敌群, 回合预置, 预置已执行的页]，走 t1 变体）。预置回合取能让该页真跑到的值：
// 2025 第 3 页（第 6 回合）、2019 第 4 页（第 10 回合）、825 第 2 页（第 30 回合）同回合排在前面的随机强制页（3+3·X／1+1·X）
// 先出手会把 1 级开局队伍打倒、轮不到后面的页，所以把前面那页预置成本回合已执行（同 467 的 flags）
const LATE_GAPS6 = [[2025, 4, null], [2025, 6, [0]], [2019, 10, [0]], [825, 30, [1]], [165, 3, null], [203, 9, null],
  [823, 15, null], [824, 3, null], [824, 30, null]];
// rules-gaps6：「111 开关 682（S3西游模式）为 ON」再给自己加状态的守层者／首领（都在第 2 页未交礼支里）
const SW682 = [125, 126, 270, 467, 468, 469, 661, 791, 792, 793, 795, 796, 797, 816, 817, 818, 830, 831];
// rules-gaps6：两名首领的敌群 798～814 第 1、2 页各自掷一次变量 844（同一回合、同一个 EVENT_R），第 1 页 844＝2／3 的强制
// 先出手打倒 1 级开局队伍，第 2 页（敌人 1）这两支跑不到：回合预置 3（预置 2 的话第 3 回合开始时清掉「每回合」页的已执行标记），
// 第 1 页预置成本回合已执行，单看第 2 页
const PAGE2_844 = [798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811, 812, 813, 814];
// rules-gaps7：嘤嘤怪 1 的五页：第 2／3／5 页（回合 1、1+1·X）角色 4 在队且会技能 23（全队加状态 11；角色 4 本来就会，否则支是空的不用另跑）／会 509（随机变量 53＝1～3 时
// 全队加 45，之后 214 暂时消除本页）、角色 29 会 575（角色 29、30 加 51），第 4 页（回合 5+1·X）角色 20 会 201（自己加 34）；不会走否则支。
// [variant, 角色技能（负数＝忘掉）, eventRandom（null＝不换事件随机）, 回合预置]。回合预置 4／5 两例键靠 turnPreset 区分（oracle_additions），
// eventRandom 例键靠 eventRandom 区分
const YING_PARTY = [1, 4, 20, 29];
const YING_CASES = [['party', {}, null, 0], ['party.k575', {29: [575]}, null, 0],
  ['party.k509.r1', {4: [509]}, 0, 0], ['party.k509.r2', {4: [509]}, 0.01, 0], ['party.k509.r3', {4: [509]}, 0.02, 0],
  ['party.t5.k201', {20: [201]}, null, 4], ['party.t6', {}, null, 5]];
const LATE_V062 = [[2004, 4], [2012, 7], [2014, 9], [2019, 9], [2025, 3], [2025, 5]];
const T1_TURN3 = [111, 118, 125, 126, 138, 172, 173, 174, 270, 333, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469,
  599, 661, 739, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 769, 770,
  772, 773, 774, 775, 776, 777, 778, 779, 780, 781, 782, 783, 784, 785, 786, 787, 788, 789, 790, 791, 792, 793, 794, 795, 796, 797,
  798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811, 812, 813, 814, 816, 817, 818, 825, 830, 831, 901, 902,
  // floor1：新源新增敌群里第 1 页是「回合 3＋3·X」的
  2001, 2002, 2003, 2004, 2011, 2013, 2018, 2020, 2021, 2022, 2023, 2024, 2025, 2027, 2028];
const stub = new Proxy(function () {}, {get: (t, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprite = () => {
  const store = {x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255};
  return new Proxy(store, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => { t[k] = v; return true; }});
};
const sprites = new Map();
w.BattleManager.actionBattleHud = function () { return true; };
w.BattleManager.otbDisplayWindow = function () { return stub; };
w.Game_Battler.prototype.battler = function () { if (!sprites.has(this)) sprites.set(this, sprite()); return sprites.get(this); };
const key = b => b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
let popups = null;
w.Game_Battler.prototype.startDamagePopup = function () {
  if (popups) popups.push({target: key(this), hpDamage: this._result.hpDamage, hpAffected: this._result.hpAffected});
};
// 插件指令 battleback … scroll speed（三十一层起守层者第 2 页）：只改战斗背景画面；无场景时原函数读 SceneManager._scene._spriteset 报错，
// 按「没有 spriteset 就返回」处理（同原函数在 spriteset 缺失时的分支）。
const alterBattleback = w.BattleManager.alterBattleback;
w.BattleManager.alterBattleback = function (line) { return w.SceneManager._scene ? alterBattleback.call(this, line) : undefined; };
// rules-gaps6：敌群页把敌人全体战斗不能（雷劫使 823 第 15 回合、神劫使 824 第 30 回合的 333 状态 1）时原版走 processVictory，
// 胜利界面插件读 SceneManager._scene 的窗口，无场景引擎里报错。没有场景时只记到战斗结束（旧例没有一例走到胜利，不受影响）
const processVictory = w.BattleManager.processVictory;
w.BattleManager.processVictory = function () {
  if (w.SceneManager._scene) return processVictory.call(this);
  this._phase = 'battleEnd';
};

// 覆盖记录（cc events13，环境变量 XIYOU_COVER=1 才开，默认不记、troop_events.json 逐字节不变）：每例记解释器实际执行到的
// 「位置:下标」（敌群页 tTpP、公共事件 ceN，按 _list 对象认），101 连带消费的 401／102 续行也算；另写 .sandbox/troop_events_cover.json，
// byCase 以 cases 序号为键，给 03_转换工具/敌群页覆盖.py 和 Godot 侧 xiyou_troop_events --coverage 对照。
// rules-gaps5：事件里的随机变量（122 操作数「随机」）逐支预置。EVENT_R 非空时 122 随机取 floor(n·EVENT_R)（只在这条指令里换 Math.random，
// 别处照旧 0.5）。T1_TURN3 第 1 页「回合 3+3·X」按变量 844 随机四选一强制（2018 是二选一），旧 t1 例取 0.5 只走一支；
// 这里给其余每支各跑一例（eventRandom＝k/n），从 $dataTroops 的 122 读取值域，不手写分支表。
let EVENT_R = null;
// rules-gaps7：换队伍（嘤嘤怪 1 的页按角色 4／20／29 在队、会不会技能 23／509／201／575 走分支：111 角色条件第 3 类是「技能」）。
// PARTY_CASE 非空时开局队伍换成 PARTY_CASE.party，开战（BattleManager.setup）后按 PARTY_CASE.skills（{角色号: [技能…]}，负数＝忘掉）
// 学会／忘掉技能；记 party／actorSkills 字段，旧例不写
let PARTY_CASE = null;
function runParty(pc, fn) {
  PARTY_CASE = pc;
  try { return fn(); } finally { PARTY_CASE = null; }
}
const c122 = w.Game_Interpreter.prototype.command122;
w.Game_Interpreter.prototype.command122 = function (params) {
  if (EVENT_R === null || Number((params || this._params)[3]) !== 2) return c122.apply(this, arguments);
  const mr = w.Math.random;
  w.Math.random = () => EVENT_R;
  try { return c122.apply(this, arguments); } finally { w.Math.random = mr; }
};
function eventRandomBranches(troopId) {
  const out = [];
  for (const pg of w.$dataTroops[troopId].pages) for (const c of pg.list)
    if (c.code === 122 && c.parameters[0] <= 844 && 844 <= c.parameters[1] && c.parameters[3] === 2) {
      const n = c.parameters[5] - c.parameters[4] + 1;
      for (let k = 0; k < n; k++) if (k !== Math.floor(n * 0.5) && !out.includes(k / n)) out.push(k / n);
    }
  return out;
}
function runEventRandom(troopId, r, flags = null, turnPreset = 2) {
  EVENT_R = r;
  try { return Object.assign(run(troopId, false, null, 0, 0, flags, turnPreset), {variant: 't1', eventRandom: r}); } finally { EVENT_R = null; }
}
const COVER = process.env.XIYOU_COVER === '1', coverByCase = [];
let ran = null;
if (COVER) {
  const where = new Map();
  w.$dataTroops.forEach(t => t && t.pages.forEach((pg, p) => where.set(pg.list, 't' + t.id + 'p' + p)));
  w.$dataCommonEvents.forEach(ce => ce && where.set(ce.list, 'ce' + ce.id));
  const exec = w.Game_Interpreter.prototype.executeCommand;
  w.Game_Interpreter.prototype.executeCommand = function () {
    const at = ran && where.get(this._list), start = this._index, cmd = at && this.currentCommand();
    const res = exec.apply(this, arguments);
    if (cmd) {
      ran.add(at + ':' + start);
      if (cmd.code === 101) for (let i = start + 1; i < this._index; i++) ran.add(at + ':' + i);
    }
    return res;
  };
}

// hpRate：开战前把敌人 0 的 HP 设为上限的这个比例（向下取整），照常跑两回合；消息忙时直接关掉（模拟玩家读完），
// 记录 messages（每条的回合与文字）与回合结束时各敌人的 enemyId（三十层敌群 466：HP≤25% 第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// flags：开战前把这些敌群页标为已执行（$gameTroop._eventFlags），旧例不写字段。
// hpEnemy：hpRate 预置的敌人序号（默认 0 不写字段）。
// vars：开战前另设的变量（{变量号: 值}，默认不写字段）。
// GC 11-08（tools-troop-shards）：分段并行。XIYOU_PROBE_SHARD=i/n 时只跑「全局用例序号 % n == i」的用例（序号＝run() 被调用的先后，
// 与单进程的 cases 顺序一致），其余返回占位、最后滤掉；XIYOU_TROOP_OUT 改写输出路径。拼回见 同步正式西游.py 的 TROOP_MERGE_JS
// （按序号交错，与单进程逐字相同）。不设就是单进程，行为与旧版完全相同。XIYOU_COVER 的下标是全局的，所以不许与分段同用。
const SHARD = (() => {
  const m = /^(\d+)\/(\d+)$/.exec(process.env.XIYOU_PROBE_SHARD || '');
  if (!m) return null;
  const i = Number(m[1]), n = Number(m[2]);
  if (!(n >= 1 && i < n)) throw new Error('XIYOU_PROBE_SHARD 不合法：' + process.env.XIYOU_PROBE_SHARD);
  if (process.env.XIYOU_COVER === '1') throw new Error('XIYOU_COVER 记录的下标是全局的，不能与 XIYOU_PROBE_SHARD 同用');
  return {i, n};
})();
// XIYOU_PROBE_FROM=k（开发用）：只跑全局用例序号 ≥ k 的「尾部新例」，输出只含这些例，必须同时给 XIYOU_TROOP_OUT（免得盖掉整份产物）；
// 可与 XIYOU_PROBE_SHARD 同用。新例的序号看 cases 总数（上一份产物的 cases.length）。
const FROM = Number(process.env.XIYOU_PROBE_FROM || 0);
if (FROM > 0 && !process.env.XIYOU_TROOP_OUT) throw new Error('XIYOU_PROBE_FROM 只出部分用例，必须同时给 XIYOU_TROOP_OUT');
if (FROM > 0 && process.env.XIYOU_COVER === '1') throw new Error('XIYOU_COVER 记录的下标是全局的，不能与 XIYOU_PROBE_FROM 同用');
const PARTIAL = !!SHARD || FROM > 0;
let caseCounter = 0;
// switches：开战前打开的开关（[开关号…]，默认不写字段；rules-gaps6 木桩抵抗档 174～177、S3西游模式 682）。
function run(troopId, paid = false, preset = null, target = 0, hpRate = 0, flags = null, turnPreset = 0, hpEnemy = 0, vars = null, switches = null) {
  { const idx = caseCounter++; if (idx < FROM || (SHARD && idx % SHARD.n !== SHARD.i)) return {__skip: true}; }
  if (COVER) { ran = new Set(); coverByCase.push(ran); }
  // rules-gaps5：上一例的敌我精灵代理不再用到；不清的话 Map 一直攥着历届 Game_Battler，900 多例后默认堆 OOM（XIYOU_COVER 时更快）
  sprites.clear();
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  const party = PARTY_CASE ? PARTY_CASE.party : PARTY;
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});');
  w.$gameVariables.setValue(842, paid ? 1 : 0);
  if (vars) for (const k of Object.keys(vars)) w.$gameVariables.setValue(Number(k), vars[k]);
  if (switches) for (const k of switches) w.$gameSwitches.setValue(k, true);
  for (const id of party) {
    const a = w.$gameActors.actor(id);
    [6168, 5980, 5548].concat([1, 2, 3, 4, 5, 6, 7, 52].includes(id) ? [2571, 2786] : []).forEach(k => a.learnSkill(k));
    a.refresh(); a.recoverAll();
  }
  if (!w.$dataMap) w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const BM = w.BattleManager;
  w.Math.random = () => 0.99;
  BM.setup(troopId, false, false);
  BM._logWindow = stub; BM._spriteset = stub; BM._statusWindow = stub;
  w.Math.random = () => 0.5;
  if (PARTY_CASE) for (const id of Object.keys(PARTY_CASE.skills || {})) for (const k of PARTY_CASE.skills[id]) {
    const a = w.$gameActors.actor(Number(id));
    if (k > 0) a.learnSkill(k); else a.forgetSkill(-k);
  }
  const out = {troop: troopId, paid, actions: [], invokes: [], errors: [], battlers: {}};
  if (vars) out.vars = vars;
  if (switches) out.switches = switches;
  if (PARTY_CASE) { out.party = party; out.actorSkills = PARTY_CASE.skills || {}; }
  if (target !== 0) out.target = target;   // 玩家普通攻击的敌人序号（默认 0 不写字段，旧例逐字节不变）
  // turnPreset：开战前把回合计数设为这个值（金之巨人 830 第 20 回合强制 8203：从头打到 20 回合队伍早已倒下），跑到该回合结束；
  // 开战检查与第 N 回合的消息一并记录
  if (turnPreset) { out.turnPreset = turnPreset; out.messages = []; w.$gameTroop._turnCount = turnPreset; }
  if (flags) { out.flags = flags; for (const i of flags) w.$gameTroop._eventFlags[i] = true; }
  if (hpRate) {
    out.hpRate = hpRate; out.messages = [];
    if (hpEnemy) out.hpEnemy = hpEnemy;
    const e0 = w.$gameTroop.members()[hpEnemy];
    e0.setHp(Math.floor(e0.mhp * hpRate));
    out.hpPreset = e0.hp;
  }
  // preset：开战前把敌人 HP 设成定值（{敌人序号: hp}），只跑到第 1 回合输入前，记开场敌群事件的结果
  if (preset) {
    out.preset = preset;
    for (const i of Object.keys(preset)) w.$gameTroop.members()[Number(i)].setHp(preset[i]);
  }
  // 下一回合开始（BattleManager.startTurn，回合末事件已跑完）时各敌人的状态与剩余回合：Godot run_turn 跑完一回合（含回合末事件）后就是这个时点
  // （沙僧50 内容批 P2-C1：领域事件给全体敌人的 44 第 1 回合末 2→1）
  const st0 = BM.startTurn;
  out.turnStarts = [];
  BM.startTurn = function () {
    if (w.$gameTroop._turnCount > 0) {
      const enemies = {};
      for (const e of w.$gameTroop.members()) enemies[key(e)] = {hp: e.hp, states: e._states.slice(), turns: Object.assign({}, e._stateTurns)};
      out.turnStarts.push({after: w.$gameTroop._turnCount, enemies});
    }
    return st0.apply(this, arguments);
  };
  const inv = BM.invokeAction, sa = BM.startAction;
  BM.startAction = function () {
    const s = this._subject, act = s && s.currentAction();
    out.actions.push({turn: w.$gameTroop._turnCount, subject: s && key(s), skill: act && act.item() ? act.item().id : null,
      forced: !!(act && act._forcing), processingForced: !!this._processingForcedAction});
    return sa.call(this);
  };
  BM.invokeAction = function (su, t) {
    const hp0 = t.hp; popups = [];
    const res = inv.call(this, su, t);
    out.invokes.push({turn: w.$gameTroop._turnCount, subject: key(su), skill: this._action && this._action.item() ? this._action.item().id : null,
      target: key(t), hpBefore: hp0, hpAfter: t.hp, popups, userAtk: su.atk, userMat: su.mat,
      userStates: su._states.slice(), targetStates: t._states.slice()});
    popups = null;
    return res;
  };
  try {
    BM.startBattle();
    for (let i = 0; i < 20000; i++) {
      if (BM._phase === 'battleEnd' || w.$gameTroop._turnCount > (turnPreset ? turnPreset + 1 : 2) || BM.isBattleEnd && BM._phase === null) break;
      if (preset && BM._phase === 'input') break;
      if ((hpRate || turnPreset) && w.$gameMessage.isBusy()) {
        out.messages.push({turn: w.$gameTroop._turnCount, texts: w.$gameMessage._texts.slice(), faceName: w.$gameMessage.faceName()});
        w.$gameMessage.clear();
        continue;
      }
      if (BM._phase === 'input') {
        const act = BM.inputtingAction();
        if (act) { act.setAttack(); act.setTarget(target); }
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.invokeAction = inv; BM.startAction = sa; BM.startTurn = st0;
  ran = null;
  // rules-gaps6：敌群页里的 353 游戏结束（圣劫使 825 第 30 回合）在无场景引擎里只留下 SceneManager._nextScene，
  // 不清的话之后每例 BattleManager 都当作「正在换场景」、停在 start 不动。记下换到的场景再清掉（旧例没有换场景，不写字段）
  if (w.SceneManager._nextScene) { out.sceneChange = w.SceneManager._nextScene.constructor.name; w.SceneManager._nextScene = null; }
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members()))
    out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, atk: b.atk, mat: b.mat, agi: b.agi, states: b._states.slice()};
  if (hpRate) out.enemyIds = w.$gameTroop.members().map(e => e.enemyId());
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return out;
}

// rules-gaps9：只在战斗里跑的公共事件（内容覆盖检查.py 的 battleOnlyCommonEvents：场合＝战斗的技能／物品效果 44 起点可达、
// 地图页与别的场合都调不到；这里按原版数据同法算，不读切片，所以比切片里的多几个，Godot 侧跳过切片没有的）。上面的敌群例玩家只普攻，
// 这些事件几乎跑不到。每个直接起点各一例：敌群 2、全员 HP 加到打不死，CE 里第一个「111 角色在队」的角色（没有就 1 号）当使用者，
// 学会起点技能（物品就给 5 个），第 1 回合输入时用它打敌人 0，其余人防御；CE 里有「111 角色会技能 K」时分 met（都学会）／unmet（都忘掉）两例，
// 没有就一例 plain。跑到第 1 回合结束，记行动序列（行动者、技能或物品、是否强制）、公共事件开跑时刻，
// 以及事件之后下一个非强制行动开始时（或回合结束）CE 里 313／333 提到的那些状态在谁身上（snap）。
// 用例带 party 字段，oracle_additions 按 (troop, paid, variant) 成键；variant＝'ce<号>.<met|unmet|plain>'。
const SKILL_CE = (() => {
  const ces = w.$dataCommonEvents, occ = new Map();
  const calls = list => new Set((list || []).filter(c => c.code === 117 && ces[c.parameters[0]]).map(c => c.parameters[0]));
  const closure = start => { const seen = new Set(start), q = [...start];
    while (q.length) for (const x of calls(ces[q.pop()].list)) if (!seen.has(x)) { seen.add(x); q.push(x); }
    return seen; };
  const srcs = new Map();
  for (const [kind, tab] of [['skill', w.$dataSkills], ['item', w.$dataItems]]) for (const r of tab) if (r) for (const e of r.effects || [])
    if (e.code === 44 && ces[e.dataId]) {
      if (!occ.has(e.dataId)) occ.set(e.dataId, new Set());
      occ.get(e.dataId).add(r.occasion);
      if (r.occasion === 1) { if (!srcs.has(e.dataId)) srcs.set(e.dataId, []);
        srcs.get(e.dataId).push({kind, id: r.id, single: r.effects.filter(x => x.code === 44).length === 1}); }
    }
  const mapStart = new Set();
  for (const f of fs.readdirSync(path.join(APP, 'data'))) if (/^Map\d{3}\.json$/.test(f))
    for (const e of JSON.parse(fs.readFileSync(path.join(APP, 'data', f), 'utf8')).events || []) if (e)
      for (const pg of e.pages || []) for (const x of calls(pg.list)) mapStart.add(x);
  const only = [...occ].filter(([, s]) => s.size === 1 && s.has(1)).map(([id]) => id);
  const other = [...occ].filter(([, s]) => !(s.size === 1 && s.has(1))).map(([id]) => id);
  const bad = closure([...mapStart, ...other]);
  const out = [];
  for (const ce of [...closure(only)].filter(x => !bad.has(x) && srcs.has(x)).sort((a, b) => a - b)) {
    const list = ces[ce].list, sub = closure([ce]);
    const conds = list.filter(c => c.code === 111 && c.parameters[0] === 4);
    // 使用者：CE 里第一个「111 角色在队」的角色，没有就第一个 111 角色条件、再没有就第一个强制行动（339）的角色，都没有取 1 号。
    // 队伍：使用者在前，再放 CE 里 111／313／339 提到的其余角色（原版 339 对不在队的角色照样强制，重制只认在队的，实战这些人都在队），
    // 不满 4 人用 1／8／9／10 补
    const forcedActors = [...sub].flatMap(id => ces[id].list.filter(c => c.code === 339 && c.parameters[0] === 1).map(c => c.parameters[1]));
    const user = ((conds.find(c => c.parameters[2] === 0) || conds[0] || {parameters: [4, forcedActors[0] || 1]}).parameters[1]);
    const named = [...sub].flatMap(id => ces[id].list.filter(c => c.code === 111 && c.parameters[0] === 4).map(c => c.parameters[1])
      .concat(ces[id].list.filter(c => c.code === 313 && c.parameters[0] === 0 && c.parameters[1] > 0).map(c => c.parameters[1])))
      .concat(forcedActors).filter(a => w.$dataActors[a]);
    const party = [...new Set([user, ...named, 1, 8, 9, 10])].slice(0, 4);
    const learn = conds.filter(c => c.parameters[2] === 3).map(c => [c.parameters[1], c.parameters[3]]);
    const watch = new Set();
    for (const id of sub) for (const c of ces[id].list) if (c.code === 313 || c.code === 333) watch.add(c.parameters[3] !== undefined && c.code === 313 ? c.parameters[3] : c.parameters[2]);
    const src = srcs.get(ce).find(s => s.single) || srcs.get(ce)[0];
    for (const v of learn.length ? ['met', 'unmet'] : ['plain']) out.push({ce, user, party, learn, src, watch: [...watch].sort((a, b) => a - b), v});
  }
  return out;
})();
// 1516 鼬万花筒：261 播放影片在无场景引擎里 Graphics._playVideo 读不到 video 元素报错、事件停下；没有 _video 时按「放完」处理
const playVideo = w.Graphics.playVideo;
w.Graphics.playVideo = function () { return this._video ? playVideo.apply(this, arguments) : undefined; };
const isVideoPlaying = w.Graphics.isVideoPlaying;
w.Graphics.isVideoPlaying = function () { return this._video ? isVideoPlaying.apply(this, arguments) : false; };
function runSkillCE(sc) {
  { const idx = caseCounter++; if (idx < FROM || (SHARD && idx % SHARD.n !== SHARD.i)) return {__skip: true}; }
  if (COVER) { ran = new Set(); coverByCase.push(ran); }
  sprites.clear();
  const party = sc.party;
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  // 照常 addActor（继承难度等）；部分高号角色（超强者等）默认难度会被拦，之后直接写 _actors 补上
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});$gameParty._actors=' + JSON.stringify(party) + ';');
  const skills = {[sc.user]: sc.src.kind === 'skill' ? [sc.src.id] : []};
  for (const [a, k] of sc.learn) (skills[a] = skills[a] || []).push(sc.v === 'met' ? k : -k);
  for (const id of party) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 999999999; }
  for (const id of Object.keys(skills)) for (const k of skills[id]) { const a = w.$gameActors.actor(Number(id)); if (k > 0) a.learnSkill(k); else a.forgetSkill(-k); }
  if (sc.src.kind === 'item') w.$gameParty.gainItem(w.$dataItems[sc.src.id], 5);
  for (const id of party) { const a = w.$gameActors.actor(id); a.refresh(); a.recoverAll(); a._tp = 100; }
  if (!w.$dataMap) w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const BM = w.BattleManager;
  w.Math.random = () => 0.99;
  BM.setup(2, false, false);
  BM._logWindow = stub; BM._spriteset = stub; BM._statusWindow = stub;
  w.Math.random = () => 0.5;
  w.$gameTroop.members().forEach(e => { e._paramPlus[0] = 999999999; e.recoverAll(); });
  const out = {troop: 2, paid: false, variant: 'ce' + sc.ce + '.' + sc.v, skillCE: sc.ce, party, actorSkills: skills,
    use: [sc.src.kind, sc.src.id, sc.user], watch: sc.watch, actions: [], invokes: [], events: [], errors: [], battlers: {}};
  const snap = () => { const s = {};
    for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members())) s[key(b)] = b._states.filter(x => sc.watch.includes(x));
    return s; };
  const sa = BM.startAction, setupCE = w.Game_Interpreter.prototype.setupReservedCommonEvent;
  BM.startAction = function () {
    const s = this._subject, act = s && s.currentAction(), forcing = !!(act && act._forcing);
    if (!forcing && !out.snap && out.events.some(e => e.commonEvent === sc.ce)) out.snap = snap();
    out.actions.push({subject: s && key(s), item: act && act.item() ? [act.isItem() ? 'item' : 'skill', act.item().id] : null, forced: forcing});
    return sa.call(this);
  };
  w.Game_Interpreter.prototype.setupReservedCommonEvent = function () {
    const id = w.$gameTemp._commonEventId, ok = setupCE.apply(this, arguments);
    if (ok) out.events.push({commonEvent: id, afterActions: out.actions.length});
    return ok;
  };
  let used = false;
  try {
    BM.startBattle();
    for (let i = 0; i < 20000; i++) {
      if (BM._phase === 'battleEnd' || w.$gameTroop._turnCount > 1) break;
      if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
      if (BM._phase === 'input') {
        const actor = BM.actor(), act = BM.inputtingAction();
        if (act && actor && actor.actorId() === sc.user && !used) {
          if (sc.src.kind === 'item') act.setItem(sc.src.id); else act.setSkill(sc.src.id);
          act.setTarget(0); used = true;
        } else if (act) act.setGuard();
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.startAction = sa; w.Game_Interpreter.prototype.setupReservedCommonEvent = setupCE;
  ran = null;
  if (w.SceneManager._nextScene) { out.sceneChange = w.SceneManager._nextScene.constructor.name; w.SceneManager._nextScene = null; }
  if (!out.snap) out.snap = snap();
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members())) out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, states: b._states.slice()};
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return out;
}

const result = {sourceIdentity: identity, party: PARTY, difficulty: 3,
  cases: TROOPS.map(id => run(id)).concat([111,118,138,172,173,174,333,456,457,458,459,460,461,462,463,464,465,466].map(id => run(id, true)))
    // 敌群 462 有金角、银角两名守层者：玩家集火银角（敌人 1），看第二名守层者受击与行动
    .concat([run(462, false, null, 1), run(462, true, null, 1)])
    // 十五层副本废墟深处：敌群 160 控尸者（第 3 名）HP≤1% 时两只丧尸附加战斗不能（只记开场敌群事件）
    .concat([run(160, false, {2: 1})])
    // accept4：控尸者 160 不预置 HP 的整两回合例。和上面的 preset 例同为 (160, 未交礼)，加 variant 区分键（oracle_additions 认 variant）
    .concat([Object.assign(run(160), {variant: 'noPreset'})])
    // 三十层敌群 466 玉皇大帝 HP≤25%：第 3 页对话、变身 538 与之后的强制行动（交礼／未交礼各一例）
    .concat([run(466, false, null, 0, 0.25), run(466, true, null, 0, 0.25)])
    // 三十一至三十三层守层者 HP≤30%（第 3 页）与 HP≤10%（第 3 页已执行，第 4 页变身）；Map055 引路人 794 HP≤20%（第 4 页变身 922）
    .concat([467, 468, 469].flatMap(id => [run(id, false, null, 0, 0.3), run(id, false, null, 0, 0.1, [2])]))
    .concat([run(794, false, null, 0, 0.2)])
    // 三十一层可选首领：HP≤20%（第 3 页对话＋1397）；瑞丁 818 HP≤10%（第 3 页）与 HP≤5%（预置第 3 页已执行，第 4 页变身 938＋1399）
    .concat([125, 126, 816, 817, 830, 831].map(id => run(id, false, null, 0, 0.2)))
    .concat([run(818, false, null, 0, 0.1), run(818, false, null, 0, 0.05, [2])])
    // 金之巨人 830 第 20 回合（第 4 页：101 对话＋强制 8203「毁灭」）：回合计数预置 19，跑到第 20 回合
    .concat([run(830, false, null, 0, 0, null, 19)])
    // t1（cc events13，敌群页覆盖.py 实例最多的簇「页条件：回合 3+3·X」）：守层者／首领第 1 页第 3 回合起每 3 回合随机强制（变量 844），
    // 开战两回合跑不到。回合计数预置 2、跑第 3 回合；Godot 侧只比开战检查与第 3 回合的对话、强制行动［行动者, 技能］（variant t1）
    .concat(T1_TURN3.map(id => Object.assign(run(id, false, null, 0, 0, null, 2), {variant: 't1'})))
    // floor1：新源新增敌群的已交礼例、血线页例、第 3 回合以后的回合页例（各常量的说明见文件开头）
    .concat(PAID_V062.map(id => run(id, true)))
    .concat(Object.entries(HP_V062).flatMap(([id, rows]) => rows.map(([rate, fl]) => run(Number(id), false, null, 0, rate, fl.length ? fl : null))))
    .concat(LATE_V062.map(([id, n]) => Object.assign(run(id, false, null, 0, 0, null, n), {variant: 't1'})))
    .concat(HP_GAPS4.map(([id, rate]) => run(id, false, null, 0, rate)))
    // rules-gaps5：敌人 1 的血线页（variant hpE1 单独成键）
    .concat(HP_ENEMY1.map(([id, rate]) => Object.assign(run(id, false, null, 0, rate, null, 0, 1), {variant: 'hpE1'})))
    // rules-gaps5：血线页的变量门（variant hpVar 单独成键；同敌群多例再带 hpEnemy 区分，见 oracle_additions）
    .concat(HP_VARS.map(([id, rate, ei, v]) => Object.assign(run(id, false, null, 0, rate, null, 0, ei, {[v]: 1}), {variant: ei ? 'hpVarE' + ei : 'hpVar'})))
    // rules-gaps5：t1 例的变量 844 其余各支（见 EVENT_R）
    .concat(T1_TURN3.flatMap(id => eventRandomBranches(id).map(r => runEventRandom(id, r))))
    // rules-gaps6（敌群页覆盖剩 178 条的第一批）：后期回合页（LATE_GAPS6）
    .concat(LATE_GAPS6.map(([id, n, fl]) => Object.assign(run(id, false, null, 0, 0, fl, n), {variant: 't1'})))
    // 已交见面礼（变量 842＝1）时第 1 页的否则支：嘤族之光 739、蛮荒圣人 599
    .concat([739, 599].map(id => run(id, true)))
    // 神劫使 824 第 1 页「变量 1178（小明基因锁）≥ 6」时 335 显示其余 5 名敌人
    .concat([Object.assign(run(824, false, null, 0, 0, null, 0, 0, {1178: 6}), {variant: 'v1178'})])
    // 木桩Ⅰ～Ⅵ 70～75 与英雄级木桩 352～355 开场按抵抗档开关 174～177（抵抗1W／5W／10W／50W）给自己加状态：每档一例
    .concat([70, 71, 72, 73, 74, 75, 352, 353, 354, 355].flatMap(id => [174, 175, 176, 177].map(sw =>
      Object.assign(run(id, false, null, 0, 0, null, 0, 0, null, [sw]), {variant: 'sw' + sw}))))
    // SW682（见文件开头）
    .concat(SW682.map(id => Object.assign(run(id, false, null, 0, 0, null, 0, 0, null, [682]), {variant: 'sw682'})))
    // 木桩 826（Map004）：开局两回合、变量 4 随机的另一支（第 2 页 6063）、HP≤20% 第 3 页（变身 937）；被封印者普罗米修斯 392 开局两回合
    .concat([run(826), runEventRandom(826, 0), Object.assign(run(826, false, null, 0, 0.2), {variant: 'hp'}), run(392)])
    // PAGE2_844（见文件开头）：844＝2、3 两支（eventRandom 0.25／0.5），第 1 页预置已执行（variant t1，oracle_additions 键带 flags 区分）
    .concat(PAGE2_844.flatMap(id => [0.25, 0.5].map(r => runEventRandom(id, r, [0], 3))))
    // rules-gaps7：嘤嘤怪 1（YING_PARTY，见上）：队伍换成 1／4／20／29，各页的「带状态」支与否则支
    .concat(YING_CASES.map(([v, st, r, n]) => runParty({party: YING_PARTY, skills: st}, () =>
      Object.assign(r !== null ? runEventRandom(1, r, null, n) : run(1, false, null, 0, 0, null, n), {variant: v}))))
    // rules-gaps9：只在战斗里跑的公共事件（SKILL_CE，见上）
    .concat(SKILL_CE.map(runSkillCE))};
if (PARTIAL) result.cases = result.cases.filter(c => !c.__skip);
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(process.env.XIYOU_TROOP_OUT || path.join(__dirname, '.sandbox/troop_events.json'), JSON.stringify(result, null, 1));
if (COVER) fs.writeFileSync(path.join(__dirname, '.sandbox/troop_events_cover.json'), JSON.stringify({sourceIdentity: identity,
  note: 'troop_event_probe XIYOU_COVER=1：原版解释器实际执行到的敌群页／公共事件指令（位置:下标）',
  byCase: Object.fromEntries(coverByCase.map((s, i) => [String(i), [...s].sort()]))}));
process.stdout.write(JSON.stringify(result.cases.map(c => ({troop: c.troop, actions: c.actions.length, invokes: c.invokes.length, errors: c.errors.length, turn: c.turnCount, phase: c.phase}))) + '\n');
process.exit(0);
