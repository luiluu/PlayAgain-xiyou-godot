# 交付：codex/state-effects-2e 的0b修复

- 车道／工作者：Codex（沙僧，重制_沙僧_48）。
- 状态：进行中
- 用户2026-10-22直接要求修交接板下一步0b的两项P2；沿用原树与分支，未接唐僧。已读主库交接板、两树状态／日志及八戒_51核查报告；干净合入main 05f087bc，合并检查点e3c347a。开工额度68%／11%，95%保存现场停手。
- 范围：战力预演的变量上下文与针对性回归；将地图／菜单已有预约迁入同一XState运行时槽，补第四期设计与宿主交接清单。所需power、state_effects、XState、map_scene、menu及相关测试在本次明确修复范围内；不碰八戒菜单新系统、切片或其他车道；不提前翻译1771等状态预约块，不实现永久加算或五块TP效果。
- 先用冻结原版补独立参照，再改生产。保留真实undefined与Game_Variables.value默认0的区别，不把核查建议当已测事实。全部提交待Claude核查，完成度不自增。
- 原版独立测量`review135_probe.cjs`三例已首次exit0、errors=[]；六状态各zero／set7／unset共18行均有限，未设置的getter与Custom Confirm结果和0一致。真实菜单保存→枫叶→菜单成就的槽为1→10→431；解释器setup时仍431，setup后0，运行中预约10保留。JsonEx普通读档、新局、另一Game_Temp均空。原始副本`04_验证/本地结果/state-effects-0b/native-preserved.json`（相对03_再刷重制_Godot），SHA256 `8959f36300b6585e05de92c4f493bf116ecee5f6f743c5967d0e20bb7fdef5c4`；native.log runId `ae8d7b946dfb47e3924d75594224d082`。
- 已按测量实现：PhaseValueProgram缺上下文取当前state变量，六块等已测getter缺键按0；power普通／暴击finish明确传同一预览vars（含v20=0规则）。通用公式VM的raw v[index]未改。预约迁入XState唯一运行时槽，地图按setup→clear→执行，菜单跨await保存owner，现有HUD测试改查共用槽。新增review135专项覆盖原版行、预览无副作用、战力预览vars、覆盖／busy／运行中新预约／普通读档及旧菜单跨state隔离。
- Godot编辑器导入预检exit0，未报脚本错误，日志`state-effects-0b/import.log`。现启动本批唯一一次最终正式同步`state-effects-0b/sync.log`，再跑相关专项；尚未标可合并。源探针、同步注册与生产修改已作检查点，长操作使用原单槽共享上限4包装。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】修复战力预演变量上下文与地图菜单共用预约槽（dev.待定）

- 用户指定修复交接板0b两项P2；具体修复、原版证据和验证结果在交付前补齐。

## 交接板草稿

- 0b：只处理P2-1／P2-2；P3-1阶段日志上限及原进度建议仍保留，待本轮验收后登记。
- 全部修复待Claude交叉核查；不把接口设计或原版参照计成玩法完成。
