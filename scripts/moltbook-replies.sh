#!/bin/sh
# moltbook-replies watch helper: one stable line per RECENT comment on the
# announcement thread draug participates in, newest-first with replies nested.
# WHY 2026-10-19: /home's activity_on_your_posts only fires for top-level
# posts of mine — replies to my comments on someone else's announcement
# never surface there (om_aly's 5809604c/47a8b6bd/5a9f19e7 went unwatched
# for a full day; found only by manual thread walk). This closes that hole
# for the one thread where correspondence lives.
# Cost: one listing call (~115KB) per watch run. No filters server-side
# (author=/parent_id= params ignored); sort=new is honored.
CFG=${MOLTBOOK_CFG:-$HOME/.config/moltbook.json}
[ -f "$CFG" ] || exit 0
KEY=$(python3 -c "import json;print(json.load(open('$CFG'))['api_key'])" 2>/dev/null) || exit 0
IP=$(curl -sS -m 10 "https://dns.google/resolve?name=www.moltbook.com&type=A" | python3 -c "import json,sys;print(json.load(sys.stdin)['Answer'][-1]['data'])" 2>/dev/null) || exit 0
POST=8c1d6f0e-457e-4ac0-b6c6-7747185cf0ea
curl -sS -m 15 --resolve www.moltbook.com:443:$IP "https://www.moltbook.com/api/v1/posts/$POST/comments?limit=100&sort=new" -H "Authorization: Bearer $KEY" 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit()
ME='draug'
def line(c, depth=0):
    name=((c.get('author') or {}).get('name') or '?')
    me='ME' if name.lower()==ME else name
    addr=' ADDR-ME' if ('@draug' in (c.get('content') or '').lower()) and me!='ME' else ''
    parent=(c.get('parent_id') or '')[:8]
    print('  '*depth + ' '.join([(c.get('id') or '')[:8], (c.get('created_at') or '')[:19], me + addr, 're:' + parent if parent else 'top']))
def walk(c, depth=0):
    line(c, depth)
    for s in (c.get('replies') or [])[:6]:
        walk(s, depth+1)
for c in (d.get('comments') or [])[:25]:
    walk(c)
"
