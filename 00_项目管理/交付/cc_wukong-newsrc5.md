# 交付：cc/wukong-newsrc5

- 车道／工作者：CS C 规则·强弱分类＋异化开关＋真气差异清单（cc，悟空）
- 状态：**①② 返修完成，可交总装合集成分支；④ 真气没动手，转下一位**（见「接续要点」）
- 基线：从 `cc/newsrc-switch` 4e72d5cc 切出；工作树 `.claude/worktrees/wukong-newsrc4`（沿用，分支已换），`冻结正式源/app.nw` 指 v0.62.12，跑测试和探针都设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：KyoTier 强弱分类、异化 v0.58 隐藏开关（dev.待定）

- 新 `XTier`（`modes/xiyou/core/tier.gd`，正式 v0.44 `installTierTagsV044` 的 CodexTier）：角色备注 `<KyoTier:超强者／强者>`，有名字没标签的是弱者。超强者名单（`XItemMarks.super_strong_ids`）、强者名单（新 `XPowerBooks.strong_ids()`）、弱者挑战 `is_weak`、难度传承（强弱档与补强档、167 号以后入队）、强者技能替换 `is_strong_classified` 都读它。产物里一个标签也没有（v0.44 以前的源）时各处退回原来的写死名单。v0.62.12 的标签和旧名单不一样：强者多了 121、150、151、153、154、158、178，超强者多了 174、176、177、179，150～158 里五人从超强者降成强者。
- 异化：正式 v0.58 整套隐藏，Kyo 11-05 定重制保持开启。新开关 `XAlienBattle.HIDDEN_V058`（默认 false）；打开时照 v0.58：遭遇、奖励不再出现，工坊打不开。物品隐藏、商店、读档还原、菜单项去掉还没跟（登记 O-待定·异化隐藏）。参照：`hboot` 新增 `opts.skipModules`（`shared/host.cjs` 的 `start({skipModules})` 传进去），`alien_battle_probe`、`alien_affix_probe` 跳过 `installAlienationHide`，量没装隐藏模块的原版行为；`xiyou_alien_battle` 另加默认开启与开关打开两组断言。
- 事件脚本里的 `CodexTier.nonWeakIds()`（公共事件 1345、1443～1445 等）翻译归 A：接口是 `XTier.non_weak_ids()`、`XTier.is_non_weak()`、`is_weak()`、`tier_of()`。

## 交接板

- 下一步：④ 真气差异清单等协调者派；`mv_script.gd` `_boss_roster`（破阵·投影名单，v0.44 改成只读标签、去掉备用文字）还用写死的强者名单，归 A，改时用 `XPowerBooks.strong_ids()`，注意哈基米已带强者标签，别再追加。
- 用户试玩说明：无（集成分支）。
- 需要用户决定：无（异化 Kyo 已定）。

## 进度账

- 无变化。

## 结果

| 场景 | 前 | 后 |
|---|---|---|
| difficulty_inherit、_battle、_load | 各 200 条差 | 6120/6120 全过 |
| weak_challenge | 120/125 | 121/125：`classify` 过了，剩 4 条是说明卡新排版（归界面车道） |
| alien_battle | 219/322 | 334/334（参照改量没装隐藏模块的原版＋4 条开关断言） |
| alien_affix | 2113/2117 | 不变，原因不是隐藏：v0.62.12 下「行动外 setHp 带来源」对绝缘／舍身持有者不再拦／转（绝缘 0.8 照设成 6672、舍身照设到自己），旧源拦或转给搭档。要查是哪个核心改动（疑 RecPushState 或 `_subject`），归口径待查 |

## ④ 真气本命兵／神兵试炼差异清单（`installNativeZhenqiRuntime.js` 124 行差，未动手）

1. v0.45 十二类本命兵试炼：`Z.weaponMasters()` 由敌人备注 `<CodexZhenqi: weapon N>` 找每类武器唯一的神兵（单敌敌群），`Z.weaponMenu` 分页菜单（标「试炼完成」），`Z.startWeaponTrial` 校验后开战；`specState().weaponTrials` 记完成，完成即可指定该武器类型（兼容旧 `w` 记录）。
2. 幻境不重复产出：试炼敌人 `_codexZqTrialLoot` 时战利品清空，`_codexZqWeaponTrial` 时经验金钱为 0。
3. 指定道法：领悟灵根／本命兵时 `Z.pickSpecialization` 分页列已解锁的元素／武器类型，「指定「X」」「随机（X）」「稍后再选」；随机结果持久化在 `pendingDaofaRoll`，返回不重掷。`Z.finishDaofa` 写名字（如「本命兵·剑」）。
4. 灵根解锁来源：旧 `<Element Absorb:…>` 照认，再加只给灵根的新备注 `<CodexZhenqiLinggen:…>`，同元素只解锁、只提示一次。
5. v0.37 显示：瓶颈之战、神兵试炼、可指定本命兵的 Boss 显示首领血条（只走显示层）。
6. 闭关菜单多一项「神兵试炼（指定本命兵武器）」。
- 对应场景：zhenqi_break 7 条（1、3、4）、zhenqi_daofa 13 条（1、2、6）；5 属界面（`battle/boss_hp_bar.gd`）。估计 `zhenqi.gd` 一批，约半天。

## 返修（2026-11-06 第二棒，提交 55bd84a8）

- 对照办法：本树先跑现码，再临时让 `XTier.tagged()` 返回 false 跑同一组（已还原）。关掉后变绿的＝XTier 带的：floor_run、floor_run_b、floor_run_c、flow、yunshang；关掉照挂的＝别的车道带的：reincarnation_entry（`source null`、`skill8105 [167,166]`）、weapon_unleash（w93 解放技 5636 用不了）；floor_reach080 本机两次都过（云端那次疑偶发或别的车道，待 81cfd9af 整轮对照）。
- floor_run×3、flow 根因：`XYunshang.burst` 不管身上有没有针都 `state.actor(174)`，把没入队的云裳建出来（建出时被全员学技能操作带上难度技能，但没走入队同步）；读档 `sync_difficulty_after_load` 对 ≥167 走 `inherit_difficulty`，按标签 174 是超强者、属 lateActor，多学 6216，读档前后不一致。原版 `burst` 是 `source=$gameActors.actor(n.owner)`，只在有针可引爆时取。改成 `take > 0` 才取（`yunshang.gd`）。这是重制的写法错，不是原版行为，不用开关。
- yunshang `p4.borrow`：用 node 在 v0.62.12 实测，`addActor(174)` 后原版就是 `[5562,6216,10270]`，174 入队即带 6216；参照 `tests/fixtures/yunshang_oracle.json` 还是冻结 v0.28 出的（探针不接入同步）。按 v0.62.12 重跑 `yunshang_probe.cjs` 换掉参照：81 例里只有 p4.borrow（多 6216）、p8.clear（订单奖励 2942 翻倍 1→2）两例变，重制 1675/1675 全过。p8.clear 新旧参照重制都过，说明这条断言没比到奖励数量，**可疑，归云裳口径待查**。
- 异化开关：`HIDDEN_V058` 默认 false（异化照常出现，Kyo 11-05），原有 `hidden_v058.default_off`；补 `hidden_v058.default_encounter`：开关关时同一例照常遇到异化。alien_battle 335/335。

## 接续要点（给下一位，④ 真气）

- 差异清单见上「④」节，一条没做。本机现状：zhenqi_break 76/83（挂 `break.spec.linggen.c0～c2`、`break.spec.benming.c0～c2`：缺「指定道法」分页菜单；`flow_weapon_menu`），zhenqi_daofa 55/68（挂 `weapon.masters`、`weapon.menu.*`、`weapon.fromRetreat`、`weapon.start.k3／k6`、`weapon.fight.*`：十二类神兵试炼）。原版 `js/codex/runtime/installNativeZhenqiRuntime.js`（v0.62.12），重制 `modes/xiyou/core/zhenqi.gd`（888 行）。
- 先读失败日志：`并行测试.py … xiyou_zhenqi_break.tscn xiyou_zhenqi_daofa.tscn`（设 XIYOU_APP）。首领血条（第 5 条）归界面车道。

## 接续要点（第一棒留，已处理）

- 先在集成分支头 4e72d5cc 上云端跑一次这 8 个（或本机 `并行测试.py`，记得 `XIYOU_APP`），分清是 XTier 带的还是别的车道带的。
- 已知线索：
  - yunshang `p4.borrow.*.skills`：重制给云裳（174）多学了 6216。旧代码 `DIFFICULTY_NEW_STRONG` 是 167～173、175，不含 174；新 `_difficulty_late` 按标签把 174（超强者）也算进去。原版 `lateActor` 写法相同，但参照里 174 没有 6216，疑是原版这条路径根本没调 `syncActor`（探针走 BattleManager.setup，不走 startBattle），重制调的时机更早。要对一下重制在哪里调 `sync_difficulty`。
  - floor_run／flow 读档前后状态不同：`is_strong_classified` 现在对所有非弱者成立（原版 v0.44 `isStrongActor` = `CodexTier.isNonWeak`，同口径），读档 `repair_strong_classified` 会把弱档技能换成强档（忘掉再学，技能顺序也会变）。这是原版行为，测试的「读档前后一致」前提要看：存档前是不是本来就该已经换好（`learn_skill` 时就替换）。
  - reincarnation_entry `skill8105 [167,166]`：人数差 1，疑名单人数（标签名单和旧名单不同）。
  - weapon_unleash w93、floor_reach080 宝箱：还没看。
- 回退办法：XTier 只要让 `tagged()` 返回 false 就整体回旧名单（difficulty_inherit 三个又会挂）。

## 可回退

- `XAlienBattle.HIDDEN_V058`（O-待定·异化隐藏）。XTier 在产物没标签时自动回旧名单。

## 待交叉核查

- `tier.gd`（新）、`item_marks.gd`、`power_books.gd`、`weak_challenge.gd`、`xstate.gd`（难度传承）、`actor.gd`（`is_strong_classified`，原沙僧核心文件）、`alien_battle.gd`、`ui/menu.gd`、`hboot.cjs`／`shared/host.cjs`（`skipModules`，只在传了才生效）、两个异化探针、`xiyou_alien_battle.gd`、优化登记一行。

## 验证

- 第二棒本机新源：floor_run 273/273、floor_run_b 332/332、floor_run_c 560/560、flow 49/49、yunshang 1675/1675、yunshang_wraps 214/214、alien_battle 335/335；语法检查 0 问题。
- `事件空绿扫描.py --check` 不过：4739 条「event_states.json 没量／预设已删（产物过期）」，本树事件状态产物落后，本分支没碰预设和事件；`工具回归.py` 挂 `插件备注覆盖`（`test_known_unread` 多出 codexaura、disassemblepool 等，新源备注），同样不是本分支改动。两项请总装在集成分支同步后看。

- 本机新源：上表各场景；`xiyou_alien_workshop` 过；语法检查 0 问题。
- 云端选测（提交 468eab56，XTier 那次，基准 b5449f06）：409 个场景挂 94 个，其中 86 个在换源失败表（189）里本来就挂；**新挂 8 个**：floor_reach080、floor_run、floor_run_b、floor_run_c、flow、reincarnation_entry、weapon_unleash、yunshang。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42198464348 。集成分支头（4e72d5cc）没有云端整轮记录，8 个里哪些是别的车道合进来带的还没分清。
- 注意：`generated/oracle/alien_battle.json`、`alien_affix.json` 是本树重跑探针后的新参照（不入 Git）；集成分支下次同步会因探针改动重跑这两份，测量变化是有意的（不装隐藏模块），要写进换源接受单。

## 可优化（流程／工具／效率）

- `hboot` 的 `skipModules` 可以替掉 `alien_config_probe.cjs` 里手写的 `bootNoHide`（改 main.js 文本），归工具车道顺手收。

## 本分支提交

- `git log cc/newsrc-switch..cc/wukong-newsrc5`
