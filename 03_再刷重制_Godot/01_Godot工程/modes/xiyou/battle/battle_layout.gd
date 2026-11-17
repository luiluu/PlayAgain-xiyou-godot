class_name XBattleLayout
extends RefCounted
## 【cc·天启篇】T126 战斗站位撑开（Kyo 2026-11-17「现在界面可视范围很大。boss 和角色站位再优化一下」）：
## 原版站位（敌群编辑器坐标、我方阵型 XPartyFormation）整体挤在画面中间一小块（敌人 x 94～430、我方 x 669～819），
## 新界面 HUD 收到四周后中部大片空着。这里在原版坐标之上再做一次「撑开＋放大」，首领战与小怪战各一套（Kyo 11-17 挑定：
## 首领战用出样 A 版、小怪战用 B 版；首领退到左边 Kyo 圈的位置；我方集体往右后退，拉开与敌人的距离）：
## - 我方脚底：以阵型原版中心 ACTOR_SRC 为基准，按 actor_spread 拉开后移到 actor_center；身体放大 actor_mul。
## - 敌群：整群外框按 enemy_spread 拉开、但收在 enemy_rect（脚底范围）里，外框中心对 enemy_rect 中心（8 只怨念之魂那种本来就散的不再拉）。
## - 敌人图大小差很多（嘤嘤怪、Q 版首领 40～60 高，狼、沉沦魔原图就 100～200 高）：放大到 enemy_mul 但显示高不超过 enemy_cap，
##   已经超过的不缩小（照原版大小）。
## - 首领战（敌群只有一名成员）：首领不照原版坐标，站到 solo 点，倍数与封顶换成 solo_mul／solo_cap。
## 只改站位（home）与身体缩放，技能动画、受击、伤害数字都跟着精灵位置与高度走（XBattlerSprite.width／height 已含放大）；
## 行动序列里按像素写的位移距离（冲到目标前方多少像素）没跟着放大。
## 原版竖排（设置页「战斗站位」选原版竖排）不撑开、不放大我方，只撑开敌人。
## 只在天启篇新界面（XUiSkin.on()）生效：西游档／设置页选原版界面时照原版站位与大小（小A 核查 R2：旧侧栏、旧指令窗、O-473 阵型都按原版坐标留位）。
## 回退：ENABLED＝false 回到原版站位与大小。

static var ENABLED := true

## 我方两排错开 4 人点位 (669..819, 280..580) 的中心（原版坐标、1280×720 画面）
const ACTOR_SRC := Vector2(744.0, 430.0)

## 参数（脚底坐标、1280×720）：
## HUD 占位：顶部首领血弧＋名字＋状态胶囊 y≤215（x 350～930）；右上队伍栏 x≥975、y≤250；左下行动条 y≥610（x≤560）。
## 我方 4 人两排：首领战 前排 x 822、后排 x 1017，小怪战 前排 x 811、后排 x 1029；脚底 y 330～600（上排在队伍栏下面）。
## 首领点 (215, 470)：Kyo 在首领战截图上圈的地面（800×450 图上约 (132, 283)，合 1280×720 的 (211, 453)），脚底略往下压一点站在圈里。
## 敌人脚底右边到 540 左右（狼一类朝右的图身体往右伸 100 多）。
const BOSS := {"actor_mul": 1.6, "actor_center": Vector2(920, 465), "actor_spread": Vector2(1.3, 0.9),
	"solo_mul": 2.2, "solo_cap": 260.0, "solo": Vector2(215, 470)}
const MOB := {"actor_mul": 1.9, "actor_center": Vector2(920, 465), "actor_spread": Vector2(1.45, 0.9),
	"enemy_mul": 1.8, "enemy_cap": 170.0, "enemy_rect": Rect2(120, 335, 420, 270), "enemy_spread": Vector2(1.5, 1.5)}


## solo＝本场敌群只有一名成员（首领战）
static func spec(solo: bool) -> Dictionary:
	if not ENABLED or not XUiSkin.on():
		return {}
	return BOSS if solo else MOB


## 原版竖排不放大我方（同一列上下间隔按 72 高留的，放大就叠在一起）
static func actor_mul(solo: bool) -> float:
	if XPartyFormation.current() == XPartyFormation.COLUMN:
		return 1.0
	return float(spec(solo).get("actor_mul", 1.0))


## 敌人放大倍数：h＝原版大小时的显示高；放大后不超过封顶，原本就超过的保持 1 倍
static func enemy_factor(h: float, solo: bool) -> float:
	var s := spec(solo)
	if s.is_empty() or h <= 0.0:
		return 1.0
	var mul := float(s.solo_mul if solo else s.enemy_mul)
	var cap := float(s.solo_cap if solo else s.enemy_cap)
	return clampf(cap / h, 1.0, mul)


## 敌群撑开的变换：points＝全体成员原版脚底（含隐藏的，之后出现也按同一变换）。返回 {src, dst, k}，空＝不撑开（首领战不用）
static func enemy_fit(points: Array) -> Dictionary:
	var s := spec(false)
	if s.is_empty() or points.is_empty():
		return {}
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	var r: Rect2 = s.enemy_rect
	var sp: Vector2 = s.enemy_spread
	var k := Vector2(
		minf(sp.x, r.size.x / box.size.x) if box.size.x > 0.0 else sp.x,
		minf(sp.y, r.size.y / box.size.y) if box.size.y > 0.0 else sp.y)
	return {"src": box.get_center(), "dst": r.get_center(), "k": Vector2(maxf(k.x, 1.0), maxf(k.y, 1.0))}


## 敌人脚底：原版坐标 → 撑开后；首领战站首领点
static func enemy_home(p: Vector2, fit: Dictionary, solo: bool) -> Vector2:
	var s := spec(solo)
	if s.is_empty():
		return p
	if solo:
		return s.solo
	if fit.is_empty():
		return p
	return (fit.dst + (p - fit.src) * fit.k).round()


## 我方脚底：阵型点位 → 撑开后（原版竖排不撑开）
static func actor_home(p: Vector2, solo: bool) -> Vector2:
	var s := spec(solo)
	if s.is_empty() or XPartyFormation.current() == XPartyFormation.COLUMN:
		return p
	return (s.actor_center + (p - ACTOR_SRC) * s.actor_spread).round()


static func actor_points(points: Array, solo: bool) -> Array:
	return points.map(func(p): return actor_home(p, solo))
