# 交付：cc/fix-liuying-gongfa

- 车道／工作者：B 界面／cc（Orca 车道，claude-opus-5-5＋medium）
- 状态：进行中

## 变更记录草稿

## 2026-11-14 【cc·界面·未经审查】流萤 179 技能菜单补「功法」页（dev.待定）

- 玩家反馈（v0.01.09，Kyo 11-14 转述）：「流萤看不到功法页面」。
- 根因：冻结源 v0.62.12 `js/codex/runtime/installV010UsabilityRuntime.js` 第 9 行 `newActor` 是 `id>=167 && id<=177 || id===179`，它包的 `Window_SkillType.makeCommandList`／`Game_Actor.addedSkillTypesForMenu` 给这些角色的技能菜单固定加「功法」页（技能类型 6，没学功法也列，排在被动前）。重制 ui7（cedd511db）移植时只照了 167～177，`XActorModules.menu_page_types` 把流萤 179 挡在外面；之后流萤 179 移植（5a9a8f6fc）没回头补这一处。流萤的职业特性里没有技能类型 6，所以菜单上就没有功法页，学了功法也看不到。原版里流萤能看到功法页，不是原版行为，属移植遗漏，照原版补齐，不设开关、不占 O 号。
- 修法：`modes/xiyou/core/actor_modules.gd` 加 `GONGFA_ACTOR_EXTRA := [179]` 与 `has_gongfa_page`，`menu_page_types` 改用它；178 与 180（五条悟，只进天启篇、原版没有）照旧不加。只管技能菜单，战斗指令不变。
- 发行包：`XActorModules`、`XSkillScene` 不在发行空壳名单里（`发行空壳.py targets()` 54 个类，不含它们），修复在发行包原样生效；判定与 `ReleaseEntry.is_release` 无关，不碰天启篇空壳和异化发行隐藏。
- 测试：`xiyou_battle_log` 的 `types.gongfa.fn` 补 179 有、180 没有；新增 `types.gongfa.liuying`（流萤菜单有功法页、排在被动前）、`types.gongfa.liuying.entries`（学玄天功·入门 7136 后功法页列的正是流萤的类型 6 技能）、`types.gongfa.liuying.release`（`simulate_release` 下同样）。本机单跑 77/77；反向验证 3/3 咬住（撤掉 179、功法页列错类型、发行构建下不给）。
- 玩家可见：流萤的技能菜单里有「功法」页了（和其他新角色一样排在被动前面），学过的功法能在这里看到。

## 交接板

- 下一步：无（合并后随下一个补丁出给玩家，出不出补丁 Kyo 定）
- 用户试玩说明：读一个有流萤（179）的存档 → 主菜单「技能」→ 切到流萤：技能分类里有「功法」（在「被动」前面）；让流萤学一本功法（如玄天功·入门）后，功法页里能看到它。别的新角色（167～177）照旧有功法页，老角色照旧没有。
- 需要用户决定：无（原版流萤就有功法页，照原版补齐）

## 进度账

- 无（移植遗漏补齐，不改完成度）

## 可优化（流程／工具／效率）

- 建议：重制里还有别的「角色号范围」写死的移植点，可以做一次扫描：原版 `id>=167` 一类判定里带 `||id===179` 之类追加项的，对照重制同名常量是否漏了（预计十几分钟，只读，归任意 cc 车道）。本单已查 `codex/runtime/*.js` 中同时出现 177 与 179 的判定只有这一处。

## 验证

- 语法检查：851 个 .gd，0 问题。
- 专项：`xiyou_battle_log` 本机 77/77（26 秒）。
- 反向验证：3/3 咬住。
- 工具回归：全部通过（251 秒）。
- 云端选测（`选测.py main` 选中 54 个，超 40 走云端；基准取上次云端通过的祖先 fbb2d9b96，结论是整轮 589 场景）：待写
- `--oracle` 没跑：改的是技能菜单分类列表，不碰战斗逻辑与数值链。
- 发行入口冒烟（导出整包）没跑：改动不在空壳名单、不看 is_release，专项已用 simulate_release 覆盖；本机测试车道已满，导整包不划算。

## 本分支提交

- a32d8fbbe 流萤 179 技能菜单补「功法」页；xiyou_battle_log 补流萤功法页与内容断言
- 266a3062c xiyou_battle_log：发行构建（simulate_release）下同样断言
