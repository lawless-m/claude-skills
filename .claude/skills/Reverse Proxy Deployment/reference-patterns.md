# Reverse Proxy Deployment Patterns (rivsprod01)

Proven configurations from production deployments. All configs live in `/etc/apache2/proxy-conf.d/` on rivsprod01; targets always use `http://10.99.0.3:PORT/`, never localhost.

## Pattern 1: single service

```apache
# /etc/apache2/proxy-conf.d/myservice.conf
ProxyPass /myservice/ http://10.99.0.3:8080/
ProxyPassReverse /myservice/ http://10.99.0.3:8080/
```

Plain ProxyPass directives — no `<VirtualHost>` or `<Location>` blocks needed. Trailing slashes on both sides strip the prefix: `/myservice/page` arrives at the backend as `/page`.

## Pattern 2: API + frontend

```apache
# API MUST be listed first (more specific path)
ProxyPass /rabbit/api/ http://10.99.0.3:8765/
ProxyPassReverse /rabbit/api/ http://10.99.0.3:8765/

ProxyPass /rabbit/ http://10.99.0.3:9273/
ProxyPassReverse /rabbit/ http://10.99.0.3:9273/
```

If the frontend rule is first, it catches `/rabbit/api/*` and the API 404s.

## Pattern 3: multiple services, one file

```apache
# /etc/apache2/proxy-conf.d/all-services.conf
ProxyPass /api/ http://10.99.0.3:8001/
ProxyPassReverse /api/ http://10.99.0.3:8001/

ProxyPass /admin/ http://10.99.0.3:8002/
ProxyPassReverse /admin/ http://10.99.0.3:8002/

ProxyPass /site/ http://10.99.0.3:8003/
ProxyPassReverse /site/ http://10.99.0.3:8003/
```

Order doesn't matter when paths don't overlap. Comment out a block to disable one service.

## Large uploads (PDF/image processing)

```apache
<Location /uploads/>
    ProxyPass http://10.99.0.3:7000/
    ProxyPassReverse http://10.99.0.3:7000/
    LimitRequestBody 52428800   # 50 MB
</Location>
```

## Frontend relative-URL pattern

Store the API base as a relative value so the browser resolves it against the current path (page at `/rabbit/` → request goes to `/rabbit/api/status`, proxy strips the prefix):

```html
<input type="hidden" id="serverUrl" value="api">
<script>
const res = await fetch(`${document.getElementById('serverUrl').value}/status`);
</script>
```

Value is `"api"` (relative), never `"http://localhost:8765"`.

## Troubleshooting

**404 but service works locally** — check from rivsprod01 first: `ssh rivsprod01 "curl -s http://10.99.0.3:PORT/endpoint"`. If that works, it's the config: wrong ProxyPass order or missing trailing slashes. Error log: `/var/log/apache2/error.log` on rivsprod01.

**Frontend loads, API 404s** — frontend catch-all is listed before the API path. Put the API rule first, reload Apache.

**Connection refused from rivsprod01** — service is bound to 127.0.0.1. Rebind to `10.99.0.3` or `0.0.0.0`.

**Apache broken after reload** — config syntax error. `ssh rivsprod01 "sudo systemctl status apache2"` and check the error log; fix and reload again. (`apache2ctl configtest` may not be available on rivsprod01.)
