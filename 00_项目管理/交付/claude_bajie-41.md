# 交付：claude/bajie-41

- 车道／工作者：C 规则·机制／八戒（Claude，重制_八戒_40 会话复用）
- 状态：可合并
- 验证（新规则：车道不跑全量，只跑相关专项）：`同步正式西游.py --accept-additions` 两次，均为「新增用例，已接受」（review_fix.json 15→31→32 例，只新增）；Godot 专项 xiyou_review_fix 60/60，取整改动波及处 xiyou_combat 34、custom_damage 145、drop_dh 12、drop_record 26、dungeon 6954、equipment 1228、floor_run a／b／c 261／312／525、guide 63、map 175、power 137、review_fixes 16、sequence_visual 54、status_power 36、status_power_panel 11、zhenqi 181、zhenqi_break 83、zhenqi_daofa 68、battle_ui 43 全部通过；工具回归 `测试合并工具.py` 119/119（新增两项在旧脚本下均失败、新脚本通过）。`git merge main` 一次（main 只改了交接板），之后无需重同步。

## 变更记录草稿

## 2026-10-21 【Claude·八戒·未经Codex检验】JS Math.round 取整大整数差一（dev.待定）

- 沙僧 P2（核查报告_20261021「新P2：用floorf(x+0.5)替代Math.round的大整数偏差」）：`floorf(x+0.5)` 对已是整数的大奇数（如 -4503599627370497）先加 0.5 会在双精度里被舍入改值，floor 后差一；另 0.49999999999999994 加 0.5 得 1。
- 改法：`XPower.js_round` 先取 floor，再用原值减 floor 的小数部分 ≥0.5 判进位，不对原值先加 0.5；NaN／±Infinity 原样，负零不区分。全仓同类写法统一走它，清单：
  - `core/damage.gd` 最终 settled 取整、`_healing` 取整（沙僧点名两处）
  - `core/power.gd` js_round 本身（战力等已有调用随之修正）
  - `core/zhenqi.gd` boss_reward、group 千分位显示、_js_round、_pct 四处
  - `battle/drop_popup.gd` 掉落弹字纵坐标、`battle/battle_camera.gd` _round
  - `core/equipment_view.gd` 法宝 Init Level、`core/map_transfer.gd` 掉率显示
  - 不改：`battle/mv_animation.gd` 着色器颜色量化（GLSL，0～255 颜色值，非 Math.round 语义）；`damage.gd` apply_fixed_mitigation 的 roundf（值恒 ≥0，与 Math.round 相同）。
- 参照：review_fix_probe 新增 heal.round.*（15 个输入：0.5／1.5／2.5、0.49999999999999994、631187.5／631186.5、4503599627370495.5、2^52 邻域 4503599627370495～…499、2^53 邻域 9007199254740991／…992／…994、1e21，走真实 CodexDamage.calculate 治疗入口）、round.native（原生 Math.round(±x) 可读表）、round.native.bits（同表按双精度位记录）。
- 测试：xiyou_review_fix 逐例对照。发现 Godot 的 JSON／to_float 数字解析不是正确舍入（4503599627370495.5 读成 …495.0，0.49999999999999994 也有偏差），所以输入与期望都按 round.native.bits 的位还原，不用 JSON 数字比较。

## 2026-10-21 【Claude·八戒·未经Codex检验】并行测试缓存严格校验与批测心跳（dev.待定）

- 沙僧 P2（核查报告_20261021「第二期保留问题：P2 测试缓存复用未校验结果行」）：`并行测试.py` 新增 reusable_results，记录须是对象、场景集合相同、每条只含布尔 passed 与字符串 line，passed 为真的行再用 result_ok 复核（passed＝total＞0）；任一条结构不对或自相矛盾，整份当作没有记录、整轮重跑。复现材料 review_phase2_cache_corruption.json 两种情形（line 改成 passed0/total999 仍沿用退出 0；合法 JSON 数组 AttributeError）都写成回归。
- 沙僧工具链阻断（同报告「静默批测与默认看门狗」）：批测与排槽期间每 XIYOU_TEST_HEARTBEAT 秒（默认 300，0 关闭）打印一行进度「完成 x/y，等槽 n，在跑 …」，免得长任务.py 默认 3600 秒无输出看门狗误判卡住；看门狗与并发都不改。重跑阶段同样有心跳。
- 回归：测试合并工具.py 新增 test_corrupt_or_contradictory_cache_is_not_reused、test_heartbeat_while_waiting_and_running；run_tests 允许覆盖 CHECK_GLOBAL_JOBS。旧脚本下两项都失败、新脚本通过。

## 交接板

- 下一步：Codex 核查本分支两期（js_round 全仓替换清单是否完整、缓存校验与心跳）。
- 下一步（期三砍掉，留后续）：成就 142／143 专用徽章与 143 特殊界面。原版范围（installWeakChallengeRuntime／installKyoAchievementRuntime）：
  - 图标 240201／240202 一律改画 img/codex_achievements/EssenceMaster.png／KYO.png（256² 缩到 32×倍率），成就列表里这两个徽章在 (rect.x, y) 画 64，不像普通图标偏 +16；弹窗里 32 在 (10,10)。
  - 142「本质高手」：列表与弹窗的名字改成渐变描边字（#fff8db→#f7dda0→#c69d55，描边 #2d1749 宽 3，阴影 #9463d0 模糊 4；弹窗字号 20），弹窗上下各 1px 线 #b391d5／#c7a261。
  - 143「kyo专属」：列表行不论得否只画 64 徽章（rect.x+8，垂直居中），未得透明度 80；弹窗宽 64、窗口不透明度 0、只画 40 徽章居中；首次获得需测试模式授权；另有地图名牌玩家昵称铂金渐变循环（720 帧），属称号／名牌系统。
  - 阻塞：两张 PNG 要经 xiyou_slice.json 的 extraImages 导出，本期该文件由悟空独占，未改。先补参照（achievement_probe 录 142／143 行的实际绘制调用，沙僧 P3 指出现有 probe 只留前几屏、看不到这两行），再实现。
- 用户试玩说明：伤害／治疗等取整在极大数值下不再差 1（日常数值不变）；批测日志每 5 分钟多一行进度。
- 需要用户决定：无。

## 进度账

- 不调整（P2 修复与工具改进）。

## 本分支提交

- de30845 期一：JS Math.round 取整
- 9064334 期二：并行测试缓存严格校验、批测心跳
- bdbe325 合并 main
