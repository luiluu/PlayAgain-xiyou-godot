# 交付：codex/actor-bonus-states

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_64）
- 状态：进行中，尚不可合并
- 基线：actor-bonus 7ef7584a；同一 state-effects-2b 工作树续做，首批分支保留可合并。
- 范围：先取冻结原版1612 Apply／Remove／Leave和1768 Conclude的生命周期参照，再接完整签名的param_add；当前角色持久账本与预览隔离为本期验收重点。敌人无永久账本的边界单独说明，不扩未交接的formula_execution／mv_event_core、两个TP Apply宿主或完整预览空槽。
- 开工实查额度五小时89%、周29%，95%保存停；共用登记只读，不自销核。旧原版证据、.sandbox、generated及整树保留。

## 验证

尚未开始新参照和实现验证；不重复首批已过19场或旧全量／同步。

## 可优化

独立定向参照与夹具，不注册全量同步；长批测使用python3 -u与XIYOU_TEST_HEARTBEAT=30。

## 原版参照检查点

- 七组定向参照errors空，保留来源身份与每次addParam后的HP／MP；初版探针误用Conclude方法名及recoverAll清状态，已纠正后重取，不算最终验证失败。
- 1612自然配置autoRemovalTiming=0，本来不会自然到期；forced_expire仅为明确改timing=2的测试宿主，验证Remove再Leave两组各减四次。通常驱散只Remove，重复附加只续期。移除按当时level，故3级加、5级撤会留下负余额，不擅自修正。
- 1768走原版offApplyStateEffects入口，分别测存活、仅HP0、仅死亡状态、两者及自目标；两次执行与JsonEx往返。
