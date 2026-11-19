# 交付：luiluu/cc-t275-six-dim-data

- 车道／工作者：T275 六维①数据表（cc 车道，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·T275·未经审查】天启篇六维数据表＋XTianqiSixDim 只读模块＋数据校验（dev.待定）

- 新增 `modes/xiyou/tianqi_data/six_dim.json`：八档刻度（E～SSS＝1～8）、韧性控制抗性表（−10～＋10 整数）、战商 5 档映射、敌方 AI 整数权重（辅助／输出／生存／速度／慌乱）、8 个普通怪模板（含深渊精英）、四骑士＋9 份角色样板，全表整数（附则 E）。
- 新增 `modes/xiyou/core/tianqi_six_dim.gd`（XTianqiSixDim，开关 `ENABLED`）：按 actor_id／enemy_id／骑士键读六维、`control_resist_pct`、`ai_tier`、`ai_weights`；没录的和西游档、`ENABLED=false` 全回中性（六维 C、抗控 0、战商 3 档、权重 100）。只读，不碰伤害、战斗、界面；没有任何西游路径调用它，所以不用登记发行空壳特例。
- `03_转换工具/天启篇数据校验.py` 新增 `check_six_dim`（R1～R4、全整数、抗控表随档不降、模板 8～10 个、样板号在 base_line.json、骑士键同 horsemen.json），`测试天启篇数据校验.py` 加 8 个用例（双 SSS、SS 无短板、总分超预算、小数四种违规＋S 稀有度、SSS 带 S、未知角色号、骑士键不一致）。
- 专项 `tests/xiyou_tianqi_six_dim`：62/62。
- 数据校验 0；单测 113 项通过。

## 交接板

- 下一步：卡 2（韧性接 state_rate）、卡 3（敌方 AI）、卡 4／5（界面）可开；全库铺开等四骑士＋样板实测
- 用户试玩说明：无（只读数据与模块，玩家看不到）
- 需要用户决定：谷雨（175）样板分——Kyo 11-19 改口（爆发输出 S、生存至少 S），定稿里辅助 SSS 那套作废，协调正与 Kyo 重定。**本单没录谷雨**（读取回中性），专项里谷雨断言已跳过；新分到后在 six_dim.json 补一行 actors/175，并在专项与单测补断言。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：设定稿 R2 对 SS 的「其余 5 维 S 至多 1 项」与五条悟（S＋SS）、死亡／战争骑士（S＋SS）一致，没发现矛盾；R1～R4 对 13 份样板全过，无异议。

## 本分支提交

- 见 git log
