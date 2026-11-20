# 交付：luiluu/cc-t301-select-input-handled

- 车道／工作者：T301 选测对照补关联（cc 车道，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T301·未经审查】选测按改动内容触发 xiyou_input_handled（dev.待定）

- 选测对照.json 新增 `contentEscapes`：任一 .gd 的新增行（未跟踪新文件按整份）含 `set_input_as_handled` 或 `XKeyMap.handled`，就选中 xiyou_input_handled，不挑目录。选测.py 加 `added_lines`、contentEscapes 求值与校验；测试选测.py 加 2 条回归。
- 选内容触发、不选目录关联的理由：该场景扫全源码「不许直调」，违规可写在任何目录（skin、ui、map、core 都有 handled 用法）；目录列表会漏以后新增的目录，且 ui/ 组会白白多跑它。内容规则只在真碰这两个词时才跑，误选极少。
- 回放：`选测.py bb4d0d708^ --head bb4d0d708 --list`（T288 skin_card.gd 新增直调）现在选中 xiyou_input_handled（改前没有）。

## 交接板

- 下一步：无
- 用户试玩说明：无（工具改动）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：contentEscapes 通用机制，后续「按改动内容触发场景」的漏网例可直接追加条目（回退：删对照表 contentEscapes 键即可）。

## 本分支提交

- 见 git log
