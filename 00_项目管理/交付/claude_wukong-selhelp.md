# 交付：claude/wukong-selhelp

- 车道／工作者：C 规则·机制（战斗选目标）／悟空_64（Claude）
- 状态：进行中

接种族期二（`claude/wukong-race3b-470b05`，14a21ad8）在同一工作树切出。期一做完；期二（物品、反击、二刀流等别的入口）查过，见「期二」节。

## 原版依据（冻结 v0.28）

`plugins.js`：YEP_BattleEngineCore「Select Help Window」= true，帮助文字参数是英文原样（User／Ally／Allies／Enemy／Enemies／`All %1`／`%2 Random %1`），没有中文化。

| 环节 | 原版 | 结论 |
| --- | --- | --- |
| 哪些进确认 | `YEP_BattleEngineCore.js:3563–3567` needsSelection 包装：战斗中 scope 0 永不选；`isForceSelection()` 时其余全选。`:4704–4710` onSelectAction 先 forceSelection 再调原版（原版 `rpg_scenes.js:2608` 按 isForOpponent 进选敌或选我方），之后 resetSelection | 技能、物品列表确定后，scope 1～11 都进选目标 |
| 攻击指令 | `YEP_WeaponUnleash.js:959–971` commandAttack：先 `action.needsSelection()`（此时没 force），不需要就直接 selectNextCommand | 攻击不强制（攻击技能是全体时直接出手）；妖族的种族包装例外照旧 |
| 帮助文字 | `HelpExtend.js:526–529` 把战斗的 `_helpWindow` 换成 Sprite_ItemHelp；它没有 `setBattler`。`YEP_BattleEngineCore.js:5034–5038` 敌人窗 updateHelp 调 setBattler 抛错，被 try 吞掉；`:4871–4874` 我方窗 updateHelp 里那句被注释掉 | 「All Enemies」等文字**原版画不出来**；`drawSpecialSelectionText` 里的 startAllSelection 也跑不到 |
| 光标与高亮 | `:5020–5032` 敌人窗 autoSelect＝furthestRight（全体、随机也一样，光标可移动）；`:4826–4842` 我方窗 autoSelect：自身 select 行动者并锁定，全体 cursorAll＋锁定；高亮只看 isSelected，allSelection 没开，所以只亮一个 | 全体／随机敌人：选敌、默认最右、可移动、只亮光标那只；自身：锁在行动者；全体我方（8／10）：锁在第 1 位、只亮第 1 位 |
| 取消 | `:4677–4684`／`:4695–4702` onActorCancel／onEnemyCancel 包装 → 原版 `rpg_scenes.js:2535`／`:2565` 按指令回技能／物品窗 | 回列表原位 |
| 自动战斗、敌人 AI、记忆指令 | 都不走 onSelectAction | 不受影响 |

原版实测（ui_reference 战斗夹具，美娜行动，指令「战技／魔法」→ 技能窗确定，页面内读窗口状态并截图 `selhelp_all_enemies`／`selhelp_random_enemy`／`selhelp_user`／`selhelp_all_allies`，只在本机 scratchpad，不入 Git）：闪电（2）、急冻寒冰箭（3）进选敌，敌人窗 index 2（最右），只有该敌人 isSelected；痛饮（11）我方窗 index 3（美娜）、`_inputLock`；次级治疗术（8）我方窗 index 0、cursorAll、`_inputLock`，只有狗逍遥 isSelected；四种帮助窗（Sprite_ItemHelp）都不可见；取消都回技能窗、光标原位。另见：原版选目标时角色指令窗仍显示（重制一向收起，见「遗留」）。

## 重制落点

- `battle_scene.gd` `_pick_target(skill, a, forced := true)`：新参数带缺省值（调用处只有本文件两处，`rg` 过）；技能／物品列表走 forced，攻击指令传 false。scope 0 照旧直接出手；其余进选目标：敌方范围（1～6）选敌、默认最右；7 活着的队友；9 倒下的队友；11 只有行动者；8／10 只有第 1 位。非单体范围确认后照旧返回占位目标（行动对象不变）。
- 妖族手选猎物接上：本来就进选敌，现在默认光标也照原版 furthestRight（上期取的是第一只，原版 autoSelect 是最右，顺手改正）；确认后照旧 `set_manual_prey`。
- 没碰 `battle_logic.gd`、`actor.gd`、`battler.gd`、`help_card.gd`。
- 帮助文字：原版不出字，重制也不出（不另做）。

## 期二：别的入口

- 物品：与技能同走 onSelectAction（`rpg_scenes.js:2595` onItemOk），重制同走 `_pick_action_list`，已一并生效。
- 反击、二刀流追加、连携等：都是行动里自动生成的目标，不经指令输入，原版没有这一步；不用补。
- 结论：期二无事可做。

## 优化

本期没做优化。建议（需要用户决定，未登记编号）：原版全体技能进确认时只亮一个目标，看起来像单体；可以改成全体时全部高亮（YEP 本意 startAllSelection，因说明卡缺 setBattler 没跑到），妖族群攻时光标那只另加标记当猎物。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】战斗选目标确认对原版（YEP Select Help Window）（dev.待定）

- 技能、物品确定后，除「无」范围外都先进选目标：全体／随机敌人进选敌（默认最右、可移动，只亮光标那只），自身锁在行动者，全体我方锁在第 1 位；取消回列表原位。攻击指令照原版不强制。原版帮助窗是 HelpExtend 说明卡，没有 setBattler，「All Enemies」等文字画不出来，重制也不画。
- 妖族群攻手选猎物默认光标改为最右（原版 autoSelect）。
- 验收：`xiyou_battle_ui` 加选目标确认段（全体敌人、自身、全体我方、攻击不强制）与妖族群攻选猎物段，对原版截图 `selhelp_*`。

## 交接板

- 下一步：删掉「范围外出入待定：原版 YEP Select Help Window…」那条（已做）
- 用户试玩说明：用全体、随机、自身、全体队友的技能或物品时，会先停在选目标一步，再按确定才放出（和原版一样）；取消回到列表
- 需要用户决定：全体技能确认时要不要全部高亮（见「优化」节建议）

## 进度账

- 战斗界面：选目标确认这处出入了结

## 验证

（待写）

## 遗留

- 原版选目标时角色指令窗仍显示，重制收起（`_pick_target` 一直如此，不在本期范围）。要对原版可以另派小活，`xiyou_battle_ui` 的 `target_cancel_returns` 等检查要跟着改。

## 待交叉核查

- 改了的文件：`battle_scene.gd`（`_pick_target`）、`tests/xiyou_battle_ui.gd`（`_choose_skill`、`_select_confirm`、`_prey_pick`）。没碰原沙僧独占的核心文件。

## 可优化（流程／工具／效率）

- 建议：ui_reference 战斗工具栏加「选目标确认」按钮（指定技能号走 commandSkill→onSkillOk 并读窗口状态）；本次是页面内 JS 写的，窗格在后台时要用 `__dhRef.pump` 推帧。B 界面车道，小活。

## 本分支提交

（待写）
