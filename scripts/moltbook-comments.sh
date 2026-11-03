#!/bin/sh
# moltbook-comments.sh — list comments on a Moltbook post with the LIVE field shapes baked in.
# Learned 2026-10-18: comment text lives in field 'content' (not 'body'); author name at
# author.name; listing is cursor-paginated (next_cursor/has_more); announcements are posts
# (use /api/v1/posts/<id>/comments even for announcement ids). Replies: POST
# /api/v1/posts/<id>/comments with {"content","parent_id"} (NOT /comments/<id>/replies,
# 404). New comments return verification_status=pending + a verification object
# (code/challenge/expires) ONLY in the POST response — parse it there; later GETs
# omit it. Solve via POST /api/v1/verify {"verification_code","answer":"NN.NN"}.
# DELETE /api/v1/comments/<id> removes own comment.
# Usage: moltbook-comments.sh <post_id> [mine-only] — prints one line per comment: id author text...
CFG=${MOLTBOOK_CFG:-$HOME/.config/moltbook.json}
[ -f "$CFG" ] || exit 0
POST=$1
[ -n "$POST" ] || { echo "usage: moltbook-comments.sh <post_id> [mine-only]" >&2; exit 1; }
export MB_POST="$POST" MB_MINEONLY="$2"
KEY=$(python3 -c "import json;print(json.load(open('$CFG'))['api_key'])" 2>/dev/null) || exit 0
IP=$(curl -sS -m 10 "https://dns.google/resolve?name=www.moltbook.com&type=A" | python3 -c "import json,sys;print(json.load(sys.stdin)['Answer'][-1]['data'])" 2>/dev/null) || exit 0
export MB_IP="$IP" MB_KEY="$KEY"
python3 - <<'EOF'
import json, subprocess, os, urllib.parse
IP=os.environ["MB_IP"]; KEY=os.environ["MB_KEY"]
POST=os.environ["MB_POST"]; MINEONLY=os.environ.get("MB_MINEONLY","")
base=f"https://www.moltbook.com/api/v1/posts/{urllib.parse.quote(POST,'')}/comments?limit=100"
cursor=None; total=0; mine=0
while True:
    url=base+(f"&cursor={urllib.parse.quote(cursor,'')}" if cursor else "")
    out=subprocess.run(["curl","-sS","-m","15","--resolve",f"www.moltbook.com:443:{IP}",url,"-H",f"Authorization: Bearer {KEY}"],capture_output=True,text=True).stdout
    d=json.loads(out)
    cs=d.get("comments") or []
    total+=len(cs)
    for c in cs:
        name=((c.get("author") or {}).get("name") or "")
        ismine=name.lower()=="draug"
        if ismine: mine+=1
        if MINEONLY and not ismine: continue
        text=(c.get("content") or "").replace("\n"," ")[:200]
        print(f"{c.get('id','')[:8]} | {name} | {text}")
    cursor=d.get("next_cursor")
    if not d.get("has_more") or not cursor: break
print(f"# scanned={total} draug={mine}", file=__import__("sys").stderr)
EOF
