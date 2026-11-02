# Contributing / Contribuire

[English](#english) · [Italiano](#italiano)

## English

Thank you for helping improve Scorciatoie. Small, verifiable changes are useful: a corrected shortcut, a clearer translation, a reproducible bug report or an accessibility improvement.

### Report a problem

[Open an issue](https://github.com/giuucmp/scorciatoie/issues) with:

- macOS version, app version and Apple silicon/Intel architecture.
- The target app and its version, the exact command and keys, and where you expected it to appear.
- Steps to reproduce, expected behavior and actual behavior.
- Whether the entry comes from live menus, the offline catalog or an imported binding, if known.

Remove private document names, message contents and credentials from screenshots or logs. Do not include your full personal keybinding files unless you have reviewed them.

### Build and check

Use Swift 6+ and the macOS 26 SDK from Xcode 26 or equivalent Command Line Tools. The built app targets macOS 13+. Fork the repository, create a branch, then run:

```sh
./scripts/check.sh
python3 scripts/test_key_parser.py
python3 scripts/test_category_classifier.py
./Tests/PackagedResourcesChecks/run.sh
./scripts/build-app.sh
```

For a universal Apple silicon/Intel build and DMG, run `UNIVERSAL=1 ./scripts/build-app.sh`, then `./scripts/package-dmg.sh`. Build output goes to `dist/`.

For changes to native glass rendering, also run `./scripts/check-glass.sh` on macOS 26+ with GPU access. The Swift checks are an executable test runner; a nonzero exit means a check failed.

The app’s main UI is in `Sources/Scorciatoie`; catalog, parsing and learning logic are in `Sources/ShortcutCore`. Keep the temporary overlay passive and click-through. Keyboard exercise input must stay scoped to the focused exercise, and reserved operating-system combinations must not be swallowed.

### Correct catalog data or translations

Provide an official documentation link, app/version information, or a reproducible live-menu observation. Preserve context, alternative key combinations and multi-step sequences. Do not turn an uncertain command into a guaranteed action or infer complete app coverage from a profile.

Translation dictionaries live in `Sources/ShortcutCore/Resources/Localization`. Preserve exact source keys, placeholders, command identifiers and shortcut meaning. Update both Italian and English where needed. Live third-party titles that are not in the dictionaries remain in their original language.

Catalog-building tools require Python and BeautifulSoup. Avoid regenerating unrelated data in a focused correction.

### Website

The website is static, with English at `/` and Italian at `/it/`. Edit the bilingual copy in `site/build.py` and shared styles/scripts in `site/assets`, then regenerate:

```sh
python3 site/build.py
python3 -m http.server 8765 --directory site
```

Check both languages, a narrow viewport, keyboard navigation and the modifier demo. Use real app captures for screenshots; do not present an HTML recreation as the app. Keep the site free of trackers, external fonts and unverified coverage claims.

### Pull requests and releases

Describe the problem, resulting behavior and checks you ran. Keep unrelated refactors separate and mention any check you could not run. Contributions are submitted under the [MIT license](LICENSE).

Before a public release, maintainers must verify the built architectures, minimum macOS version, localized screenshots, download filename and links. The current release is distributed without Developer ID signing or notarization; preserve that disclosure and the normal macOS installation instructions. Do not add commands that bypass Gatekeeper.

## Italiano

Grazie per il contributo a Scorciatoie. Sono utili anche modifiche piccole e verificabili: una combinazione corretta, una traduzione più chiara, un problema riproducibile o un miglioramento dell’accessibilità.

### Segnalare un problema

[Apri una issue](https://github.com/giuucmp/scorciatoie/issues) indicando:

- Versione di macOS, versione dell’app e architettura Apple silicon/Intel.
- App interessata e relativa versione, comando e tasti esatti, punto in cui ti aspettavi di trovarlo.
- Passaggi per riprodurre il problema, comportamento atteso e comportamento osservato.
- Se noto, la provenienza della voce: menu live, catalogo offline o assegnazione importata.

Rimuovi nomi di documenti privati, contenuti dei messaggi e credenziali da immagini e log. Non includere file completi di assegnazioni personali senza averli controllati.

### Compilare e verificare

Usa Swift 6+ e l’SDK macOS 26 di Xcode 26 o degli strumenti a riga di comando equivalenti. L’app compilata supporta macOS 13+. Crea un fork e un branch, quindi esegui:

```sh
./scripts/check.sh
python3 scripts/test_key_parser.py
python3 scripts/test_category_classifier.py
./Tests/PackagedResourcesChecks/run.sh
./scripts/build-app.sh
```

Per una build universale Apple silicon/Intel e il DMG, esegui `UNIVERSAL=1 ./scripts/build-app.sh`, poi `./scripts/package-dmg.sh`. I file prodotti sono in `dist/`.

Per modifiche al rendering del vetro nativo, esegui anche `./scripts/check-glass.sh` su macOS 26+ con accesso alla GPU. I controlli Swift usano un eseguibile di test: un codice di uscita diverso da zero indica un controllo fallito.

L’interfaccia principale si trova in `Sources/Scorciatoie`; catalogo, parsing e logica di apprendimento sono in `Sources/ShortcutCore`. Il pannello temporaneo deve restare consultivo e lasciare passare i clic. L’acquisizione dei tasti negli esercizi deve essere limitata al campo attivo, senza consumare combinazioni riservate al sistema operativo.

### Correggere catalogo o traduzioni

Fornisci un collegamento alla documentazione ufficiale, le versioni delle app o un riscontro riproducibile nei menu live. Conserva contesto, combinazioni alternative e sequenze. Non trasformare un comando incerto in un’azione garantita e non dedurre una copertura completa dalla presenza di un profilo.

I dizionari delle traduzioni sono in `Sources/ShortcutCore/Resources/Localization`. Conserva esattamente chiavi sorgente, segnaposto, identificatori e significato delle scorciatoie. Aggiorna italiano e inglese dove necessario. I titoli live di terze parti assenti dai dizionari restano nella lingua originale.

Gli strumenti del catalogo richiedono Python e BeautifulSoup. Per una correzione mirata, evita di rigenerare dati non pertinenti.

### Sito

Il sito è statico: inglese in `/`, italiano in `/it/`. Modifica i testi bilingui in `site/build.py` e gli stili/script condivisi in `site/assets`, poi rigenera:

```sh
python3 site/build.py
python3 -m http.server 8765 --directory site
```

Controlla entrambe le lingue, un formato stretto, la navigazione da tastiera e la demo dei modificatori. Usa catture reali dell’app per le immagini; non presentare una ricostruzione HTML come se fosse l’app. Mantieni il sito privo di tracciamenti, font esterni e affermazioni di copertura non verificate.

### Pull request e rilasci

Descrivi il problema, il comportamento risultante e i controlli eseguiti. Separa i refactoring non correlati e segnala i controlli che non hai potuto eseguire. I contributi vengono forniti con [licenza MIT](LICENSE).

Prima di un rilascio pubblico, chi mantiene il progetto deve verificare architetture della build, versione minima di macOS, schermate localizzate, nome del file scaricabile e collegamenti. Il rilascio attuale viene distribuito senza firma Developer ID e senza notarizzazione: conserva questa indicazione e le normali istruzioni di installazione macOS. Non aggiungere comandi per aggirare Gatekeeper.
