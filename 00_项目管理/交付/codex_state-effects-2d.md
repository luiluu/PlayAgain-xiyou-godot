# 交付：codex/state-effects-2d

- 车道／工作者：翻译／核查 · Codex（沙僧，重制_沙僧_42）。
- 状态：进行中，未验收；2b／2c保持原分支可独立合并。
- 工作树：沿用state-effects-2b，分支从4760a54切出，不新建工作树。
- 开工2026-10-22（Europe/Paris）：已只读main交接板及两边status／log。本树干净；main仍09ebfb0，唐僧未提交收尾不触碰。无新Claude待核查提交，不重复核dev122／123。
- 独占：状态效果翻译、state_effects.gd、state_effects_probe、自己的专项；不改actor.gd、xstate、battle_event_runner、角色／界面／工具已有脚本或共用登记。
- 本期先原版实测1047／1048元素、1834队伍存活数、2544／2545首武器类型五个完整块；2711先测未定义defender的真实错误，不将它改成target。
- 后续依五期骨架继续。③param_add要求角色能力值、存取档缺省与refresh完整链；范围外则具体提案跳④。④单槽公共事件若需范围外核心同样提案，连续两期无可交付即停手回报。
- 车道只跑专项；全量检查与推main由唐僧统一做；所有实现待Claude交叉核查，不自核。

## 原版实测与范围收窄

- 最终原版native-v3.log退出0，21例errors=[]；旧20例与2c最终参照逐项不变，只增query.native_blocks（3060行）。2711的defender在原版Action槽有定义，敌人HP比<0.2时翻倍，等于0.2不翻倍；先前怀疑接口错误已被实测排除。
- 本期只翻四个整块：1047／1048元素contains正反条件、1834我方队伍存活数、2711敌人低HP比。完整token白名单后输出value_query；不扩共享公式VM。125mul／2user_param_damage／28value_steps／35value_program不变，js448→444。
- 元素测了12组：物理／非物理／无属性／攻击属性、multiple、被动属性覆盖、null、forced空／重复／越界、added。forced优先于null；目前Godot序列尚无forced/added操作，本模块仅收显式行动上下文，不新造全局槽。
- 队伍参照真实五槽出战表与后备成员；1834即便敌人攻击也查询我方队伍，按死亡状态而非裸HP计数。生产行动上下文显式给actors，预览兜底只读已解析battle_slots/actors，不初始化真实对象。
- 2544／2545测量保留但仍js：YEP_WeaponUnleash.isAttack()依赖_replaceAttackSkillId缓存与states顺序的Replace Attack（冻结插件replaceAttackSkillId已只扫states）。技能1与替换12相互切换时isAttack真假相反，不能用id==1代替；完整移植须普攻选择／计数／反击／预览共用基础入口并核缓存生命周期，当前actor.gd禁改，交后续规则车道。
- 初次原版测量失败为夹具跨Node/window数组域，导致_states.contains不存在，改用w.eval构造数组后通过；随后发现两槽表被YEP自动重建，补足五槽再测native-v3。首个边界测试失败是对2711替换不存在的数字1，变体没有变化，修成改0.2；生产白名单未为这些失败放宽。原日志全部保留。
- 代码已写，翻译边界7项通过；Godot专项尚待验收，不按完成登记。
