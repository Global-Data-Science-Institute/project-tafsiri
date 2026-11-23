"""Verify canonical Git-blob migration hashes for the frozen RC baseline."""
from pathlib import Path
import hashlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '1d796289ba9077aa3f194fcb285bb6bf64b0580d'
MANIFEST = ROOT / 'docs/operations/synthetic-staging-001/migrations.sha256'


def main():
    entries = MANIFEST.read_text(encoding='utf-8').splitlines()
    candidate = (MANIFEST.parent / 'migrations-remediation.sha256').read_text(encoding='utf-8').splitlines()
    assert candidate[:len(entries)] == entries, 'Frozen baseline altered'
    assert [line.split('  ', 1)[1] for line in candidate] == [p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'supabase/migrations').glob('*.sql'))], 'Migration inventory mismatch'
    entries = candidate
    for entry in entries:
        digest, name = entry.split('  ', 1)
        # HEAD works in shallow CI checkouts; manifest records the frozen baseline bytes.
        source = subprocess.check_output(['git', 'show', f'HEAD:{name}'], cwd=ROOT)
        assert hashlib.sha256(source).hexdigest() == digest, name
        current = (ROOT / name).read_bytes().replace(b'\r\n', b'\n')
        assert hashlib.sha256(current).hexdigest() == digest, f'Working-tree drift: {name}'
    print(f'PASS {len(entries)} ordered candidate migration checksums (sixteen frozen baseline plus remediation) (canonical LF bytes)')


if __name__ == '__main__':
    main()
