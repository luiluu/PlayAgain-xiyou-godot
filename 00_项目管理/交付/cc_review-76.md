# 交付：cc/review-76
- 状态：可合并
- 车道／工作者：cc（审查，GH8）

只有文档，没有游戏代码。分支从本地 main 0061051b5 切。只读核，没跑 Godot、没占测试槽；对照的是 `冻结正式源/v0.62.12`（必要处加看 v0.28）。

## 变更记录草稿

## 2026-11-10 【cc·审查】核查 11-10 合进 main 的批 1～4（审查第 76 期），并列进度账各行「还能做的」

- 核查覆盖：cc/rules-gaps12、cc/rules-autopassive1、cc/tools-probe-deps2（甲）；cc/rules-battle-pixel2、cc/rules-passive-order1、cc/battle-me1、cc/ui-zorder1（乙，对原版源码核）；cc/ui-pixel3、cc/review-75（丙，看结论）。
- 甲档结论：
  - gaps12 同时倒下先判输：对 `rpg_managers.js` 2614 `checkBattleEnd`（先 `$gameParty.isAllDead` 再 `$gameTroop.isAllDead`）和 YEP_BattleEngineCore 的包装（只加阶段与事件运行的前置判断，不改次序），通过。353 不复活、301 走结束画面，通过。
  - gaps12 的 EXTRA_ONCE_IDS：用 v0.62.12 数据重算「公共事件里 339 强制的技能，效果 44 又指回自己」，正好 9 个（28、110、621、945、979、980、985、1154、1365），只截 1365，通过。
  - autopassive1 的 `XActor.states()` 重排：对 GT_EquipSuitCore `sortEquipSuitBonusStates`（优先级降序；同优先级时比较函数是 `a - b`，两个对象相减得 NaN，V8 按「不小于」处理，所以保持原先后）通过。重制底层 `state_ids` 本来就按 MV sortStates 排好，只是套装状态的位置变了。krz_state_re 的缓存包装在 GT 外层，不影响次序。
  - probe-deps2：没有声明时 `coreFor(SELF_SHA)` 与旧 `coreFingerprint`、`keyOf` 与旧键、`ProbeCache.key(exclude=())` 与旧键都逐字相同；声明里的 from／to 与合并前后 `event_state_probe.cjs` 的 SHA-256 一致，main 上没再改过；`probe_change_scope.json` 已进 `PROBE_INPUTS`。通过，另记 P3-2。
- 发现：P2 1（旧账，不在本批）、P3 3。
  - **P2-1（旧账）米拉／渡鸦数值池第二期没移植**：`installMiraRavenNumberBoostRuntime.js`（v0.28 起就有）包了 `itemHit`／`itemEva`／`itemCri`。米拉 10140～10151、渡鸦 10122～10126 打敌人时必中、不闪避；渡鸦用普攻和非专属技能时不借面板暴击（+10×灵魂进度）。重制 `number_boost.gd` 头注释自己写着「第二期起未移植」，`battle_logic.gd` 的 `item_hit`／`item_eva`／`item_cri` 也没有接。灵魂进度现在是真值，所以渡鸦普攻会多吃面板暴击，两人的专属攻击会被闪避。优化登记、交接板都没有这一条，进度账「米拉渡鸦数值」一行却记的是 1。
  - **P3-1（gaps12）340 中止战斗停得太早**：原版 `command340` 只做 `BattleManager.abort()`，然后返回 true，`Game_Interpreter.update` 同一帧接着执行后面的指令，直到遇到等待或页尾。重制在 340 当场 halt。`xiyou_battle_end_ce` 断言「340 后面的 121 不执行」，跟原版正好相反。还有一个边角：同一帧里我方全灭再 340，原版 `checkAbort` 返回 false，接着走 `processDefeat`，分支结果被改写成 2（1308 照样预约，不复活，也不进结束画面）；重制给的是 1。数据里没有用到 340 的地方，现在走不到。
  - **P3-2（probe-deps2）presetKeys 写错不报**：`scopedSelf` 只看声明的键路径在不在预设里。路径拼错，或写了任何变体都没有的路径，这条声明就成了「不影响任何变体」，该重跑的变体会被取回。要等 1% 抽查或每日审计才抓得到。现在唯一的声明是空数组，没有实际影响。建议：最新那条声明（to＝当前 SHA）的每个键，至少要在一个变体的路径里出现，否则报错。
  - **P3-3 头注释过时，盘点时会误判**：`smart_ai.gd` 写「米拉／渡鸦／宿傩 profile 没移植」，原版只有甚尔、云裳注册了 profile，两个都做了；还没做的只有 Boss 霸体那一支，见下。`alien_battle.gd` 写「其余词条未移植」，原版 15 个词条在重制里都有。`options_scene.gd` 写「其余选项还没做、灰显」，现在只有测试模式那两项是灰的。
- 乙档另记（不是缺陷）：rules-battle-pixel2 之后，`view_of` 每条伤害记录都要算 `XSideStatus.cell_rows`，`state_kind` 每个状态跑 5 个正则、不缓存，还要做拼音排序。只是费时，见「可优化」。
- 规则：`进度审查与验证.md` 加一条：模块记满前回原版逐个对包装。`项目边界与操作规则.md` 加一条：补原版事件指令先看返回值。
- 玩家可见：无。

## 进度账：各行「还能做的」（按 Kyo 口径，建议表交总装导入）

口径：完成度只看地图事件与楼层，能做的做完就是 100%。下面六行逐项列「还能做的」；其余剩项标「不可做」，按 100 折算。解释器（70%）、楼层（97%）两行不在本表，照旧。

| 部分 | 权重 | 现在 | 建议 | 还能做的（证据） | 不可做、按 100 折算 |
| --- | ---: | ---: | ---: | --- | --- |
| 工程与工具 | 5 | 95% | **100%** | 无。P3-2（presetKeys 校验）只是工具健壮性，不算完成度 | 转换只覆盖切片：切片外的地图（212／229 之外）、角色（162／167 之外）都有登记理由（调试图、`<CodexDisabledActor>`）；选测漏选的风险靠全量兜底 |
| 战斗规则与战斗画面 | 8 | 86.5% | **98%** | ① P3-1 340 对齐原版（小）；② 全灭当下的状态格：原版 endBattle 清掉战斗状态后显示「i」，重制还显示状态图标（rules-battle-pixel2「没做的」）；③ 智能 AI 不给有霸体的 Boss 估控制状态（`Codex_SmartBattleAI.js` 390／396 行 `hasHyperArmor`，重制已有 `boss_hyper_armor`）；④ 14 处参数不是整数字面量的 `addState`，逐个核一遍能不能加上那 32 个状态（`未翻译块清单.py`） | 未翻译状态块 46 块全部不可达（同一工具）；敌群页剩 1 条原版也走不到；逃跑后地图曲时机（O-待定，等 Kyo）；战力（先藏） |
| 界面页面 | 6 | 88% | **98%** | ① 像素对照剩星级／角色仓库、宝珠镶嵌（ui-pixel3 下一步）；② 状态格点开的状态详情弹窗（`installEquipmentStatusRuntime` 的 stateRows 弹窗，分「异常／增益／常驻／全部」四页）重制没有；③ 改掉 `options_scene.gd` 的过时头注释 | 测试模式、GM 工具（只在 Kyo 本机解锁）；冻结后新排版（装备页、说明卡）记扩展账 |
| 装备系统 | 4 | 97% | **99.5%** | 法宝进化页、宝珠镶嵌页的像素对照（宝珠镶嵌与界面行共用一件事，只算一次） | 冻结后：专武吸取窗口（CodexV029／openAbsorb）、双持专武、至臻闪光，记扩展账；宝珠其余 YEP 效果行数据里没用到 |
| 养成与周边系统 | 18 | 98.3% | **99%**（做 O-035 时另算） | ① 异化「行动外的 gainHp／setHp」（公式副作用）也按帧加成、记镜骸：`alien_battle.gd` 21 行写着只接了 executeHpDamage；② 称号、星级仓库的像素对照；③（要 Kyo 点头）O-035 轮回「随机角色」模式：9 选 5、免费重抽一次、本局只能招募选中的伙伴、弱者协力 10453，还有 `itemAllowed` 阵容限制（`installReincarnationRandomRuntime.js` 101 行）。当初暂缓的理由是「等角色招募系统」，现在招募已经做了 | 种族战力预演（战力先藏）；抽奖动画（已移出分母）；技能树（Kyo 定移除）；签到（原版没装载） |
| 角色与专属机制 | 13 | 91.2% | **97%** | ① P2-1 米拉／渡鸦数值池第二期（必中、不闪避、渡鸦不借面板暴击）；② 谷雨赠春的 `isValid` 包装（`installNativeGuyuRuntime.js` 283 行：transferPreview 不合法时整次行动无效），`guyu.gd` 72 行写着未移植；③ 没招募的云裳说明卡与原版有一处小差（chars-gaps2）；④ `skill_progression.gd` 的 skills／条件按 unlocked 过滤（只差同步以外直接 learn_skill 的情形，小） | 5 名 `<CodexDisabledActor>`（143、144、145、157、160）进不了招募，基础一半按 161／161＝50 算；各模块的「旧档迁移」（不迁移 MV 存档）；黑闪遗忘（数据里没有）；宿傩看破闪避（YEP 闪避公式为 0，原版就无效）；导入角色缩放（v0.62.12 倍率恒为 1）；再生开花动画（原版画不到）；渡鸦 #3／#4、形象立绘逐张比，已由 raven6 做完（审查 75 乙档核过） |

套用后：合计 (5＋7.84＋4.2＋5.88＋3.98＋17.82＋12.61＋35.89)÷97＝93.22÷97＝**96.1%**（现在是 93.3%）。O-035 如果 Kyo 要做，养成行先回 98.5，做完再回 99。数字是我的估值，各行剩下的都是小项。建议依据栏写：「审查 76（Kyo 口径：能做的做完＝100，不可做的按 100 折算）：还能做的见交付单 cc_review-76」。

## 已核／未核
已核：甲 rules-gaps12、rules-autopassive1、tools-probe-deps2（`probe_change_scope.json`、`scopedSelf`／`coreFor`、`ProbeCache.key` 的 exclude／store、读文件登记）；乙 rules-battle-pixel2、rules-passive-order1（stateKind 与 sort 逐行对 `installEquipmentStatusRuntime.js` 185～204 行）、battle-me1（对 AudioManager.playMe／stopMe／playBgm）、ui-zorder1；丙 ui-pixel3、review-75。
未核：Godot 场景一个都没跑；troop 探针用例之间有没有残留状态，只看了 BM 包装都有还原（靠每日审计兜底）；像素数字没重量。

## 交接板
- 下一步：P2-1 和 P3-1 可以合成一期派规则车道（八戒）；P3-2 派工具车道（哪吒）；P3-3 的三处过时注释随车道顺手改。进度账按上表导入，O-035 是不是现在做，放进「需要用户决定」。
- 需要用户决定：O-035 轮回「随机角色」模式现在做不做（暂缓的理由「等角色招募系统」已经不成立）。默认不做，养成行按 99 算。

## 待交叉核查
无（审查线程自己的文档分支；两条规则改动是纯文档）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- `XSideStatus.state_kind` 按（状态号、是否被动）缓存；只有 `XZhenqi.pojia_state` 会改状态字典，那一个跳过缓存就行。`view_of` 每条伤害记录都调它，挂机、快速战斗跑得多。
- 地图上 221／222 和场所移动的淡出淡入是 18 帧，原版是 24 帧；201 的淡出类型（白、无）也还没认（ui-zorder1 记的）。这是解释器行的事，可以派给分段车道顺手做。
