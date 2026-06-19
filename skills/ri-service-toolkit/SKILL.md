---
name: ri-service-toolkit
description: Build a .NET 9 service from RI's shared components — ExportKing (DBISAM/Exportmaster), KdbxCredentials (KeePass), OhSheet (S3 product images), and Anthea (customer pricing) — deployed as a TinyWeb CGI running as LocalSystem.
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

8. **TinyWeb CGIs run as LocalSystem.** That account inherits the secret-store vault, so
   credentials must be provisioned into **SYSTEM's** vault. `runas` cannot assume SYSTEM
   (no password) — use a one-shot scheduled task instead (`schtasks /create /ru SYSTEM
   /rl HIGHEST`) that runs the provisioning script. See Troubleshooting.

9. **Publish self-contained, single-file, win-x64.** Deploy the one exe plus its
   `.properties` to `\\RIVSPROD02\RI Services\TinyWeb\www\cgi-bin\`. Always verify *live*
   with a real POST after deploying — claims of "it works" mean nothing until the deployed
   endpoint returns the expected bytes.

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

## Troubleshooting

### DBISAM connect fails with `0x2C1E`
**Cause:** Wrong catalog — a filesystem path or made-up name was used.
**Solution:** Use the verified logical alias (`NISAINT_CS` for Nisa International). Confirm
against sibling production code (MrsFlow) before inventing one.

### Credentials not found when running under TinyWeb
**Cause:** TinyWeb runs as **LocalSystem**; the secret was provisioned into a *user* vault.
**Solution:** Provision into SYSTEM's vault. `runas` can't assume SYSTEM — use a one-shot
scheduled task:
```bat
schtasks /create /tn KdbxProvisionSystem /tr "powershell -File R:\kdbx\provision-credential.ps1" /ru SYSTEM /rl HIGHEST /sc ONCE /st 00:00 /f
schtasks /run /tn KdbxProvisionSystem
schtasks /delete /tn KdbxProvisionSystem /f
```
`provision-credential.ps1` uses `cmdkey` to write the master password into the vault under
the `kdbx-services` key. The default key is **`kdbx-services`**, not `kdbx-master`.

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
7. LocalSystem hosting ⇒ provision creds into SYSTEM's vault via schtasks.
8. Publish self-contained single-file; deploy exe + properties; verify live.
