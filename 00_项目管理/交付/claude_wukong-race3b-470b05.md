# 交付：claude/wukong-race3b-470b05

- 车道／工作者：C 规则·机制（含战斗画面指令窗、选敌说明卡）／悟空_63（Claude，写代码与参照）→ 悟空_64（Claude，收尾验证；10-29 从 `claude/wukong-race3` 903cd237 切出 `claude/wukong-race3b-470b05` 续上，原分支不再用）
- 状态：可合并

## 现状（2026-10-29 悟空_64 收尾）

- 第 2、3、5（画面）三项代码、参照、专项都已完成并验证（见「验证」）。main（3d6cf87d，含期一 dev.202、八戒异化词条）已在 dd478d08 合进，悟空_64 开工时 main 没有新提交，没再合。
- 改函数签名：本期没改签名；`prey()`、`insert_human()` 加的都是带缺省值的参数。

接期一（`claude/wukong-race2-aa701e`，交付单 `claude_wukong-race2-aa701e.md`，由唐僧另行合并），同一工作树从 c043ad6b 切出。

## 逐项：原版依据与重制落点

原版 `app.nw/js/codex/runtime/installNativeRaceRuntime.js`（下称 R），冻结 v0.28。原版画面用 `ui_reference` 战斗夹具（地图 5、敌群 2、美娜先手，把美娜设成魔族）截了三张：`race_blood_cmd_off`、`race_blood_cmd_on`、`race_select_poison`（只在本机截图目录，不入 Git）。

| 项 | 原版依据 | 重制落点 | 结论 |
| --- | --- | --- | --- |
| 2 妖族群攻手选猎物 | R:258 needsSelection 包装（妖族、对敌、全体、伤害类型 1／5 时也要选），R:259 onEnemyOk 包装（全体行动记 `_codexRacePreyIndex`），R:110–112 prey 先认手选（活着、在目标里才算，否则照旧自动选） | `race_battle.gd` needs_prey_selection／set_manual_prey／prey(manual)，手选按「角色＋技能」暂存，begin 时取走；`battle_scene.gd` _pick_target：妖族全体伤害进选敌，选中的记作猎物，行动对象仍是全体 | 做。**没改 battle_logic.gd** |
| 3 战斗指令「血契：开／关」 | R:260 makeCommandList 包装（魔族在最后加一行），R:261 处理器（取反、setup 重画、再激活） | `race_battle.gd` blood_command_text、`race.gd` toggle_blood；`battle_scene.gd` _command_entries 加在「逃跑」后，_command_for 处理 raceBlood（重建指令、光标照 selectLast：记忆指令开时停在血契） | 做。原版窗 851,462,220,225（7 行），重制一致 |
| 5 选敌时的毒鸡汤说明（画面） | R:215 Window_BattleEnemy.updateHelp 包装：有毒鸡汤时说明卡 `setText(敌人名\n说明)` 并显示；HelpExtend.js:356 setText＝假物品一行 12 号白字；YEP 的 setBattler 在 Sprite_ItemHelp 上不存在（异常被 YEP 吞掉），所以没毒鸡汤时原版什么也不画 | `help_card.gd` show_text；`battle_scene.gd` _poison_help（_select_target 里调） | 做，带优化 O-107（见下） |

## 优化 O-107（选敌毒鸡汤说明卡，可回退）

- 原版：说明卡位置是「上一张卡的位置」再走一次 setItem 修正（x<900 右移 52、y<220 下移 32…），选敌时每动一次光标就再挪一次；移到没有毒鸡汤的敌人时，上一只的文字留着不收。
- 优化：卡贴在该敌人（连同脚下名字与血条，约 180 宽）右侧，放不下放左侧；没有毒鸡汤就收起。
- 回退：`battle_scene.gd` 的 `POISON_HELP_NEAR := false`（照原版漂移、不收）。
- 优化登记条目（请总装并入 `00_设计/优化登记.md`）：`| O-107 | 选敌毒鸡汤说明卡位置 | 原版说明卡从上一张卡位置每次再挪一次、选到没毒的敌人也不收；改为贴敌人旁、没毒就收 | battle_scene.gd POISON_HELP_NEAR=false 回退 |`

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】种族祝福期二·期二：妖族群攻手选猎物、战斗指令「血契：开／关」、选敌毒鸡汤说明卡（dev.待定）

- 妖族用对全体敌人的伤害技能／物品时也进选敌，选中的那只当猎物（还活着、在目标里才算，否则照旧自动选最高预演）；行动仍打全体。手选在 XRaceBattle 里按角色＋技能暂存，行动根开始时取走，没改 battle_logic.gd。
- 魔族指令窗在「逃跑」后多一行「血契：关／开」，确定即切换、指令窗重画（记忆指令开时光标停在这行）。
- 选敌时该敌人本回合记有毒鸡汤：说明卡写「敌人名」「毒鸡汤（回合末） 名字：量；…」，样式同原版 setText（12 号白字、品质 0 外框）；位置按 O-107 贴敌人旁、没毒就收。
- 参照：`race_battle_probe.cjs` 加 battle.demon_manual（手选第三只、第一只、手选已倒下的回到自动、单体不受手选影响）与 needsSelection（无族／妖族／魔族 × 技能 1／3／9／10），51 例；专项 `xiyou_race_battle` 610→653；`xiyou_battle_ui` 加种族段（指令文字与窗矩形、切换、说明卡内容与位置、换目标收起），对原版截图。

## 交接板

- 下一步：种族「未移植」清单清完（R.status 死代码不移植）。另有范围外出入待定：原版 YEP「Select Help Window」开着，除 scope 0 外每个技能都先进选目标确认、帮助写「All Enemies」等，重制只对单体选择（已报唐僧）
- 用户试玩说明：魔族角色指令里多「血契：关／开」可直接切；妖族放全体技能时会让你点一只敌人当猎物；人族毒鸡汤打上后，选敌时指向该敌人会出说明卡
- 需要用户决定：O-107（说明卡贴敌人旁、没毒就收）是否保留

## 进度账

- 种族祝福：「未移植」清单 9 项全部了结（2、3 与 5 的画面本期做完）

## 验证

悟空_64，2026-10-29，工作树 `.claude/worktrees/wukong-race3b-470b05`：

- `新建工作树.sh --补齐` 通过。
- `同步正式西游.py --accept-additions` 通过：只重跑 `race_battle_probe.cjs`（61 个复用），`race_battle.json` cases 49→51（新增 demon_manual、needsSelection，原有用例测量不变），verify issues 为空；产物指纹留在本工作树。
- 选测（`并行测试.py … xiyou_race_ xiyou_power xiyou_status_power xiyou_battle xiyou_help_card xiyou_event_compare xiyou_dual_wield xiyou_item_list xiyou_flow xiyou_floor_run xiyou_determinism xiyou_poison_collapse xiyou_actor_p0`）27 个场景全过，无偶发，523 秒：`xiyou_race_battle` 653/653、`xiyou_race_menu` 66/66、`xiyou_battle_ui` 76/76（无头；截图检查不计）、`xiyou_help_card` 992/992（`_apply` 抽出后行为不变）、`xiyou_event_compare` 5/5、`xiyou_actor_p0` 3322/3322、`xiyou_determinism` 372/372、`xiyou_floor_run` a/b/c 273/332/560、`xiyou_poison_collapse` 191/191、`xiyou_dual_wield` 301/301、`xiyou_power*` 137/6136/55682/1068、`xiyou_status_power*` 36/11、`xiyou_battle*` 其余 8/13/22/108/92/50/5、`xiyou_flow` 48/48、`xiyou_item_list` 38/38。
- `xiyou_battle_ui` 窗口模式带 `--out` 单跑：99/99（含 20 张截图，与悟空_63 合 main 前一致）。
- 没跑全量 `检查.sh`（车道规矩）。

## 遗留

- 妖族手选猎物的画面流程只有规则测试（`xiyou_race_battle`），`xiyou_battle_ui` 还没有「妖族点全体技能→选敌→猎物」一段（派单里是可选项，为省额度没做）；可以下期补。

## 待交叉核查

- 改了的文件：`battle_scene.gd`（指令、选目标、说明卡）、`help_card.gd`（show_text，show_for 抽出 _apply，行为不变）、`race.gd`、`race_battle.gd`、`tests/xiyou_battle_ui.gd`、`tests/xiyou_race_battle.gd`、`race_battle_probe.cjs`。没碰 battle_logic.gd、damage.gd、alien_battle.gd、alienation.gd、actor.gd、battler.gd。

## 可优化（流程／工具／效率）

- 已做：O-107（见上）。
- 建议：`ui_reference` 战斗夹具没有「给角色设种族」的入口，本次在页面里用 JS 包 BattleManager.setup 临时设的；若以后常截种族画面，可在工具栏加按钮（B 界面车道，小活）。
- 流程：本次开同步前 pgrep 看到另一条同步在跑仍启动了（共用槽排队，没出问题）；下次照规矩先等。

## 本分支提交

- f243c7aa 妖族群攻手选猎物、战斗指令血契开关、选敌毒鸡汤说明卡（O-107）
- 750555c4 战斗画面验收加种族段
- dd478d08 合并 main
- 903cd237 暂停现状
- （本提交）收尾验证、交付单改名、可合并
