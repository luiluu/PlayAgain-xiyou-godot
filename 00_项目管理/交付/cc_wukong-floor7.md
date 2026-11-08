# 交付：cc/wukong-floor7

- 车道／工作者：A 内容·楼层／悟空（cc，协调派：传送连通性扩到开关／变量改变落点或出口的页）
- 状态：进行中（floor6 会话到上下文线交接，还没有改动）

## 接续要点（新会话从这里接）

- 分支从 cc/wukong-floor6 末端 44d24fd6 切出。工作树 sharp-kapitsa-ff9fc1 已补齐（generated 是 floor5 那轮转换器的产物；那轮同步中途停了，参照没重量，本单不碰切片就不用同步）。
- 任务：floor6 的 `xiyou_transfer_reach` 只用新开局状态，出口按「任一页有传送」算。本单要把开关、变量会改变落点或出口的传送页挑出来，按 event_compare 已知的页组合逐个验证；走不到的写进 `tests/fixtures/transfer_reach_known.json` 并说明原因。只用云端，本机不占槽。
- 建议做法：
  1. `03_转换工具/地图盘点.py` 的 fixture 生成处（`transfers()`、landings／exits 两段）给每个落点和出口记下来源页的页条件（开关、变量、独立开关、物品、角色），并记外层 111 条件。出口改成按页记：`{event, page, cond}`。
  2. 页组合从参照里取：`generated/oracle/events.json` 的 cases 用 `id`「m<图>e<事件>p<页>」标出参照逐页跑过的页；`event_states.json` 的 `#w..` 变体带状态。只挑这些页，不自己穷举。
  3. 专项给每个组合设好状态（照 `xiyou_unlock_chain._apply`：开关、变量、物品、独立开关、角色；超强者被拦时直接 `party.append`），进目标图，用 `e.page_index` 断言出口事件选中了预期页，再 BFS（`xiyou_reach_check.reachable`＋`_tiles_reach`）。
  4. 云端用 `07_开发环境/云端选测.py run --base HEAD~1` 只跑改了的场景，几分钟出结果；日志用 `gh run download <run> -R luiluu/PlayAgain-xiyou-godot`。
- 坑：JSON 号码是浮点，比事件号先转 int；Map002 开局图不走（退出时资源泄漏）；并行测试只要出现 `^ERROR:` 就判失败。

## 变更记录草稿

（待写）

## 交接板

- 下一步：（待写）
- 需要用户决定：无

## 验证

（待填）
