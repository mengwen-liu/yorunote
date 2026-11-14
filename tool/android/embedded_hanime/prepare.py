
from pathlib import Path
from uuid import uuid4
from zipfile import ZipFile
import hashlib
import json
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
config = Path(__file__).resolve().parent
work = root / '.local-data/build-env'
upstream = root / 'third_party/Han1meViewer-Remastered'
commit = '901a89ca4ebd557bf793d2dd6130b714e22b3109'

def run(args, cwd=root, capture=False):
    env = os.environ.copy()
    if args[:2] == ['git', 'apply']:
        # Apply against the isolated directory even when it is nested in a Git worktree.
        env['GIT_CEILING_DIRECTORIES'] = str(cwd.parent)
    return subprocess.run(args, cwd=cwd, check=True, capture_output=capture, env=env)

def digest(file):
    return hashlib.sha256(file.read_bytes().replace(b'\r\n', b'\n')).hexdigest()

def prepare_pub(cache):
    entries = json.loads((config / 'pub-patches.json').read_text(encoding='utf-8'))
    state = []
    for entry in entries:
        p = cache / entry['path']
        sha = digest(p)
        if sha not in (entry['before'], entry['after']):
            raise SystemExit(f'Unexpected Pub source hash: {entry["path"]} ({sha})')
        state.append(entry['before'] == sha)
    patch = config / 'pub.patch'
    if all(state):
        # Pub packages may contain CRLF. Normalize only the seven verified inputs.
        for entry in entries:
            p = cache / entry['path']
            source = p.read_bytes()
            if b'\r\n' in source:
                p.write_bytes(source.replace(b'\r\n', b'\n'))
        run(['git', 'apply', '--check', str(patch)], cache)
        run(['git', 'apply', str(patch)], cache)
    elif any(state):
        raise SystemExit('Pub cache has mixed patch state. Use a separate pristine PUB_CACHE.')
    for entry in entries:
        if digest(cache / entry['path']) != entry['after']:
            raise SystemExit(f'Pub patch produced an unexpected hash: {entry["path"]}')

def prepare_library():
    head = run(['git', 'rev-parse', 'HEAD'], upstream, True).stdout.decode().strip()
    if head != commit:
        raise SystemExit(f'Submodule must be initialized at {commit}. Found {head}.')
    work.mkdir(parents=True, exist_ok=True)
    dest = work / f'han1me-{uuid4().hex[:12]}'
    dest.mkdir()
    archive = dest / 'source.zip'
    with archive.open('wb') as stream:
        subprocess.run(['git', 'archive', '--format=zip', commit,
         '--', '.', ':(exclude)app/keystore'], cwd=upstream, stdout=stream, check=True)
    with ZipFile(archive) as z:
        if any('/keystore/' in p or p.lower().endswith(('.jks', '.p12', '.pfx')) for p in z.namelist()):
            raise SystemExit('Signing file in upstream source archive')
        z.extractall(dest)
    archive.unlink()
    patch = config / 'han1meviewer.patch'
    run(['git', 'apply', '--check', str(patch)], dest)
    run(['git', 'apply', str(patch)], dest)
    sdk = Path(os.environ['ANDROID_HOME']).as_posix()
    (dest / 'local.properties').write_text(f'sdk.dir={sdk}\n', encoding='utf-8')
    print(dest, flush=True)

if sys.argv[1:] == ['library']:
    prepare_library()
elif len(sys.argv) == 3 and sys.argv[1] == 'pub':
    prepare_pub(Path(sys.argv[2]).resolve(strict=True))
else:
    raise SystemExit('Use prepare.py library or prepare.py pub <isolated PUB_CACHE>')
