---
name: BrowserBridge
description: Use when a task needs real-time control of a connected browser via the Browser Bridge Broker — submit JS jobs over HTTP that browsers eval and return.
---

# BrowserBridge — Browser Bridge Broker

A message broker for JavaScript jobs. **Clients** (you) submit JS over HTTP; connected
**browsers** running `browser-bridge-client.js` execute it with `eval` and the typed
result is routed back.

```
client ──HTTP──▶ broker ──WebSocket──▶ browser (eval) ──result──▶ broker ──▶ client
```

The broker is a zero-dependency Node server (`server.js`). Full docs live at
`GET /bridge/readme` (unauthenticated) and a machine-readable manifest at `GET /bridge/`.

## Endpoints & auth

Two base URLs point at the same broker:
- **Local:** `http://localhost:3141` (loopback, Apache fronts it)
- **Public:** `https://dw.ramsden-international.com/bridge` (through Apache, incl. the `/ws` WebSocket upgrade)

Auth: send `Authorization: Bearer <BRIDGE_TOKEN>` on **every** call except the
unauthenticated ones: `/`, `/readme`, `/health`, `/client.js`, `/status`.

The shared secret is the broker's `BRIDGE_TOKEN` env var. If you don't have it, ask the
user, or read it from the running unit (`systemctl show browser-bridge-broker -p Environment`).

| Method | Path         | Body                          | Behaviour |
|--------|--------------|-------------------------------|-----------|
| GET    | `/`          | —                             | Self-describing manifest (unauthenticated discovery). |
| GET    | `/readme`    | —                             | This README as Markdown (unauthenticated). |
| POST   | `/jobs/sync` | `{script, target?, timeout?}` | Dispatch and block until the result arrives. `503` if no browser, `408` on timeout. |
| POST   | `/jobs`      | `{script, target?}`           | Enqueue, return `{jobId}`. Runs now, or when a browser connects. |
| GET    | `/jobs/:id`  | —                             | Job status + result (`pending`/`dispatched`/`done`/`failed`/`expired`). |
| GET    | `/workers`   | —                             | Connected browsers: `connectionId`, `ip`, `url`, `host`, `path`, `title`. |
| GET    | `/health`    | —                             | `{status, workers, jobs}` (unauthenticated). |
| GET    | `/status`    | —                             | HTML dashboard (unauthenticated shell; paste token in-page). |

`target` is a specific `connectionId`; omit it to run on any one connected browser.

## Quick start

```bash
TOKEN=<BRIDGE_TOKEN>

# 1. Is the broker up and are any browsers connected?
curl -s http://localhost:3141/health          # {"status":"ok","workers":N,"jobs":M}

# 2. Which browsers / pages are connected (need the right one before targeting)?
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3141/workers

# 3. Run JS on any connected browser (blocks until result):
curl -s -XPOST http://localhost:3141/jobs/sync \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"script":"document.title"}'

# 4. Target a specific tab by connectionId:
curl -s -XPOST http://localhost:3141/jobs/sync \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"script":"document.title","target":"proxy_1783..._abc"}'
```

The public URL works identically — swap the base for `https://dw.ramsden-international.com/bridge`.

## Structured result

A job returns the value **with its type**, anything the script logged, and on failure
the error **with a stack**:

```json
{
  "jobId": "...", "status": "done",
  "result": "Your Basket",                     // real JSON value where serializable
  "resultType": "string",                      // string|number|boolean|object|array|element|...
  "logs": [{"level":"log","message":"..."}],   // console output captured during eval
  "error": null, "stack": null,
  "workerConnectionId": "...", "createdAt": 1750, "completedAt": 1750
}
```

DOM elements come back as `outerHTML` with `resultType: "element"`. On `status: "failed"`,
`error` and `stack` are populated instead of `result`.

## Script form

A job's `script` is either a **JS expression** or **statements ending in `return`**, and
**top-level `await` works**:

```js
document.title                                              // expression
(await fetch('/api/cart')).json()                           // async expression
const r = await fetch('/api/cart'); return (await r.json()).total;   // statements + return
```

Long async jobs may exceed the default `/jobs/sync` timeout (10s) — pass `timeout` (ms)
in the body, or use `POST /jobs` + poll `GET /jobs/:id`.

Escaping: keep it simple by using single quotes inside the JS and double quotes for the JSON:
`-d '{"script":"document.querySelector('"'"'#id'"'"')?.textContent"}'`, or write the
JS to a file and build the body with a heredoc / `jq -Rs`.

## Cooperative pages: the `window.bridge` helper

Raw eval works on any page, but selectors break when a page is restyled. Pages can opt into
a stable contract. The client exposes `window.bridge`; a page declares addressable elements
with `data-bridge-node` and/or registers named actions:

```html
<span data-bridge-node="cart-total">£0.00</span>
<script>bridge.register('checkout', () => document.querySelector('#pay').click());</script>
```

Drive the page by stable name, not selector:

| Call | Returns |
|------|---------|
| `bridge.nodes()` | enumerate declared nodes `[{node,tag,text,value}]` — the page's contract |
| `bridge.node(name)` | element tagged `data-bridge-node="name"` (or `null`) |
| `bridge.all(name)` | all elements tagged `data-bridge-node="name"` |
| `bridge.actions()` | registered action names |
| `bridge.action(name, ...args)` | invoke a registered action (may return a Promise — `await` it) |
| `bridge.register(name, fn)` | page-side: register a named action |

Also advertised in `GET /` under `pageHelper`.

## Getting a browser connected

Pages connect by loading the client. Either add it per-page:

```html
<script>
  window.__BRIDGE_URL   = 'wss://dw.ramsden-international.com/bridge/ws';
  window.__BRIDGE_TOKEN = '<BRIDGE_TOKEN>';
</script>
<script src="/browser-bridge-client.js"></script>
```

…or auto-inject the broker's own worker script into every page via Apache `mod_substitute`:

```apache
AddOutputFilterByType SUBSTITUTE text/html
Substitute "s|</head>|<script src=\"https://dw.ramsden-international.com/bridge/client.js\"></script></head>|in"
```

The client `eval`s incoming scripts, so **the page's CSP must not block eval** — don't set a
restrictive `script-src` on pages that load the client. For proxied pages, `mod_deflate`/gzip
must be off so `Substitute` can see the HTML. See `deploy/apache-inject.conf` and
`deploy/apache-bridge.conf` (the latter includes the WebSocket upgrade rule;
`a2enmod proxy proxy_http proxy_wstunnel`).

## Troubleshooting

- **`{"error":"unauthorized"}`** — missing/wrong `Authorization: Bearer <token>` header on an
  authed endpoint. `/health` and `/status` are unauthenticated; `/workers`, `/jobs*` are not.
- **`curl: (7) connection refused`** — broker not running. `systemctl status browser-bridge-broker`,
  or start manually: `BRIDGE_TOKEN=... node server.js`.
- **`503` from `/jobs/sync`** — no browser connected. Check `/workers`; open/reload a page that
  loads the client.
- **`408` from `/jobs/sync`** — job ran longer than the timeout. Pass a larger `timeout`, or
  enqueue with `POST /jobs` and poll `GET /jobs/:id`.
- **Page never appears in `/workers`** — its CSP is blocking `client.js` (`script-src`) or the
  WebSocket (`connect-src`), or gzip is on for a proxied page so injection didn't happen.
- **`GET /status`** — live dashboard; paste the token in-page (kept in `sessionStorage`, sent
  only as a Bearer header) to see workers grouped by host.

## Security notes

- Broker listens on loopback (`127.0.0.1:3141`); Apache fronts the public `/bridge` path.
- Token-authed, but it executes **arbitrary JavaScript** in connected browsers by design —
  treat the token as a secret and don't run untrusted scripts.
- Not a general-web tool: it only reaches browsers that have loaded the client.
