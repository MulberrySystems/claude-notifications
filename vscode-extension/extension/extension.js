// Focus the integrated terminal whose shell pid is in the request.
// Primary signal: ~/.claude/terminal-focus-request.json, written by the click script and watched
// by every window; the window owning a terminal with a matching shell pid shows it. The
// vscode://mulberrysystems.claude-terminal-focus/focus?pids=1,2&name=... URI and window focus changes
// re-check the same file. Each window records its root, folders and terminal shell pids under
// its extension-host pid in ~/.claude/vscode-windows.json and injects CLAUDE_VSCODE_ROOT into its
// terminals, so the click script can raise the right window with `code <root>`. The entry also
// says whether the window has focus and which terminal is active, so the hook can skip the
// notification when the user is already looking at that terminal.
const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

const DIR = path.join(os.homedir(), '.claude');
const REQUEST = path.join(DIR, 'terminal-focus-request.json');
const WINDOWS = path.join(DIR, 'vscode-windows.json');
const LOG = path.join(DIR, 'terminal-focus.log');
const MAX_AGE_MS = 20000;

function log(msg) {
  try {
    if (fs.existsSync(LOG) && fs.statSync(LOG).size > 200000) fs.truncateSync(LOG, 0);
    fs.appendFileSync(LOG, `${new Date().toISOString()} [${process.pid}] ${msg}\n`);
  } catch {}
}

function alive(pid) { try { process.kill(pid, 0); return true; } catch { return false; } }

let last = '';
async function registerWindow(context) {
  const ws = vscode.workspace.workspaceFile;
  const folders = (vscode.workspace.workspaceFolders || []).filter((f) => f.uri.scheme === 'file').map((f) => f.uri.fsPath);
  const root = ws && ws.scheme === 'file' ? ws.fsPath : folders[0];
  const terminals = await Promise.all(vscode.window.terminals.map(async (t) => ({ pid: await t.processId, name: t.name })));
  const pids = terminals.map((t) => t.pid).filter(Boolean);
  const a = vscode.window.activeTerminal;
  const active = a ? { pid: await a.processId, name: a.name } : null;
  const entry = { root: root || null, folders, pids, terminals, focused: vscode.window.state.focused, active };
  const key = JSON.stringify(entry);
  if (key === last) return;
  last = key;
  let all = {};
  try { all = JSON.parse(fs.readFileSync(WINDOWS, 'utf8')) || {}; } catch {}
  for (const k of Object.keys(all)) { if (!alive(Number(k))) delete all[k]; }
  all[process.pid] = { ...entry, ts: Date.now() };
  try { fs.writeFileSync(WINDOWS, JSON.stringify(all, null, 1)); } catch {}
  if (root) context.environmentVariableCollection.replace('CLAUDE_VSCODE_ROOT', root);
  else context.environmentVariableCollection.delete('CLAUDE_VSCODE_ROOT');
}

// Claude Code prefixes the tab title with a spinner glyph that changes with state; ignore it.
const norm = (s) => (s || '').replace(/^[^\p{L}\p{N}]+/u, '').replace(/\s+/g, ' ').trim().toLowerCase();

async function focus(pids, name) {
  for (const t of vscode.window.terminals) {
    const pid = await t.processId;
    if (pid && pids.includes(pid)) { t.show(false); log(`focused terminal pid ${pid}`); return true; }
  }
  const want = norm(name);
  if (want) {
    const t = vscode.window.terminals.find((t) => norm(t.name) === want)
      || vscode.window.terminals.find((t) => norm(t.name).includes(want) || want.includes(norm(t.name)) && norm(t.name).length > 3);
    if (t) { t.show(false); log(`focused terminal by name "${t.name}" for "${name}"`); return true; }
    log(`names here: ${vscode.window.terminals.map((t) => JSON.stringify(t.name)).join(', ')}`);
  }
  return false;
}

let busy = false;
async function fromFile(why) {
  if (busy) return false;
  busy = true;
  try {
    let req;
    try { req = JSON.parse(fs.readFileSync(REQUEST, 'utf8')); } catch { return false; }
    if (!req || Date.now() - (req.ts || 0) > MAX_AGE_MS) return false;
    log(`${why}: request pids=${(req.pids || []).join(',')} name=${req.name || ''}`);
    const ok = await focus(req.pids || [], req.name);
    if (ok) { try { fs.unlinkSync(REQUEST); } catch {} }
    else log(`${why}: no matching terminal here`);
    return ok;
  } finally { busy = false; }
}

function activate(context) {
  const reg = () => { registerWindow(context).catch((e) => log(`register failed: ${e}`)); };
  reg();
  context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(reg));
  context.subscriptions.push(vscode.window.onDidOpenTerminal(() => setTimeout(reg, 1500)));
  context.subscriptions.push(vscode.window.onDidCloseTerminal(reg));
  context.subscriptions.push(vscode.window.onDidChangeActiveTerminal(reg));
  context.subscriptions.push(vscode.window.onDidChangeWindowState(reg));
  const timer = setInterval(reg, 5000); // tab titles change without an event
  context.subscriptions.push({ dispose: () => clearInterval(timer) });
  context.subscriptions.push(vscode.window.registerUriHandler({
    async handleUri(uri) {
      const q = new URLSearchParams(uri.query);
      const pids = (q.get('pids') || '').split(',').map(Number).filter(Boolean);
      log(`uri pids=${pids.join(',')}`);
      if (!(await focus(pids, q.get('name')))) await fromFile('uri');
    },
  }));
  context.subscriptions.push(vscode.window.onDidChangeWindowState((s) => { if (s.focused) fromFile('focus'); }));
  try {
    const w = fs.watch(DIR, (ev, file) => { if (file === path.basename(REQUEST)) setTimeout(() => fromFile('watch'), 150); });
    context.subscriptions.push({ dispose: () => w.close() });
  } catch (e) { log(`watch failed: ${e}`); }
  fromFile('activate');
  log(`activated root=${vscode.workspace.workspaceFile?.fsPath || (vscode.workspace.workspaceFolders || [])[0]?.uri.fsPath}`);
}

module.exports = { activate, deactivate() {} };
