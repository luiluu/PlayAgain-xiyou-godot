# 交付：luiluu/cc-script-census-fest（T101）

- 车道／工作者：T101 普查红修复／cc（Sonnet 5.5＋medium，机械修）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】T101：庆典报名处把解释器当宿主传给冠军之路，真机会崩；改传地图宿主（dev.待定）

- 玩家可见：庆典大厅报名处点「去冠军之路」不再脚本报错（此前入口收到的是事件解释器，没有 show_text_with_choices／start_battle，选档对话就断了）。
- 根因：`fest_lobby.gd` 的 `enroll` 调 `road.call(ROAD_METHOD, interp)`，而 `fest_road.gd` 的 talk／run 对宿主调 `show_text_with_choices`、`start_battle`，这两个只在地图宿主（XMapScene）上有。xiyou_script_census 选测抓到，是真机缺陷不只是测试宿主缺桩，所以修调用方：改传 `interp.host`，不补桩掩盖。
- 测试：普查宿主 CensusHost 补 `start_battle` 桩（普查只看认不认得，返回 0）；`show_text_with_choices` 桩原本就有。
- 复现：main 上单跑 xiyou_script_census 4 条 SCRIPT ERROR（3 条 show_text_with_choices、1 条 start_battle），TEST_RESULT 仍 31/31 但判挂；修后 0 条。

- 并入（总协调 11-16 加单）：main 上 T070（ce9e7a8fb）后 `检查.sh` 报「发行空壳缺成员」，实为 `发行空壳.py check` 的 suspects：`modes/xiyou/core/text_fix.gd` 头注释含「只在天启篇」被当天启篇专属。查实它是 XDB 读表／地图的通用文字修正，西游档也要用（只有 tianqi_dict 一条限天启篇存档），不能换空壳，故登记进 `发行空壳.py` 的 MIXED_OK 并写理由；`发行空壳.py check` 通过（64 脚本 579 函数）、`测试发行空壳.py` OK。
- 待总协调定（不在本单范围）：`text_fix/rules.json` 的 tianqi_dict（晨星币／霸主／见证使者等改名）会随真脚本进发行包，发行审计里没有 DENY 它；是否剔掉请定。

## 交接板

- 下一步：无
- 用户试玩说明：庆典报名处进冠军之路可用
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- xiyou_script_census、xiyou_fest_lobby 127/127、xiyou_fest_road 66/66、xiyou_fest_reward 56/56 前台单跑通过；选测 70 场景见回报。
- 待交叉核查：fest_lobby.gd 一行改动（调用方换传 interp.host）。

## 本分支提交

- 见 git log
