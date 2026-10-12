// 【Claude·未经Codex检验】复制自再刷西游 Louis/rpg-maker-mac/strength-recheck-20261010-210743/sim/hboot.cjs
// （源 SHA256 de6f861e1bfcd7604dfcb16327c137c3b202bb6d5186fd8c714872ed5cbaf5b0），新增文件系统守卫：
// 写入只限 opts.sandbox 与调用方显式给出的 opts.allowWrite 目录；屏蔽真实存档/作者钥匙/Application Support。
// 无画面完整引擎：按 index.html 顺序加载引擎、全部启用插件与 Codex 模块。
// 渲染、音频只给占位；Game_*、BattleManager、DataManager 与插件逻辑都是工程原文件。
'use strict';
const {JSDOM, VirtualConsole} = require('jsdom');
const fs = require('fs'), path = require('path'), zlib = require('zlib');


const ORACLE_DIR = __dirname;
function installGuard(root, sandbox, allow) {
  if (fs.__oracleGuard) { Object.assign(fs.__oracleGuard, {root, sandbox, allow}); return; }
  const g = fs.__oracleGuard = {root, sandbox, allow};
  const inside = (p, base) => { const r = path.relative(base, path.resolve(String(p))); return r === '' || (!r.startsWith('..') && !path.isAbsolute(r)); };
  const blocked = p => /Application Support|codex_author_key|\/save\//.test(path.resolve(String(p))) && !inside(p, g.sandbox);
  const canWrite = p => typeof p === 'number' || inside(p, g.sandbox) || g.allow.some(d => inside(p, d));
  for (const k of ['writeFileSync', 'appendFileSync', 'mkdirSync', 'renameSync', 'unlinkSync', 'rmSync', 'rmdirSync', 'copyFileSync', 'openSync', 'writeFile', 'appendFile', 'mkdir', 'rename', 'unlink', 'rm']) {
    const orig = fs[k]; if (typeof orig !== 'function') continue;
    fs[k] = function(p, flags) {
      const isOpen = k === 'openSync';
      const writing = !isOpen || /[wa+]/.test(String(flags || 'r'));
      if (writing && !canWrite(p)) throw new Error('oracle guard: write blocked ' + p);
      if (blocked(p)) throw new Error('oracle guard: blocked ' + p);
      return orig.apply(this, arguments);
    };
  }
  for (const k of ['readFileSync', 'readdirSync', 'existsSync', 'statSync']) {
    const orig = fs[k];
    fs[k] = function(p) {
      if (typeof p !== 'number' && blocked(p)) { if (k === 'existsSync') return false; throw new Error('oracle guard: read blocked ' + p); }
      return orig.apply(this, arguments);
    };
  }
}

function deepNoop() {
  const f = function() {};
  const p = new Proxy(f, {
    get: (o, k) => k === Symbol.toPrimitive ? (() => 0) : k === 'then' ? undefined : k === 'length' ? 0 : p,
    apply: () => undefined, construct: () => p, set: () => true
  });
  return p;
}

function boot(root, opts = {}) {
  root = path.resolve(root);
  const sandbox = path.resolve(opts.sandbox || path.join(ORACLE_DIR, '.sandbox'));
  fs.mkdirSync(sandbox, {recursive: true});
  installGuard(root, sandbox, (opts.allowWrite || []).map(d => path.resolve(d)));
  const errors = [];
  const vc = new VirtualConsole();
  vc.on('jsdomError', e => errors.push(String(e && e.message || e)));
  if (opts.verbose) vc.sendTo(console, {omitJSDOMErrors: true});
  const dom = new JSDOM('<!DOCTYPE html><html><head></head><body></body></html>',
    {runScripts: 'outside-only', pretendToBeVisual: true, url: 'file://' + root + '/index.html', virtualConsole: vc});
  const w = dom.window;
  // ---- 宿主环境占位 ----
  function ctxProxy(canvas) {
    const store = {canvas, globalAlpha: 1, font: '', fillStyle: '#000', strokeStyle: '#000', lineWidth: 1, textAlign: 'left',
      textBaseline: 'alphabetic', globalCompositeOperation: 'source-over', imageSmoothingEnabled: true};
    return new Proxy(store, {
      get(o, k) {
        if (k in o) return o[k];
        if (k === 'measureText') return t => ({width: String(t).length * Math.max(1, parseInt(o.font) || 28) * 0.6});
        if (k === 'getImageData' || k === 'createImageData') return (a, b, c, d) => {
          let ww = k === 'createImageData' ? a : c, hh = k === 'createImageData' ? b : d;
          ww = Math.max(1, ww | 0); hh = Math.max(1, hh | 0);
          return {data: new Uint8ClampedArray(ww * hh * 4), width: ww, height: hh};
        };
        if (/^create(Linear|Radial)Gradient$|^createPattern$/.test(k)) return () => ({addColorStop() {}});
        return function() {};
      },
      set(o, k, v) { o[k] = v; return true; }
    });
  }
  w.HTMLCanvasElement.prototype.getContext = function(t) { if (t === '2d') { if (!this.__ctx) this.__ctx = ctxProxy(this); return this.__ctx; } return null; };
  w.HTMLCanvasElement.prototype.toDataURL = () => 'data:,';
  w.HTMLMediaElement.prototype.play = function() { return Promise.resolve(); };
  w.HTMLMediaElement.prototype.pause = function() {};
  w.HTMLMediaElement.prototype.load = function() {};
  w.require = require; w.process = process; w.Buffer = Buffer;
  const fakeWin = {menu: null, on() {}, removeAllListeners() {}, showDevTools() {}, maximize() {}, enterFullscreen() {},
    leaveFullscreen() {}, toggleFullscreen() {}, isFullscreen: false, setPosition() {}, resizeTo() {}, moveTo() {}, focus() {},
    close() {}, x: 0, y: 0, width: 1280, height: 720, title: ''};
  w.nw = {App: {startPath: root, argv: [], dataPath: sandbox, quit() {}, manifest: JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'))},
    Window: {get: () => fakeWin}, Menu: function() { this.createMacBuiltin = function() {}; this.append = function() {}; },
    MenuItem: function() {}, Shell: {openExternal() {}}, Screen: {Init() {}, screens: [], on() {}}};
  const macroot = opts.macRoot || path.join(sandbox, 'macport');
  fs.mkdirSync(path.join(macroot, 'save'), {recursive: true});
  w.MacPort = {root: macroot, save: path.join(macroot, 'save') + path.sep, bundle: root, qa: '', log() {}};
  w.AudioContext = w.webkitAudioContext = function() { return deepNoop(); };
  w.requestAnimationFrame = () => 0; w.cancelAnimationFrame = () => {};
  w.FontFace = function(name, src) { this.family = name; this.status = 'loaded'; this.load = () => Promise.resolve(this); };
  try { Object.defineProperty(w.document, 'fonts', {value: {add() {}, delete() {}, has: () => true, check: () => true, load: () => Promise.resolve([]), ready: Promise.resolve(), forEach() {}, status: 'loaded'}, configurable: true}); } catch (e) {}
  ['UpperCanvas', 'GameCanvas', 'GameVideo', 'ErrorPrinter'].forEach(id => {
    const c = w.document.createElement(id === 'GameVideo' ? 'video' : id === 'ErrorPrinter' ? 'p' : 'canvas');
    c.id = id; w.document.body.appendChild(c);
  });
  const loaded = [];
  function run(rel, src) {
    if (src === undefined) src = fs.readFileSync(path.join(root, rel), 'utf8');
    if (process.env.HB_TRACE) fs.writeSync(2, '> ' + rel + '\n');
    try { w.eval(src + '\n//# sourceURL=' + rel); loaded.push(rel); }
    catch (e) { e.message = rel + ': ' + e.message; if (opts.tolerant) errors.push(e.message); else throw e; }
  }
  // ---- 按 index.html 顺序 ----
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const scripts = [...html.matchAll(/<script[^>]*src="([^"]+)"/g)].map(m => m[1]);
  for (const rel of scripts) {
    if (rel === 'js/mac-preload.js') continue; // MacPort 已占位
    if (rel === 'js/main.js') break;
    if (rel === 'js/rpg_core.js') {
      run(rel);
      // 画面尺寸在 SceneManager.initGraphics 中设置；这里直接给值。
      w.eval("Graphics._width=1280;Graphics._height=720;Graphics._boxWidth=1280;Graphics._boxHeight=720;Graphics._renderer=null;Graphics.frameCount=0;Graphics._canvas=document.getElementById('GameCanvas');Graphics._upperCanvas=document.getElementById('UpperCanvas');");
      continue;
    }
    if (rel === 'js/rpg_managеrs.js') {
      run(rel);
      // 数据库同步读取
      w.__readData = (src) => fs.readFileSync(path.join(root, 'data', src), 'utf8');
      w.__sandboxSave = path.join(sandbox, 'save') + path.sep;
      fs.mkdirSync(w.__sandboxSave, {recursive: true});
      w.eval("StorageManager.localFileDirectoryPath=function(){return window.__sandboxSave;};");
      w.eval("DataManager.loadDataFile=function(name,src){var t;try{t=window.__readData(src);}catch(e){window[name]=null;return;}window[name]=JSON.parse(t);DataManager.onLoad(window[name]);};");
      continue;
    }
    if (rel === 'js/plugins.js') {
      run(rel);
      // 插件同步加载
      w.__readPlugin = (name) => fs.readFileSync(path.join(root, 'js/plugins', name), 'utf8');
      w.__runPlugin = (name) => run('js/plugins/' + name, w.__readPlugin(name));
      w.eval("PluginManager.loadScript=function(name){window.__runPlugin(name);};");
      w.eval('PluginManager.setup($plugins);');
      continue;
    }
    run(rel);
  }
  if (w.$ && w.$.toaster) w.$.toaster = function() {};
  // ---- main.js：只取模块安装序列，不启动 SceneManager ----
  const main = fs.readFileSync(path.join(root, 'js/main.js'), 'utf8');
  const head = main.slice(0, main.indexOf('  function tryStart() {'));
  const a = main.indexOf('    try {', main.indexOf('  function tryStart() {'));
  const b = main.indexOf('    } catch (error) {', a);
  const block = main.slice(a + '    try {'.length, b);
  run('js/main.js[install]', head.replace("  'use strict';", "  'use strict';") + block + '\n})();');
  if (w.$ && w.$.toaster) w.$.toaster = function() {};
  // ---- 音频：全部静音占位 ----
  w.eval("['AudioManager','SoundManager'].forEach(function(n){var o=window[n];Object.getOwnPropertyNames(o).forEach(function(k){if(typeof o[k]==='function')o[k]=function(){};});});WebAudio.initialize=function(){return false;};");
  // ---- 数据库 ----
  w.eval('DataManager.loadDatabase();');
  const dbOk = w.eval('DataManager.isDatabaseLoaded()');
  if (opts.log !== false) console.error(JSON.stringify({scripts: loaded.length, db: dbOk,
    modules: w.CodexRuntime ? w.CodexRuntime.status().filter(m => m.state !== 'installed').map(m => m.name + ':' + m.state + ':' + m.error) : 'none',
    errors: errors.slice(0, 20)}));
  return {window: w, errors, loaded};
}

function decodeFile(file) {
  const d = fs.readFileSync(file, 'utf8'), P = '@@__YUH_SAVEPRO__@@';
  if (d.startsWith(P)) return zlib.inflateSync(Buffer.from(Buffer.from(d.slice(P.length), 'base64').toString('latin1'), 'latin1')).toString('utf8');
  return require('lz-string').decompressFromBase64(d);
}
function loadConfig(w, file) { w.ConfigManager.applyData(w.JSON.parse(decodeFile(file))); }
function loadSave(w, file) {
  const cfg = path.join(path.dirname(file), 'config.rpgsave');
  if (fs.existsSync(cfg)) loadConfig(w, cfg);
  const contents = w.JsonEx.parse(decodeFile(file));
  w.DataManager.createGameObjects();
  w.DataManager.extractSaveContents(contents);
  try { w.DataManager.loadMapData(w.$gameMap.mapId()); } catch (e) {}
  if (!w.$dataMap) w.$dataMap = {displayName: '', encounterList: [], events: [], data: [], width: 1, height: 1, note: '', meta: {}};
  return contents;
}
module.exports = {boot, loadSave, loadConfig, decodeFile, deepNoop};
if (require.main === module) {
  const t = Date.now();
  const r = boot(process.argv[2], {tolerant: true});
  console.log('boot ms', Date.now() - t, 'loaded', r.loaded.length, 'errors', r.errors.length);
  process.exit(0);
}
