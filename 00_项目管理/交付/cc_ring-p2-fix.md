# 交付：cc/ring-p2-fix

- 车道／工作者：T039 环纹卡1 两条 P2（cc，claude-sonnet-5-5＋medium，P6）；核查：小A（甲档，Hydrogen）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】环纹卡1 P2：切人重置演出、微亮态／脱下 0.3 秒淡入淡出（dev.待定）

- 依据：T029 小A 核查报告第六节 P2-1、P2-2；设计稿 `装备环样式设计_v0.2` v0.2.1 §4.1。
- P2-1：`_sync_ring_style` 里 `ctx`（角色＋出战顺序）变了就 `ring.cancel_intro()`、清 `_intro_ms`，演出进行中切人／换队序不再接着铺开、说明不闪旧金。
- P2-2：`play_intro("fade", 旧环快照)`；fade 期间旧环（光带贴图、法阵、程序光带／主圈／细线／虚线）按 1−alpha 淡出、新环按 alpha 淡入，环心框旧图同样淡出；程序态的颜色原来没乘 alpha，现在乘。0.3 秒后快照清空。动效「关」不留快照（一帧直接切换）。burn 演出不变。
- 新增接口：`XSkinRingNav.cancel_intro()`、`play_intro(kind, from)`、`fade_from`；`_draw_body` 从 `_draw` 拆出（法阵＋程序环身）。环开关关闭时 `style_art` 空、不演出，画面不变。
- 专项 `xiyou_tianqi_ring_style` 93→（带窗口 125）条：切人作废演出、脱下 fade＋旧环／旧环心快照、0.15 秒半透明、0.3 秒清空、cancel／动效关无快照；带窗口截图 `归档/交付截图/cc_ring-p2-fix/`。

## 验证

- `xiyou_tianqi_ring_style` 无头 93/93、带窗口 125/125。
- `检查.sh --affected main`、`交付自检.py` 见回报。

## 我不同意的地方

- 无。一处补充：报告说「脱下时立即清空 style_art」，只让新环淡入不够（旧环会瞬间消失），所以做了旧环快照交叉淡出，改动比报告字面稍大。
