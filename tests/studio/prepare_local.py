"""Prepare an isolated synthetic Supabase stack; never connects to hosted projects."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / '.studio-local' / 'supabase'

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    config = (ROOT / 'supabase/config.toml').read_text(encoding='utf-8')
    config = config.replace('project_id = "project-tafsiri"', 'project_id = "tafsiri-studio-synthetic"')
    config = config.replace('5462', '5562').replace('55520', '55620')
    config = config.replace('sql_paths = ["./seed.sql"]', 'sql_paths = []')
    config = config.replace('http://127.0.0.1:3000', 'http://127.0.0.1:3014')
    import re
    config = re.sub(r'(\[auth\][\s\S]*?enable_signup = )false', r'\g<1>true', config)
    config = re.sub(r'(\[auth.email\][\s\S]*?enable_signup = )false', r'\g<1>true', config)
    (DEST / 'config.toml').write_text(config, encoding='utf-8')
    (DEST / 'migrations').mkdir(exist_ok=True)
    for migration in (ROOT / 'supabase/migrations').glob('*.sql'):
        shutil.copyfile(migration, DEST / 'migrations' / migration.name)
    print('Prepared .studio-local: isolated project tafsiri-studio-synthetic, API 55621, DB 55622; no seed data.')

if __name__ == '__main__':
    main()
