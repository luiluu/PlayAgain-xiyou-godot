# cc/bailong-ui3 交付单（白龙）

状态：**可合并**

## 做了
- 饿狼读档同步：`XGarou.after_load`（clear_battle＋sync），`xstate.gd` 读档处在 XGuyu.after_load 后调用，对应原版 `extractSaveContents` 包装（installNativeGarouRuntime.js:201）。
- 饿狼「输入阶段预排琦玉」：**查明不用移植**。原版 `meetsSkillConditions` 的 planned 分支读 `_actions.slice(0,_actionInputIndex)`，但 OTB（Olivia_BattleSysOTB.js:666）的 `selectNextCommand` 有 _subject 就直接 startAction，不会调 `Game_Actor.selectNextCommand`（唯一给 `_actionInputIndex` 加一的地方，rpg_οbjects.js:4389），所以正式战斗里该下标恒为 0，分支取不到。重制逐次选行动、琦玉模式命中即开 saitama，与原版效果一致。`garou.gd` 头注已改写，未移植清单去掉这两项。这是静态读源码结论，没跑 mv_oracle 探针；规则没改，无需新参照。
- 测试：`xiyou_garou_progress` 加 `save.load_clear`、`save.load_sync`；`save.old`／`save.roundtrip` 改成按字段比较（读档同步会写 garou.breakthroughs，与原版 G.sync 一致）。

## 验证
- 语法检查通过。选测 `选测.py main --list` 因 xstate.gd 扩出 283 个场景，没全跑，跑了 17 个相关：actor_looks、actor_modules、actor_p0、battle_log、event_compare、garou_battle、garou_progress、determinism、autosave、battleback_save、flow、guyu、pets、save_events、save_page、difficulty_inherit_load、global_vars；另 skill_mastery 全部通过。

## 待交叉核查
- 无核心战斗文件改动；改了 `xstate.gd` 读档流程一行（核查重点）。
