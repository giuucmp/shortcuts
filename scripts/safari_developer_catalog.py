"""Documented Safari developer shortcuts, isolated from page browsing.

Call supplement(profiles, records) from the catalog builder. This module never
reads browser state or changes Safari settings. Running it directly validates
its data and writes only its own localization resource.

Evidence reviewed 2026-11-02:
* Apple Develop menu documentation + its public menu screenshot (macOS 14).
* WebKit keyboard reference: last updated 2022-10-31, STP 156, not a claim
  of complete current-Safari keyboard verification.
* Read-only inspection of Safari 27.2 (22625.2.8.11.9) Info.plist,
  MainMenu.nib, and Safari.framework Localizable.strings confirmed the app
  version and developer labels. Developer accelerators are not serialized
  in that nib; therefore the public Apple screenshot is their evidence.
No user preferences, browsing content, or live menus were accessed; no apps were launched.
"""
import hashlib
import json
from pathlib import Path
from key_parser import parse

REFERENCE = 'https://webkit.org/web-inspector/keyboard-shortcuts/'
ENABLING = 'https://webkit.org/web-inspector/enabling-web-inspector/'
APPLE_HELP = 'https://support.apple.com/guide/safari/use-the-developer-tools-in-the-develop-menu-sfri20948/mac'
DEVELOP = 'https://developer.apple.com/documentation/safari-developer-tools/develop-menu'
MENU_IMAGE = 'https://developer.apple.com/tutorials/images/com.apple.safari.developer-tools/DevelopMenu@2x.png'
RESPONSIVE = 'https://webkit.org/blog/14670/simplified-responsive-design-mode/'
INTERFACE = 'https://webkit.org/web-inspector/web-inspector-interface/'
LOCAL_LABELS = 'file:///System/Library/PrivateFrameworks/Safari.framework/Resources/en.lproj/Localizable.strings'
LOCALIZATIONS = {}


def t(it, en):
    pair = {'it': it, 'en': en}
    assert it not in LOCALIZATIONS or LOCALIZATIONS[it] == pair, it
    LOCALIZATIONS[it] = pair
    return it


CATEGORY = t('Sviluppare e debuggare', 'Develop and debug')
DEVELOP_SECTION = t('Menu Sviluppo', 'Develop menu')
INSPECTOR_NAME = t('Safari · Web Inspector', 'Safari · Web Inspector')
DEVELOP_CONTEXT = t('Safari · menu Sviluppo attivo', 'Safari · Develop menu enabled')
DEVELOP_NOTE = t(
    'Richiede Safari > Impostazioni > Avanzate > Mostra funzionalità per sviluppatori web. Combinazione documentata da Apple; disponibilità nella finestra attuale non verificata.',
    'Requires Safari > Settings > Advanced > Show features for web developers. Apple-documented shortcut; availability in the current window has not been verified.')
INSPECTOR_NOTE = t(
    'Riferimento WebKit aggiornato per Safari Technology Preview 156 (31 ottobre 2022). Richiede Web Inspector attivo e il contesto indicato; non è una verifica completa della versione installata.',
    'WebKit reference updated for Safari Technology Preview 156 (October 31, 2022). Requires an active Web Inspector and the stated context; this is not complete verification of the installed version.')
MENU_ONLY_NOTE = t(
    'Voce documentata del menu Sviluppo, senza combinazione di tasti verificata. Le voci per dispositivi, app ed estensioni dipendono dai contenuti ispezionabili disponibili.',
    'Documented Develop menu item without a verified key binding. Device, app, and extension entries depend on available inspectable content.')
MENU_ONLY_BINDING = t('Dal menu Sviluppo · nessun tasto documentato', 'Develop menu · no documented key binding')
PROFILE_NOTE = t(
    'Comandi interni di Web Inspector, separati dalla navigazione nelle pagine. Include le combinazioni della guida WebKit per STP 156 e i gesti documentati, con contesti espliciti. La disponibilità effettiva va verificata nella versione in uso.',
    'Internal Web Inspector commands, separate from page browsing. Includes the WebKit STP 156 reference bindings and documented gestures, with explicit contexts. Actual availability must be checked in the version in use.')
SAFARI_NOTE = t(
    'Catalogo Safari con menu Sviluppo. Le scorciatoie di sviluppo richiedono le funzionalità per sviluppatori web; i comandi interni di Web Inspector hanno un profilo separato. Combinazioni da fonti Apple/WebKit, senza verifica del menu attuale.',
    'Safari catalog including the Develop menu. Developer shortcuts require web developer features; internal Web Inspector commands have a separate profile. Bindings come from Apple/WebKit sources, without verification of the current menu.')

# Each alternative is its own row: alternatives are never modeled as a chord.
MAIN = []
INSPECTOR = []


def main(action, it, en, binding=None, condition=None, condition_en=None, source=MENU_IMAGE):
    context = DEVELOP_CONTEXT
    if condition:
        context = t(DEVELOP_CONTEXT + ' · ' + condition,
                    'Safari · Develop menu enabled · ' + condition_en)
    MAIN.append((action, t(it, en), binding, context, DEVELOP_SECTION,
                 DEVELOP_NOTE if binding else MENU_ONLY_NOTE, source))


def inspector(action, it, en, bindings, context_it, context_en, section_it, section_en, gesture=None, gesture_en=None):
    title = t(it, en)
    context = t('Web Inspector attivo · ' + context_it, 'Active Web Inspector · ' + context_en)
    section = t(section_it, section_en)
    raw = t(gesture, gesture_en) if gesture else None
    for binding in bindings or [None]:
        INSPECTOR.append((action, title, binding, context, section, INSPECTOR_NOTE, REFERENCE, raw))


main('responsive-design', 'Attiva o disattiva la modalità di progettazione adattiva', 'Toggle Responsive Design Mode', 'Control+Command+R', source=RESPONSIVE)
main('web-inspector', 'Mostra o nascondi Web Inspector', 'Show or hide Web Inspector', 'Option+Command+I')
main('javascript-console', 'Mostra la console JavaScript', 'Show the JavaScript console', 'Option+Command+C')
main('page-source', 'Mostra il sorgente della pagina', 'Show page source', 'Option+Command+U')
main('page-resources', 'Mostra le risorse della pagina', 'Show page resources', 'Option+Command+A')
main('timeline-recording', 'Avvia o interrompi la registrazione della timeline', 'Start or stop timeline recording', 'Option+Shift+Command+T')
main('element-selection', 'Avvia o interrompi la selezione degli elementi', 'Start or stop element selection', 'Shift+Command+C')
main('empty-caches', 'Svuota le cache', 'Empty caches', 'Option+Command+E')
for action, it, en in [
    ('open-page-with', 'Apri la pagina con un altro browser o simulatore', 'Open the page in another browser or simulator'),
    ('user-agent', 'Scegli lo user agent', 'Choose the user agent'),
    ('inspect-apps-devices', 'Ispeziona app e dispositivi', 'Inspect apps and devices'),
    ('service-workers', 'Ispeziona un service worker', 'Inspect a service worker'),
    ('extension-background', 'Ispeziona i contenuti in background delle estensioni web', 'Inspect web extension background content'),
    ('developer-settings', 'Apri le impostazioni per sviluppatori', 'Open Developer settings'),
    ('feature-flags', 'Apri le impostazioni dei flag delle funzionalità', 'Open Feature Flag settings'),
]:
    main(action, it, en, source=DEVELOP)
for action, it, en, condition, condition_en in [
    ('inspect-device-content', 'Ispeziona i contenuti di un dispositivo o simulatore', 'Inspect content on a device or simulator', 'Dispositivo o simulatore con contenuti ispezionabili', 'Device or simulator with inspectable content'),
    ('connect-network', 'Collega il dispositivo tramite rete', 'Connect the device via network', 'Dispositivo abbinato e sulla stessa rete', 'Paired device on the same network'),
    ('unpair-device', 'Annulla l’abbinamento del dispositivo', 'Unpair the device', 'Dispositivo abbinato tramite rete', 'Device paired over the network'),
    ('automatic-js-inspection', 'Mostra automaticamente Web Inspector per JSContext', 'Automatically show Web Inspector for JSContexts', 'Menu del dispositivo · contesti JavaScript ispezionabili', 'Device menu · inspectable JavaScript contexts'),
    ('automatic-js-pause', 'Metti automaticamente in pausa i JSContext alla connessione', 'Automatically pause JSContexts on connection', 'Menu del dispositivo · contesti JavaScript ispezionabili', 'Device menu · inspectable JavaScript contexts'),
]:
    main(action, it, en, condition=condition, condition_en=condition_en,
         source=ENABLING if action.startswith('automatic') else DEVELOP)

# General inspector operations and appearance.
for action, it, en, keys in [
    ('toggle-inspector', 'Apri o chiudi Web Inspector', 'Open or close Web Inspector', ['Option+Command+I']),
    ('connect-inspector', 'Collega o scollega Web Inspector', 'Connect or disconnect Web Inspector', ['Option+Shift+Command+I']),
    ('open-resource', 'Vai a un file o a una risorsa', 'Go to a file or resource', ['Shift+Command+O', 'Command+P']),
    ('reload', 'Ricarica la pagina ispezionata', 'Reload the inspected page', ['Command+R']),
    ('reload-origin', 'Ricarica la pagina ispezionata dall’origine', 'Reload the inspected page from origin', ['Option+Command+R']),
    ('dock-previous', 'Ripristina la configurazione di ancoraggio precedente', 'Switch to the previous docking configuration', ['Shift+Command+D']),
    ('zoom-in', 'Aumenta lo zoom di Web Inspector', 'Increase Web Inspector zoom', ['Command++', 'Shift+Command++']),
    ('zoom-out', 'Riduci lo zoom di Web Inspector', 'Decrease Web Inspector zoom', ['Command+-', 'Shift+Command+-']),
    ('zoom-reset', 'Ripristina lo zoom di Web Inspector', 'Reset Web Inspector zoom', ['Command+0']),
]: inspector(action,it,en,keys,'Finestra di Web Inspector','Web Inspector window','Web Inspector','Web Inspector')

for action,it,en,keys,ctx,ctx_en in [
    ('find','Mostra la barra di ricerca','Show the find bar',['Command+F'],'Contenuto ricercabile','Searchable content'),
    ('find-selection','Usa la selezione per la ricerca','Use the selection for finding',['Command+E'],'Testo selezionato','Selected text'),
    ('find-hide','Nascondi la barra di ricerca','Hide the find bar',['Escape'],'Barra di ricerca attiva','Focused find bar'),
    ('find-next','Trova la corrispondenza successiva','Find the next match',['Command+G'],'Ricerca · scrittura da sinistra a destra o da destra a sinistra','Find · left-to-right or right-to-left writing direction'),
    ('find-previous','Trova la corrispondenza precedente','Find the previous match',['Shift+Command+G'],'Ricerca · scrittura da sinistra a destra o da destra a sinistra','Find · left-to-right or right-to-left writing direction'),
    ('search-resources','Cerca in tutti i file e le risorse','Search all files and resources',['Shift+Command+F'],'Ricerca nelle risorse','Resource search'),
]: inspector(action,it,en,keys,ctx,ctx_en,'Ricerca in Web Inspector','Web Inspector search')

for action,it,en,key,ctx,ctx_en in [
    ('tree-previous','Seleziona il nodo fratello precedente','Select the previous sibling node','Up','Nodo selezionato','Selected node'),
    ('tree-next','Seleziona il nodo fratello successivo','Select the next sibling node','Down','Nodo selezionato','Selected node'),
    ('tree-first-child','Seleziona il primo nodo figlio','Select the first child node','Right','Nodo selezionato espanso','Expanded selected node'),
    ('tree-collapse','Comprimi i nodi figli','Collapse child nodes','Left','Nodo selezionato espanso','Expanded selected node'),
    ('tree-collapse-recursive','Comprimi ricorsivamente i nodi figli','Recursively collapse child nodes','Option+Left','Nodo selezionato espanso','Expanded selected node'),
    ('tree-expand','Espandi i nodi figli','Expand child nodes','Right','Nodo selezionato compresso','Collapsed selected node'),
    ('tree-parent','Seleziona il nodo genitore','Select the parent node','Left','Nodo selezionato compresso','Collapsed selected node'),
    ('tree-expand-parent','Espandi ricorsivamente il nodo genitore','Recursively expand the parent node','Option+Right','Nodo selezionato compresso','Collapsed selected node'),
    ('tree-toggle','Attiva o disattiva il nodo','Enable or disable the node','Space','Nodo disattivabile selezionato','Selected node supports disabling'),
    ('tree-edit','Inizia a modificare il nodo','Start editing the node','Return','Nodo modificabile selezionato','Selected node supports editing'),
    ('tree-remove','Rimuovi il nodo selezionato','Remove the selected node','Delete','Nodo rimovibile selezionato','Selected node supports removal'),
]: inspector(action,it,en,[key],'Struttura ad albero · '+ctx,'Tree outline · '+ctx_en,'Strutture ad albero','Tree outlines')

for action,it,en,keys in [
    ('editor-undo','Annulla la modifica al codice','Undo the code edit',['Command+Z']),
    ('editor-redo','Ripristina la modifica al codice','Redo the code edit',['Shift+Command+Z']),
    ('editor-copy','Copia il testo nell’editor','Copy text in the editor',['Command+C']),
    ('editor-cut','Taglia il testo nell’editor','Cut text in the editor',['Command+X']),
    ('editor-paste','Incolla il testo nell’editor','Paste text in the editor',['Command+V']),
    ('editor-select-all','Seleziona tutto il testo nell’editor','Select all text in the editor',['Command+A']),
    ('editor-comment','Commenta o decommenta la riga di codice','Comment or uncomment the code line',['Command+/']),
    ('editor-line','Vai a una riga di codice','Go to a code line',['Control+G']),
    ('editor-next-character','Vai al carattere successivo','Go to the next character',['Right']),
    ('editor-previous-character','Vai al carattere precedente','Go to the previous character',['Left']),
    ('editor-next-word','Vai alla parola successiva','Go to the next word',['Option+Right']),
    ('editor-previous-word','Vai alla parola precedente','Go to the previous word',['Option+Left']),
    ('editor-line-start','Vai all’inizio della riga di codice','Go to the start of the code line',['Command+Left','Control+A']),
    ('editor-line-end','Vai alla fine della riga di codice','Go to the end of the code line',['Command+Right','Control+E']),
    ('editor-next-line','Vai alla riga di codice successiva','Go to the next code line',['Down']),
    ('editor-previous-line','Vai alla riga di codice precedente','Go to the previous code line',['Up']),
    ('editor-file-start','Vai all’inizio del file di codice','Go to the start of the code file',['Command+Up','Control+Up']),
    ('editor-file-end','Vai alla fine del file di codice','Go to the end of the code file',['Command+Down','Control+Down']),
    ('editor-select-next-character','Seleziona il carattere successivo','Select the next character',['Shift+Right']),
    ('editor-select-previous-character','Seleziona il carattere precedente','Select the previous character',['Shift+Left']),
    ('editor-select-next-word','Seleziona la parola successiva','Select the next word',['Shift+Option+Right']),
    ('editor-select-previous-word','Seleziona la parola precedente','Select the previous word',['Shift+Option+Left']),
    ('editor-select-line-start','Seleziona fino all’inizio della riga di codice','Select to the start of the code line',['Shift+Command+Left','Shift+Control+A']),
    ('editor-select-line-end','Seleziona fino alla fine della riga di codice','Select to the end of the code line',['Shift+Command+Right','Shift+Control+E']),
    ('editor-select-next-line','Estendi la selezione alla riga successiva','Extend the selection to the next line',['Shift+Down']),
    ('editor-select-previous-line','Estendi la selezione alla riga precedente','Extend the selection to the previous line',['Shift+Up']),
    ('editor-select-file-start','Seleziona fino all’inizio del file di codice','Select to the start of the code file',['Shift+Command+Up','Shift+Control+Up']),
    ('editor-select-file-end','Seleziona fino alla fine del file di codice','Select to the end of the code file',['Shift+Command+Down','Shift+Control+Down']),
    ('editor-next-occurrence','Seleziona l’occorrenza successiva della selezione attuale','Select the next occurrence of the current selection',['Command+D']),
]: inspector(action,it,en,keys,'Editor di testo attivo','Focused text editor','Editor di Web Inspector','Web Inspector editor')
for step,key in [(1,'Option+Up'),(-1,'Option+Down'),(10,'Shift+Option+Up'),(-10,'Shift+Option+Down')]:
    inspector('editor-number-'+str(step),'Modifica il numero di '+f'{step:+d}','Change the number by '+f'{step:+d}',[key],
              'Editor di testo · cursore su un numero','Text editor · cursor on a number','Editor di Web Inspector','Web Inspector editor')
inspector('editor-number-drag','Regola un numero trascinando','Adjust a number by dragging',[],
          'Editor di testo · puntatore su un numero','Text editor · pointer over a number','Editor di Web Inspector','Web Inspector editor',
          gesture='Opzione + trascina',gesture_en='Option + drag')

for action,it,en,keys in [
    ('content-save','Salva la risorsa visualizzata','Save the displayed resource',['Command+S']),
    ('content-save-as','Salva la risorsa visualizzata con un altro nome','Save the displayed resource as',['Shift+Command+S']),
    ('sidebar-navigation','Mostra o nascondi la barra laterale di navigazione','Show or hide the navigation sidebar',['Shift+Command+0']),
    ('sidebar-details','Mostra o nascondi la barra laterale dei dettagli','Show or hide the details sidebar',['Option+Command+0']),
]: inspector(action,it,en,keys,'Browser dei contenuti','Content browser','Browser dei contenuti','Content browser')
for direction,ctx,ctx_en,back,forward in [
    ('ltr','Scrittura da sinistra a destra','Left-to-right writing direction','Left','Right'),
    ('rtl','Scrittura da destra a sinistra','Right-to-left writing direction','Right','Left'),
]:
    inspector('content-back-'+direction,'Torna alla risorsa precedente','Go back to the previous resource',['Control+Command+'+back],
              'Browser dei contenuti · '+ctx,'Content browser · '+ctx_en,'Browser dei contenuti','Content browser')
    inspector('content-forward-'+direction,'Vai alla risorsa successiva','Go forward to the next resource',['Control+Command+'+forward],
              'Browser dei contenuti · '+ctx,'Content browser · '+ctx_en,'Browser dei contenuti','Content browser')

for action,it,en,keys,ctx,ctx_en in [
    ('console-focus','Porta il focus al prompt della console','Focus the console prompt',['Escape','Control+`'],'Prompt della console','Console prompt'),
    ('console-toggle','Espandi o comprimi la console rapida','Expand or collapse Quick Console',['Escape'],'Scheda che supporta la console divisa','Tab supporting the Split Console'),
    ('console-clear','Svuota il registro della console','Clear the console log',['Command+K','Control+L'],'Registro della console','Console message log'),
    ('console-select-all','Seleziona tutti i messaggi della console','Select all console messages',['Command+A'],'Messaggi della console','Console messages'),
    ('console-deselect','Annulla la selezione dei messaggi','Clear the message selection',['Escape'],'Messaggi della console selezionati','Selected console messages'),
]: inspector(action,it,en,keys,ctx,ctx_en,'Console rapida','Quick Console')

for number in range(1,10):
    inspector('tab-'+str(number),'Apri la scheda '+str(number)+' di Web Inspector','Open Web Inspector tab '+str(number),['Option+Command+'+str(number)],
              'Navigazione tra le schede','Tab navigation','Schede di Web Inspector','Web Inspector tabs')
for direction,ctx,ctx_en,nextkeys,prevkeys in [
    ('ltr','Scrittura da sinistra a destra','Left-to-right writing direction',['Shift+Command+}','Control+Tab','Shift+Command+Right'],['Shift+Command+{','Control+Shift+Tab','Shift+Command+Left']),
    ('rtl','Scrittura da destra a sinistra','Right-to-left writing direction',['Shift+Command+{','Control+Shift+Tab','Shift+Command+Left'],['Shift+Command+}','Control+Tab','Shift+Command+Right']),
]:
    inspector('tab-next-'+direction,'Mostra la scheda successiva di Web Inspector','Show the next Web Inspector tab',nextkeys,ctx,ctx_en,'Schede di Web Inspector','Web Inspector tabs')
    inspector('tab-previous-'+direction,'Mostra la scheda precedente di Web Inspector','Show the previous Web Inspector tab',prevkeys,ctx,ctx_en,'Schede di Web Inspector','Web Inspector tabs')

for action,it,en,keys,ctx,ctx_en in [
    ('elements-select','Attiva o disattiva la selezione degli elementi DOM','Toggle DOM element selection',['Shift+Command+C'],'Struttura DOM','DOM tree'),
    ('elements-copy','Copia il nodo DOM','Copy the DOM node',['Command+C'],'Struttura DOM · un nodo selezionato','DOM tree · one selected node'),
    ('elements-paste','Incolla il nodo DOM','Paste the DOM node',['Command+V'],'Struttura DOM · un nodo selezionato','DOM tree · one selected node'),
    ('elements-hide','Nascondi gli elementi DOM selezionati','Hide the selected DOM elements',['H'],'Struttura DOM · uno o più nodi selezionati','DOM tree · one or more selected nodes'),
    ('elements-remove','Rimuovi gli elementi DOM selezionati','Remove the selected DOM elements',['Delete'],'Struttura DOM · uno o più nodi selezionati','DOM tree · one or more selected nodes'),
    ('styles-save','Salva gli stili CSS','Save CSS styles',['Command+S'],'Pannello Stili','Styles panel'),
    ('styles-save-as','Salva gli stili CSS con un altro nome','Save CSS styles as',['Shift+Command+S'],'Pannello Stili','Styles panel'),
    ('styles-comment','Commenta o decommenta la dichiarazione CSS','Comment or uncomment the CSS declaration',['Command+/'],'Pannello Stili','Styles panel'),
    ('styles-completions','Mostra o nascondi i completamenti CSS','Show or hide CSS completions',['Control+Space'],'Pannello Stili','Styles panel'),
]: inspector(action,it,en,keys,'Scheda Elementi · '+ctx,'Elements tab · '+ctx_en,'Elementi e CSS','Elements and CSS')
inspector('styles-show-source','Mostra la dichiarazione CSS nelle sorgenti','Show the CSS declaration in Sources',[],
          'Scheda Elementi · pannello Stili','Elements tab · Styles panel','Elementi e CSS','Elements and CSS',
          gesture='Comando + clic',gesture_en='Command + click')
for step,key in [('1','Up'),('-1','Down'),('0.1','Option+Up'),('-0.1','Option+Down'),('10','Shift+Up'),('-10','Shift+Down'),('100','Command+Up'),('-100','Command+Down')]:
    display = step if step.startswith('-') else '+'+step
    inspector('styles-number-'+step,'Modifica il numero CSS di '+display,'Change the CSS number by '+display,[key],
              'Pannello Stili · cursore su un numero','Styles panel · cursor on a number','Elementi e CSS','Elements and CSS')

for action,it,en,keys,ctx,ctx_en in [
    ('sources-tab','Mostra la scheda Sorgenti','Show the Sources tab',['Option+Command+A'],'Navigazione nelle sorgenti','Source navigation'),
    ('sources-page','Mostra il sorgente della pagina ispezionata','Show the inspected page source',['Option+Command+U'],'Navigazione nelle sorgenti','Source navigation'),
    ('debugger-breakpoints','Attiva o disattiva i punti di interruzione','Enable or disable breakpoints',['Command+Y'],'Debugger','Debugger'),
    ('debugger-pause','Metti in pausa o riprendi il debugger','Pause or resume the debugger',['Control+Command+Y','Command+\\'],'Debugger','Debugger'),
    ('debugger-over','Esegui la prossima istruzione senza entrare nelle funzioni','Step over the next instruction',["Command+'",'F6'],'Debugger in pausa','Paused debugger'),
    ('debugger-into','Esegui la prossima istruzione entrando nelle funzioni','Step into the next instruction',['Command+;','F7'],'Debugger in pausa','Paused debugger'),
    ('debugger-out','Completa la funzione corrente ed esci','Step out of the current function',['Shift+Command+;','F8'],'Debugger in pausa','Paused debugger'),
    ('debugger-step','Esegui un singolo passo del debugger','Take a single debugger step',["Shift+Command+'",'F9'],'Debugger in pausa','Paused debugger'),
    ('snippet-run','Esegui lo snippet della console selezionato','Run the selected console snippet',['Space','Return'],'Snippet della console selezionato','Selected console snippet'),
]: inspector(action,it,en,keys,'Scheda Sorgenti · '+ctx,'Sources tab · '+ctx_en,'Sorgenti e debugger','Sources and debugger')

for action,it,en,keys,ctx,ctx_en,section,section_en in [
    ('timeline-toggle','Avvia o interrompi la registrazione nella timeline','Start or stop recording in Timelines',['Space','Option+Shift+Command+T'],'Scheda Timeline','Timelines tab','Timeline','Timelines'),
    ('timeline-new','Avvia una nuova registrazione della timeline','Start a new timeline recording',['Shift+Space'],'Scheda Timeline','Timelines tab','Timeline','Timelines'),
    ('timeline-clear','Cancella la registrazione attiva della timeline','Clear the active timeline recording',['Command+K'],'Scheda Timeline · registrazione attiva','Timelines tab · active recording','Timeline','Timelines'),
    ('graphics-toggle','Avvia o interrompi la registrazione del canvas','Start or stop canvas recording',['Space'],'Scheda Grafica · canvas selezionato','Graphics tab · selected canvas','Grafica','Graphics'),
    ('graphics-frame','Registra un singolo fotogramma del canvas','Record a single canvas frame',['Shift+Space'],'Scheda Grafica · canvas selezionato','Graphics tab · selected canvas','Grafica','Graphics'),
    ('audit-toggle','Avvia o interrompi l’audit selezionato','Start or stop the selected audit',['Space'],'Scheda Audit · audit selezionato','Audit tab · selected audit','Audit','Audit'),
    ('console-tab','Apri la scheda Console','Open the Console tab',['Option+Command+C'],'Navigazione tra le schede','Tab navigation','Console','Console'),
    ('settings-tab','Apri le impostazioni di Web Inspector','Open Web Inspector settings',['Command+,'],'Navigazione tra le schede','Tab navigation','Impostazioni di Web Inspector','Web Inspector settings'),
]: inspector(action,it,en,keys,ctx,ctx_en,section,section_en)


def _register_context_components():
    """Keep translated fragments available when presentation recomposes context.

    Keyboard contexts are split on the same separator as L10n.components.
    Menu-only entries and pointer gestures retain their complete raw labels.
    Safari itself is an unchanged brand already supplied by the base catalog.
    """
    for row in MAIN + INSPECTOR:
        if not row[2]:
            continue
        pair = LOCALIZATIONS[row[3]]
        italian = pair['it'].split(' · ')
        english = pair['en'].split(' · ')
        assert len(italian) == len(english), row[3]
        for it, en in zip(italian, english):
            if it != 'Safari':
                t(it, en)


_register_context_components()


def _record(profile, prefix, entry):
    action, title, binding, context, section, note, source, *raw = entry
    strokes = parse(binding) if binding else []
    assert not binding or strokes, (action, binding)
    identity = hashlib.sha256((action+'|'+(binding or '')+'|'+context).encode()).hexdigest()[:16]
    return dict(id=prefix+identity, profile=profile, title=title, category=CATEGORY,
                strokes=strokes, context=context, section=section, source='catalog',
                sourceURL=source, actionID=profile+':'+action, enabled=None, note=note,
                rawBinding=(raw[0] if raw else MENU_ONLY_BINDING) if not binding else None)


def supplement(profiles, records):
    """Replace only this supplement's stable namespaces; retain unrelated data."""
    if 'safari' not in profiles:
        raise ValueError('Safari profile must exist before its developer supplement')
    records[:] = [r for r in records if not r['id'].startswith(('safari:developer:', 'safari-inspector:'))]
    records.extend(_record('safari', 'safari:developer:', row) for row in MAIN)
    records.extend(_record('safari-inspector', 'safari-inspector:', row) for row in INSPECTOR)
    profiles['safari']['note'] = SAFARI_NOTE
    profiles['safari']['sources'] = list(dict.fromkeys(profiles['safari'].get('sources', []) +
        [DEVELOP, APPLE_HELP, ENABLING, REFERENCE, MENU_IMAGE, RESPONSIVE]))
    # No Safari bundle ID: selection is explicit. The ordinary page profile
    # must never auto-select inspector-only commands merely because Safari runs.
    profiles['safari-inspector'] = dict(id='safari-inspector', name=INSPECTOR_NAME,
        bundleIDs=[], parent='safari', note=PROFILE_NOTE, sources=[REFERENCE, ENABLING, DEVELOP, INTERFACE])


def validate():
    profiles = {'safari': {'id': 'safari', 'name': 'Safari', 'bundleIDs': ['com.apple.Safari'], 'sources': []}}
    records = []
    supplement(profiles, records)
    first = json.dumps((profiles, records), ensure_ascii=False, sort_keys=True)
    supplement(profiles, records)
    assert first == json.dumps((profiles, records), ensure_ascii=False, sort_keys=True)
    assert len({r['id'] for r in records}) == len(records)
    assert all(r['enabled'] is None and r['context'] and r['sourceURL'] for r in records)
    for row in records:
        for field in ('title', 'category', 'context', 'section', 'note', 'rawBinding'):
            if row.get(field): assert row[field] in LOCALIZATIONS, (row['id'], field)
    assert all(v['it'].strip() and v['en'].strip() for v in LOCALIZATIONS.values())
    return {'safari': len(MAIN), 'safariKeyboard': sum(bool(r[2]) for r in MAIN),
            'inspector': len(INSPECTOR), 'inspectorKeyboard': sum(bool(r[2]) for r in INSPECTOR),
            'localizedStrings': len(LOCALIZATIONS)}


if __name__ == '__main__':
    result = validate()
    destination = Path(__file__).resolve().parents[1]/'Sources/ShortcutCore/Resources/Localization/catalog-safari.json'
    destination.write_text(json.dumps(LOCALIZATIONS, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, indent=2))
