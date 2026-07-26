---
name: Suno-Automation
description: Drive Suno (suno.com) to generate songs by remote-controlling a logged-in browser via the Browser Bridge — connect the bridge client, fill Song Title / Styles / Lyrics on /create, press Create (Cloudflare Turnstile auto-solves on the real domain), and verify generation. Covers the Lexical lyrics editor technique, the Turnstile domain-lock, the copyright filter, and the console eager-eval connection-storm gotcha. Use when asked to make/generate a song on Suno, automate Suno, or fill the Suno create form programmatically.
---

# Suno Automation via the Browser Bridge

Generate songs on **Suno** by driving a real, logged-in browser tab with the
[[BrowserBridge]] broker. You submit JS jobs to the broker; the tab evals them and returns
results. This fills the Create form and presses Create for you.

## The one hard rule: it MUST be the real `suno.com`

Generation is gated by **Cloudflare Turnstile** (`POST /api/c/check` →
`{"required":true,"captcha_version":2}`). Turnstile's sitekey is allowlisted to `suno.com`
hostnames in Suno's Cloudflare dashboard. On **any other domain** (e.g. a reverse proxy)
`turnstile.render` returns **error `110200` (domain not allowed)** and generation hangs
forever. Suno's backend also verifies the token's hostname server-side, so there is no spoof.
➡️ **Drive the genuine `https://suno.com`, in a browser already logged into the account.**
(Everything else — Clerk auth, the studio-api data API — a proxy can fake; the Turnstile wall
it cannot. Don't waste time on a proxy for generation.)

## 1. Connect the bridge client to a suno.com tab

The bridge is not injected on suno.com (it's a third-party site), so load `client.js` manually.
suno.com's CSP is permissive (`frame-ancestors 'none'; font-src 'self'` — no `script-src`/
`connect-src`), so this just works. In the suno.com tab's **DevTools Console**, paste this
**guarded** snippet (the guard is essential — see Gotchas):

```js
if(!window.__bridgeLoaded){window.__bridgeLoaded=true;window.__BRIDGE_URL='wss://dw.ramsden-international.com/bridge/ws';window.__BRIDGE_TOKEN='<BRIDGE_TOKEN>';var s=document.createElement('script');s.src='https://dw.ramsden-international.com/bridge/client.js?_='+Date.now();document.head.appendChild(s);}
```

Console shows `[Bridge] Connected`. As a reusable bookmarklet, prefix with `javascript:` and
wrap in `(function(){...})()` — but create it via the Bookmarks *manager*, not the address bar
(Chromium/Vivaldi strips the `javascript:` prefix when pasted into the address bar).

Verify from the broker (`<BRIDGE_TOKEN>` is the broker's `BRIDGE_TOKEN` env var — `systemctl show browser-bridge-broker -p Environment` on dw, or see the BrowserBridge skill):
```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3141/workers \
  | jq -r '.workers[]|select(.host=="suno.com")|"\(.connectionId)  \(.url)"'
```

## 2. Target the tab robustly (ids churn)

The worker `connectionId` changes on **every navigation/reload**, and jobs fail with
"no browser connected" if you target a stale one. Never hardcode an id — always look up the
*current* suno.com worker and retry. Drop this helper in and reuse it:

```bash
cat > /tmp/run_suno.sh <<'SH'
#!/bin/bash
# run_suno.sh <script-file> [timeout-ms]  — evals JS on the current suno.com tab, retries
# Requires TOKEN env var = the broker's BRIDGE_TOKEN (see BrowserBridge skill)
SCRIPT="$1"; TMO="${2:-15000}"
for i in $(seq 1 6); do
  W=$(curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3141/workers \
      | jq -r '.workers[]|select(.host=="suno.com")|.connectionId' | head -1)
  [ -z "$W" ] && { sleep 2; continue; }
  jq -Rs --arg t "$W" --argjson to "$TMO" '{target:$t,timeout:$to,script:.}' "$SCRIPT" > /tmp/_sj.json
  R=$(curl -s -XPOST http://localhost:3141/jobs/sync -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' --max-time $((TMO/1000+8)) -d @/tmp/_sj.json)
  echo "$R" | grep -q 'no browser connected' && { sleep 2; continue; }
  echo "$R" | jq -r '.result, (.error//empty)'; exit 0
done
echo "NO_SUNO_TAB"
SH
chmod +x /tmp/run_suno.sh
```

## 3. Navigate to /create (SOFT nav only)

A hard reload (`location.href=`, `location.reload()`) **drops the bridge** on suno.com (no
server-side re-injection). Navigate client-side by clicking a Next `<Link>`:

```js
// /tmp/goto_create.js
const a=[...document.querySelectorAll('a[href="/create"],a[href*="/create"]')].filter(e=>e.offsetParent!==null)[0];
if(a){a.click();await new Promise(r=>setTimeout(r,1800));return location.pathname;}
return 'no /create link; path='+location.pathname;
```
`/tmp/run_suno.sh /tmp/goto_create.js`

## 4. Fill the form

Fields on `/create` (custom mode). **Song Title** and **Styles** are React-controlled inputs —
set them with the native value setter then dispatch `input`+`change`. **Lyrics** is a **Lexical**
rich editor: DOM edits (`execCommand`, synthetic paste) only *append* because Lexical owns its
selection — instead grab the editor instance at `el.__lexicalEditor` and `setEditorState`.

**Fill order matters:** set Lyrics and Styles *before* Title. Lexical's `setEditorState` on the
lyrics editor triggers a re-render that clobbers the Title input if it was already set —
filling title last (and re-verifying it after the lyrics write) avoids a silent revert to empty.

```js
// /tmp/fill.js  — edit TITLE / STYLES / LINES to taste
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function setNative(el,val,proto){const s=Object.getOwnPropertyDescriptor(proto,'value').set;s.call(el,val);el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}
const TITLE='My Song';
const STYLES='dreamy synthwave, warm analog pads, 80s';
const LINES=['[Verse]','first line','second line','','[Chorus]','hook line one','hook line two']; // '' = blank line
const out={};
let st=document.querySelector('textarea[maxlength="1000"]');            // Styles (Exclude-styles is an <input>, not textarea)
if(st){st.focus();setNative(st,STYLES,HTMLTextAreaElement.prototype);out.styles=st.value;}
let l=document.querySelector('[aria-label="Lyrics editor"]');
if(l&&l.__lexicalEditor){
  const para=x=>({type:'paragraph',version:1,format:'',indent:0,direction:'ltr',children:x?[{type:'text',version:1,text:x,format:0,style:'',mode:'normal',detail:0}]:[]});
  const state={root:{type:'root',version:1,format:'',indent:0,direction:'ltr',children:LINES.map(para)}};
  const ed=l.__lexicalEditor; ed.setEditorState(ed.parseEditorState(JSON.stringify(state)));
  await sleep(200); out.lyrics=l.innerText.slice(0,60);
}
let t=[...document.querySelectorAll('input[placeholder^="Song Title"]')].filter(e=>e.offsetParent!==null)[0]||document.querySelector('input[placeholder^="Song Title"]');
if(t){t.focus();setNative(t,TITLE,HTMLInputElement.prototype);out.title=t.value;}
return JSON.stringify(out,null,2);
```
`/tmp/run_suno.sh /tmp/fill.js`

## 5. Press Create (Turnstile solves itself)

```js
// /tmp/create.js
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
window.__gen=[];
const _f=window.fetch;
window.fetch=async function(i,init){const u=(typeof i==='string'?i:(i&&i.url))||'';const r=await _f.apply(this,arguments);if(/generate\/v2|c\/check/i.test(u)){try{const b=/generate\/v2/.test(u)?(await r.clone().text()).slice(0,160):'';window.__gen.push(r.status+' '+u.replace(/^https?:\/\/[^/]+/,'').slice(0,40)+(b?' :: '+b:''));}catch(e){}}return r;};
const btn=[...document.querySelectorAll('button')].find(b=>/create song/i.test(b.getAttribute('aria-label')||'')&&b.offsetParent!==null);
if(!btn) return 'no Create button';
btn.click();
await sleep(9000);
return JSON.stringify(window.__gen,null,2);
```
`/tmp/run_suno.sh /tmp/create.js 22000`

Success looks like: `200 /api/c/check` then `200 /api/generate/v2-web/ :: {"id":"…","clips":[{"status":"submitted","title":"…"}]}`. Two variants render.

## 6. Verify generation

Watch progress, or poll the feed. Statuses go `submitted` → `streaming` → `complete`
(feed lags a few seconds behind the workspace). A session token for direct API reads comes from
Clerk in-page: `await window.Clerk.session.getToken()`.

```js
// /tmp/verify.js
const tok=await window.Clerk.session.getToken();
const d=await (await fetch('https://studio-api-prod.suno.com/api/feed/v2?page=0&_='+Date.now(),{headers:{Authorization:'Bearer '+tok}})).json();
const mine=(d.clips||[]).filter(c=>/My Song/i.test(c.title||'')).slice(0,4).map(c=>({id:(c.id||'').slice(0,8),status:c.status,title:c.title}));
const prog=[...document.querySelectorAll('*')].filter(e=>e.children.length===0&&/^\d{1,3}%$/.test((e.textContent||'').trim())).map(e=>e.textContent.trim());
return JSON.stringify({mine,progress:prog},null,2);
```

Read-only Suno data (library, billing, projects) is available the same way — call
`https://studio-api-prod.suno.com/api/...` with the `Bearer` token; no Turnstile needed for reads.

## Gotchas (each cost real time to learn)

- **Turnstile domain-lock (110200):** generation only works on real `suno.com`. Non-negotiable.
- **Title reverts to empty:** filling Title before Lyrics loses the title — the Lexical
  `setEditorState` call re-renders the form and clobbers it. Fill Styles + Lyrics first, Title
  last, and verify all three values right before pressing Create.
- **Copyright filter:** Suno kills generations whose lyrics match known copyrighted material —
  and it false-flags short/rhyme-y original lines. If a run dies "copyrighted", retry with
  clearly-original, quirky lyrics, or clear lyrics and go instrumental (style only).
- **Console eager-eval storm:** DevTools "Eager evaluation" *executes* a pasted side-effecting
  snippet repeatedly while previewing it. Pasting an *unguarded* loader spawns a new bridge
  client several times a second until it hits the broker's 99-connection cap and jams
  everything. ALWAYS use the `if(!window.__bridgeLoaded)` guard above. To recover from a storm:
  fully **close** the offending tab (a broker restart alone won't help — the instances live in
  the page and reconnect), then `sudo systemctl restart browser-bridge-broker` if needed.
- **Bridge drops on hard reload** (no server injection on suno.com) — soft-navigate only;
  re-run the loader if the page fully reloads.
- **~6-minute mass reconnect:** all bridge tabs blip-reconnect roughly every 6 min (Apache WS
  idle timeout). Normal; they re-attach in ~5s. Work in the stable windows.
- **Real credits:** every successful Create spends credits. Confirm with the user first.
- **Don't read "credits" from `/api/billing/info/`** — that field is a plan/tier number, not the
  balance shown in the UI.

## Selectors quick-reference (Suno /create, as of 2026-07)

| Field | Selector | How to set |
|-------|----------|-----------|
| Song Title | `input[placeholder^="Song Title"]` (visible) | native input setter + `input`/`change` |
| Styles | `textarea[maxlength="1000"]` | native textarea setter + events |
| Lyrics | `[aria-label="Lyrics editor"]` (Lexical) | `el.__lexicalEditor.setEditorState(...)` |
| Create button | `button[aria-label="Create song"]` | `.click()` |

Selectors may drift as Suno ships UI changes — re-enumerate
(`document.querySelectorAll('textarea, input, [contenteditable]')` with placeholders/aria) if a
selector misses.
