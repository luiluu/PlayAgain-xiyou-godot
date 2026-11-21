# 交付：luiluu/t269

- 车道／工作者：T269 渡鸦旧档读档压回灵魂 15 万／cc 车道（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·T269·未经审查】天启篇渡鸦旧档读档即压回灵魂 15 万（dev.待定）

- 依据：T257 交付单「可优化」（旧档读进来要等下一次 sync 才压回）；T259 卡验收第 5 条移出、归存档线（11-19 协调第 48 任）。
- 问题：T257 只在 `XRaven.sync`（setup／升级）开头调 `growth_clamp`。没学至尊鸦皇 10136 却已攒到 15 万以上的旧档，读进来到下一次 sync 之前，灵魂进度、面板都按超出的值算。
- 改法：`modes/xiyou/core/tianqi_save.gd` 的 `XTianqiSave.after_load`（XState.from_dict 末尾、`_become_current` 之后）最后加 `_raven_clamp(s)`：当前档里有渡鸦（167）就调 `XRaven.growth_clamp`。门槛全由 `growth_clamp` 自己判：只在 `XTianqiGrowth.on`（天启篇档且无限成长开着）、没学 10136、灵魂 > 15 万时压到 15 万并刷面板；不受存档门面 `ENABLED`（只管分区迁移）影响。幂等。
- 回退：`XTianqiGrowth.ENABLED = false`（同 T257，读档也不压；专项核）。西游档 `XTianqiGrowth.on` 为假，读档零变化（专项核）。
- 玩家可见：天启篇里没学至尊鸦皇、灵魂超过 15 万的旧档，读档后灵魂直接显示 15 万（原来要等升级等下一次同步）。

## 验证

- 专项 `xiyou_tianqi_growth_count` 66/66（新增 5 条：`raven_load_new` 新档 12 万读档不变、`raven_load_old_clamp` 存档文件里改成 18 万的旧档读档即 15 万、`raven_load_off_noclamp` 关开关读档不压、`raven_load_learned` 学了 10136 的 23 万读档不动、`raven_load_xiyou` 西游档 18 万读档不动）。改代码前跑过：`raven_load_old_clamp` 失败（读回 180000），断言咬得住。
- 本机：`xiyou_tianqi_save` 82/82、`xiyou_tianqi_random` 75/75、`xiyou_tianqi_brand` 248/248、`xiyou_tianqi_growth` 58/58；语法检查 0 问题。
- 云端选测（4e7c196c36，选测.py 的 8 个场景，含 xiyou_event_compare 四个）：8/8 全过；`gh run watch` 前台等完，退出码 0。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇渡鸦没学至尊鸦皇时灵魂超 15 万的旧档，读档即显示 15 万。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 4e7c196c3 T269 XTianqiSave.after_load 调 XRaven.growth_clamp＋专项
- （本提交）交付单
