# 交付：luiluu/cc-t312-yunshang-cev

- 车道／工作者：T312 云裳派生暴击对齐 D237 减法（cc，Sonnet＋medium）
- 状态：可合并（依赖 T285 先合；本分支从 T285 a4cd05d15 切）

## 变更记录草稿

## 2026-11-20 【cc·天启篇·未经审查】云裳派生伤害的暴击底子改走 crit_after_cev（dev.待定）

- 依据：T285 小A 核 P2-4：`core/yunshang.gd` 派生伤害暴击仍手算「暴击率×(1−暴闪)」乘法，没走 T285 的减法。
- 改法：`XYunshang.derived_base_cri`：技能不暴击＝0；`XTianqiCombat.SUBTRACTIVE_CEV` 开且 `on()` 且目标是敌人＝`XTianqiCombat.crit_after_cev(src.cri, …)`（减法、攻击方 ≤0 按 0、下限 0）；其余（开关关、西游档、目标非敌人）原样 `src.cri*(1−t.cev)`。
- 测试：`xiyou_tianqi_enemy_cev` 加 ys.* 6 项（关＝乘法 100%／130%；开＝同 crit_after_cev、减法下限 0、负暴击 0）。反向验证：把派生改回乘法→专项失败（咬住）；去掉开关判断→没咬住（等价改动：开关关时 crit_after_cev 自身回退乘法，不算漏断言）。
- 玩家可见：不涉及文字。

## 没做／偏离

- 无。派生暴击没带 critPush（改前就没带），保持。

## 验证

- 语法检查 0 问题；本机跑 xiyou_tianqi_enemy_cev、xiyou_yunshang、_wraps、_ui、_shop、xiyou_determinism 共 6 个全过（并行测试的 Godot 带 --headless，没起窗口）。

## 交接板

- 无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
