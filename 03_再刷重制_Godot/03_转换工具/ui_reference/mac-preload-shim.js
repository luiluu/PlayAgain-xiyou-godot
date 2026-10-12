/* 参照用浏览器垫片：替代需要 Node 的 mac-preload.js。不读写任何文件；存档只会进浏览器自己的 localStorage。 */
(function () {
    var x = new XMLHttpRequest(); x.open('GET', 'package.json', false); x.send();
    var manifest = JSON.parse(x.responseText);
    var win = { title: '', menu: null, on: function () {}, enterFullscreen: function () {}, leaveFullscreen: function () {}, toggleFullscreen: function () {}, isFullscreen: false, showDevTools: function () {}, focus: function () {}, resizeTo: function () {}, moveTo: function () {} };
    window.nw = { App: { manifest: manifest, startPath: '', argv: [], fullArgv: [], dataPath: '', quit: function () {} }, Window: { get: function () { return win; } }, Menu: function () { return { createMacBuiltin: function () {} }; }, Shell: { openExternal: function () {} } };
    window.MacPort = { root: '', save: '', bundle: '', qa: '', log: function () {} };
})();
(function () {
    window.__refErrors = [];
    var t = setInterval(function () {
        if (window.SceneManager && SceneManager.catchException && !SceneManager.__refWrapped) {
            var c = SceneManager.catchException;
            SceneManager.catchException = function (e) { window.__refErrors.push(String(e && e.stack || e)); return c.apply(this, arguments); };
            SceneManager.__refWrapped = true;
        }
    }, 1);
    setTimeout(function () { clearInterval(t); }, 60000);
})();
window.__refShot = function (name) {
    var b = SceneManager.snap();
    var x = new XMLHttpRequest(); x.open('POST', '/__ref_shot/' + name, false); x.send(b._canvas.toDataURL('image/png'));
    return x.status;
};
