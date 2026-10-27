# 交付：claude/wukong-challenge3

- 车道／工作者：A 内容／悟空（Claude，悟空_62 期十五）
- 状态：可合并

## 变更记录草稿

## 2026-10-27 【Claude·悟空·未经Codex检验】难度倍率后 xparam 的命中／闪避／暴击判定对冻结 v0.28：重制已一致（dev.待定）

- 接期十四遗留第一条：Star_Warehouse 把敌人 xparam 乘到 1.4～2.85 后，判定处与原版是否一致。新探针 `mv_oracle/hit_warehouse_probe.cjs` 量真实 `Game_Action.itemHit／itemEva／itemCri` 和 `apply` 的 missed／evaded／critical：敌人打角色 1、角色 1 打敌人；技能 攻击／物理／魔法／必中 四类；追加 xparam 特征 6 组（无、闪避、高闪避含魔闪、低命中、暴击＋暴击闪避、高暴击，在内存敌人数据上追加，使基础值越过 1）；标志 无／L2／L4／L5；Math.random 取 0.01／0.2／0.4／0.6／0.8／0.99，共 192 例。
- 原版结论：①`itemHit` 钳到 0～1（命中乘到 >1 也只是 1，敌人命中 2.85 不会"超必中"）；目标闪避被倍率乘到 >1 时命中公式 `skillHitRate*(命中-闪避)*1.2` 为负，钳成 0 ＝ 随机数 0.01 也必不命中；必中技能不受闪避影响。②`itemEva` 恒为 0（YEP 闪避公式为 0），"闪避"全并入命中公式，没有 evaded。③`itemCri` ＝ 攻击方暴击 ×(1−目标暴击闪避)，钳到 1：暴击率超 1 就是必暴；敌人暴击乘到 >1 时必暴；目标暴击闪避被倍率乘大则暴击率降低。④apply 次序：随机数≥itemHit 未命中，再 随机数<itemEva 闪避，再 随机数<itemCri 暴击，未命中不再判暴击。
- 重制 `battle_logic.gd` 的 `item_hit`／`item_eva` 与 `_apply` 的暴击判定逐例一致（2689／2689），**没有改判定代码**。
- 新夹具 `tests/fixtures/hit_warehouse_oracle.json`，新专项 `xiyou_hit_warehouse`（敌人子类临时追加 xparam 特征，不动共享数据）。

### 改了的核心文件

- 无（只加探针、夹具、专项）。

## 交接板

- 下一步：差异 1（五乘区）等用户定；期十四遗留里难度继承分档 6216／6235、补强档开关 2461～2463、角色≥167 路径、读档补同步**本期没做**——要先读公共事件 1345／1443～1445 的名单并补参照，是单独一期的量。
- 需要用户决定：无新增。

## 验证

- 新专项：`xiyou_hit_warehouse` 2689／2689（首跑）。
- 没改任何游戏代码，故没跑 `xiyou_rules` 全段与 `xiyou_event_compare`（任务要求"改了判定就跑全部"，本期没改）。

## 遗留

- 同期十四遗留的难度继承分档／补强档／≥167／读档补同步，仍无参照。
- 夹具 `hit_warehouse_oracle.json` 与 `enemy_warehouse_oracle.json` 一样是手工拷自 `.sandbox` 的静态夹具，没挂进同步探针表。

## 本分支提交

- 本期探针、夹具、专项、交付单一次提交。
