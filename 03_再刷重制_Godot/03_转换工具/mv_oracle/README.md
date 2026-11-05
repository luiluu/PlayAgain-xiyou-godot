# mv_oracle 探针须知

参照探针（`*_probe.cjs`）在 jsdom 里启动冻结正式源，测完写进 `.sandbox/`，由 `同步正式西游.py` 复制到产物 `oracle/`。只写 `.sandbox/`，不去掉 `fs_guard.cjs` 的文件系统守卫。

## 脚本结尾要显式退出

正式源启动后 jsdom 的计时器（`setInterval`／`requestAnimationFrame` 等）一直挂着，Node 事件循环不会自己结束：
**不写 `process.exit` 的脚本测完也不退出**，前台命令会一直等（八戒期三的临时检查脚本卡了 20 分钟；实测只调
`start()`＋`newGame()` 的脚本 90 秒后仍未退出，加 `process.exit` 后 6 秒结束）。

所有探针与临时检查脚本（`node -e`、自己写的 `inspect.cjs`）最后都这样收：

```js
const ok = finish(host, 'xxx.json', {cases});   // 正式探针
process.exit(ok ? 0 : 1);
```

临时只打印结果的：`console.log(JSON.stringify(result)); process.exit(0);`。出错路径也要退出（`try { … } catch (e) { console.error(e); process.exit(1); }`）。

为什么不改 `shared/host.cjs` 自动退出：`mv_oracle/` 下非探针的 `.cjs`／`.js`／`.json` 都是每个探针缓存键的一部分（`incremental_sync.py` helpers），改它会让下一次同步全部探针整轮重跑；本说明不进缓存键。

## 无头 Chrome 量具（real/）

jsdom 里图不会真加载，「插件之间谁盖谁」（Mx_SuperSV 多帧、运行时静态大图、绘制顺序）量不出来。`real/sprite_real.cjs` 用本机 Playwright 的无头 Chrome 真跑冻结正式源，进一场战斗、按步骤改状态，记指定角色 Sprite_Actor 最终画的图名、大小、帧、缩放、偏移、透明度、武器／影子，可截图：

```bash
node real/sprite_real.cjs real/raven_myth.json   # 产物 .sandbox/sprite_real/raven_myth/（result.json、各步截图）
```

规格写法见脚本开头注释。本地 http 只读地提供冻结正式源，别的主机一律拦掉，只写 `.sandbox/`。`real/` 不进探针缓存公共键（`incremental_sync.py` 排除），加量具、加规格不会让探针整轮重跑；它也不在同步里跑，量完把要对的值写进专项（例：`real/raven_myth.result.json` → `tests/xiyou_raven_visual.gd` 的 `_myth_alpha`）。
