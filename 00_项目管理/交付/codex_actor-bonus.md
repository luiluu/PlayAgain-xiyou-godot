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
