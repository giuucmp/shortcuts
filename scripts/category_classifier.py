"""The same action-only rules used by the live Swift menu reader."""
import json,re
from pathlib import Path
_rules=json.loads((Path(__file__).resolve().parents[1]/'Sources/ShortcutCore/Resources/category-rules.json').read_text())
_compiled=[(r['name'],re.compile(r['pattern'],re.I)) for r in _rules]
def classify(title):
    action=title.split(' (',1)[0]
    action=re.sub(r'([a-z])([A-Z])',r'\1 \2',action)
    return next((name for name,pattern in _compiled if pattern.search(action)),'Altri comandi')
