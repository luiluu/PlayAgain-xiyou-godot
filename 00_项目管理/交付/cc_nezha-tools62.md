# 交付：cc/nezha-tools62

- 车道／工作者：D 工具／哪吒（cc，Sonnet／medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】选测：单个 mv_oracle 探针改动只选读它产物的场景（dev.待定）

- `选测.py` 新增单个探针收窄（`probeNarrow`）：改动文件是 `03_转换工具/mv_oracle/<名>_probe.cjs`（直接放在该目录下的单个探针源）时，不再整组归 converter（67 个场景），改归新组 `probe_narrow`：只选引用「探针文件名」「产物名」「按产物名加载它的 modes/ 模块 class_name」的测试。产物名取 `同步正式西游.py` PROBES 里这条命令登记的产物，没登记就看夹具 `tests/fixtures/<名>_oracle.json`。检查项同 converter（guards、tools、content、same_source）。
- 一律退回整组 converter 的情况：`shared/`、`node_modules`、`host.cjs` 等公共部分；`excludeProbes`（slice_probe、event_probe、map_probe，产物影响所有生成物）；找不到产物或找不到任何引用；产物同时被转换器等脚本读取（排除只读检查 `readerIgnore`：oracle_additions、验证西游来源、*_contract 等）。
- 回退开关：`选测对照.json` 的 `probeNarrow.enabled = false`，或环境变量 `XIYOU_PROBE_NARROW=0`。
- 真实资料库 152 个探针里 149 个能收窄，3 个退回整组（custom_damage_probe 没测试引用；otb_probe、state_effects_tp_context_probe 没登记产物）。
- 测试 `测试选测.py` 加 `ProbeNarrowTests` 11 例（登记探针、夹具探针、多产物、shared／host、无引用、转换器读产物、只读检查不挡、excludeProbes、环境变量开关、对照表开关、真实表覆盖率）。

## 优化登记草稿

| O-待定 | 选测对单个 mv_oracle 探针改动收窄范围（工具，不影响游戏；`07_开发环境/选测.py` `probe_outputs`／`single_probe`、`选测对照.json` `probeNarrow`） | 整个 `03_转换工具/*` 归 converter，只改一个探针也选 67 个场景（含 xiyou_rules* 抽样后约 19 个） | 单个探针只选引用探针名、产物名、加载产物的模块的场景；公共部分、找不到引用、转换器读产物时退回整组 | 探针产物只被读它的场景和加载它的模块使用；其余影响面由 same_source／content 检查与 escapes 兜底 | `选测对照.json` 的 `probeNarrow.enabled = false`，或环境变量 `XIYOU_PROBE_NARROW=0` | cc（哪吒） | 待用户确认 |

## 量化（不抽样，`--head` 回放真实合并，只看该探针那一项）

| 合并 | 改的探针 | 收窄前 | 收窄后 |
| --- | --- | --- | --- |
| 7dc02483 悟空 tail5 | stunned_turn_probe | 67 个场景 | 1（xiyou_stunned_turn） |
| 3a9ef70b 八戒 rules7 | confusion_probe | 67 | 1（xiyou_confusion） |
| 36444006 悟空 custom1b | target_eval_probe | 67 | 1（xiyou_target_eval） |

- 三次合并整批选测仍是 67／270／272 个场景（tail5 整批 67→1，因它只改了这个探针；rules7、custom1b 同批改了 battle_logic 等，选测由别的文件决定，不变）。
- 带抽样（xiyou_rules*、smart_ai* 每族留 1 段）时，收窄前该探针项约 19 个。

## 待交叉核查

- `选测.py` 的 `take()` 里 probe 段：`readers` 过滤（排除 mv_oracle 探针、测试脚本、同步脚本登记、`readerIgnore`）；`readerIgnore` 名单是否多放了（它们读产物但不改产物）。
- `excludeProbes` 只列了 slice_probe、event_probe、map_probe：转换器读产物的另行靠 readers 兜底，是否漏列别的「产物影响所有生成物」的探针。
- 引用词只有探针文件名、产物名、加载模块 class_name：只靠 `generated/oracle` 目录遍历读产物的测试不会被选到（目前没发现）。

## 验证

- 没碰 .gd，不跑 Godot 选测。
- `测试选测.py` 119/119（含新 11 例）；`测试回退开关覆盖.py` 13／13；`回退开关覆盖.py` 新缺口 0。

## 可优化（流程／工具／效率）

- 已做：以上收窄（回退见上）。
- 建议：`custom_damage_probe.cjs` 没有任何测试引用产物 custom_damage.json，要么补一个读它的测试，要么确认它只是登记用；otb_probe、state_effects_tp_context_probe 没登记产物也没夹具（归哪条车道由总装定）。

## 本分支提交

- 见 `git log cc/nezha-tools61..cc/nezha-tools62`
