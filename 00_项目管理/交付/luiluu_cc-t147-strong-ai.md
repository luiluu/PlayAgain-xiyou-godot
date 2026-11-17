# 交付：luiluu/cc-t147-strong-ai

- 车道／工作者：C 规则／机制／cc（T147，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·未经审查】天启篇超强者判定补齐：自动战斗／智能 AI 与号卷外分支读天启档位表（dev.待定）

- `XTusu.super_strong`（tusu.gd）和 `XPowerBooks.actor_class` 号卷以外分支由 `XItemMarks.is_super_strong` 改读 `XItemMarks._super_in(XState.current, id)`：天启篇存档且 `XTianqiSkills.TIERS` 开着按天启档位表（云裳 174＝强者），否则回退原版名单；西游档不变。
- 测试：`xiyou_boss_strong_tianqi` 加 5 条（天启篇 174 非超强者、152 仍是、TIERS 关回退、西游 174 超强者、号卷分档）；选测 19 场景全过。
- D179（三笠 95、饿狼 173 按名单算超强者）照推荐，未改成长档。
- 玩家可见：天启篇里云裳不再被智能 AI 当超强者（不再被排除出自动战斗的强者专属处理）。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无。我不同意的地方：无（改动面小，`actor_class` 里天启篇号卷已先于该分支返回，此处是兜底，属于防御性一致）。
- 备注：`检查.sh --affected` 必须带基准参数（`--affected main`）。

## 本分支提交

- 见 git log
