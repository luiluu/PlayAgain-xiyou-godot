# 交付：cc/nezha-tools51

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并（基于 cc/nezha-tools50，先合它）

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】探针五乘区存量清理（三期，5 个，最后一期）（dev.待定）

- 加开关并前后比对：options、drop_record、sequence、battle_event 四个产物逐字相同，直接从存量删。
- passive_content：关五乘区后产物变了（growth 0.6437→1，伤害如 619→961）。更新 `tests/fixtures/passive_content_oracle.json`（沿用原来的“头部缩进、cases 一例一行”格式，diff 只含真实变化），`xiyou_passive_content` 通过，断言一条没改。
- 存量 28→23，余下的是 *_battle、slice_probe、state_effects 等大件，以及 formula_effect、guyu_ui、jingliu、heartsteel 等中件，按总装安排本期不做；登记检查已拦住新增，留在存量里不碍事。

## 交接板

- 下一步：无（清理到此为止）。
- 用户试玩说明：无。
- 需要用户决定：无。

## 验证

- `探针登记检查.py`（存量 23）、`测试探针登记检查.py`、`语法检查.py` 通过；`xiyou_passive_content` 通过。没跑全量。
