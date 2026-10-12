#!/usr/bin/env python3
"""Read the Steam original through the running PD VM; never write or launch games."""
import argparse
import base64
import json
from pathlib import Path, PureWindowsPath
import subprocess

LIBRARY = Path(__file__).resolve().parents[3]
PRLCTL = '/Applications/Parallels Desktop.app/Contents/MacOS/prlctl'
DEFAULT_VM = '{41b9e50d-7445-4a97-98b8-6fca401302fa}'
DEFAULT_GAME = r'C:\Program Files (x86)\Steam\steamapps\common\再刷一把 PlayAgain'


def settings():
    source = json.loads((LIBRARY / '00_项目管理/来源登记.json').read_text())
    source = next(s for s in source['sources'] if s['id'] == 'steam_playagain_original')
    access = source.get('access', {})
    return access.get('vmUuid', DEFAULT_VM), access.get('windowsGamePath', DEFAULT_GAME)


def ps_literal(text):
    return "'" + str(text).replace("'", "''") + "'"


def relative_path(text):
    p = PureWindowsPath(text or '.')
    if p.is_absolute() or p.drive or p.root or '..' in p.parts:
        raise ValueError('Only relative paths within the original game are allowed')
    if any(part.lower() in {'save', 'saves', 'app_userdata'} for part in p.parts):
        raise ValueError('Player save directories are excluded')
    if p.suffix.lower() in {'.rpgsave', '.sav', '.save'}:
        raise ValueError('Player save files are excluded')
    return str(p)


def call_vm(code, timeout=60):
    vm, _ = settings()
    prefix = "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new(); $ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'; "
    encoded = base64.b64encode((prefix + code).encode('utf-16le')).decode('ascii')
    result = subprocess.run(
        [PRLCTL, 'exec', vm, 'powershell.exe', '-NoProfile', '-NonInteractive',
         '-EncodedCommand', encoded], capture_output=True, text=True,
        encoding='utf-8', errors='replace', timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    try:
        return json.loads(result.stdout.strip().lstrip('\ufeff'))
    except json.JSONDecodeError as error:
        raise RuntimeError('PD did not return valid JSON') from error


def status():
    _, game = settings()
    manifest = str(PureWindowsPath(game).parents[1] / 'appmanifest_2059790.acf')
    code = "$g=" + ps_literal(game) + "; $m=" + ps_literal(manifest) + "; "
    code += r"""
    $t=if(Test-Path -LiteralPath $m){[IO.File]::ReadAllText($m,[Text.Encoding]::UTF8)}else{''};
    function field([string]$n){return [regex]::Match($t,'"'+$n+'"\s+"([^"]*)"').Groups[1].Value};
    [ordered]@{gameExists=[bool](Test-Path -LiteralPath $g); manifestExists=[bool](Test-Path -LiteralPath $m);
      appId=[string](field 'appid'); buildId=[string](field 'buildid'); name=[string](field 'name');
      stateFlags=[string](field 'StateFlags'); depotManifest=[string](field 'manifest');
      gamePath=[string]$g; manifestPath=[string]$m;
      files=@(Get-ChildItem -LiteralPath $g | ForEach-Object {[string]$_.Name})} | ConvertTo-Json -Compress -Depth 4
    """
    return call_vm(code)


def list_files(relative=''):
    _, game = settings()
    path = str(PureWindowsPath(game) / relative_path(relative))
    code = "$p=" + ps_literal(path) + "; "
    code += r"""@{path=[string]$p; entries=@(Get-ChildItem -LiteralPath $p | ForEach-Object {
      @{name=[string]$_.Name; directory=[bool]$_.PSIsContainer; bytes=$(if($_.PSIsContainer){$null}else{[long]$_.Length})}
    })} | ConvertTo-Json -Compress -Depth 4"""
    return call_vm(code)


def read_file(relative, max_bytes=16 * 1024 * 1024):
    _, game = settings()
    path = str(PureWindowsPath(game) / relative_path(relative))
    code = "$p=" + ps_literal(path) + "; $limit=" + str(int(max_bytes)) + "; "
    code += r"""$f=Get-Item -LiteralPath $p; if($f.PSIsContainer -or $f.Length -gt $limit){throw 'File exceeds read limit or is a directory'};
    $b=[IO.File]::ReadAllBytes($p); $sha=[Security.Cryptography.SHA256]::Create();
    try {$h=[BitConverter]::ToString($sha.ComputeHash($b)).Replace('-','').ToLowerInvariant()} finally {$sha.Dispose()};
    @{path=[string]$p; bytes=[long]$b.Length; sha256=[string]$h; contentBase64=[Convert]::ToBase64String($b)} | ConvertTo-Json -Compress
    """
    return call_vm(code)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['status', 'list', 'read'])
    parser.add_argument('relative', nargs='?', default='')
    args = parser.parse_args()
    if args.action == 'status':
        result = status()
    elif args.action == 'list':
        result = list_files(args.relative)
    else:
        if not args.relative:
            parser.error('read requires a relative file path')
        result = read_file(args.relative)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
