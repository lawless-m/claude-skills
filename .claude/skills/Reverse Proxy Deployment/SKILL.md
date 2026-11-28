---
name: Reverse Proxy Deployment
description: Use when deploying behind the Apache reverse proxy on rivsprod01, writing a ProxyPass config in /etc/apache2/proxy-conf.d/, or fixing 404s under a path prefix.
---

# Reverse Proxy Deployment

rivsprod01 (10.99.0.2) runs Apache as the reverse proxy for `https://dw.ramsden-international.com/`. Services run on pogs and must bind to 10.99.0.3 (or 0.0.0.0) — **never use `localhost`/`127.0.0.1` in ProxyPass targets**; rivsprod01 cannot reach them.

## Rules that bite

- **Trailing slashes on BOTH source and target** of ProxyPass, or path stripping breaks.
- **Order matters**: more specific paths (API) must come before the frontend catch-all, or the frontend swallows API requests → 404.
- **Frontends must use relative URLs** (`fetch('api/status')`, not `http://localhost:8765/...`) so they work under the path prefix.
- Drop configs in `/etc/apache2/proxy-conf.d/*.conf` — automatically included by the default SSL site config; no `a2ensite` needed.
- Test from rivsprod01 before blaming Apache: `ssh rivsprod01 "curl -s http://10.99.0.3:PORT/endpoint"`.
- After config changes: `ssh rivsprod01 "sudo systemctl reload apache2"`.

## Worked example: rabbit.conf (invoice OCR)

`rabbit.conf` in this folder is the production config — frontend at `/rabbit/` (port 9273), API at `/rabbit/api/` (port 8765):

```apache
# Backend API - must come FIRST (more specific path)
ProxyPass /rabbit/api/ http://10.99.0.3:8765/
ProxyPassReverse /rabbit/api/ http://10.99.0.3:8765/

# Frontend catch-all - comes SECOND
ProxyPass /rabbit/ http://10.99.0.3:9273/
ProxyPassReverse /rabbit/ http://10.99.0.3:9273/
```

For the deployment patterns (single service, API + frontend, multi-service, large uploads) and troubleshooting detail, see `reference-patterns.md`.
