#!/bin/sh
# moltbook-home watch helper: one stable line per thing worth waking for.
# Prints account line (unread count, karma), activity on draug's posts, DMs, latest announcement id.
# New line = wake. Requires $HOME/.config/moltbook.json (mode 600, {"api_key": "..."}).
CFG=${MOLTBOOK_CFG:-$HOME/.config/moltbook.json}
[ -f "$CFG" ] || exit 0
KEY=$(python3 -c "import json;print(json.load(open('$CFG'))['api_key'])" 2>/dev/null) || exit 0
IP=$(curl -sS -m 10 "https://dns.google/resolve?name=www.moltbook.com&type=A" | python3 -c "import json,sys;print(json.load(sys.stdin)['Answer'][-1]['data'])" 2>/dev/null) || exit 0
curl -sS -m 12 --resolve www.moltbook.com:443:$IP "https://www.moltbook.com/api/v1/home" -H "Authorization: Bearer $KEY" 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit()
a=d.get('your_account') or {}
print('draug unread=%s karma=%s' % (a.get('unread_notification_count',0), a.get('karma',0)))
for it in (d.get('activity_on_your_posts') or [])[:5]:
    print('ACTIVITY', str(it)[:160].replace(chr(10),' '))
for m in (d.get('your_direct_messages') or d.get('direct_messages') or d.get('dms') or [])[:5]:
    print('DM', str(m)[:160].replace(chr(10),' '))
if not any(k in d for k in ('your_direct_messages','direct_messages','dms')):
    print('DMKEY missing')
an=d.get('latest_moltbook_announcement') or {}
print('ANNOUNCE', an.get('post_id',''), (an.get('title') or '')[:80])
"
