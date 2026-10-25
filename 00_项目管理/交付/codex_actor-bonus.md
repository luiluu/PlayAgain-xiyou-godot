# 交付：codex/actor-bonus

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_63）
- 状态：进行中
- 基线：rng-compare-review b495833a；依赖四零散→2g→随机核查。只用已有 state-effects-2b 树，上一位已停，开工工作区干净，无在途任务。额度五小时67%、周25%。共用登记只读。
- 本期首批：复用 XParamPlus／mv_param_plus 的永久加算；宠物出战前八项、后六项特性映射；整队时 TeamA 技能迁移。先补冻结原版参照，再接线；不重复旧同步／全量／旧专项。
- 初读：永久加算当前放 param_base、值被 int 截断，需测 addParam 的小数与 paramPlus 分层。宠物原版 traitsSum 的 id5 不加、id6 回退用 push13，不能简单把后六项顺序塞进 xparam。整队原版在各槽位变更前忘旧 TeamA、变更后学新 TeamA；不等退出菜单。
- actor.gd 保留 XTraining／XParamPlus／XActorModules 例外接口；本树尚无 XActorModules 挂点，不自行补别车道内容。未交接的公式执行接口、两个 Apply、完整预览尾巴不碰。

## 变更记录草稿

本期尚未完成实现或验收；自己的提交全部待 Claude，不自销核、不自评完成度。

## 可优化

- 原版参照用独立定向探针＋测试夹具，不触发整轮同步；保留源身份和生成脚本，可单独复测。现有 generated／旧证据／.sandbox／整树均保留。

## 原版证据

- 独立 actor_bonus_probe.cjs 三组原版取样 errors 空：永久 addParam 小数／减生命上限／recoverAll／JsonEx 往返、宠物完整切换／重学／TeamA 换位／休息与仓库、traitsSum 后六项和敌人不加成。夹具含冻结来源身份；原始脚本输出在 .sandbox/actor_bonus.json 保留。探针首跑因跨 VM 数组缺 contains 失败，改为原版 realm Array 后全过，未改冻结代码。
- 确认 refreshGTWar 临时撤回前八项会夹 HP/MP；接线需保留。原版属性层 paramBase 不含永久加算，paramPlus 保留 12.5−1.25=11.25；不能用 int 丢小数。

## 实现检查点（尚未交付）

- XParamPlus 保留小数，复用原 mv_param_plus；加算搬到 paramPlus 层，addParam 后按原版 refresh 截资源。保留修炼挂点、装备／套装／法宝／哈基米贡献。
- 宠物前八项复用 XParamPlus 入账／撤回，仓库同享；后六项在 actor traits_sum 读取（XP5 不加、XP6 回退 push13），先于被动、套装和命中保底。重学先撤属性夹资源，出战／切换／休息逐项加减同一能力账本，名单随宠物记录保存，读档标记防止重复加。
- 在 XState 增加仅运行时的上次 TeamA 接收者，槽位重排／重建即时迁移；读档按当前槽位恢复接收者，不增加存档字段。
- 新专项 436/436。初版测试的 XEnemy.setup 少传难度导致语法失败（已修）；一次 435/436 是原版 mapping 脚本直接赋 GTWar 后读旧 xparam 缓存，改用原生学／忘／refresh 取同一时点后 436/436，不改生产去迎合坏采样。不是偶发。下面继续补槽位边界并跑依赖；未运行全量或同步。


## 边界补证与设计定稿

- 同槽重排也必须重新学 TeamA，去掉“接收者没变就跳过”的捷径；空槽→重建、读档→换位均逐字段对上。四组原版取样 errors 空。
- 发现新加入角色原版未发属性、休息却扣成负数，故采用原版同一 paramPlus 账本逐项加减，放弃早期动态按成员身份求值的实现；已提交的早期描述由本节取代。新档 pets.bonus_ledger 标识已经入账，bonus_actors 保存发放名单，读档不重复加；重制旧档无标记时只补一次此前未接的属性（不迁移 MV 存档）。
- 可回退优化（待总装分配 O 编号）：XPets.FIX_UNGRANTED_BONUS 默认 true，只撤实际发过的角色加成，防止未加先扣；false 恢复原版的负数缺陷。新增者不会凭空获得未发过的加成，换宠物／refresh_war 后按原版统一重发。必须登记原版行为、修正、理由与开关，留用户最终决定。
- 原版角色 xparam 有缓存；从未入队／仓库的观察对象 10 在 membership 场景休息后仍留旧缓存。该场景的严格范围是现有队伍／仓库＋新增9，剔除从未参与的10；既有 lifecycle 的全员10仍完整比较，traitsSum 十项与敌人零加成也严格比较。完整角色 xparam 缓存不在本首批范围，不把这个差异伪装成已移植。
