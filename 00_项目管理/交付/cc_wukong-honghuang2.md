# cc/wukong-honghuang2（悟空·洪荒二期）— WIP，未完成，不可合并

- 分支从 cc/wukong-honghuang1（253b43dc）切出，已合 main（e808c146）并 `--补齐`。honghuang1 还没进 main，合并时先合 honghuang1。
- 本期只做了调查和一个还没跑过的原版参照探针；没改 Godot 代码。总装十五 11-03 因额度收工叫停。

## 变更记录草稿

- （未完成，暂无）

## 接续（下一位从这里开始）

### 1. 判定口径（已查清，还没改）
- 原版 `CodexHonghuang.isHonghuang` = 开关 2483 **或** 2463。全游戏扫过一遍（地图、公共事件、敌群）：
  - 2483、2463 一起开、同时 `Difficulty SetID 8`：只有大厅 Map004 EV41 第 3／5 页（开洪荒）。
  - CE1441（女帝抽奖第 9 档）只开 2483，不设难度。
  - Map004 EV62 第 3 页（牢妲）关掉 2483（**不关 2463**），还能把怪物难度单独切到 1～9（含 8）。
  - CE714「难度修复」：2483 开着就 SetID 8。
  - 所以「难度 8」和「开关」会不一致：牢妲切过难度后，原版仍按 2463 算洪荒；只切到难度 8、没开开关的，原版不算。
- 重制只有一处按难度判洪荒：`modes/xiyou/map/mv_script.gd:309`（`s.difficulty != 8`）。`zhenqi.gd:95` 已经按 2483／2463 判，跟原版一致。
- 要改的：在 `honghuang.gd` 加 `is_honghuang(s)`（2483 或 2463），309 行改用它。

### 2. 原版参照探针（写好了，**还没跑过**）
- `03_转换工具/mv_oracle/honghuang_reward_probe.cjs`：① 判定口径 6 例（含只设难度 8）；② 发券 10 例（持有者、四舍五入）；③ rollPower 21 例（真实 setup／startBattle／endBattle，区段 1～5 分别用地图 152／161／162／177／210，熟练度 10／50，上限，同一场调两次）；④ CE1445 开／关 2463。
- 下一步：`node honghuang_reward_probe.cjs`，看各例 errors，再把 `.sandbox/honghuang_reward.json` 拷成 `tests/fixtures/honghuang_reward_oracle.json`。注意难度用 `$gameSystem._difficultyId` 直接写，读回用 `difficultyId()`；`$.toaster` 已经接住。

### 3. 实现要点（还没写）
- 发券 `grantTicketBonus`：`max(0, round(5×(curse_bonus(持有者)−1)))` 张 1639；持有者＝队伍里第一个学了诅咒的人，没有就取队首；提示文字「洪荒诅咒加成（×N.N）：肝帝积分抽奖券额外+n」（toFixed(1)）。CE1439 里这一句不在 2483 的条件分支里，靠它自己判洪荒。
- 权能 `rollPower`：开战时记 `{eligible: 洪荒 且 XYunshangOrders.immortal_clear(s, troop), troop, floor: XDungeon.boss_floor(map), won, rolled}`；建议在 `mv_interpreter.gd:236` 的 301 指令里，`start_battle` 之前记、之后写胜负；在 `xstate._become_current` 里清掉（`battle_replay.gd:44` 的 prior_contexts 也要带上）。区段 `SEGMENTS [[0,15],[16,18],[19,21],[22,25],[26,99]]`，这一段的书是道具备注 `<CodexPower: N>`（1655／1718＝1，1656／1658＝2，1657／1667＝3，1654／1659＝4，1674／1683＝5），每本掷一次 `rand < min(1, 0.03×倍率×XDungeon.power_factor(s, troop))`；CE1439 里 `bossReward` 先跑，熟练度已经 +1。提示「洪荒权能掉落：书名！」。
- CE1445 洪荒压制：把去掉空白后的整段 `var hh=$dataSkills.filter(…<CodexHonghuangSuppress>…)[0];for(var j=1;…)learnSkill(hh.id)` 加进 `_honghuang_curse`，换成 actor op `{"op":"learn","skill":10300,"named":true}`；技能 ID 和 `xstate.sync_native_tier` 共用一个查找函数。做完删掉 `tests/xiyou_honghuang_curse.gd` 里的 `SUPPRESS_SKIPPED`。
- `guide.gd:204` 的 `_power_line` 和修行页「洪荒权能」那句话，等权能接好再改。

### 4. 诅咒 7201～7215 战斗效果（还没查）
- 技能备注已经列出来了：7201～7205、7208～7210、7212～7215 用 `Start(WT|AE)PushState` 挂状态 1265～1272／1282～1285／2675；7207 `<passiveCrHarmRi:-1000>`；7211 `<passiveIRUP:-40>`；10300 挂状态 2679。下一步对着这些状态的备注，查重制战斗认不认这些标签。

## 验证

- 没跑测试（总装叫停；探针也还没跑）。

## 本分支提交

- （本提交）WIP：探针与交付单接续
