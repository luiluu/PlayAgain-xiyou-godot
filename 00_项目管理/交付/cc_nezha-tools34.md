# 交付：cc/nezha-tools34

- 车道／工作者：C 工具／cc（哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】tools34：测试里固定随机流的整数取法统一成 floor(0.5×n)（dev.待定）

- 参照里 Math.random 恒为 0.5，整数取法是 floor(n×0.5)；测试里的固定随机流整数一律给原始 uint 2^31，引擎再对 n 取模，只有 n 是 2 的幂时碰巧得对。照 tools33 的 `xiyou_alien_affix`，给下列测试的流类加 `next_index_mod`／`next_int_inclusive` 覆写：
  - HalfStream 类（取 n÷2）：`toji_battle`、`yomi_battle`、`race_battle`、`param_cache`、`alien_battle`、`cat`、`mira_battle`、`sukuna_battle`。
  - FixedStream 类（取 floor(n×value)）：`yunshang`、`jingliu`、`jingliu2`、`raven_battle` 补 `next_index_mod`（它们原来只有 `next_int_inclusive`）；`garou_battle` 两个都补。
- 只改测试；rg 全工程 `2147483648`，其余是脚本化磁带（`scripted`，按磁带原值走）和 `event_compare` 的宝珠种子，不是同写法，没动。

## 交接板

- 下一步：无
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无（工具车道）

## 可优化（流程／工具／效率）

- 已做：见上（回退＝删各测试里新加的覆写）。建议：把这类固定随机流收成一个公共测试辅助类，免得每个测试各抄一份（工具车道，小）。

## 验证

- 14 个专项全过：toji_battle／yomi_battle／race_battle／param_cache／alien_battle／cat／mira_battle／sukuna_battle／alien_affix（741 秒）；yunshang／jingliu／jingliu2／raven_battle／garou_battle（202 秒）；语法检查通过；未跑全量。

## 待交叉核查

- 无需（只改测试）

## 本分支提交

- 见 git log
