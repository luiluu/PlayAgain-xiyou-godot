# 交付：codex/rng-rework

- 车道／工作者：规则返工／沙僧（Codex，重制_沙僧_8 接手沙僧_7）
- 分支与工作树：`codex/rng-rework`，`.claude/worktrees/rng-rework`，从main 0ea5c5c新建；辅助补齐和Godot导入已结束；沙僧8核对进程后开始游戏侧返工。
- 开工时main由唐僧合八戒_27：C车道已从交接板删掉，原车道干净且交付可合并，只有A悟空_23仍写代码。可接本RNG车道；不得改A转换器／切片或抢改battle_logic、XBattler.recover_all。main的开发编号／交接板等尚在唐僧未提交的合并收尾中，不要替他提交。

## 变更记录草稿

## 2026-10-19 【Codex·沙僧·未经Claude检验】RNG返工开工与接力

- 本提交仅保存任务与接续位置，尚无游戏侧实施，不宣称完成、自测通过或增加进度。

## 交接板

- 第一优先：完成用户dev.099返工。普通存档不再严格匹配Godot引擎串，异串可读且重建随机流；unsupported实战公式告警并留诊断；同档重打可刷不同结果，普通档只保留原版固定的装备实例、rom池与游标、orb_seed及已有内容，battle/world/装备现掷流不随档固定；debug replay每场保存种子并显式恢复，仍可拒绝异版本。
- 游戏侧接流：遇敌、事件脚本随机、真气、挂机接world；地图随机走动和打字音各自独立RNG。world按用户默认不随档固定。插槽／强化等现掷不能因equipment RNG随存档续跑而重新固定。八戒_26的测试调整已在main。
- 验收：异引擎串档能读／运行时流重建；unsupported告警；同档两次真战出现不同结果；rom数组／全部游标和既有实例逐字不变；显式replay复现；预览／走动／音效／画面不推进规则流；并行完整检查下xiyou_floor_run_c连续两轮通过；检查.sh --oracle全部通过。规则参照先于实现，不碰真实存档／源。
- 代码定位：XState._ensure_random_master目前从orb_seed派生，所以仅删除random序列化仍会固定；to_dict/random_save、from_dict及XSave.valid_data目前严格引擎串；replay目前靠initial普通档隐式重建同一battle，切分后须独立保存／恢复边界runtime及setup前本场seed，不能恢复结束游标或走普通读档重新随机；run_item执行入口对多种不可用原因早退，需统一实战告警／诊断，纯预览不告警。mv_script的RomGet也调用MVInterpreter.random_int，接world时应保留其预掷语义与池数据。
- 独立后续任务：缓存核查问题修复在`codex/review-backlog-20261019-followup`；不要混入RNG分支。converter-write-changed仍归A独占，未做。可选老积压最后处理。
- 需要用户决定：无新增；按10-19已定可刷与world默认继续，不重复询问。

## 进度账

- 不增加。前轮沙僧4～6的`codex/review-backlog-20261019`（12aa60f）已有可合并核查交付，尚未并入main，不能覆盖或自核其Codex补丁；其中dev.087／090的战斗61%建议等唐僧登记。

## 本分支提交

- 本次提交：仅RNG返工接续说明。

## 沙僧7其余工作与正在运行的检查

- `codex/review-backlog-20261019-followup`，工作树`.claude/worktrees/review-backlog-20261019-followup`，头dc14416，干净，只有交付文档。已核32个登记探针依赖：无Python依赖，读generated者仅formula_program／formula_equipment／event，当前(a)放宽无漏项。真实Node＋真实ProbeCache复现(b)漏洞：旧party用例value1→2，首轮退出2，第二轮缓存命中退出0，第三轮--full也退出0；因比较基线取已被覆盖的generated/oracle，非单纯缓存问题。**尚未修**，需独立保留已接受基线（oracle＋源manifest），拒绝后缓存可复用但比较不能换基线；最近三份备份淘汰不能删该基线。需补拒绝连续重跑、只新增后显式接受、变化撤回、全量／车道克隆回归。30项既有工具回归全过（930fd759b7b04277818b439511395dac）。P0拒收、bab1981二进制日志、敌人双向上下文已在main并留回归；旧Codex实现仅核实存在，不替代Claude核查。
- 上述分支完整检查正在运行：`03_再刷重制_Godot/04_验证/本地结果/20261019_缓存复核/完整检查.log`，基线main368cf18，runId见.status.json。证据同目录有复现测量基线.py/json与探针依赖清单.json；仅临时夹具，无真实数据。**先用等待任务.sh读取结束，不重复开检查；等待器超时124不是被测任务失败。** 原PTY session70192只作辅助，结束以日志状态为准。
- `codex/framework-docs`，工作树`.claude/worktrees/framework-docs`，头4700681，干净。已完成现状／历史拆分（六段原文逐字保留）、11备注转换期解析／12 XSession／13模块挂点接口、八例覆盖矩阵与含466→538的可执行缺口清单、用户10-19非持久运行时RNG目标；仅文档。当前八例过滤2651、缺剩余回合／待行动／完整队列等如实标注。预检旧链接补battle-events稳定锚点。完整检查正在运行：`03_再刷重制_Godot/04_验证/本地结果/20261019_框架文档/完整检查.log`，基线main368cf18，PTY13061，结束以日志状态为准。合并工具模拟能提取1条框架／3条复核记录，无共用章节混入。
- main刚新增八戒_27合并0ea5c5c，唐僧正在收尾；以上两条检查只认证旧基线。结束后整理结果、小步提交，再等main收尾已提交后各自merge main，修正文档对“已知变身／Permanent问题仍待修”的过时描述；需要重新检查时按新main实际变化执行，不用旧结果冒充新基线通过。两条交付目前状态进行中，别提前写可合并。
- 收工仍按用户模板：交付二级标题原样，最后普通“- 状态：可合并”；游戏改动标题用开发编号占位；每次提交尾注“执行者: Codex（沙僧）／核查: 待Claude”。不改主交接板／记录／进度／编号／来源登记。源码与工具都等Claude交叉核查，不自销。

- 沙僧8已读交接板、主工作区及本车道status/log，确认主工作区未提交内容属于唐僧；原两条完整检查仍在跑，不重复启动。参照基线指纹在`04_验证/本地结果/20261019_RNG返工/参照基线.json`。

- 状态：进行中
