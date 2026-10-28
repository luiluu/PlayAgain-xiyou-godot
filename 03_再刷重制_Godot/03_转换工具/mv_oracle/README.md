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
