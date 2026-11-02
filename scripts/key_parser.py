import re
mods={'command':1,'cmd':1,'comando':1,'⌘':1,'option':2,'alt':2,'opzione':2,'⌥':2,'control':4,'ctrl':4,'controllo':4,'⌃':4,'shift':8,'maiuscole':8,'⇧':8,'fn':16,'function':16,'meta':2}
keymap={'up':'Up','up arrow':'Up','freccia su':'Up','freccia in su':'Up','↑':'Up','down':'Down','down arrow':'Down','freccia giù':'Down','freccia in giù':'Down','↓':'Down','left':'Left','left arrow':'Left','freccia sinistra':'Left','←':'Left','right':'Right','right arrow':'Right','freccia destra':'Right','→':'Right','tab':'Tab','tab key':'Tab','tabulatore':'Tab','tabulazione':'Tab','return':'Return','enter':'Return','invio':'Return','a capo':'Return','esc':'Escape','escape':'Escape','space':'Space','spacebar':'Space','barra spaziatrice':'Space','backspace':'Delete','delete':'Delete','canc':'Delete','cancella':'Delete','forward delete':'ForwardDelete','page up':'PageUp','pageup':'PageUp','pagina su':'PageUp','page down':'PageDown','pagedown':'PageDown','pagina giù':'PageDown','home':'Home','inizio':'Home','end':'End','fine':'End','plus':'+' ,'minus':'-','virgola':',','punto':'.','punto e virgola':';','trattino':'-','uguale':'=','comma':',','period':'.','backtick':'`','backslash':'\\'}

def parse_one(s):
 s=s.strip().replace('\u2060','').replace('\u200b','').replace('\xa0',' ')
 s=re.sub(r'\s*\*+$','',s)
 # Notes in parentheses often name a literal key, preserve it.
 s=re.sub(r'(?:Right angle bracket|Left angle bracket|Right bracket|Left bracket|Plus|Minus|Comma|Period|Semicolon)\s*\((.)\)',r'\1',s,flags=re.I)
 s=re.sub(r'\s+(?:key|tasto)$','',s,flags=re.I)
 # Adjacent symbols do not require a separator.
 s=re.sub(r'([⌘⌥⌃⇧])\s*\+?\s*',r'\1+',s)
 s=re.sub(r'\s*\+\s*','+',s)
 s=s.replace('–','-').replace('—','-')
 s=re.sub(r'(?:Cmd\s+Command|Command\s+Cmd)', 'Command', s, flags=re.I)
 bits=0
 while True:
  found=False
  for token,b in mods.items():
   m=re.match(re.escape(token)+r'(?:\s*[-+]\s*|\s+)',s,re.I)
   if m:bits|=b;s=s[m.end():];found=True;break
  if not found:break
 s=s.strip()
 named=re.fullmatch(r'[^()]+\(\s*(.)\s*\)',s)
 if named:s=named.group(1)
 s=re.sub(r'\s+key$','',s,flags=re.I)
 # Single key, including a literal plus or minus.
 if s.lower() in keymap:k=keymap[s.lower()]
 elif len(s)==1:k=s.upper()
 elif re.fullmatch(r'F(?:[1-9]|1[0-9]|2[0-4])',s,re.I):k=s.upper()
 else:return None
 return {'key':k,'modifiers':bits}

def parse(s):
 one=parse_one(s)
 if one:return [one]
 pieces=re.split(r'\s+(?=(?:Ctrl|Control|Cmd|Command|Alt|Option|Shift|Meta)\+|[⌘⌥⌃⇧])|\s*→\s*',s)
 if len(pieces)==1:pieces=s.split()
 parsed=[parse_one(p) for p in pieces]
 return parsed if len(parsed)>1 and all(parsed) else []
