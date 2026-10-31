# 交付单：cc/nezha-bulkpills1（哪吒_12，批量服用丹药 BulkPills）

- 状态：进行中（WIP，不可合并）。哪吒_12 上下文到 70%，按规矩停手，交给下一位。
- 执行者：cc（哪吒_12）；从 parammax1 末端 87253910 切出。

## 已完成：探针量原版

- 新探针 `03_转换工具/mv_oracle/bulk_pills_probe.cjs`，产物拷到了 `01_Godot工程/tests/fixtures/bulk_pills_oracle.json`（没接全量同步）。不开场景，照原版 `processBatch` 的顺序逐颗服：useItem → 对目标 apply（numRepeats 次）→ applyGlobal，期间拦下 reserveCommonEvent，审过的事件当场用解释器跑完。
  - MOG_TreasurePopup 在 126 指令里要按事件角色画「获得物品」弹窗，不开场景会报错。探针里把 `checkTreasurePopup` 换成了空操作，只是画面，物品照常进背包。
- 8 个用例，结果要点：
  - `supports`：43 个支持的物品全部认（1685～1700、1702～1717、1726～1728、1901～1903、1906～1908、1987、1997）；1684、1701、1718、1497、1 都不认；把 CE1226 第 3 条阈值改成 239 后 1685 就不支持了，改回来又支持。
  - `batch.1685_cross`：变量 968 从 237 起，服 5 颗：到 240 那颗给万灵增元丹 1497 ×1、开开关 2466，提示「你获得了 万灵增元丹  !」「二品丹药商店权限开启!」；最大生命每颗 +200。
  - `batch.1710_cross`：变量 971 从 78 起，服 4 颗：只涨到 80 就不再加（rank 3 那条事件外面多一层「=80 跳过」），给 1500、开 2469；4 颗都消耗了，4 条提示。
  - `batch.1726`：没有事件，最大生命每颗 +10。
  - `batch.1901`／`1987`：不对队友（scope 0），每颗跑一次插件指令 `MagicWeaponAllGainExp 100`（究极是 1000000），各一条提示。
  - `batch.short`：要 5 颗只有 3 颗，停在「库存不足或道具已改变」。

## 下一位接着做

1. **逻辑核心** `modes/xiyou/core/bulk_pills.gd`（新文件，class_name 比如 XBulkPills）：
   - `SUPPORTED`、`EXPECTED_EVENTS`、`EXP_EVENTS` 照原版 `installBulkPillsRuntime.js` 第 5～16 行；`approved_event(id)` 照第 30～57 行逐条比结构（toaster 那条用同样的正则）；`supports(item)` 照第 58～64 行。
   - `run(host, s, item, requested)`（async）：照第 221～258 行逐颗做。用的人取法同 `ui/item_scene.gd` `_use()`（第 705～730 行：能行动的角色里 pha 最大者）；对队友时目标照 `_targets()`；消耗、`logic._effect` 逐效果、44 号公共事件收集起来，审过的用 `MVInterpreter` 当场跑（同 xiyou_achievement 测试里 `await MVInterpreter.new(host, 0, 0, list).run()`），没审过的照原版按先进先出留给地图（`s.reserve_common_event`，单槽，排不下的记一个队列）。返回 `{used, reason, remaining}`，reason 用原版的中文原因。
   - 「已学满」（1497～1500 的目标都已学会效果 43 的技能）照第 72～84 行。
2. **专项** `tests/xiyou_bulk_pills.gd`：逐例对 `bulk_pills_oracle.json`（supports 名单、tampered 例；每个 batch 比 used、reason、变量、开关、奖励物品、库存、角色八项能力、提示条数与内容、插件指令）。反向验证：把 `approved_event` 改成全放行或全拒，看 tampered 例和 1685 例会失败。
3. **入口**：`ui/item_scene.gd` 选到支持的物品时开数量窗。可以借商店的数字窗（`ui/shop.gd` 的 number 模式）。只接入口；原版专用数量窗的样式（456 宽、8 行高、居中、「服用数量」「持有：N 颗」「← / → ±1    ↑ / ↓ ±10」）写进「下一步」交给界面车道。结束提示：帮助窗写「已服用 名字 × N；剩余 N 颗（原因）」。
4. MagicWeaponAllGainExp：重制里看 `core/magic_weapon.gd`（`use_exp` 等）有没有对应的插件指令实现，`MVInterpreter` 的 356 能不能认；不能认就要补。

## 本分支提交

- 7576391f 探针与参照夹具
