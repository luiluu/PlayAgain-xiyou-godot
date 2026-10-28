# 交付：codex/review-backlog-20261028-10

- 车道／工作者：核查／重制_沙僧_87（Codex）。
- 状态：WIP，勿合并。
- 正在做什么：固定 dc8057c1，先核 Claude attack-query3 的敌人无行动／不能用、角色执行、禁用号角及测试边界；前九期按各自交付单登记，不复核自身工作。
- 前九期交付单均为祖先，总装按实际合并顺序处理，避免重复导入；继续沿用工作树，旧证据全部保留，不改共享文件。

## 核查检查点

- 目标批：607dd6b、cf39218、2473344、44abfba、5c850de、12ecc0f（均须再核尾注）；`attack-original.md`、`attack-diff.patch`、`attack-registration.patch` 已存本地结果。
- 冻结原版 `processTurn` 对敌人检查 `isValid`；OTB 角色输入后直接 `startAction`，与本批处理方向吻合。正式 `xiyou_attack_query` 的 skip 组需注意它明确忽略原版 `valid`、`forcedValid`、`phase` 等字段，限定于实际逐项比较。
- 单独重采 `attack_query_probe`，done／0，43 例无错误，sourceIdentity 与全部 cases 和工程 generated 相同；原件与诊断源保留。收尾登记与原单仅开发编号替换和额外注明重复函数修正；该修正删掉 challenge4 添加的重名函数并保留已有实现，challenge4 整批尚待另核。
- 正式相关专项 `attack-specialties.log` 正在运行（名称前缀会展开多场），不得提前声称通过；查 status 后用等待任务脚本接续。仍需继续核实无行动的收尾路径、专项与测试边界、尾注及登记模拟，再做文档选测和交付。

## 沙僧87→88同树接续（2026-10-28）

- 会话接近 40% 接力线：最后读取 input_tokens 189249／475000＝39.84%，接下来的保存与接续会跨线；按既有明确授权创建同树下一会话，87 创建成功即停。额度最近五小时 36%、周 31%，不使用重置；继续清固定基准可核积压，不每期停等。
- 显式 workdir 为本车道原 state-effects-2b；分支 codex/review-backlog-20261028-10，固定代码 dc8057c186702569d93f0213d702dd52e4442b71，不追新 main、不建／清树、reset、cherry-pick、接管 main，不改共享交接板／编号／变更记录，不建 PR。旧未跟踪证据、generated、sandbox 全保留。只核 Claude，不修实现或正式测试，不自核 Codex 历史、自己的报告和完成度；问题记 P 级／出处／复现／建议交总装派 Claude，不给其他 chat 发消息或派活。
- 第九期 ffc5638baa40cf3532ca96a53421346ab2b3f05b 已交付、推 github 并核远端同 SHA，四批 21 个 Claude 提交限定通过；14 场 709832／709832，文档选测 --affected dc8057c1 --oracle done／0。黄泉招募差异源于宿主数组跨 realm 导致原版入队异常，修正夹具后四组读数一致，异常及原件保留。登记模拟待 Codex 55→51，unsafeRemoved=[]、notRemoved=[]，尚未实际登记。第七、八期与第九期均由总装按实际合并顺序处理交付单祖先，不重复导入；第六期四批仍待登记。旧问题按原单保留。
- 第十期 WIP：仅攻 attack-query3 六个 Claude 提交（607dd6b、cf39218、2473344、44abfba、5c850de、12ecc0f），尾注全为 Claude／待Codex；原单、净 diff、收尾 patch 在本地结果 review-backlog-20261028-10。收尾多一处 item_marks 重名函数修正：保留已有的 super_strong_ids 缓存函数，删 challenge4 新加重复定义；challenge4 整批另核，不要借本期清掉。
- 已看本批 battle_logic、item_scene、troop_events 的净 diff、原版核心 processTurn 与 OTB 路径、专项 skip 组及探针。敌人 isValid 无效跳过，角色 OTB 输入后直接 startAction；本测试忽略原版 valid／forcedValid／phase 等字段，应按实际对照范围表述；无行动收尾链仍需进一步核对，不提前断言完整通过。收尾变更记录与原单逐行比对仅编号和追加重名修正。未评估进度初值。
- 原版 probe 重采 attack-native87.log done／0，43 例 sourceIdentity 与 cases 均与 generated 相同，无错误；原输出和脚本已存本期本地结果。无新产品问题已确认。
- 两项长任务在途：attack-specialties.log（多个场景，6 个名称前缀会展开，最后见 troop_events_half 运行）与 simulation87.log（生产 draft／pending 限定六 hash，尚运行）；先读对应 .status.json，再用 等待任务.sh --timeout 45 等；不要重启／取消。模拟以六 hash 写 draft87.md，实际登记正文须相同范围；查 unsafeRemoved 与 notRemoved。专项按最终逐场结果和错误通道判定。
- 下一步：等两任务，继续对照原版无效行动后的 onAllActionsEnd 与 Godot act 收尾和敌群测试收窄边界；若发现问题先复现并记录交 Claude，不修。按实际核查限定范围写报告、生产草稿模拟、文档选测 --affected dc8057c1 --oracle；完成后标可合并、提交推 github 核远端，同树续清其余未核批。五小时 95%、周 90% 停手；上下文实际 input_tokens 达 40% 同树下一序号。
