# 交付：claude/bailong-exclusive4

- 车道／工作者：C 规则·机制（角色专属养成）／白龙_6（Claude）
- 状态：进行中
- 分支基于 claude/bailong-exclusive3 末端（期三已并入 main，dev.231）。

## 变更记录草稿

## 2026-10-31 【Claude·白龙_6·未经审查】渡鸦灵魂积累与铸印（dev.待定）

照原版 installNativeRavenRuntime.js 的 gainSoulFrom／canForge／awardRavenAdvanceSeal（第 954～992 行）与进阶确认包装（第 836～852 行），重制 `XRaven` 第二期：

1. **存档**：灵魂 `_codexRavenSoul` 与已铸印的阶 `_codexRavenForgedStage` 存进 `XState.raven`，存档键 `codexRaven`（`{soul, forged}`；旧档没有该键＝0 魂、−1 没铸过）。此前灵魂恒 0，进度、冥河冠冕溢出、法宝魂力加成、面板暴击都按 0 算，现在随灵魂生效。
2. **得魂**（Game_Enemy.die 包装，`XBattler._add_state` 阵亡分支、怪物图鉴计数之后调 `XRaven.on_enemy_death`）：渡鸦在 `$gameParty.members()`（战斗中＝出战成员，战斗外＝全队）里、这个敌人没算过时，得 clamp(10..50, floor(12＋5×log2(1＋经验/100)))，神话 ×3、备注 `<Boss>`／`<boss>` ×10，再夹到 50。经验取 `Game_Enemy.exp()`：数据库经验 × 神话倍率；难度经验倍率包在里层、被后装的 exp 改写盖掉，原版这里读不到（参照：难度 2 的经验倍率是 3，敌人 3 的 exp() 仍是 40）。
3. **铸印**：阶 < 5、本阶没铸过、灵魂 ≥ REQUIRE[阶＋1]（3000／12000／35000／80000／150000）→ 记本阶已铸；背包没有冥羽进阶印 2901 才给一枚。印丢掉后本阶不再补。
4. **进阶确认**（`XAdvance.advance` 末尾调 `after_advance`）：渡鸦升了一阶 → 灵魂清零、重排专属技能、再判铸印。
- 不移植：新局／读档再判一次铸印（restoreRavenState）。重制的灵魂只在倒敌（当场判过）和进阶（清零）时变，读进来的档不会处在「够了却没铸」的状态，只有 MV 旧档会（不迁移）。
- 参照：新探针 `mv_oracle/raven_soul_probe.cjs`（正式 Game_Enemy.die、Scene_ActorAdvanced.onConfirmOk；167 是超强角色，开挑战开关 2494 才能入队）28 例：得魂 16（七个敌人 × 神话与否，复活再倒下不重计）、后备与不在队 2、铸印 7、印丢掉后 1、进阶确认 3、模块常量 1。已登记进 `同步正式西游.py` 与 `oracle_additions.py`。
- 专项 `tests/xiyou_raven_soul`（97 项）：逐例比经验、神话、得魂、铸印前后的灵魂／印数／已铸阶、进阶后的阶／灵魂／印数／专属技能；另核存档往返与旧档。
- 反向验证：去掉神话 ×3、去掉「本阶没铸过」、进阶不清零，7 项失败（印丢掉后那例是之后补的，针对「本阶没铸过」）。

## 发现（未修，交审查／总装定）

- **战斗经验的难度倍率**：原版 `Game_Enemy.exp()` 读不到 Vitsuno 的难度经验倍率（见上第 2 条），重制 `XBattleLogic.rewards` 的经验是 `exp_reward × 难度「Drop Rate」第一项`。两者是否一致取决于原版另一处是否再乘（如 gainExp），本期没查；建议战斗核心车道用现有奖励参照核一次。

## 交接板

- 下一步：白龙期五（黑闪共用＋宿傩开战 TP／普攻换 10238／伤口，照 bailong-exclusive1 后续分期 4）。渡鸦剩下的：得魂时残响 10132／狩猎 10133 计数与神话形态续期（随期十的残响、神话形态做）、技能说明里的灵魂进度行（界面车道 B，Window_SkillList.updateHelp）。
- 用户试玩说明：渡鸦在队时每打倒一个敌人得 10～50 魂（神话、首领更多），本阶灵魂够了自动得到一枚冥羽进阶印，进阶后灵魂清零重攒；灵魂越多，渡鸦的暴击、伤害与法宝加成越高。
- 需要用户决定：无

## 进度账

- 角色与专属机制：50% → 50.5%（Claude 初值建议，待审查核定）。依据：渡鸦灵魂与铸印让第一期已做的魂力相关加成真正生效，按一名角色的主要养成线计＋0.5。

## 验证

- 专项：`xiyou_raven_soul` 97/97（本地）。
- 选测：待写
- 同步：待写

## 待交叉核查（改了原沙僧核心文件）

- `modes/xiyou/core/battler.gd`：`_add_state` 阵亡分支加一行 `XRaven.on_enemy_death`。
- `modes/xiyou/core/xstate.gd`：新字段 `raven`，`to_dict`／`from_dict` 各一处（存档键 codexRaven）。
- `modes/xiyou/core/advance.gd`：`advance` 记进阶前次数、末尾调 `XRaven.after_advance`。

## 可优化（流程／工具／效率）

- 建议（归工具车道）：`云端选测.py run` 在新分支名第一次跑时要整份推转换产物快照（约 400 MB，本机这次 20 多分钟）。车道换新分支（如期三 → 期四）时可以先从上一个分支的快照 ref 复制再增量推，省一次全量上传。

## 本分支提交

- fa487612 渡鸦灵魂积累与铸印：XRaven 第二期、存档 codexRaven、raven_soul_probe 参照与专项
- 1d8e3318 合并 main
