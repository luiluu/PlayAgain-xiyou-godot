# 原版界面参照（浏览器）

用内置浏览器直接运行正式西游 `app.nw` 的网页版，截取原版真实画面，作为 Godot 逐页复现的像素参照。

- `serve.py <app.nw> [截图目录]`：只读服务 127.0.0.1:8766。只允许 GET；拒绝 `save/` 与 `..` 路径段；`js/mac-preload.js` 换成本目录的 `mac-preload-shim.js`（需要 Node 的 Mac 启动脚本在浏览器里无法运行）。唯一的写入是 `POST /__ref_shot/<名字>`，只写截图目录。全部响应 `no-store`，同时允许约 250 个并发脚本请求。
- `mac-preload-shim.js`：提供 `nw`、`MacPort` 的空实现，不读写文件；浏览器模式下存档只进该浏览器自己的 localStorage，不碰真实玩家存档（`StorageManager.isLocalMode()` 为 false）。另提供 `__refShot(名字)`（`SceneManager.snap()` 原尺寸 1280×720 PNG）与 `__refErrors`（场景异常）。
- 使用：后台运行 `python3 -I serve.py "<app.nw>"`，浏览器打开 `http://127.0.0.1:8766/index.html`，视口设 1280×720，启动约 30 秒到标题。用页面内 JS 推进剧情/打开场景后调用 `__refShot`。
- 截图默认写到 `04_验证/本地结果/原版参照/`（不入 Git）。不修改正式应用的任何文件。

- `index.html?battle_ref=1`：战斗验收工具栏，提供四人/五人内存夹具（地图 5、敌群 2）、胜利结算与截图；隔离地图剧情并固定随机值，按钮不会同时确认游戏窗口。运行时读数在折叠栏内。只测界面，不作为真实开局或战斗规则参照。
