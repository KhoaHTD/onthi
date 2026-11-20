import pdfplumber, re, unicodedata, json, collections, sys
pdf = pdfplumber.open(sys.argv[1])
DOT = '̣'
lines = []  # (num, body, ans)
xs = collections.Counter()
for pi, p in enumerate(pdf.pages):
    chars = [c for c in p.chars if 55 < c['top'] < p.height - 40]
    # fix unmapped dot-below
    fixed = []
    for i, c in enumerate(chars):
        if c['text'] == 'ẹ' and not (i + 1 < len(chars) and chars[i + 1]['text'] == ''):
            c = dict(c); c['text'] = 'e'
        elif c['text'] == 'ẹ':
            fixed.append(c); continue
        if c['text'] == '':
            if fixed and fixed[-1]['text'] and fixed[-1]['text'][-1] in 'aeiouyAEIOUY':
                fixed[-1] = dict(fixed[-1]); fixed[-1]['text'] += DOT
            continue
        fixed.append(c)
    rows = collections.defaultdict(list)
    for c in fixed:
        key = round(c['top'])
        rows[key].append(c)
    # merge adjacent keys
    keys = sorted(rows)
    merged = []
    for k in keys:
        if merged and k - merged[-1][0] <= 3:
            merged[-1][1].extend(rows[k])
        else:
            merged.append([k, list(rows[k])])
    for k, cs in merged:
        cs.sort(key=lambda c: c['x0'])
        cols = {'num': '', 'body': '', 'ans': ''}
        for c in cs:
            col = 'num' if c['x0'] < 50 else ('body' if c['x0'] < 359 else 'ans')
            if col == 'ans' and c['text'].strip(): xs[round(c['x0'])] += 1
            cols[col] += c['text']
        lines.append({k2: unicodedata.normalize('NFC', v).strip() for k2, v in cols.items()} | {'page': pi + 1})

qs = []
cur = None
for l in lines:
    m = re.match(r'^(\d+)\.$', l['num'])
    if m:
        cur = {'n': int(m.group(1)), 'body': [], 'ans': ''}
        qs.append(cur)
    if cur is None: continue
    if l['ans']: cur['ans'] += (' ' if cur['ans'] else '') + l['ans']
    if l['body']: cur['body'].append(l['body'])

out = []; bad = []
for q in qs:
    text_parts = []; opts = []
    for b in q['body']:
        b = b.replace('Α','A').replace('Β','B').replace('Ε','E')
        m = re.match(r'^([A-Fa-f])\.\s*(.*)$', b)
        if m and (not opts and m.group(1).lower() == 'a' or opts and ord(m.group(1).lower()) == ord(opts[-1][0]) + 1):
            opts.append([m.group(1).lower(), m.group(2)])
        elif opts:
            opts[-1][1] += ' ' + b
        else:
            text_parts.append(b)
    qtext = re.sub(r'\s+', ' ', ' '.join(text_parts)).strip()
    qtext = re.sub(r'\s*\(\s*NHUNG\s*HOÀNG\s*\)\s*', ' ', qtext).strip()
    raw = q['ans'].strip()
    ans = raw[:1].lower(); note = raw[1:].strip()
    mm = re.match(r'^([A-E]{1,4})(?=\s|\(|$)\s*', note)
    if mm:
        ans += mm.group(1).lower(); note = note[mm.end():].strip()
    ans = ''.join(sorted(set(ans)))
    item = {'id': q['n'], 'q': qtext, 'opts': [re.sub(r'\s+', ' ', o[1]).strip() for o in opts], 'ans': ans, 'note': note}
    if not opts or len(opts)<2 or not ans or any(ord(a) - 97 >= len(opts) or ord(a) < 97 for a in ans):
        bad.append(item)
    out.append(item)
print('total', len(out), 'bad', len(bad), file=sys.stderr)
print('ans x0', sorted(xs.items())[:10], file=sys.stderr)
ids=[o['id'] for o in out]; print('missing',sorted(set(range(1,max(ids)+1))-set(ids)),'dups',[i for i in set(ids) if ids.count(i)>1],file=sys.stderr)
for b in bad: print(json.dumps(b, ensure_ascii=False), file=sys.stderr)
print(collections.Counter(len(o['opts']) for o in out), file=sys.stderr)
def clean(t):
    t = re.sub(r'\s*\(\s*NHUNG\s*HOÀNG\s*\)\s*', ' ', t)
    t = re.sub(r'\s*\(?\d{3}-\d{3}-\d{4}\)?\s*', ' ', t)
    return re.sub(r'\s+', ' ', t).strip()
for o in out:
    o['q'] = clean(o['q']); o['opts'] = [clean(x) for x in o['opts']]; o['note'] = clean(o['note'])
json.dump(out, open('questions.json', 'w'), ensure_ascii=False, indent=0)
