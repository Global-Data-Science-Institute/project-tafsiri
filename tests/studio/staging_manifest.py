"""Verify canonical Git-blob migration hashes for the frozen RC baseline."""
from pathlib import Path
import hashlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '1d796289ba9077aa3f194fcb285bb6bf64b0580d'
MANIFEST = ROOT / 'docs/operations/synthetic-staging-001/migrations.sha256'


def main():
    entries = MANIFEST.read_text(encoding='utf-8').splitlines()
    for entry in entries:
        digest, name = entry.split('  ', 1)
        # HEAD works in shallow CI checkouts; manifest records the frozen baseline bytes.
        source = subprocess.check_output(['git', 'show', f'HEAD:{name}'], cwd=ROOT)
        assert hashlib.sha256(source).hexdigest() == digest, name
        current = (ROOT / name).read_bytes().replace(b'\r\n', b'\n')
        assert hashlib.sha256(current).hexdigest() == digest, f'Working-tree drift: {name}'
    print(f'PASS {len(entries)} ordered baseline migration checksums (canonical LF bytes)')


if __name__ == '__main__':
    main()
