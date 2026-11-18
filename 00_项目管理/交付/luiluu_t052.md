# 交付：luiluu/t052

- 车道／工作者：T052 空壳技能从技能列表收起／cc（Sonnet 5.5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T052·未经审查】天启篇技能列表收起已并入／已移除的空壳技能（dev.待定）

- 现象：天启篇技能页还列着改写稿里只剩「已并入…」「原…已移除」的空壳技能（约 245 条），点开没有可看的效果。
- 改法：`XTianqiSkills.is_shell(id)`：角色卡开着，且改写稿 desc 每行都是「效果：已并入…」或「效果：原…已移除」才算空壳；只在 `skill_scene.gd` 的 `entries()` 过滤里用。存档里的技能 id、战斗指令、AI、装备效果都不动，可用性不变。西游档（卡没开）列表逐条不变。
- 回退开关：`XTianqiSkills.HIDE_SHELLS`（static var，默认 true），设 false 回到全部列出。
- 验证：新增专项 `xiyou_tianqi_shell_hide.tscn` 15/15（天启篇隐藏、存读档后空壳仍学会且记录可读、关开关全列出、西游档全列出）；`检查.sh --affected HEAD~1` 选测 53 个场景全过、语法 0 问题，唯一失败项见「可优化」。
- 不新增玩家可见文字。
- 玩家可见：天启篇技能页不再出现已并入其他技能的空壳项。

## 交接板

- 下一步：无新增
- 用户试玩说明：天启篇开角色卡后，技能页里没有效果的「已并入」空壳项不再显示；已学会的技能存档不受影响
- 需要用户决定：无

## 进度账

- 无（列表显示小修，不动完成度）

## 优化登记草稿

- O-待定｜`XTianqiSkills.HIDE_SHELLS`｜天启篇技能页收起已并入／已移除的空壳技能｜恢复方法：`XTianqiSkills.HIDE_SHELLS` 设 `false`｜状态：保留（按 Kyo 11-11 优化直接接受）；专项 `xiyou_tianqi_shell_hide.tscn` 已把它设成 false 测过回退支

## 可优化（流程／工具／效率）

- 发现（基线已有，非本单引入）：`07_开发环境/发行空壳.py check` 报「XTianqiSkills.data 被西游代码调用而空壳返回空容器」，`检查.sh` 因此失败；已用 HEAD~1 临时 worktree 复现。建议：另派一单逐个看 `tianqi_base.gd`、`tianqi_weak_clear.gd`、`guyu.gd`、`tianqi_drop.gd` 对 `XTianqiSkills.data()` 的调用，在 `发行空壳特例.json` 登记特例或「已确认空值安全」（归总装或工具车道，一两行 JSON）。

## 本分支提交

- 34b15a982 T052 天启篇技能列表收起已并入／已移除的空壳技能（HIDE_SHELLS 开关，只管菜单列表显示）
