---
name: ri-service-toolkit
description: Use when building a .NET 9 service from RI's shared components (ExportKing, KdbxCredentials, OhSheet, Anthea) deployed as a TinyWeb CGI, or registering a URL on the dw portal page.
---

# RI Service Toolkit

This skill captures the proven pattern for assembling an internal Ramsden International
data service out of the four shared building blocks. Reach for it whenever a task needs
any combination of: a product/description lookup from **Exportmaster** (DBISAM), a
**product image** from S3, a **credential** held in KeePass, or a **customer-specific
price** from Anthea — and especially when the result is a CGI deployed under TinyWeb.

The reference implementation throughout is **SuperSub** (`C:\Users\matthew.heath\Git\SuperSub`,
Gogs: `git@dw.ramsden-international.com:matthew.heath/SuperSub.git`), which uses all four.

## The four building blocks

| Concern | Library | What it gives you | Auth |
|---------|---------|-------------------|------|
| Product description + barcode | **ExportKing** (`ExportKing.Data`) | Native DBISAM client for .NET 9. `SELECT` + DML via `ExecuteNonQuery` | DBISAM user/pass (from KeePass) |
| Product images | **OhSheet** imaging pipeline (vendored) | S3 two-source reconciliation → SkiaSharp resize → bytes ready to embed | AWS creds file |
| Secrets | **KdbxCredentials** (`KdbxCredentials`) | Read-only KDBX4 lookup; master password from OS secret store | OS secret store key |
| Customer pricing | **Anthea** (web service) | POST `{customer:{delivery,products[]}}` → aligned `prices[]` | none (internal CGI) |
| Hosting | **TinyWeb** + NSSM | CGI host; service runs as **LocalSystem** | inherits LocalSystem |

## Instructions

When building or extending an RI service, follow these rules:

1. **Config in a `.properties` file, never in code.** Load one `supersub.properties`-style
   file (Java-properties format) at startup. Connection hosts/ports, the KeePass pointer,
   the Anthea URL, and S3 buckets all live there. Secrets do **not** — only the *pointer*
   to the secret (the KeePass entry path + secret-store key).

2. **DBISAM catalog is a server-side logical name, not a filesystem path.** For Nisa
   International data the verified catalog is **`NISAINT_CS`** (confirmed against production
   MrsFlow code — 653 tables). Do **not** guess `Nisa International` or a directory name;
   that fails with server code `0x2C1E`. If you need a different dataset, find the alias in
   sibling production code before using it.

3. **Credentials resolve through `Database.Open(path, secretStoreKey)`.** The standard
   secret-store key for RI services is **`kdbx-services`** (not `kdbx-master`). The KDBX
   file's master password lives in the OS secret store under that key; the library reads it
   automatically. Never read the master password from config or source.

   **The "OS secret store" is platform-specific, and on Linux it is `systemd` credentials —
   not a keyring you can query ad-hoc.** On Linux the master password is a **root-only file at
   `/etc/credstore/kdbx-services`**; the service unit declares
   `LoadCredential=kdbx-services:/etc/credstore/kdbx-services`, systemd injects it into the
   unit's private `$CREDENTIALS_DIRECTORY/kdbx-services`, and `KdbxCredentials` reads it from
   there. **Consequence: a process NOT launched by systemd with that directive — a bare
   `dotnet run`, a CLI like `kdbx-getfield`, an interactive shell — can't read it by default.**
   There is no ambient keyring/daemon to fall back to (the kernel/gnome keyring is empty by
   design), so the lookup just returns nothing *unless you provide the directory yourself*.

   **Dev/manual access (this comes up constantly).** The Linux store reads
   `$CREDENTIALS_DIRECTORY/<secretStoreKey>` *verbatim* — there is no systemd magic beyond that
   env var. So on a dev box you reproduce the vault by hand once, then set the env var per run
   (it doesn't need to be systemd):

   ```bash
   mkdir -p ~/.config/ri-creds && chmod 700 ~/.config/ri-creds
   # UTF-8, NO trailing newline — hence printf '%s', not echo:
   printf '%s' 'MASTER_PASSWORD' > ~/.config/ri-creds/kdbx-services && chmod 600 ~/.config/ri-creds/kdbx-services
   # now any tool/app works when launched with the env var set:
   CREDENTIALS_DIRECTORY=~/.config/ri-creds kdbx-getfield <db.kdbx> kdbx-services <group/entry> username
   CREDENTIALS_DIRECTORY=~/.config/ri-creds dotnet run --project src/Foo.Cli -- ...
   ```

   `kdbx-getfield` (usage: `getfield <db> <secretStoreKey> <entry> <field>`, fields:
   username/password/url/notes) lives at `/usr/local/bin` and is handy for verifying the file
   is right — read the *username* to prove the unlock without printing the password. Only the
   master-password value itself is still a secret you must obtain; the mechanism is not.
   The RI vault password is constant, so provision this **once** and persist
   `export CREDENTIALS_DIRECTORY="$HOME/.config/ri-creds"` in `~/.bashrc` **above** the
   non-interactive guard (Debian's `.bashrc` `return`s early otherwise). On RI's Linux dev box
   this is already set up; note non-interactive, non-login shells (some tool/cron invocations)
   still don't source `.bashrc`, so there prefix the var or use `bash -lc`.
   RI's current Linux host is **systemd 247 with no `systemd-creds`**, so this is an
   **unencrypted `LoadCredential`** (not `LoadCredentialEncrypted`). The proven reference unit
   is `S3ImageCache/deploy/s3imagecache.service` (the `Keepass-access-libs/csharp` lib is the
   same one Windows uses; only the credential delivery differs).

4. **ExportKing is read/write.** It supports `SELECT` *and* DML (`INSERT`/`UPDATE`/`DELETE`
   via `ExecuteNonQuery`) with inline literals — escape single quotes by doubling them
   (`'` → `''`). Don't claim it's "SELECT only."

5. **ExportKing has no parameters — escape inline literals so values can't break the query.**
   `CreateDbParameter()` throws; inline literals are the only option. The point of escaping
   here is *robustness*, not security — the data isn't adversarial, but a value parsed from a
   report (a description with an apostrophe, say) would otherwise produce malformed SQL and a
   failed query. So place every value inside a single-quoted literal and double any embedded
   single quotes (`'` → `''`); for a SQL string literal that's a complete fix. One caveat:
   doubling only protects *quoted* literals — never interpolate a value into a numeric or
   identifier position, where escaping does nothing.

6. **Anthea pricing is best-effort.** The request and response arrays are *aligned by
   index* (`products[i]` ↔ `prices[i]`). A null/non-number price means "couldn't price it"
   — leave the column blank, don't fail the whole job. Wrap the call in try/catch.

7. **Use the report's own dates, not "today."** When a report carries a pricing date, that
   date drives the Anthea lookup — not the date the service runs. Keep report context
   (names, codes, dates) distinct from generation time.

8. **Any service password the CGI needs must live in KeePass, and its KDBX master key in
   the secret store of the account the service runs as.** TinyWeb CGIs run as **LocalSystem**,
   so the master key must be in **SYSTEM's** vault — the credential is per-user (DPAPI), so
   provisioning it as your own login does nothing for the service. Don't reinvent the
   provisioning steps: the **KeePass docs** (`Keepass-access-libs/csharp/USAGE.md`, §3) give
   the exact recipe for getting master keys into each kind of vault, including the LocalSystem
   one-shot scheduled-task method (`runas` can't assume SYSTEM). Follow that.

9. **Publish self-contained, single-file, win-x64.** Deploy the one exe plus its
   `.properties` to `\\RIVSPROD02\RI Services\TinyWeb\www\cgi-bin\`. Always verify *live*
   with a real POST after deploying — claims of "it works" mean nothing until the deployed
   endpoint returns the expected bytes.

10. **It isn't deployed until it's on the portal.** Anything with a human-facing URL — a
    liveboard, a report page, an app — must get a card on
    **https://dw.ramsden-international.com/**, or nobody will ever find it. Deploying the
    files and stopping is the single most common way a finished thing goes unused. See
    *The portal page* below.

## Examples

### Example 1: "I need a product's description and barcode from Exportmaster"
```
User: Look up descriptions for these substitute codes from Exportmaster.

Claude: I'll use ExportKing with the DBISAM connection from config and credentials
from KeePass:
- Resolve the DBISAM login via Database.Open(path, "kdbx-services") → Lookup(entry)
- Build a DbisamConnectionStringBuilder (Host/Port/UserId/Password/Catalog=NISAINT_CS)
- SELECT code, desc1, uf_ibarcode FROM Product WHERE code IN (...escaped list...)

[Uses the Exportmaster Lookup pattern from the reference below]
```

### Example 2: "Add a price column for this customer"
```
User: Price these products for customer 994163 on the report's pricing date.

Claude: I'll POST one request to the Anthea CGI and read the aligned prices array:
- payload = { "994163": { delivery: "2026-06-26", products: [...] } }
- Read back result["994163"].prices[], pairing by index with .products[]
- Treat any non-number as "no price" and leave that cell blank (best-effort)

[Uses the Anthea client pattern from the reference below]
```

### Example 3: "Stand up a new CGI for this on TinyWeb"
```
User: Wrap this in a web endpoint like SuperSub.

Claude: I'll mirror the SuperSub CGI shape:
- A thin Cgi/Program.cs that reads the body (multipart upload, "report" field, or raw
  text/plain), loads supersub.properties from AppContext.BaseDirectory, runs the core
  pipeline, and streams the result with CGI headers
- Publish self-contained single-file win-x64; deploy exe + .properties to the cgi-bin share
- Provision DBISAM creds into SYSTEM's vault (TinyWeb runs as LocalSystem)
- Verify live with a real POST before reporting done

[Uses the CGI front-door + deployment patterns from the reference below]
```

---

# Reference Implementation Details

Proven code from SuperSub (`src/SuperSub.Core/...`). Paths are relative to that repo.

## Configuration (`Configuration/SuperSubConfig.cs` + `supersub.properties`)

Load one properties file; require everything except ports/sizes (which default).

```properties
# ---- Exportmaster (DBISAM via ExportKing) ----
supersub.dbisam_host=RIVSEM01
supersub.dbisam_port=12005
supersub.dbisam_catalog=NISAINT_CS

# ---- KeePass pointer (NOT the secret itself) ----
supersub.kdbx_path=\\\\RIVSPROD02\\RI SERVICES\\Credentials\\ServicePasswords.kdbx
supersub.kdbx_entry=Exportmaster/RIVSEM01
supersub.kdbx_secret_store_key=kdbx-services

# ---- Anthea price service ----
supersub.anthea_url=https://dw.ramsden-international.com/tiny02/cgi-bin/Anthea.exe

# ---- S3 product images (same sources OhSheet uses) ----
ri.s3_credentials=C:\\RI Services\\Credentials\\aws.txt
ri.s3_region_RAMSDEN=eu-west-2
ri.s3_bucket_RAMSDEN=ramsden-devstorage
ri.s3_key_prefix_RAMSDEN=ProductImagesRamsden
ri.s3_region_BRANDBANK=eu-west-2
ri.s3_bucket_BRANDBANK=ramsden-devstorage
ri.s3_key_prefix_BRANDBANK=ProductImagesBrandbank
```

**Key points:**
- Note the **quadruple backslashes** for UNC paths in Java-properties (`\\` escape, doubled).
- S3 has **two sources** (RAMSDEN, BRANDBANK); OhSheet reconciles them and prefers the largest image.

## KeePass credential resolution (`Credentials/CredentialStore.cs`)

```csharp
using KdbxCredentials;

public static (string User, string Password) GetDbisamLogin(SuperSubConfig cfg)
{
    using var db = Database.Open(cfg.KdbxPath, cfg.KdbxSecretStoreKey);  // key = "kdbx-services"
    using var entry = db.Lookup(cfg.KdbxEntry);                          // e.g. "Exportmaster/RIVSEM01"
    return (entry.Username ?? "", entry.Password ?? "");
}
```

**Key points:**
- The master password is fetched from the OS secret store under `kdbx-services` — never passed in.
- Read-only; `Database`, `entry` are `IDisposable` — `using` them.

## Exportmaster lookup (`Products/ProductLookup.cs`)

```csharp
using ExportKing.Data;

var csb = new DbisamConnectionStringBuilder
{
    Host = cfg.DbisamHost, Port = cfg.DbisamPort,
    UserId = user, Password = password,
    Catalog = cfg.DbisamCatalog,                 // "NISAINT_CS"
};

// ExportKing has no parameters. Build an inline IN list, escaping each code as a
// single-quoted literal with embedded quotes doubled so a stray apostrophe can't
// break the query (robustness, not anti-injection — the data isn't adversarial).
string inList = string.Join(", ", wanted.Select(c => "'" + c.Replace("'", "''") + "'"));
string sql = $"SELECT code, desc1, uf_ibarcode FROM Product WHERE code IN ({inList})";

using var conn = new DbisamConnection(csb.ConnectionString);
conn.Open();
using var cmd = conn.CreateCommand();
cmd.CommandText = sql;
using var reader = cmd.ExecuteReader();
while (reader.Read()) { /* code, desc1, uf_ibarcode (the image barcode) */ }
```

**Key points:**
- `desc1` is the product description; `uf_ibarcode` is the barcode used to find its image.
- For writes, use `cmd.ExecuteNonQuery()` — ExportKing supports DML.

## DBISAM SQL dialect — check the DCG, don't guess

DBISAM is **not** modern SQL, and the official Elevate docs don't fully match the
engine. The authoritative spec is the **Dibdog DCG** — a formal, executable grammar of
the *exact* DBISAM version we ship, reconciled against the live engine:

- Repo: `C:\Users\matthew.heath\Git\Dibdog` (Gogs: `matthew.heath/Dibdog`).
- Canonical grammar: `dbisam-dcg-project/grammar/dcg.pl` (the DCG wins over all prose).
- Human-readable: `dbisam-dcg-project/railroad/grammar.ebnf` — one line per production;
  read this to answer "is construct X accepted, and in what shape?".
- Engine-verified function catalogue: `dbisam-dcg-project/docs/functions.md`.
- Doc/engine/disassembly disagreements: `dbisam-dcg-project/docs/DIVERGENCES.md`.

**Before writing any non-trivial DBISAM SQL, grep the EBNF / functions.md.** The dialect
is SQL-89-baseline (no CTEs, no window functions; comma-form FROM is primary). Gotchas
that bite — all confirmed against the engine:

- **`TOP n` goes LAST, not after `SELECT`.** Clause order is
  `WHERE → GROUP BY → HAVING → ORDER BY → TOP`. So `SELECT code FROM Product TOP 1`,
  **never** `SELECT TOP 1 code …` (the latter is rejected, server code `0x2EAD`).
- **No `TRIM`.** Only `LTRIM` / `RTRIM` exist — nest them (`LTRIM(RTRIM(x))`) for both
  sides. `UPPER`/`LOWER`/`UCASE`/`LCASE`, `COALESCE`, `IF`, `SUBSTRING`, `POS` are fine.
- **`SELECT` requires a `FROM`.** There is no `DUAL` / bare `SELECT 1` — a one-row scalar
  probe must target a real table.
- A rejected statement returns `IOException … server rejected the statement (code 0x2EAD)`
  — that's a *syntax/dialect* rejection, distinct from `0x2C1E` (bad catalog).

**ExportKing client caveat (not a dialect matter):** selecting **string literals as
columns** (e.g. `SELECT 'ean' AS verdict, …`) can make ExportKing's reader throw
`ReadRecordBlock record size N outside expected …` on the row-returning path. Return
**real table columns only** and classify in the caller. Empty `uf_ibarcode` is `''`/NULL
(no space-padding), so equality works without `TRIM`.

## Anthea pricing (`Pricing/AntheaClient.cs`)

```csharp
// Request: { "<customerCode>": { delivery: "yyyy-MM-dd", products: [ "code", ... ] } }
var payload = new Dictionary<string, object>
{
    [customerCode] = new { delivery = deliveryDate, products = productCodes },
};
// Response: result[customerCode].products[] aligned by index with .prices[]
for (int i = 0; i < prodList.Count && i < priceList.Count; i++)
    prices[prodList[i]] = priceList[i].ValueKind == JsonValueKind.Number
        ? priceList[i].GetDecimal() : null;   // non-number ⇒ unpriced ⇒ blank
```

**Key points:**
- Single POST for all products. Pair results **by array index**, not by re-querying.
- The `delivery` date is the report's **pricing date**, not the run date.
- Call site wraps this in try/catch — pricing failure must not sink the job.

## S3 image source (`SubstitutionService.RunAsync`)

```csharp
using var imageSource = new S3ImageSource(
    cfg.S3,
    new ImageCache(Path.Combine(Path.GetTempPath(), "supersub-cache")),
    OutputImageFormat.Jpg,
    shotTypeNumber: "1");

// Fetch each distinct barcode's image once, in parallel, at the target size:
await Parallel.ForEachAsync(barcodes,
    new ParallelOptions { MaxDegreeOfParallelism = dop },
    async (barcode, c) => images[barcode] = await imageSource.GetAsync(barcode, [imageSize], c));
```

**Key points:**
- Key images by **barcode** (`uf_ibarcode`), not product code.
- `ImageCache` is a local temp dir; safe to share across requests.
- `S3ImageSource` is `IDisposable`. Tests inject a `StubImageSource` instead (no live S3).

## CGI front door (`SuperSub.Cgi/Program.cs`)

A thin CGI that reuses the core. Reads body three ways (multipart file, `report` field,
or raw `text/plain`), loads config beside the exe, runs the pipeline, streams the result.

```csharp
string propsPath = Path.Combine(AppContext.BaseDirectory, "supersub.properties");
var cfg = SuperSubConfig.Load(propsPath);
await SubstitutionService.RunAsync(cfg, reportText, outPath);
// then WriteBinary with CGI headers:
//   Content-Type: <mime>\r\nContent-Disposition: attachment; filename="..."\r\nContent-Length: N\r\n\r\n
```

**Key points:**
- Read exactly `CONTENT_LENGTH` bytes from stdin; don't block on EOF when length is known.
- Always return `0` and emit a CGI error body on exception — never crash the CGI.
- Config sits **next to the exe** (`AppContext.BaseDirectory`), deployed alongside it.

## Build & deploy

```powershell
# Self-contained single-file CGI
dotnet publish src/SuperSub.Cgi -c Release -r win-x64 --self-contained `
  -p:PublishSingleFile=true -o publish

# Deploy exe + properties to the TinyWeb cgi-bin share
Copy-Item publish\SuperSub.Cgi.exe "\\RIVSPROD02\RI Services\TinyWeb\www\cgi-bin\" -Force
Copy-Item supersub.properties      "\\RIVSPROD02\RI Services\TinyWeb\www\cgi-bin\" -Force
```

Then **verify live** (the only proof that counts):

```powershell
Invoke-WebRequest -Uri "https://dw.ramsden-international.com/tiny02/cgi-bin/SuperSub.Cgi.exe" `
  -Method Post -InFile example.txt -ContentType "text/plain" -OutFile out.xlsx
```

## No-cache on anything served from TinyWeb

Every page under `R:\TinyWeb\www\pibs\` must carry the no-cache meta block, or people
keep seeing yesterday's board after you deploy and conclude the change didn't work:

```html
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
```

TinyWeb already sends `Cache-Control: no-cache` with a `Last-Modified` on these paths, and
conditional requests do work (an `If-Modified-Since` matching the file returns 304, an older
one returns 200). But **`no-cache` means "revalidate before reusing", not "do not store"** —
a browser holding an open tab, or a back/forward navigation, can still paint a stale copy.
So after redeploying a page, verify with a hard refresh rather than a normal one, and check
the served bytes rather than what your tab shows:

```bash
curl -sI  "https://dw.ramsden-international.com/tiny02/pibs/<name>.html" | grep -i -E "cache|last-modified"
curl -s   "https://dw.ramsden-international.com/tiny02/pibs/<name>.html" | grep -c "<some string only the new version has>"
```

Data fetches are separate from the document and need their own opt-out — the MrsFlow boards
pass `{ cache: 'no-store' }` on every `fetch()` to `mrsflow-cgi.exe`, which is what stops a
board showing a fresh page built from a cached parquet.

## The portal page

Everything human-facing at RI is indexed from one page: **https://dw.ramsden-international.com/**
("Liveboards and Apps"). A service that isn't on it is, in practice, invisible. Adding a card is
the last step of *every* deployment that produces a URL.

**Where it lives — and the trap.** On **`vsprod`** (`RIVSPROD01`, reachable over SSH as `vsprod`):

```
/var/www/html/dw/index.html      -> SYMLINK to liveboards.html   <-- do NOT edit this
/var/www/html/dw/liveboards.html <-- EDIT THIS, it's the real file
```

Editing `index.html` "works" only because it dereferences; edit the target so nothing is
surprising later. Note the docroot is `/var/www/html/dw` but it is served at the **site root**,
so the live page is `https://dw.ramsden-international.com/`, *not* `/dw/` (that 404s).

**Back it up first — it's a hand-maintained production file with no repo behind it:**

```bash
ssh vsprod 'cd /var/www/html/dw && cp liveboards.html liveboards.html.bak-$(date +%Y%m%d-%H%M%S)'
```

**The card format.** Cards sit inside a `<div class="grid">` under a section `<h2>`
(*Forecasting*, *Commercial*, …). Copy the shape exactly:

```html
    <a class="card" href="/tiny02/pibs/credits.html">
      <span class="arrow">→</span>
      <img class="thumb" src="/tiny02/pibs/credits.png" alt="" loading="lazy" onerror="this.remove()">
      <div class="name">Credit Notes</div>
      <div class="desc">Credit notes — value, reasons and rate by customer.</div>
      <div class="meta"><span class="chip live">Liveboard</span></div>
    </a>
```

- **`chip` classes:** `live` (liveboard), `app` (application), `exp` (experimental). Pick one.
- **The thumbnail is optional** and carries `onerror="this.remove()"` so a missing image degrades
  to a text-only card rather than a broken-image icon. Keep that attribute.
- Images for TinyWeb boards live **flat** in `\\rivsprod02\RI Services\TinyWeb\www\pibs\`
  (`suma.png`, `Sugro.png`, `credits.png`) and are referenced as `/tiny02/pibs/<name>.png`.

**Write the `desc` like a library catalogue entry, not a press release.** One short line saying
what the thing *is*. This is a portal — the reader is scanning twenty cards to find one. Match the
neighbours (`"Sales — Suma."`, `"Weekly product availability."`). **Do not put findings, headline
numbers, or conclusions on the card** — those belong on the board itself, and they go stale on the
portal where nothing recomputes them.

**Edit it as a file, not with `sed`.** A guarded Python replace is safest — it refuses to act
twice and refuses to act on a missed anchor, so a re-run can't silently duplicate a card:

```bash
ssh vsprod 'python3 - <<EOF
p = "/var/www/html/dw/liveboards.html"
s = open(p, encoding="utf-8").read()
anchor = """    <a class="card" href="/tiny02/pibs/sugro.html">"""   # insert BEFORE this card
card = """    <a class="card" href="/tiny02/pibs/credits.html">
      ...
    </a>

"""
if "credits.html" in s:   print("ALREADY PRESENT - no change")
elif anchor not in s:     print("ANCHOR NOT FOUND - no change")
else:
    open(p, "w", encoding="utf-8").write(s.replace(anchor, card + anchor, 1))
    print("inserted")
EOF'
```

**Then verify against the live page, not the file on disk:**

```bash
curl -s https://dw.ramsden-international.com/ | grep -A4 'credits.html'   # card is published
curl -s -o /dev/null -w '%{http_code}\n' https://dw.ramsden-international.com/tiny02/pibs/credits.html
curl -s -o /dev/null -w '%{http_code}\n' https://dw.ramsden-international.com/tiny02/pibs/credits.png
```

A card pointing at a 404 is worse than no card. Check the target **and** the thumbnail.

## Troubleshooting

### New card doesn't show up on the portal
**Cause:** usually one of four things, in order of likelihood.
**Solution:**
1. You edited a copy, not the live file. The real file is
   `vsprod:/var/www/html/dw/liveboards.html`; `index.html` is a *symlink* to it.
2. You checked the wrong URL. The page is served at the **site root**
   (`https://dw.ramsden-international.com/`), not `/dw/` — that 404s, which looks like your
   edit vanished.
3. The insert anchor didn't match, so a `sed`/replace silently did nothing. Use a guarded
   Python replace that *prints* when the anchor is missing (see *The portal page*).
4. Browser cache. Confirm with `curl` against the live URL, never by reloading a tab.

### DBISAM connect fails with `0x2C1E`
**Cause:** Wrong catalog — a filesystem path or made-up name was used.
**Solution:** Use the verified logical alias (`NISAINT_CS` for Nisa International). Confirm
against sibling production code (MrsFlow) before inventing one.

### Credentials not found when running under TinyWeb
**Cause:** TinyWeb runs as **LocalSystem**; the KDBX master key was provisioned into a *user*
vault (per-user DPAPI), so the service can't read it.
**Solution:** Get the master key into **SYSTEM's** vault. The KeePass docs
(`Keepass-access-libs/csharp/USAGE.md`, §3 + `R:\kdbx\provision-system.bat`) have the exact
one-shot scheduled-task recipe — `runas` can't assume SYSTEM. Use the **`kdbx-services`**
secret-store key (not `kdbx-master`). Because the secret lives in SYSTEM's vault, `cmdkey
/list` as an admin won't show it — confirm by having the service itself read it.

### Anthea returns blanks for everything
**Cause:** Customer code, delivery date, or array alignment is off.
**Solution:** Confirm the request key is the customer code and `delivery` is the report's
pricing date (`yyyy-MM-dd`). Match `prices[]` to `products[]` by index from the response,
not the request order.

## Best Practices Summary

1. One `.properties` file; pointers to secrets, never secrets.
2. `NISAINT_CS` catalog; verify aliases against production code.
3. `kdbx-services` secret-store key; master password from the OS vault.
4. ExportKing does DML too; escape quotes by doubling.
5. Anthea is best-effort and index-aligned; never let it sink the job.
6. Report dates drive lookups, not the run clock.
7. Service passwords in KeePass; master key in the run-as account's secret store
   (LocalSystem ⇒ SYSTEM's vault) — follow the KeePass docs for provisioning.
8. Publish self-contained single-file; deploy exe + properties; verify live.
