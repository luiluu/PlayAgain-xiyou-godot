'use strict';
// 开战／收战转场逐帧读数（八戒 battlefx1）：无头 Chrome（临时用户目录、1280×720、静音）打开 serve.py 的只读服务
// （index.html?map_ref=1），点「一层地图夹具」（内存新局，不读写存档），包住 Scene_Map.update／Scene_Battle.update 逐帧记：
//   enc：Scene_Map.launchBattle 之后每帧的遇敌演出剩余帧、$gameScreen 镜头（缩放与中心）、淡出黑幕不透明度、玩家画面坐标；
//   battle：Scene_Battle 每帧的黑幕不透明度、剩余淡入帧、isBusy；在淡入结束后 pop 回地图，接着记淡出；
//   back：回到 Scene_Map 后前几帧的黑幕。另记 BGM 的停／放（AudioManager.playBgm／stopBgm）与系统音效（playStaticSe）。
// 用法：先 `python3 -I serve.py <冻结 app.nw> <截图目录>`（127.0.0.1:8766），再 `node battle_transition_ref.cjs <输出.json>`。
// 只写给出的输出文件。
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const out = path.resolve(process.argv[2] || 'battle_transition_oracle.json');
const port = Number((process.argv.find(a => a.startsWith('--port=')) || '--port=8766').slice(7));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-btref-'));
const dbg = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

const PROBE = String.raw`(async () => {
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const B = window.__bt = {enc: [], battle: [], back: [], audio: [], phase: ''};
  const frame = () => Graphics.frameCount;
  const pb = AudioManager.playBgm; AudioManager.playBgm = function (b) { if (B.phase) B.audio.push({f: frame(), phase: B.phase, op: 'playBgm', name: b && b.name}); return pb.apply(this, arguments); };
  const sb = AudioManager.stopBgm; AudioManager.stopBgm = function () { if (B.phase) B.audio.push({f: frame(), phase: B.phase, op: 'stopBgm'}); return sb.apply(this, arguments); };
  const ss = AudioManager.playStaticSe; AudioManager.playStaticSe = function (se) { if (B.phase) B.audio.push({f: frame(), phase: B.phase, op: 'playStaticSe', name: se && se.name}); return ss.apply(this, arguments); };
  const mu = Scene_Map.prototype.update;
  Scene_Map.prototype.update = function () {
    mu.call(this);
    if (B.phase !== 'enc' && B.phase !== 'back') return;
    const r = {enc: this._encounterEffectDuration, zoom: $gameScreen.zoomScale(), zoomX: $gameScreen.zoomX(), zoomY: $gameScreen.zoomY(),
      fade: this._fadeSprite ? this._fadeSprite.opacity : null, player: [$gamePlayer.screenX(), $gamePlayer.screenY()],
      spriteset: this._spriteset ? [this._spriteset.x, this._spriteset.y, this._spriteset.scale.x] : null};
    (B.phase === 'enc' ? B.enc : B.back).push(r);
  };
  const bu = Scene_Battle.prototype.update;
  Scene_Battle.prototype.update = function () {
    bu.call(this);
    B.battle.push({fade: this._fadeSprite ? this._fadeSprite.opacity : null, left: this._fadeDuration, busy: this.isBusy(), active: this.isActive()});
  };
  B.phase = 'enc';
  BattleManager.setup(2, true, false);
  SceneManager.push(Scene_Battle);
  for (let i = 0; i < 400 && !(SceneManager._scene instanceof Scene_Battle && B.battle.length > 40 && !SceneManager._scene.isBusy()); i++) await sleep(20);
  B.battleIn = B.battle.length;
  B.phase = 'back';
  SceneManager.pop();
  for (let i = 0; i < 400 && !(SceneManager._scene instanceof Scene_Map && B.back.length >= 6); i++) await sleep(20);
  B.phase = '';
  return {enc: B.enc, battle: B.battle, battleIn: B.battleIn, back: B.back, audio: B.audio, errors: window.__refErrors || []};
})()`;

async function connect() {
  for (let i = 0; i < 100; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${dbg}/json/list`)).json();
      const page = list.find(t => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (e) { /* 等 Chrome 起来 */ }
    await sleep(200);
  }
  throw new Error('Chrome 调试端口未就绪');
}

async function main() {
  const ws = new WebSocket(await connect());
  await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
  let id = 0; const wait = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); } };
  const send = (method, params = {}) => new Promise(ok => { const n = ++id; wait.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });
  const evaluate = async (expr, timeout = 120000) => {
    const r = await send('Runtime.evaluate', {expression: expr, awaitPromise: true, returnByValue: true, timeout});
    if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
    return r.result.result.value;
  };
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  await send('Page.enable');
  await send('Page.navigate', {url: `http://127.0.0.1:${port}/index.html?map_ref=1`});
  const ready = expr => evaluate(`(() => { try { return !!(${expr}); } catch (e) { return false; } })()`, 5000);
  for (let i = 0; i < 240 && !(await ready("DataManager.isDatabaseLoaded() && SceneManager._scene && /Title|Splash/.test(SceneManager._scene.constructor.name)")); i++) await sleep(500);
  await sleep(2000);
  await evaluate("[...document.querySelectorAll('button')].find(x => x.textContent == '一层地图夹具').click()");
  for (let i = 0; i < 120 && !(await ready("SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted && $dataMap && $gameMap.mapId() === 5")); i++) await sleep(500);
  await sleep(1500);
  const data = await evaluate(PROBE);
  fs.writeFileSync(out, JSON.stringify(data) + '\n');
  console.log('enc', data.enc.length, 'battle', data.battle.length, 'battleIn', data.battleIn, 'back', data.back.length, 'errors', data.errors.length);
}

main().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  try { chrome.kill('SIGKILL'); } catch (e) { /* 已退出 */ }
  setTimeout(() => { try { fs.rmSync(profile, {recursive: true, force: true}); } catch (e) { /* 留给系统清 */ } process.exit(); }, 500);
});
