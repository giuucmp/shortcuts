#!/usr/bin/env python3
"""Build the two static language routes. Python 3 only; no network or dependencies."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parent
BASE = 'https://giuucmp.github.io/scorciatoie/'
REPO = 'https://github.com/giuucmp/scorciatoie'
VERSION = '0.3.0'
DOWNLOAD = f'{REPO}/releases/download/v{VERSION}/Scorciatoie-{VERSION}-universal.dmg'
ARROW = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v5h14v-5" stroke-linecap="round" stroke-linejoin="round"/></svg>'
COPY = {
'en': {
 'title': 'Scorciatoie — Learn your Mac’s shortcuts as you work',
 'description': 'A native, open-source Mac app. Hold a modifier to see the active app’s shortcuts, then practice in Studio. English and Italian. Everything stays on your Mac.',
 'skip': 'Skip to content', 'navHow': 'How it works', 'navInstall': 'Install', 'navSource': 'Source',
 'other': 'Italiano', 'otherLabel': 'Leggi il sito in italiano', 'hero': 'Your app’s shortcuts.<br>One held key away.',
 'intro': 'Hold a modifier. See what you can do in the app you’re using. Learn the combinations as you work.',
 'download': 'Download for Mac', 'requirements': 'v0.3.0 · macOS 13+ · Apple silicon & Intel',
 'unsigned': 'Not notarized.', 'installLink': 'Read the installation steps',
 'panelAlt': 'Scorciatoie in English: app shortcuts grouped by purpose, with a separate macOS section.',
 'panelCaption': 'Your app’s actions come first. macOS shortcuts stay in a smaller, separate band.',
 'fullSize': 'View full-size screenshot',
 'panelPending': 'Hold a modifier to reveal the active app’s shortcuts. Release it to close the panel.',
 'howTitle': 'A brief look.<br>Back to your work.',
 'howIntro': 'Scorciatoie lives in your menu bar. Its temporary panel stays out of the way of the app you’re using.',
 'howSteps': [
  ('Hold a modifier', 'Press and hold Command, Option, Control, Shift or Fn. After a short delay, the panel appears.'),
  ('Narrow the choices', 'Add another modifier to filter the combinations. Actions remain grouped by what you want to do.'),
  ('Carry on', 'Release the modifiers to close the panel. It never takes focus and lets clicks pass through. Your shortcuts still go to your app.')
 ],
 'demoTitle': 'Try the filter', 'demoIntro': 'Click the keys below. These are a few illustrative Finder shortcuts, not the app itself.',
 'demoResult': '{count} examples match. Add another modifier to narrow the list.',
 'demoEmpty': 'No examples for these keys in this small demo. Try Command with Shift or Option.',
 'demoRows': [('New Finder window','⌘N','command'), ('New tab','⌘T','command'), ('Get Info','⌘I','command'), ('New folder','⇧⌘N','command shift'), ('Go to folder','⇧⌘G','command shift'), ('Open Downloads','⌥⌘L','command option')],
 'practiceTitle': 'Make the next shortcut<br>one you remember.',
 'practiceIntro': 'Open Studio to explore the catalog or practice with the keyboard. Choose an app, focus the exercise, and enter the combination or sequence. Review a mistake, then try again.',
 'practiceAlt': 'Scorciatoie Studio in English, showing a keyboard practice exercise.',
 'practiceCaption': 'Exercises use local, focused keyboard input. OS-reserved combinations are excluded from typing practice.',
 'practicePending': 'Studio brings the catalog, your favorites and keyboard practice into one window.',
 'features': [
  ('Keep the useful ones', 'Save favorites, hide actions you don’t need, and bring them back from Hidden. Import shortcuts you have already configured in your apps.'),
  ('Read it your way', 'Choose English, Italian or automatic language. Adjust text size, appearance, panel position and the modifiers that open it.'),
  ('Practice deliberately', 'Work on real chords and sequences. See errors, retry them, and keep your progress on your Mac. Practice only captures input while its exercise has focus.')
 ],
 'installTitle': 'A few steps.<br>Then it’s at hand.',
 'installIntro': 'This release is free and open source. It is not Developer ID signed or Apple-notarized, so macOS may ask you to approve it once.',
 'installSteps': [
  ('Move it to Applications', 'Download the DMG, open it, and drag Scorciatoie into <span class="path">Applications</span>. Then open Scorciatoie from there.'),
  ('Approve the first opening', 'If macOS blocks it, go to <span class="path">System Settings → Privacy &amp; Security → Open Anyway</span>, then confirm opening Scorciatoie. Only approve the copy you downloaded from this project’s release.'),
  ('Allow Accessibility', 'Enable Scorciatoie in <span class="path">System Settings → Privacy &amp; Security → Accessibility</span>. This lets it read app menus and detect the held modifiers. Its Command icon then lives in your menu bar.')
 ],
 'installNote': 'No Screen Recording permission is needed. You can turn off Accessibility access at any time in System Settings. After an update, macOS may ask you to enable it again.',
 'factsTitle': 'Know what<br>you’re installing.',
 'faq': [
  ('What does Scorciatoie read?', 'The active app’s accessible menus and structural context, offline shortcut catalogs, and supported editor keybinding files and extension declarations. It does not record what you type in other apps. There is no sign-in, telemetry or network traffic from the app; preferences and practice progress stay local.'),
  ('Does it know every shortcut?', 'No. Coverage combines live menus, documented offline catalogs and supported VS Code/Cursor bindings. A recognized app is not a guarantee of complete coverage. Some menus load only when opened, and not every context or extension condition can be resolved. The app marks partial or conditional information.'),
  ('Are both languages fully supported?', 'The interface, bundled catalog and exercises support English and Italian, with an automatic system-language option. An unfamiliar live command title from a third-party app stays in its original language when no translation is in the catalog.'),
  ('Will it work on an older Mac?', 'Scorciatoie requires macOS 13 or later. The download supports Apple silicon and Intel. Native Liquid Glass is available on macOS 26 and later; earlier systems use a translucent fallback. Reduce Transparency and Increase Contrast settings are respected.'),
  ('Will an exercise run commands in another app?', 'Practice is a focused, local exercise. It captures input only while its keyboard field has focus, and OS-reserved combinations are excluded from typing exercises. The passive overlay is separate: it never intercepts your app’s commands.'),
  ('Can I change or remove it?', 'Yes. Pause or quit it from the menu bar, revoke Accessibility permission in System Settings, or remove the app from Applications. The source is available under the MIT license, so you can inspect, build and adapt it.')
 ],
 'sourceTitle': 'Open source. Open to your ideas.',
 'sourceText': 'Check the code, correct a shortcut or help improve a translation.',
 'sourceCode': 'View source', 'fork': 'Fork on GitHub', 'contribute': 'Contribute',
 'footer': 'Made for macOS. Built with Swift and SwiftUI.', 'license': 'MIT license', 'releases': 'Release notes',
 'keys': [('command','⌘','Command'),('option','⌥','Option'),('control','⌃','Control'),('shift','⇧','Shift'),('function','fn','Fn')]
},
'it': {
 'title': 'Scorciatoie — Impara le combinazioni del Mac mentre lavori',
 'description': 'Un’app Mac nativa e open source. Tieni premuto un modificatore per vedere le scorciatoie dell’app attiva, poi esercitati in Studio. Italiano e inglese. Tutto resta sul Mac.',
 'skip': 'Vai al contenuto', 'navHow': 'Come funziona', 'navInstall': 'Installa', 'navSource': 'Codice',
 'other': 'English', 'otherLabel': 'Read the website in English', 'hero': 'Le scorciatoie della tua app.<br>A un tasto di distanza.',
 'intro': 'Tieni premuto un modificatore. Guarda cosa puoi fare nell’app che stai usando. Impara le combinazioni mentre lavori.',
 'download': 'Scarica per Mac', 'requirements': 'v0.3.0 · macOS 13+ · Apple silicon e Intel',
 'unsigned': 'Non notarizzata.', 'installLink': 'Leggi come installarla',
 'panelAlt': 'Scorciatoie in italiano: comandi dell’app raggruppati per scopo, con una sezione macOS separata.',
 'panelCaption': 'Prima le azioni della tua app. Le scorciatoie macOS restano in una fascia separata, più piccola.',
 'fullSize': 'Apri la schermata a dimensione intera',
 'panelPending': 'Tieni premuto un modificatore per vedere le scorciatoie dell’app attiva. Rilascialo per chiudere il pannello.',
 'howTitle': 'Un’occhiata.<br>E torni al lavoro.',
 'howIntro': 'Scorciatoie vive nella barra dei menu. Il suo pannello temporaneo lascia il controllo all’app che stai usando.',
 'howSteps': [
  ('Tieni premuto un modificatore', 'Premi e tieni premuto Comando, Opzione, Ctrl, Maiuscole o Fn. Dopo una breve attesa, compare il pannello.'),
  ('Restringi la scelta', 'Aggiungi un altro modificatore per filtrare le combinazioni. Le azioni restano raggruppate in base a quello che vuoi fare.'),
  ('Continua a lavorare', 'Rilascia i modificatori per chiudere il pannello. Non prende il focus e lascia passare i clic. Le scorciatoie continuano a funzionare nella tua app.')
 ],
 'demoTitle': 'Prova il filtro', 'demoIntro': 'Fai clic sui tasti qui sotto. Sono alcuni esempi di scorciatoie del Finder, non l’app vera e propria.',
 'demoResult': '{count} esempi corrispondenti. Aggiungi un modificatore per restringere l’elenco.',
 'demoEmpty': 'Nessun esempio per questi tasti in questa piccola demo. Prova Comando con Maiuscole o Opzione.',
 'demoRows': [('Nuova finestra Finder','⌘N','command'), ('Nuovo pannello','⌘T','command'), ('Ottieni informazioni','⌘I','command'), ('Nuova cartella','⇧⌘N','command shift'), ('Vai alla cartella','⇧⌘G','command shift'), ('Apri Download','⌥⌘L','command option')],
 'practiceTitle': 'La prossima scorciatoia<br>te la ricordi.',
 'practiceIntro': 'Apri Studio per esplorare il catalogo o esercitarti con la tastiera. Scegli un’app, attiva l’esercizio e digita la combinazione o la sequenza. Rivedi un errore, poi riprova.',
 'practiceAlt': 'Studio di Scorciatoie in italiano, con un esercizio da svolgere con la tastiera.',
 'practiceCaption': 'Gli esercizi acquisiscono i tasti localmente, nel campo attivo. Le combinazioni riservate al sistema sono escluse dalla pratica digitata.',
 'practicePending': 'Studio riunisce il catalogo, i tuoi preferiti e gli esercizi con la tastiera in una finestra.',
 'features': [
  ('Tieni quelle che ti servono', 'Salva i preferiti, nascondi le azioni che non usi e recuperale da Nascoste. Importa le scorciatoie che hai già configurato nelle tue app.'),
  ('Leggile a modo tuo', 'Scegli italiano, inglese o lingua automatica. Regola dimensione del testo, aspetto, posizione del pannello e modificatori di richiamo.'),
  ('Esercitati con attenzione', 'Prova combinazioni e sequenze reali. Vedi gli errori, ripassali e conserva i progressi sul Mac. L’esercizio acquisisce i tasti solo quando ha il focus.')
 ],
 'installTitle': 'Pochi passaggi.<br>Poi è a portata di mano.',
 'installIntro': 'Questa versione è gratuita e open source. Non è firmata con Developer ID né notarizzata da Apple: macOS può chiederti di approvarne il primo avvio.',
 'installSteps': [
  ('Spostala in Applicazioni', 'Scarica il DMG, aprilo e trascina Scorciatoie in <span class="path">Applicazioni</span>. Poi apri Scorciatoie da lì.'),
  ('Approva il primo avvio', 'Se macOS la blocca, vai in <span class="path">Impostazioni di Sistema → Privacy e sicurezza → Apri comunque</span>, poi conferma l’apertura di Scorciatoie. Approva solo la copia scaricata dal rilascio di questo progetto.'),
  ('Consenti l’accesso ad Accessibilità', 'Abilita Scorciatoie in <span class="path">Impostazioni di Sistema → Privacy e sicurezza → Accessibilità</span>. Serve per leggere i menu delle app e rilevare i modificatori premuti. L’icona Comando resta nella barra dei menu.')
 ],
 'installNote': 'Non serve il permesso Registrazione schermo. Puoi disattivare l’accesso ad Accessibilità in qualsiasi momento dalle Impostazioni di Sistema. Dopo un aggiornamento, macOS potrebbe chiederti di abilitarlo di nuovo.',
 'factsTitle': 'Sai cosa<br>stai installando.',
 'faq': [
  ('Cosa legge Scorciatoie?', 'I menu accessibili e il contesto strutturale dell’app attiva, i cataloghi offline e i file delle assegnazioni e le dichiarazioni delle estensioni degli editor supportati. Non registra quello che digiti nelle altre app. L’app non richiede account, non invia telemetria e non effettua traffico di rete; preferenze e progressi restano locali.'),
  ('Conosce tutte le scorciatoie?', 'No. La copertura unisce menu live, cataloghi offline documentati e assegnazioni supportate di VS Code e Cursor. Un’app riconosciuta non garantisce una copertura completa. Alcuni menu si caricano solo quando vengono aperti e non tutte le condizioni del contesto o delle estensioni sono interpretabili. L’app segnala le informazioni parziali o condizionate.'),
  ('Sono supportate entrambe le lingue?', 'Interfaccia, catalogo incluso ed esercizi supportano italiano e inglese, con un’opzione automatica che segue la lingua del sistema. Un titolo live sconosciuto proveniente da un’app di terze parti resta nella lingua originale quando manca una traduzione nel catalogo.'),
  ('Funziona su un Mac meno recente?', 'Scorciatoie richiede macOS 13 o successivo. Il download supporta Apple silicon e Intel. Liquid Glass nativo è disponibile da macOS 26; sui sistemi precedenti viene usato un materiale traslucido. Sono rispettate le impostazioni Riduci trasparenza e Aumenta contrasto.'),
  ('Un esercizio esegue comandi in altre app?', 'La pratica avviene in un esercizio locale dedicato. Acquisisce i tasti solo quando il suo campo ha il focus ed esclude dalla digitazione le combinazioni riservate al sistema. Il pannello consultivo è separato: non intercetta i comandi delle tue app.'),
  ('Posso modificarla o rimuoverla?', 'Sì. Puoi metterla in pausa o chiuderla dalla barra dei menu, revocare Accessibilità nelle Impostazioni di Sistema o rimuoverla da Applicazioni. Il codice è disponibile con licenza MIT: puoi leggerlo, compilarlo e adattarlo.')
 ],
 'sourceTitle': 'Codice aperto. Spazio alle tue idee.',
 'sourceText': 'Esplora il codice, correggi una scorciatoia o migliora una traduzione.',
 'sourceCode': 'Vedi il codice', 'fork': 'Crea un fork su GitHub', 'contribute': 'Contribuisci',
 'footer': 'Per macOS. Sviluppata con Swift e SwiftUI.', 'license': 'Licenza MIT', 'releases': 'Note di rilascio',
 'keys': [('command','⌘','Comando'),('option','⌥','Opzione'),('control','⌃','Ctrl'),('shift','⇧','Maiuscole'),('function','fn','Fn')]
}}

def steps(items):
    return '<ol class="steps">' + ''.join(f'<li><h3>{title}</h3><p>{body}</p></li>' for title,body in items) + '</ol>'

def render(lang):
    c=COPY[lang]
    rel='' if lang=='en' else '../'
    canonical=BASE if lang=='en' else BASE+'it/'
    other='it/' if lang=='en' else '../'
    otherlang='it' if lang=='en' else 'en'
    button=f'<a class="button" href="{DOWNLOAD}">{ARROW}{c["download"]}</a>'
    keys=''.join(f'<button type="button" data-modifier="{key}" aria-pressed="{"true" if key=="command" else "false"}"><span aria-hidden="true">{symbol}</span><small>{label}</small></button>' for key,symbol,label in c['keys'])
    rows=''.join(f'<li data-keys="{mods}"><span>{title}</span><kbd>{keys}</kbd></li>' for title,keys,mods in c['demoRows'])
    features=''.join(f'<div><h3>{title}</h3><p>{body}</p></div>' for title,body in c['features'])
    faq=''.join(f'<details><summary>{title}</summary><p>{body}</p></details>' for title,body in c['faq'])
    schema={'@context':'https://schema.org','@type':'SoftwareApplication','name':'Scorciatoie','operatingSystem':'macOS 13+','applicationCategory':'UtilitiesApplication','inLanguage':['en','it'],'softwareVersion':VERSION,'license':REPO+'/blob/main/LICENSE','downloadUrl':DOWNLOAD,'offers':{'@type':'Offer','price':'0','priceCurrency':'EUR'}}
    return f'''<!doctype html>
<!-- Generated by site/build.py. Edit the bilingual copy there, then rebuild. -->
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(c['title'])}</title>
<meta name="description" content="{escape(c['description'], quote=True)}">
<meta name="theme-color" content="#f7f8fa">
<link rel="canonical" href="{canonical}">
<link rel="alternate" hreflang="en" href="{BASE}">
<link rel="alternate" hreflang="it" href="{BASE}it/">
<link rel="alternate" hreflang="x-default" href="{BASE}">
<meta property="og:type" content="website">
<meta property="og:title" content="{escape(c['title'], quote=True)}">
<meta property="og:description" content="{escape(c['description'], quote=True)}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{BASE}assets/app-icon.png">
<meta property="og:locale" content="{'en_US' if lang=='en' else 'it_IT'}">
<link rel="icon" type="image/png" href="{rel}assets/app-icon.png">
<link rel="stylesheet" href="{rel}assets/site.css">
<script src="{rel}assets/site.js" defer></script>
<script type="application/ld+json">{json.dumps(schema,ensure_ascii=False)}</script>
</head>
<body>
<a class="skip" href="#main">{c['skip']}</a>
<header class="header wrap">
<a class="brand" href="{'./' if lang=='en' else '../it/'}"><img src="{rel}assets/app-icon.png" alt="" width="43" height="43">Scorciatoie</a>
<nav class="nav" aria-label="{'Main navigation' if lang=='en' else 'Navigazione principale'}">
<a class="desktop-link" href="#how-it-works">{c['navHow']}</a><a class="desktop-link" href="#install">{c['navInstall']}</a><a href="{REPO}">{c['navSource']}</a><a class="language" href="{other}" lang="{otherlang}" hreflang="{otherlang}" aria-label="{c['otherLabel']}">{c['other']}</a>
</nav>
</header>
<main id="main">
<section class="hero wrap" aria-labelledby="hero-title">
<div class="hero-top"><h1 id="hero-title">{c['hero']}</h1><div class="hero-intro"><p>{c['intro']}</p>{button}<p class="meta">{c['requirements']}</p><p class="install-note">{c['unsigned']} <a href="#install">{c['installLink']}</a></p></div></div>
<figure class="app-shot"><div class="shot-stage"><a class="shot-link" href="{rel}assets/panel-{lang}.png" aria-label="{c['fullSize']}"><img data-app-image src="{rel}assets/panel-{lang}.png" alt="{c['panelAlt']}" width="1120" height="1469" fetchpriority="high"></a><p class="asset-note">{c['panelPending']}</p></div><figcaption>{c['panelCaption']} <a href="{rel}assets/panel-{lang}.png">{c['fullSize']}</a>.</figcaption></figure>
</section>
<section class="section wrap" id="how-it-works" aria-labelledby="how-title">
<div class="section-head"><h2 id="how-title">{c['howTitle']}</h2><p>{c['howIntro']}</p></div>
<div class="mechanism">{steps(c['howSteps'])}<div class="demo" data-demo data-result="{c['demoResult']}" data-empty="{c['demoEmpty']}"><h3>{c['demoTitle']}</h3><p class="demo-intro">{c['demoIntro']}</p><div class="modifiers" role="group" aria-label="{'Filter examples by modifier' if lang=='en' else 'Filtra gli esempi per modificatore'}">{keys}</div><ul class="demo-list">{rows}</ul><p class="demo-status" role="status" aria-live="polite"></p></div></div>
</section>
<section class="section practice" aria-labelledby="practice-title"><div class="wrap">
<div class="section-head"><h2 id="practice-title">{c['practiceTitle']}</h2><p>{c['practiceIntro']}</p></div>
<figure class="app-shot"><div class="shot-stage"><a class="shot-link" href="{rel}assets/practice-{lang}.png" aria-label="{c['fullSize']}"><img data-app-image src="{rel}assets/practice-{lang}.png" alt="{c['practiceAlt']}" loading="lazy"></a><p class="asset-note">{c['practicePending']}</p></div><figcaption>{c['practiceCaption']} <a href="{rel}assets/practice-{lang}.png">{c['fullSize']}</a>.</figcaption></figure>
<div class="details-row">{features}</div>
</div></section>
<section class="section install wrap" id="install" aria-labelledby="install-title"><div><h2 id="install-title">{c['installTitle']}</h2><p class="lead">{c['installIntro']}</p>{button}<p class="meta">{c['requirements']}</p><p class="note">{c['installNote']}</p></div>{steps(c['installSteps'])}</section>
<section class="facts wrap" aria-labelledby="facts-title"><h2 id="facts-title">{c['factsTitle']}</h2><div class="faq">{faq}</div></section>
<section class="open-source wrap" aria-labelledby="source-title"><div><h2 id="source-title">{c['sourceTitle']}</h2><p>{c['sourceText']}</p></div><div class="source-links"><a href="{REPO}">{c['sourceCode']}</a><a href="{REPO}/fork">{c['fork']}</a></div></section>
</main>
<footer class="footer wrap"><span>{c['footer']}</span><div class="footer-links"><a href="{REPO}/blob/main/LICENSE">{c['license']}</a><a href="{REPO}/blob/main/CONTRIBUTING.md">{c['contribute']}</a><a href="{REPO}/releases/tag/v{VERSION}">{c['releases']}</a></div></footer>
</body>
</html>
'''

for lang in COPY:
    target=ROOT/'index.html' if lang=='en' else ROOT/'it/index.html'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(render(lang),encoding='utf-8')
print('Built English and Italian routes.')
