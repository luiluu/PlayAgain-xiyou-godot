# 交付：luiluu/t350

- 车道／工作者：T350 列表惯性滑动打开／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·天启篇·未经审查】T350 列表惯性滑动默认打开（dev.待定）

- Kyo 11-22（Orca 待办 9）定「开」：`XSkinDrag.INERTIA_ENABLED` 默认改 true（T339 dev.823 已做好惯性滑行与 24px 橡皮筋回弹）。动效设置 Motion.OFF 照旧不惯性；`XUiSkin.DETAIL_V1 = false` 回退旧行为（无惯性）；`INERTIA_ENABLED = false` 也可单独关。
- 专项 `xiyou_ui_detail_d3` 断言改为默认开（inertia_default_on），收尾复位为 true；默认开下惯性不越界、回弹到位的断言原有并保留。
- 玩家可见：列表、状态页等手指/鼠标拖动松手后会轻惯性滑一小段，到边界有轻微回弹。

## 交接板

- 下一步：无
- 用户试玩说明：列表拖动松手有惯性与边界回弹；设置里动效关闭则不惯性
- 需要用户决定：无

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log（T350）
