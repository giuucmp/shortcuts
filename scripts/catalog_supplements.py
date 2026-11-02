"""Reproducible desktop additions, separate from Claude Code's CLI key map."""
import hashlib
import json
from pathlib import Path
from key_parser import parse
from category_classifier import classify

DESKTOP_SOURCE = 'https://code.claude.com/docs/en/desktop#keyboard-shortcuts'
DESKTOP = [
    ('Mostra scorciatoie', 'Command+/', None),
    ('Nuova sessione', 'Command+N', None),
    ('Nuovo ambiente', 'Command+Option+0', 'Nella schermata nuova sessione'),
    ('Chiudi sessione', 'Command+W', None),
    ('Sessione successiva', 'Control+Tab', None),
    ('Sessione precedente', 'Control+Shift+Tab', None),
    ('Sessione successiva', 'Command+Shift+]', None),
    ('Sessione precedente', 'Command+Shift+[', None),
    ('Interrompi la risposta', 'Escape', 'Durante una risposta'),
    ('Accetta il prompt suggerito', 'Tab', 'Con un suggerimento nel campo vuoto'),
    ('Accetta il prompt suggerito', 'Right', 'Con un suggerimento nel campo vuoto'),
    ('Mostra o nascondi modifiche', 'Command+Shift+D', None),
    ('Mostra o nascondi browser', 'Command+Shift+B', None),
    ('Seleziona elemento nel browser', 'Command+Shift+S', 'Browser integrato attivo'),
    ('Mostra o nascondi terminale', 'Control+`', None),
    ('Chiudi riquadro attivo', 'Command+\\', None),
    ('Estrai sessione dalla vista divisa', 'Command+Control+W', 'Con sessioni affiancate'),
    ('Apri chat laterale', 'Command+;', None),
    ('Cambia modalità di visualizzazione', 'Control+O', None),
    ('Scegli modalità permessi', 'Command+Shift+M', None),
    ('Scegli modello', 'Command+Shift+I', None),
    ('Scegli livello di ragionamento', 'Command+Shift+E', None),
] + [('Seleziona ambiente '+str(i), 'Command+Option+'+str(i), 'Nella schermata nuova sessione') for i in range(1, 10)] + [
    ('Scegli voce '+str(i)+' nel menu', str(i), 'Con un menu aperto') for i in range(1, 10)
]
# Exact accelerator/label pairs read from the installed Claude 4.4212.0 app.asar
# menu definitions on 2026-11-02. No user configuration or conversation data.
COMMON = [
    ('Impostazioni', 'Command+,'), ('Esci da Claude', 'Command+Q'),
    ('Copia', 'Command+C'), ('Incolla', 'Command+V'), ('Taglia', 'Command+X'),
    ('Incolla e adatta lo stile', 'Command+Option+Shift+V'),
    ('Seleziona tutto', 'Command+A'), ('Annulla', 'Command+Z'), ('Ripristina', 'Command+Shift+Z'),
    ('Cerca', 'Command+F'), ('Risultato successivo', 'Command+G'), ('Risultato precedente', 'Command+Shift+G'),
    ('Tavolozza comandi', 'Command+K'), ('Mostra o nascondi barra laterale', 'Command+B'),
    ('Zoom avanti', 'Command++'), ('Zoom avanti', 'Command+='), ('Zoom indietro', 'Command+-'),
    ('Dimensioni originali', 'Command+0'), ('Attiva o disattiva schermo intero', 'Command+Control+F'),
]

def supplement(profiles, records):
    records[:] = [row for row in records if not row['id'].startswith('claude:desktop:')]
    for title, binding, extra in DESKTOP:
        _add(records, title, binding, 'Nella sezione Code' + (' · '+extra if extra else ''), DESKTOP_SOURCE)
    for title, binding in COMMON:
        _add(records, title, binding, None, None)
    profiles['claude']['name'] = 'Claude · app desktop'
    profiles['claude']['note'] = 'Comandi comuni e sezione Code dell’app desktop. I comandi CLI hanno un profilo separato. Se la sezione attiva non è esposta, i comandi Code restano indicati come condizionali. Copertura non certificata.'
    profiles['claude']['sources'] = [DESKTOP_SOURCE]

def _add(records, title, binding, context, source):
    strokes = parse(binding)
    assert strokes, (title, binding)
    identity = hashlib.sha256((title+'|'+binding).encode()).hexdigest()[:16]
    category = classify(title)
    if 'sessione' in title.lower() or title == 'Chiudi riquadro attivo': category = 'Finestre e schede'
    if 'ambiente' in title: category = 'Organizzare'
    if title.startswith(('Scegli modalità', 'Scegli modello', 'Scegli livello')): category = 'Sviluppare e debuggare'
    if title.startswith('Scegli voce'): category = 'Scegliere e confermare'
    if title == 'Mostra scorciatoie': category = 'Aiuto e riferimenti'
    if title == 'Cambia modalità di visualizzazione': category = 'Vista'
    if title.startswith(('Interrompi la risposta', 'Accetta il prompt')): category = 'Chat'
    records.append(dict(id='claude:desktop:'+identity, profile='claude', title=title,
        category=category, strokes=strokes, context=context, section='Code' if context else 'App',
        source='catalog', sourceURL=source or 'file:///Applications/Claude.app/Contents/Resources/app.asar#4.4212.0', actionID=None, enabled=None,
        note=None, rawBinding=None))

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    path = root/'Sources/ShortcutCore/Resources/catalog.json'
    catalog = json.loads(path.read_text())
    profiles = {p['id']: p for p in catalog['profiles']}
    supplement(profiles, catalog['shortcuts'])
    catalog['profiles'] = sorted(profiles.values(), key=lambda p:p['name'])
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
    coverage = []
    for p in catalog['profiles']:
        rows = [r for r in catalog['shortcuts'] if r['profile'] == p['id']]
        coverage.append(dict(id=p['id'],name=p['name'],records=len(rows),parsed=sum(bool(r['strokes']) for r in rows),unparsed=sum(not r['strokes'] for r in rows),liveVerified=False,note=p['note']))
    prior = json.loads((root/'docs/coverage.json').read_text())
    order = {r['id']: i for i, r in enumerate(prior)}
    coverage.sort(key=lambda r: order.get(r['id'], len(order)))
    (root/'docs/coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2))
    print('Claude desktop:', len([r for r in catalog['shortcuts'] if r['profile']=='claude']), 'records')
