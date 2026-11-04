# 交付：cc/review-41

- 车道／工作者：审查（核查轨，不写游戏代码）；从 main `1072662b`（含 events2）切出
- 状态：可合并（只含文档：核查报告、本交付单；没有代码改动）

## 变更记录草稿

## 2026-11-04 【cc·审查】核查 nezha-preempt1、bailong-visual1、wukong-scan2、nezha-fix3、bajie-events1、bailong-visual2、bajie-events2

- 核查覆盖：cc/nezha-preempt1（b6f8cb39）；cc/bailong-visual1（118b56d…5c374a31）；cc/wukong-scan2（1db2e1a5…15b9000f）；cc/nezha-fix3（ab3f2b0c、263606ae、40454887）；cc/bajie-events1（f65802f3…4fade685）；cc/bailong-visual2（d1444156、eef90f25、4525d30a、296de77b）；cc/bajie-events2（0d5b269f、f34f20a7、66712387、1072662b）
- 结论：P1 无，P2 一条，P3 六条。要点：①events2：`event_states.json` 缺失时 `事件空绿扫描.py --check` 报红，而 `xiyou_event_compare` 静默跳过变体仍通过（P2，main 上现在就没有该产物）；②visual2 补做了反向验证，三处改坏没被咬住（边长 /41、碎块水平速度范围、锚点偏移），倒下粉碎网格读的宽高含缩放而探针写死成位图尺寸（非 SV 敌人呼吸 ±2%），边缘碎块锚点按裁剪后的取图框算——后两条没有实机对照，记为推断；③`XSvPngFd.scale` 读 `skill_ids` 而原版读 `skills()`（现无技能带该备注，无现实影响）；④events2 的 2 个变体仍空绿却被算已补，对照整段关了 `seal_check_fix`；⑤preempt1 随机遇敌多抽两次战斗随机流。详见[报告](核查报告_20261104_审查第41期.md)。
- 验证：本机跑了 Godot 专项（collapse_fx 55、scan2 57、svpngfd 27、sve_visual 31、vsfx 22、passive 257、script_gaps 56、hp_gauge_visible 18、state_change_remove 10、preempt 211、battle 9、floor_reach075 68、event_compare 5839 例 5838 一致＝登记的 O-044）、`测试状态js翻译.py` 25 项、`探针登记检查.py`；改坏实现做反向验证（collapse 7 处、script_gaps 的 replace 2 处、is_guard、Max Item），结果见报告；没做实机画面对照。

## 交接板

- 清掉「待交叉核查」里上述各批对应的行（销账靠上面变更记录条目里的分支名与提交号，`待核查.py` 自动识别）。
- 下一步建议（交总装派车道，审查只记不修）：
  1. （P2-1，优先）`xiyou_event_compare` 在 `event_states.json` 缺失时要 `check` 失败而不是静默跳过；`检查.sh` 的空绿检查在产物没生成时先补跑探针（5 秒）或区分提示。合并后总装第一次同步会生成 main 上的产物。
  2. （P3-1／2）`xiyou_collapse_fx` 补三处断言：边长取整（再加一个 `/40` 与 `/41` 取整不同的尺寸）、`sx` 取值范围、锚点；`collapse_probe.cjs` 加「呼吸相位」几例量网格；边缘碎块锚点需要实机或真 PIXI 对一次。
  3. （P3-4）`XSvPngFd.scale` 改读 `a.skills()`（与被动缓存一致），或在注释里写明「现无技能带 SvPngFd」。
  4. （P3-5）`事件空绿扫描.py` 的 `covered` 只排除有效变体，`quiet` 的 2 个（`m84e11p0#s1`、`ce1194#s1`）仍算空绿。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：新车道补齐后 `generated/oracle` 缺新探针产物是常态（本期 `event_states.json`），检查脚本对「产物没生成」应给一条明确提示并给出补跑命令，而不是让专项各自决定红／绿。

## 待交叉核查（改了核心文件）

- 无（本分支只有文档，提交尾注写「核查: 无」）。

## 验证

- 见核查报告开头与「本期没有覆盖」。

## 本分支提交

- 见 `git log main..cc/review-41`
