# 交付：cc/nezha-tools50

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并（二期做完，存量 50→28；剩余见接续）

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】探针五乘区存量清理（一期，7 个）（dev.待定）

- 分支基于 cc/nezha-tools49（尚未合进 main 时先合它）。
- 对 7 个探针（boss_output、formula_rest、guyu、shield、stage50_review、state_merge_context、state_operation）加 `w.eval('CodexZones.ENABLED=false;')`；每个都先跑一次原样、再跑一次加开关，产物（去掉 sourceIdentity）逐字相同，所以 fixture／参照不变；从 `探针五乘区存量.json` 删掉这 7 行（剩 43）。
- 未改任何 fixture，未跑 Godot 专项（产物没变）。

## 交接板

- 下一步：接着清存量剩下的 43 个（见接续）。
- 用户试玩说明：无。
- 需要用户决定：无。

## 验证

- `探针登记检查.py` 通过（存量 43）、`测试探针登记检查.py` 通过。其余只靠上面的前后产物比对；没跑全量、没跑选测（总装 15 号收尾通知说不用）。

## 二期（本次，15 个）

- 加开关并前后比对：skill_change_to、nanoha_kill、nanoha2、boss_react、boss_sequence、boss_state_origin、boss_output_context、attack_query、binding、cat_trial、state_js、review_fix 共 12 个产物逐字相同，直接从存量删。
- 产物变了的 3 个：toji（伤害 growth 1.04→1，如 1269219→1219452）、param_cache、pushstate。toji、param_cache 的参照是同步生成的 generated/oracle（不入 Git），换成新产物后 xiyou_toji*、xiyou_param_cache、xiyou_boss_state_origin 全过；pushstate 更新 `tests/fixtures/pushstate_oracle.json`，xiyou_pushstate 通过。断言一条没改。toji_battle／toji_eva 等没动（仍在存量里）。
- 存量 43→28。验证：探针登记检查、测试探针登记检查、语法检查通过；Godot 专项如上，未跑全量。合并后同步正式西游会重生 toji／param_cache 参照。

## 接续

- 没比对：battle_event、options、sequence（旧脚本认不出输出文件名，需手动）；drop_record 不走 finish；passive_content_probe 受五乘区影响明显（growth 0.6437→1），要更新 `tests/fixtures/passive_content_oracle.json` 并跑对应专项；其余 formula_effect、各 *_battle、guyu_ui、jingliu 等未做；slice_probe、state_effects 最后做。
- 临时脚本 /private/tmp/claude-501/s/zone.py（插入开关、前后各跑、比对产物）。
