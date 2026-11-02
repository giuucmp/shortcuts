#!/usr/bin/env python3
"""Build factual shortcut records from official tables; retain unparsed bindings for review.
Usage: python3 scripts/catalog_builder.py /path/to/downloaded/source/html
The source directory contains index.json with name/url/file entries. No HTML is bundled.
"""
from pathlib import Path
from bs4 import BeautifulSoup
import re,json,hashlib,plistlib,sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '../sources')
out=Path(__file__).resolve().parents[1]
profiles={};records=[];audit=[]

def profile(pid,name,bids=[],parent=None):
 profiles[pid]={'id':pid,'name':name,'bundleIDs':bids,'note':'Catalogo documentato; verifica nella versione installata da completare.','sources':[],'parent':parent}
def slug(s):return re.sub('[^a-z0-9]+','-',s.lower()).strip('-')
from category_classifier import classify
def cat(title,section=''):
 return classify(title)
from key_parser import parse, parse_one

def add(pid,title,binding,url,section='',actionID=None,note=None,context=None,category=None):
 title=' '.join(title.split()).strip('. ')
 binding=' '.join(binding.split()).strip()
 if not title or not binding:return
 if binding.lower() in ['(unbound)','none','n/a','—','-']:return
 # Alternative bindings, keep complex expressions as unresolved rather than guessing.
 alternatives=re.split(r'\s+(?:or|oppure|o)\s+(?=(?:Cmd|Command|Ctrl|Control|Option|Shift|⌘|⌥|⇧|⌃|Esc|F[0-9]|Tab|[A-Z]$))|,\s+(?=(?:Ctrl|Cmd|Escape|Tab|Right|Left|Up|Down|Space|Backspace|Delete|[A-Z](?:,|$)))',binding)
 for b in alternatives:
  qualifier=None
  if pid=='cursor':
   split=re.split(r'\s+(?=when |with |unless )',b,maxsplit=1)
   if len(split)==2:b,qualifier=split
  strokes=parse(b)
  if not strokes:
   suffix=re.fullmatch(r'(.*?)\s+\(([^()]+)\)',b)
   if suffix and parse(suffix.group(1)):
    strokes=parse(suffix.group(1));qualifier=suffix.group(2)
  key=hashlib.sha256((pid+title+b+section).encode()).hexdigest()[:16]
  row={'id':pid+':'+key,'profile':pid,'title':title,'category':category or cat(title,section),'strokes':strokes,'context':context or (section if pid=='claude-code' or (pid=='cursor' and section=='Chat') else None),'section':section or None,'source':'catalog','sourceURL':url,'actionID':actionID,'enabled':None,'note':note or qualifier,'rawBinding':None if strokes else b}
  records.append(row)
  if url not in profiles[pid]['sources']:profiles[pid]['sources'].append(url)

def text(el):
 clone=BeautifulSoup(str(el),'html.parser')
 for img in clone.select('img'):
  a=img.get('alt','').lower();img.replace_with('Command' if 'command' in a else 'Option' if 'option' in a else 'Shift' if 'shift' in a else 'Control' if 'control' in a else '')
 for x in clone.select('.docs-kbd-slot-alt'):x.decompose()
 for switch in clone.select('.switchinline'):
  mac=switch.select_one('.MAC')
  if mac:switch.replace_with(mac.get_text(' ',strip=True))
 return clone.get_text(' ',strip=True)

mapping={
'Apple TV app shortcuts':('tv','TV',['com.apple.TV']), 'App Store shortcuts':('app-store','App Store',['com.apple.AppStore']),
'Calendar shortcuts':('calendar','Calendario',['com.apple.iCal']), 'Contacts shortcuts':('contacts','Contatti',['com.apple.AddressBook']),
'Disk Utility shortcuts':('disk-utility','Utility Disco',['com.apple.DiskUtility']), 'Find My shortcuts':('find-my','Dov’è',['com.apple.findmy']),
'iMovie shortcuts':('imovie','iMovie',['com.apple.iMovieApp']), 'Keynote shortcuts':('keynote','Keynote',['com.apple.iWork.Keynote']),
'Mail shortcuts':('mail','Mail',['com.apple.mail']), 'Maps shortcuts':('maps','Mappe',['com.apple.Maps']),
'Messages shortcuts':('messages','Messaggi',['com.apple.MobileSMS']), 'Music shortcuts':('music','Musica',['com.apple.Music']),
'News shortcuts':('news','News',['com.apple.news']), 'Notes shortcuts':('notes','Note',['com.apple.Notes']),
'Numbers shortcuts':('numbers','Numbers',['com.apple.iWork.Numbers']), 'Pages shortcuts':('pages','Pages',['com.apple.iWork.Pages']),
'Photos shortcuts':('photos','Foto',['com.apple.Photos']), 'Podcasts shortcuts':('podcasts','Podcast',['com.apple.podcasts']),
'Reminders shortcuts':('reminders','Promemoria',['com.apple.reminders']), 'Preview shortcuts':('preview','Anteprima',['com.apple.Preview']),
'Safari shortcuts':('safari','Safari',['com.apple.Safari']), 'Spotlight shortcuts':('spotlight','Spotlight',['com.apple.Spotlight']),
'Terminal shortcuts':('terminal','Terminale',['com.apple.Terminal']), 'Voice Memos shortcuts':('voice-memos','Memo Vocali',['com.apple.VoiceMemos']),
'Word':('word','Microsoft Word',['com.microsoft.Word']), 'Excel':('excel','Microsoft Excel',['com.microsoft.Excel']),
'PowerPoint':('powerpoint','Microsoft PowerPoint',['com.microsoft.Powerpoint']), 'Outlook':('outlook','Microsoft Outlook',['com.microsoft.Outlook']),
'Edge':('edge','Microsoft Edge',['com.microsoft.edgemac']), 'Firefox':('firefox','Firefox',['org.mozilla.firefox']),
'Cursor':('cursor','Cursor',['com.todesktop.230313mzl4w4u92']), 'Codex':('codex','Codex / ChatGPT',['com.openai.codex']),
'QuickTime':('quicktime','QuickTime Player',['com.apple.QuickTimePlayerX']),
'OneNote':('onenote','Microsoft OneNote',['com.microsoft.onenote']),
'LibreOffice':('libreoffice','LibreOffice Writer',['org.libreoffice.script']),
'VS Code defaults':('vscode','Visual Studio Code',['com.microsoft.VSCode']),
'Claude Code bindings':('claude-code','Claude Code · terminale',[]), 'VS Code':('vscode','Visual Studio Code',['com.microsoft.VSCode']),
}
for pid,name,bids in mapping.values():profile(pid,name,bids)
for pid,name,bids in [('system','macOS',[]),('finder','Finder',['com.apple.finder']),('text','Scrittura macOS',[]),('textedit','TextEdit',['com.apple.TextEdit']),('codex-cli','Codex · terminale',[]),('grok','Grok Bot',['com.anysphere.sand']),('vlc','VLC',['org.videolan.vlc']),('quicktime','QuickTime Player',['com.apple.QuickTimePlayerX']),('libreoffice','LibreOffice',['org.libreoffice.script']),('onenote','Microsoft OneNote',['com.microsoft.onenote']),('teams','Microsoft Teams',['com.microsoft.teams2']),('tor','Tor Browser',['org.torproject.torbrowser']),('claude','Claude',['com.anthropic.claudefordesktop'])]:profile(pid,name,bids)
profiles['cursor']['parent']='vscode'
profiles['textedit']['parent']='text'
for entry in json.loads((root/'index.json').read_text()):
 name=entry['name']
 if name not in mapping or 'error' in entry:continue
 pid=mapping[name][0];file=root/(name+'.html');s=BeautifulSoup(file.read_text(),'html.parser');url=entry['url']
 tables=s.select('table')
 if name in ['Word','Excel','PowerPoint','Outlook','OneNote']:
  section=s.select_one('section[data-tab=macos]')
  tables=section.select('table') if section else []
 if name=='Edge':tables=tables[1:2]
 if name=='Codex':tables=tables[:1]
 if name=='QuickTime':tables=[t for t in tables if 'Gesto' not in t.get_text(' ',strip=True)[:60]]
 if name=='Cursor':tables=tables[:4]
 if name=='VS Code':tables=[] # these tables document syntax, not a shortcut reference
 if name=='Claude Code bindings':tables=tables[2:29]
 before=len(records)
 for table in tables:
  heading=table.find_previous(['h2','h3']);section=text(heading).strip('​ ') if heading else ''
  rows=table.select('tr')
  for row in rows:
   cells=row.find_all('td',recursive=False)
   if len(cells)<2:continue
   vals=[text(c) for c in cells]
   if name=='Claude Code bindings':
    if len(vals)<3:continue
    actionID,binding,title=vals[:3]
    section={'app':'Global','chat':'Chat','history':'Chat','autocomplete':'Autocomplete','confirm':'Confirmation','transcript':'Transcript','historySearch':'HistorySearch','task':'Task','tabs':'Tabs','attachments':'Attachments','footer':'Footer','diff':'Diff','modelPicker':'ModelPicker','select':'Select','settings':'Settings','voice':'Chat'}.get(actionID.split(':')[0],section)
   elif name in ['Edge','Cursor']:
    binding,title=vals[:2];actionID=None
   else:title,binding=vals[:2];actionID=None
   if name=='VS Code defaults':
    actionID=vals[2] if len(vals)>2 else None
    binding=re.sub(r'\(Windows.*?\)','',binding).strip()
   # Retain paragraph-separated alternative keys as separate entries where safe.
   bindcell=cells[1] if name not in ['Edge','Cursor'] else cells[0]
   parts=[text(p) for p in bindcell.find_all('p',recursive=False)]
   if name=='VS Code defaults':parts=[]
   if name=='Claude Code bindings':parts=[]
   validparts=[part for part in parts if parse(part)]
   if validparts:
    notes=' '.join(part for part in parts if not parse(part))
    for part in validparts:add(pid,title,part,url,section,actionID,note=notes or None)
   else:add(pid,title,binding,url,section,actionID)
 audit.append({'profile':pid,'source':url,'rowsAdded':len(records)-before})

apple='https://support.apple.com/en-us/102650'
def manual(pid,rows,url=apple):
 for title,binding,category,*rest in rows:add(pid,title,binding,url,category,category=category,note=rest[0] if rest else None)
manual('system',[
('Passa all’app successiva','Command+Tab','App e finestre'),('Passa all’app precedente','Command+Shift+Tab','App e finestre'),
('Apri Spotlight','Command+Space','Ricerca'),('Apri ricerca Finder','Command+Option+Space','Ricerca'),
('Mission Control','Control+Up','App e finestre'),('Finestre dell’app attiva','Control+Down','App e finestre'),
('Desktop precedente','Control+Left','App e finestre'),('Desktop successivo','Control+Right','App e finestre'),
('Blocca lo schermo','Control+Command+Q','Sistema'),('Chiusura forzata applicazioni','Command+Option+Escape','Sistema'),
('Mostra o nascondi Dock','Command+Option+D','Sistema'),('Emoji e simboli','Control+Command+Space','Scrittura'),
('Screenshot: schermo intero','Command+Shift+3','Screenshot'),('Screenshot: area','Command+Shift+4','Screenshot'),
('Screenshot negli appunti: area','Control+Command+Shift+4','Screenshot'),('Screenshot negli appunti: schermo','Control+Command+Shift+3','Screenshot'),
('Screenshot e registrazione','Command+Shift+5','Screenshot'),('Sorgente di input precedente','Control+Space','Sistema'),
('Sorgente di input successiva','Control+Option+Space','Sistema'),('Passa alla finestra successiva dell’app','Command+`','App e finestre','Il tasto dipende dal layout e dalle impostazioni Tastiera.'),
('Impostazioni Monitor','Option+F2','Monitor e audio','F2 deve agire come tasto luminosità. Può essere necessario Fn, secondo la tastiera.'),
('Luminosità: aumenta di poco','Option+Shift+F2','Monitor e audio','Tasto luminosità; dipende dalle impostazioni dei tasti funzione.'),
('Luminosità: diminuisci di poco','Option+Shift+F1','Monitor e audio','Tasto luminosità; dipende dalle impostazioni dei tasti funzione.'),
('Volume: aumenta di poco','Option+Shift+F12','Monitor e audio','Tasto volume; dipende dalla tastiera.'),('Volume: diminuisci di poco','Option+Shift+F11','Monitor e audio','Tasto volume; dipende dalla tastiera.')])
manual('finder',[
('Copia','Command+C','File'),('Incolla','Command+V','File'),('Sposta qui gli elementi copiati','Command+Option+V','File'),
('Nuova finestra Finder','Command+N','File'),('Nuova cartella','Command+Shift+N','File'),('Apri elemento','Command+O','File'),('Apri elemento selezionato','Command+Down','File'),('Rinomina elemento','Return','File'),('Anteprima rapida','Space','Vista'),
('Sposta nel Cestino','Command+Delete','File'),('Elimina immediatamente','Command+Option+Delete','File','Comando distruttivo: elimina senza spostare nel Cestino.'),
('Ottieni informazioni','Command+I','File'),('Duplica','Command+D','File'),('Annulla','Command+Z','File'),('Ripristina','Command+Shift+Z','File'),
('Vai alla cartella','Command+Shift+G','Navigazione'),('Applicazioni','Command+Shift+A','Navigazione'),('Scrivania','Command+Shift+D','Navigazione'),('Cartella Inizio','Command+Shift+H','Navigazione'),('Download','Command+Option+L','Navigazione'),('Cartella superiore','Command+Up','Navigazione'),('Cerca','Command+F','Ricerca'),
('Vista a icone','Command+1','Vista'),('Vista elenco','Command+2','Vista'),('Vista colonne','Command+3','Vista'),('Vista galleria','Command+4','Vista'),('Mostra file nascosti','Command+Shift+.','Vista'),('Nuovo pannello','Command+T','Finestre e schede'),('Chiudi finestra o pannello','Command+W','Finestre e schede')])
manual('text',[
('Copia testo','Command+C','Scrittura e modifica'),('Incolla testo','Command+V','Scrittura e modifica'),('Taglia testo','Command+X','Scrittura e modifica'),('Seleziona tutto','Command+A','Scrittura e modifica'),('Annulla','Command+Z','Scrittura e modifica'),('Ripristina','Command+Shift+Z','Scrittura e modifica'),('Salva documento','Command+S','File'),('Stampa documento','Command+P','File'),
('Parola precedente','Option+Left','Navigazione'),('Parola successiva','Option+Right','Navigazione'),('Seleziona parola precedente','Option+Shift+Left','Scrittura e modifica'),('Seleziona parola successiva','Option+Shift+Right','Scrittura e modifica'),('Elimina parola precedente','Option+Delete','Scrittura e modifica'),('Elimina fino a inizio riga','Command+Delete','Scrittura e modifica'),('Inizio riga','Command+Left','Navigazione'),('Fine riga','Command+Right','Navigazione'),('Inizio documento','Command+Up','Navigazione'),('Fine documento','Command+Down','Navigazione'),('Elimina carattere successivo','Fn+Delete','Scrittura e modifica'),('Inizio documento (Home)','Fn+Left','Navigazione'),('Fine documento (End)','Fn+Right','Navigazione'),('Pagina precedente','Fn+Up','Navigazione'),('Pagina successiva','Fn+Down','Navigazione'),('Inizio riga (Emacs)','Control+A','Navigazione'),('Fine riga (Emacs)','Control+E','Navigazione'),('Elimina carattere successivo (Emacs)','Control+D','Scrittura e modifica'),('Elimina fino a fine riga (Emacs)','Control+K','Scrittura e modifica'),('Cerca nel documento','Command+F','Ricerca'),('Risultato successivo','Command+G','Ricerca'),('Risultato precedente','Command+Shift+G','Ricerca'),('Incolla e adatta lo stile','Command+Option+Shift+V','Scrittura e modifica')])
manual('vlc',[('Avanza di un fotogramma','E','Riproduzione','Segnalata dall’utente; verificare le assegnazioni della versione installata.')],url='https://www.youtube.com/watch?v=LLUrxMWdVqU')
manual('vscode',[
('Tavolozza comandi','Command+Shift+P','Ricerca'),('Apri rapidamente un file','Command+P','File'),('Salva','Command+S','File'),('Copia','Command+C','Scrittura e modifica'),('Incolla','Command+V','Scrittura e modifica'),('Taglia','Command+X','Scrittura e modifica'),('Cerca','Command+F','Ricerca'),('Cerca nei file','Command+Shift+F','Ricerca'),('Impostazioni','Command+,','Sistema'),('Scorciatoie da tastiera','Command+K Command+S','Sistema'),('Commenta la riga','Command+/','Scrittura e modifica'),('Vai alla riga','Control+G','Navigazione'),('Vai alla definizione','F12','Navigazione'),('Mostra suggerimenti','Control+Space','Scrittura e modifica'),('Terminale integrato','Control+`','Finestre e schede'),('Seleziona occorrenza successiva','Command+D','Scrittura e modifica'),('Sposta riga in alto','Option+Up','Scrittura e modifica'),('Sposta riga in basso','Option+Down','Scrittura e modifica'),('Copia riga in alto','Option+Shift+Up','Scrittura e modifica'),('Copia riga in basso','Option+Shift+Down','Scrittura e modifica')],url='https://code.visualstudio.com/docs/reference/default-keybindings')
manual('codex-cli',[
('Copia l’ultima risposta completata','Control+O','Chat'),('Apri editor esterno','Control+G','Scrittura e modifica'),('Pulisci lo schermo','Control+L','Vista'),('Invia o indirizza il turno corrente','Return','Chat'),('Accoda il messaggio al turno successivo','Tab','Chat')],url='https://learn.chatgpt.com/docs/developer-commands')
# Supplement zoom in browsers explicitly without treating it as a system-wide shortcut.
for pid in ['safari','edge','firefox']:
 manual(pid,[('Zoom avanti','Command++','Vista'),('Zoom indietro','Command+-','Vista'),('Dimensioni originali','Command+0','Vista'),('Nuova scheda','Command+T','Finestre e schede'),('Chiudi scheda','Command+W','Finestre e schede'),('Scheda successiva','Control+Tab','Finestre e schede'),('Scheda precedente','Control+Shift+Tab','Finestre e schede')],url=profiles[pid]['sources'][0] if profiles[pid]['sources'] else 'https://support.mozilla.org/en-US/kb/keyboard-shortcuts-perform-firefox-tasks-quickly')
# Inventory all installed Apple user apps/utilities with honest menu-only support.
for base in ['/System/Applications','/System/Applications/Utilities']:
 for app in sorted(Path(base).glob('*.app')):
  try:d=plistlib.loads((app/'Contents/Info.plist').read_bytes());bid=d['CFBundleIdentifier']
  except Exception:continue
  if not any(bid in p['bundleIDs'] for p in profiles.values()):
   pid='apple-'+slug(app.stem);profile(pid,app.stem,[bid]);profiles[pid]['note']='Menu dell’app tramite Accessibilità. Catalogo dedicato non ancora integrato.'
# Match known VS Code commands across translated manual and official references.
command_ids={'Copia':'editor.action.clipboardCopyAction','Incolla':'editor.action.clipboardPasteAction','Taglia':'editor.action.clipboardCutAction','Salva':'workbench.action.files.save','Cerca':'actions.find','Cerca nei file':'workbench.action.findInFiles','Tavolozza comandi':'workbench.action.showCommands','Apri rapidamente un file':'workbench.action.quickOpen','Impostazioni':'workbench.action.openSettings','Scorciatoie da tastiera':'workbench.action.openGlobalKeybindings','Vai alla riga':'workbench.action.gotoLine','Vai alla definizione':'editor.action.revealDefinition','Mostra suggerimenti':'editor.action.triggerSuggest','Terminale integrato':'workbench.action.terminal.toggleTerminal','Seleziona occorrenza successiva':'editor.action.addSelectionToNextFindMatch','Sposta riga in alto':'editor.action.moveLinesUpAction','Sposta riga in basso':'editor.action.moveLinesDownAction','Copia riga in alto':'editor.action.copyLinesUpAction','Copia riga in basso':'editor.action.copyLinesDownAction','Commenta la riga':'editor.action.commentLine'}
for row in records:
 if row['profile']=='vscode' and row['title'] in command_ids:row['actionID']=command_ids[row['title']]
profiles['firefox']['note']='Catalogo di base limitato: il riferimento ufficiale ha richiesto una verifica browser. Lettura dei menu disponibile; verifica completa ancora da svolgere.'
profiles['grok']['note']='Riconosciuto dal bundle ID: lettura live dei menu. Scorciatoie interne non esposte ancora da verificare.'
# No false full-coverage flags for empty or partially parsed catalogs.
from catalog_supplements import supplement
supplement(profiles, records)
from safari_developer_catalog import supplement as supplement_safari_developer
supplement_safari_developer(profiles, records)
unique={r['id']:r for r in records};records=list(unique.values())
for p in profiles.values():
 rows=[r for r in records if r['profile']==p['id']]
 if not rows:p['note']='Lettura dei menu disponibile se esposti. Catalogo dedicato e verifica della copertura da completare.'
 p['sources']=sorted(set(p['sources']))
coverage=[]
for p in profiles.values():
 rows=[r for r in records if r['profile']==p['id']];coverage.append({'id':p['id'],'name':p['name'],'records':len(rows),'parsed':sum(bool(r['strokes']) for r in rows),'unparsed':sum(not r['strokes'] for r in rows),'liveVerified':False,'note':p['note']})
result={'schemaVersion':1,'generated':'2026-11-02','profiles':sorted(profiles.values(),key=lambda p:p['name']),'shortcuts':records}
(out/'Sources/ShortcutCore/Resources/catalog.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
(out/'docs/coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2))
(out/'docs/source-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
print(f'{len(profiles)} profiles; {len(records)} records; {sum(bool(r["strokes"]) for r in records)} normalized; {sum(not r["strokes"] for r in records)} require review')
