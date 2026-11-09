# 交付：cc/bailong-raven6

- 车道／工作者：B 界面／白龙（cc，chars-raven6；派单第十六批追加十八 GR1）
- 状态：进行中

## 派单两项其实已做完（给下次进度核定销账）

进度核定 dev.411 第 102 行「角色与专属机制」还挂着「渡鸦 #3／#4、形象立绘逐张比」，前两项早就做完，只是核定表没跟上：

| 项 | 做在哪 | 证据 |
| --- | --- | --- |
| #4 神话静态大图 Raven_Mythic_Monster | dev.364（cc·ravenfx2） | 无头 Chrome 量具 `mv_oracle/real/sprite_real.cjs`＋规格 `real/raven_myth.json`，结果 `real/raven_myth.result.json`：实机最终画的是 UserSV_RavenMythic 逐帧图（缩放 0.4615、藏武器和影子），大图从不出现；只剩阵亡透明度 0.35 一条，已补（`XBattlerSprite._raven_myth_alpha`，O-198，专项 `xiyou_raven_visual` 的 `_myth_alpha`）。dev.398 又核过 v0.62.12 的两个运行时文件与 v0.28 逐字相同 |
| #3 施放特效屏蔽支 | dev.398（cc·悟空 newsrc10） | 探针 `mv_oracle/raven_fx_probe.cjs` 14 例（真实 BattleManager 行动序列）、专项 `xiyou_raven_fx` 54 项；顺带修了行动序列里不放羽毛特效 |
| 战斗图逐张比 | dev.398（cc·悟空 newsrc10） | `real/actor_sv_real.cjs`＋`tests/xiyou_actor_sv_compare.tscn`，切片 162 名几何与逐像素 |

真没做的只有人物图鉴立绘的逐张比（dev.361 核定第 42 行：「图鉴只比了图名，没逐张截图」），本期做。

## 变更记录草稿

待写

## 交接板

- 下一步：待写
- 用户试玩说明：待写
- 需要用户决定：无

## 进度账

待写

## 可优化（流程／工具／效率）

待写

## 待交叉核查

待写

## 验证

待写

## 本分支提交

待写
