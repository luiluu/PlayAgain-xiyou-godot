# 交付：luiluu/t200

- 车道／工作者：T200 T187 遗留 live 32 个程序／脚本／暴击专属类逐个读程序定去向（cc，Opus＋medium）
- 状态：可合并（行为改动只有 38 缝合归池，走 POOL_LIVE，产品默认关、期四总开关开着才开；其余只改总账登记，守卫只记不改数）

## 变更记录草稿

## 2026-11-18 【cc·未经审查】T200 总账 live 清零：T187 留下的 32 个程序类逐个定去向（14 个挪 never、38 缝合归池、17 个进程序类永久允许）（dev.待定）

依据：T187 交付单「剩下的 32 个（程序／脚本类，留豁免）」；D203①（增伤一律归池）；派单口径「能折成固定 ×k 的归池、缩小类进 reduce、来源已删的进 never（带开关）、真不能静态折算的留永久豁免并写理由」。

- 先数清楚：main 上 `state_confirm_class.live` 是 32 个（skill 15、gear 4、state 2、unscanned 11）。小A R2 说的「11 个」是其中 unscanned（没扫到来源）那一组的数，不是 live 总数。
- `damage_ledger.json` `state_confirm_class`：
  - **挪 never 14 个**：
    - NO_SOURCE 12 个：543、719、1310、1401、1406、1441、1703、1707、1730、1733（T083 时就没扫到来源；这次补扫了转换数据表的 note、效果、特性、职业习得、物品教技能，地图／公共事件／敌群的加状态与习得指令和脚本，插件参数，Godot 代码，tianqi_data，还是一处挂的都没有。插件里的 1703／1707 是 EMosaicAId 防具号）；1424 赌场之证（唯一来源技能 8092 没有任何习得路径，而且乘数只会是 0 或 −1）；2522 虚无（来源 10075、10086～10088 都学不到，防具 136 只给它们 SkillPass、不教；能学到的是另一套 10485～10488，挂 2731）。
    - NO_HONGHUANG 1 个：1259 轮回不止2（由 1258 挂，1258 只来自技能 7196，7196 只由物品 1648 教，和 T187 已挪的 7195／7199 是同一套洪荒权能书）。
    - CARDS 1 个：2803 贝吉特合体复制（只给 9940 挂，9940 的卡删了全部 StartPushState；2565 本身在 card 类）。
  - **归池 1 个**：38 缝合（套装 8）。程序写法，但确认阶段其实是固定 ×1.05（暴击段加 0），另播动画 2。pool 表加一条 `as`＝换写后的效果：`mul ×1.05`（照常带 skipTypes）＋去掉改 value 那两步的原程序（只留播动画，打放行标记）。③ ＋5%，cap nine。
  - **新类 program 17 个（永久允许，行 `state_confirm_program`）**，各条写 kind 和理由：
    - inert（不改伤害）：1062（js 只清暴击标记，Godot 不执行；而且挂在敌人身上）、1352、1747（原版就是语法错误）。
    - extra（不改本击伤害值，是独立附加扣血或秒杀）：1642 千刃乱雨、2559 血梅香、1661 湮灭（按血量比例附加扣血）、50 雷鸣、97 狂风（固定附加伤害）、2568（概率秒杀）。
    - dynamic（倍率跟运行期的量走，静态折不成固定 ×k）：1421 欧皇之证、1422 非酋之证（跟变量，封顶 ×1.1／×1.05）、2583 雷道之威（跟双方最大 HP 比，可能 <1）、2731 虚无（跟目标状态数）、1834 孤世独行（只剩自己活着时 ×1.5，要按出手时的存活人数判）、1666 半步真仙效果（一次性另扣一下等于本击的血然后自删）。
    - crit（暴击专属段）：1522 神秘成圣（＋50%，暴击再 ×1.5）、2556 胡桃（暴击 ×2.5）。
  - `live` 清零；`live_note` 改写；新增 `program_note`。
  - rows：新增 `state_confirm_program`（allowed）；`state_confirm`（exempt，期五到期）改名为兜底行，说明写清现在只兜 713 在 POOL_SUIT 关着（回退中）时那一步。
- `tianqi_ledger.gd`：`confirm_source` 认 program 类 → `state_confirm_program`（`reload_table` 一并清缓存）；pool 表的条目可带 `as`（`_live_source_effects`）：`live_pool_effects` 按 `as` 算 ③，`live_confirm_rows` 把这个状态确认阶段那几条整个换成 `as`（mul 带 skipTypes＋标记，不改 value 的程序只打标记）。
- 专项：`xiyou_tianqi_live_sample` 加 4 条（t200_live_cleared、t200_never、t200_38_as、t200_38_runtime），`_fixed_k` 认 `as`，`live_only_dynamic` 里 1062 改认 program；`xiyou_tianqi_ledger` 覆盖检查认 program 类、confirm 各行加 program 行。反向验证：去掉 `live_confirm_rows` 的 `as` 换写 → t200_38_runtime 失败（打敌人又乘回 105、守卫报 38）。
- 验证：`语法检查.py` 0 问题；`发行空壳.py check` 679 个函数都有；`并行测试.py` xiyou_tianqi_ledger、xiyou_tianqi_ledger_p3、xiyou_tianqi_live_sample、xiyou_tianqi_phase4、xiyou_tianqi_phase4_modules、xiyou_tianqi_no_diff_passive、xiyou_tianqi_trumpet、xiyou_state_effects、xiyou_state_effects_tp、xiyou_combat、xiyou_custom_damage、xiyou_state_js、xiyou_pushstate 全过。没跑：K 复量（期四里唯一变数的是 38 缝合 ＋5%，还算进九线封顶，冒不了尖）、`--oracle`、虚拟玩家 climb（PHASE4 关着时新代码第一句就返回）。

## 交接板

- 下一步：无（live 已清零）。program 类里 dynamic 6 个、crit 2 个是「理论上是增伤、但这次没归池」的，见下「可优化」。
- 用户试玩说明：无（期四总开关默认关）
- 需要用户决定：无新增

## 进度账

- 无

## 可优化（流程／工具／效率）

- dynamic 类（1421、1422、2583、2731、1834、1666）按 D203①其实也该归池，只是倍率要在出手时算。办法：总账在出手时用这一击的上下文先跑一遍这段程序（value 取个探针值，不执行），得出这一下的 k，把 k−1 进③，原那一步对敌人跳过。要让 `state_effects.gd` 的 value_program／value_query 认 skipTypes（现在只有 mul、value_steps 认），超出本卡的独占文件，所以没做。
- crit 类（1522、2556）要归池得先定「暴击专属段进爆伤池」的口径，还要动 `damage.gd`（加暴击那份）。1522 的非暴击段 ＋50% 能单独先归池，但要先给守卫加「半归池」的认法。两样都是另一张卡。

## 要 Kyo 定

- 无

## 异议

- 派单说「小A R2 说重分类后 live 实剩 11 个」：查 main 是 32 个，11 是其中 unscanned 那一组（T187 交付单「41 个没扫到来源的」一节写的就是「剩 11 个在 live」），不是 live 总数。
- 「永久豁免」的 17 个里有 8 个（dynamic 6、crit 2）是增伤，和 D203①「增伤一律归池」有出入；照派单「真不能静态折算的留永久豁免」办，归池办法写在「可优化」。
