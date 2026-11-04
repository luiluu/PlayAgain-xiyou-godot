# 交付：cc/wukong-xuan4c

- 车道／工作者：C 规则／悟空（cc，悟空 xuan4c，Opus）
- 状态：进行中

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】璇第三期（期二）：60 级列星、手动先制（dev.待定）

- 60 级列星（`installThreeGrowthRelicRuntime`，`XXuanBattle._list_star60`、`incoming_ops`、`hp_after`）：列星期间首次回光或璃壁给目标归宿（60 级、不看法宝）；戴周天命星仪时首次回光额外净化一个（软状态也算），首次璃壁给星幕。归宿、星幕各让下一次敌方直接伤害 ×0.9（同时带 ×0.81），当回合有效，敌方直接伤害打出后消费（被护盾吸收也算）。资格按一次行动算，列星期间打到所有受益者的那一次全给；再放列星重置。自律内部施放同样算。
- 手动先制：量过原版，`Game_Action.speed` ＋100000 在 OTB 下没效果。排序只在回合开始做，这时行动是 `makeActions` 新建的空白行动（`seenInMakeSpeed` 只见到空白；手动带星纹与不带星纹排序一样；硬塞璃壁进行动才排到最前，说明包装本身是通的）。
- 优化 O-待定（`XXuanBattle.XIANZHAO_MANUAL_FIRST`，false 回到原版）：先照手动璃壁付费时把璇排到下个回合最前，排序预览同样显示。
- 测试：`xuan_auto_probe` 补 9 个 60 级例和 3 个 speed 例（17→29 例，hits、快照逐步对照）；定轨的序列扣血例换成真实动作序列（诸神黄昏 8048，`Hp -10%: actors`），两边都走真实路径，去掉手动包装次序的 `seqhit` 步骤。

## 交接板

- 下一步：璇第三期收尾，无接续。
- 用户试玩说明：璇 60 级列星后，第一次回光或璃壁的目标下一次受敌方直接伤害少一成；戴周天命星仪时第一次回光多净化一个负面状态，第一次璃壁再减一成。选了先照的手动璃壁，下个回合璇排最前。
- 需要用户决定：O-待定（先照手动先制）是保留重制的「下个回合最前」，还是回到原版的没效果。默认保留。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：`反向验证.py` 清单字段写错（`to` 代替 `replace`）直接抛 KeyError，可以先校验清单再开跑；归哪吒，收益小。

## 待交叉核查

- 核心文件改动：`battle_logic.gd`（`execute_hp_damage` 加 `XXuanBattle.hp_after`、`_otb_user_shift` 加 `manual_first_shift`）、`battle_scene.gd`（排序预览）、`actor_damage_hooks.gd`（`incoming_ops`）。
- 请看：①`_cast` 里 `_grants60` 的保存与清空，反向验证没咬住（去掉后测试仍过）：只在一次行动结束或回合末连放两个内部施放、且落到不同目标时才看得出，没写例子；②O-待定的「最前」夹在眩晕醒来的人之后（`_shift` 的 `minimum`）。

## 验证

- 原版探针 `xuan_auto_probe` 29 例在本树重跑，产物复制为夹具；`home_59` 放在最前（法宝被 60 级的璇同步过就留着进化标记，`$dataArmors` 跨例共用）。
- 反向验证（`反向验证.py`，`xiyou_xuan_auto`）：归宿不减伤、星幕不减伤（第一轮没咬住，伤害太小 ×0.81 和 ×0.9 取整同值，星幕例加 `enemyAtk` 后重验）、不消费归宿、额外净化只算硬控、列星不重置首次、不看法宝、先制不看开关、先制不看手动都咬住；内部施放不清资格没咬住（见上）。
- 回退开关：`xiyou_xuan_auto` 里 `XXuanBattle.XIANZHAO_MANUAL_FIRST = false` 有断言。`回退开关覆盖.py` 新缺口 0。
- `语法检查.py`：512 个 .gd，0 个问题。
- 专项：`xiyou_xuan_auto`、`xiyou_xuan_bind`、`xiyou_xuan_battle` 全过。

## 本分支提交

- 见 git log。
