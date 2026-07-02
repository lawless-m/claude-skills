---
name: X3 SOAP Web Services
description: Building, deploying, and calling Classic SOAP sub-program web services on Sage X3 — covers 4GL signature, publication setup, SOAP envelope format (including TAB/LIN arrays), pool quirks, and Ramsden-specific install notes
---

# X3 SOAP Web Services

Skill for creating, deploying, and calling Classic SOAP sub-program web services on a Sage X3 install. Use when:

- Writing or editing a `.src` 4GL subprog that will be exposed via SOAP
- Building or fixing a SOAP envelope to call an X3 web service
- Diagnosing why a SOAP call returns empty / no output
- Deploying changes to a service (publication, pool restart)
- Creating a new web service publication entry

## Architecture

A working X3 Classic SOAP web service has four parts:

1. **4GL source file** (`.src`) containing a `Subprog <NAME>(...)` declaration in TRT directory.
2. **Subprograms dictionary entry** registering the subprog (Subprograms record with Web services ticked).
3. **Publication** in GESAWE (Classic SOAP web services) with a parameter Mapping.
4. **Pool worker** (Classic SOAP pool, e.g. `WSBUILD`) that loads and runs the compiled wrapper `WJ<NAME>`.

A SOAP call hits Syracuse → assigns to a pool worker → optional CHGUSR → reads HORDAT → loads wrapper `WJ<NAME>` → calls subprog → returns.

## Naming

- Service codes are limited to **10 characters** (X3 internal limit; longer names truncate silently and break dictionary lookups).
- Custom services use a `Z` prefix by Ramsden convention (e.g. `ZWEMSTAGE` = `Z` + `Write` + `EMStage`).
- The `Subprog` declaration name, the `File`/`Subprograms` fields in the dict, and the GESAWE publication name all match.

## 4GL syntax gotchas (Adonix)

- **Line continuation is `&` (not `_`).** Trailing underscore = `Illegal character` compile error.
- **Use `Return` (not `End`) to exit a Subprog early.** `End` halts the entire Adonix process.
- **Files**: declare with the table code, alias the abbreviation:
  ```
  Local File BPCUSTOMER [BPC]
  ```
  Then use `Read [BPC]BPC0 = ...` and `[F:BPC]field = ...`. Without the declaration, file ops silently no-op at runtime.
- **String concat**: `+`. No `+=`.
- **`Trace` keyword** isn't reliably available — don't depend on it for diagnostics. Set `O_RETCODE` to numeric breadcrumbs (`10`, `20`, …) instead.
- **For/Next**: explicit loop variable on `Next` (`Next WI`) on stricter parsers.

## SOAP envelope — boilerplate

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:wss="http://www.adonix.com/WSS"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Header/>
  <soapenv:Body>
    <wss:run soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <callContext xsi:type="wss:CAdxCallContext">
        <codeLang xsi:type="xsd:string">ENG</codeLang>
        <poolAlias xsi:type="xsd:string">WSBUILD</poolAlias>
        <requestConfig xsi:type="xsd:string">adxwss.optiontype=adxwss.optiontype.multi&amp;adxwss.trace.on=on&amp;adxwss.beautify=true</requestConfig>
      </callContext>
      <publicName xsi:type="xsd:string">YOURSERVICE</publicName>
      <inputXml xsi:type="xsd:string"><![CDATA[<PARAM>
... see input format below ...
</PARAM>]]></inputXml>
    </wss:run>
  </soapenv:Body>
</soapenv:Envelope>
```

### `requestConfig` flags

- Separator is `&` (XML-escape as `&amp;`), **not** `|`.
- `adxwss.trace.on=on` — essential while debugging; without it the response trace is empty.
- `adxwss.optiontype=adxwss.optiontype.multi` — forces per-call session reset; gives per-worker CHGUSR rather than once-per-pool-cycle.
- `adxwss.beautify=true` — pretty-prints the response.

## inputXml — by Dimension

The publication groups parameters into screen-style groups (`GRP1`, `GRP2`, …). The Mapping tab in GESAWE shows the layout; the **XML view** button gives the canonical schema (saved as `<service>.xml`).

### Scalar group (Dimension = 1) — use `<GRP>`

```xml
<GRP ID="GRP2">
  <FLD NAM="I_NEW_STAGE">6</FLD>
  <FLD NAM="I_OTHER_PARAM">value</FLD>
</GRP>
```

### Array group (Dimension > 1) — use `<TAB>` with `<LIN>` rows

```xml
<TAB ID="GRP1">
  <LIN><FLD NAM="I_BPCNUM">425073</FLD></LIN>
  <LIN><FLD NAM="I_BPCNUM">400044</FLD></LIN>
  <LIN><FLD NAM="I_BPCNUM">425099</FLD></LIN>
</TAB>
```

Mixing both works — group your scalars, TAB your arrays:

```xml
<PARAM>
  <TAB ID="GRP1">
    <LIN><FLD NAM="I_BPCNUM">425073</FLD></LIN>
    <LIN><FLD NAM="I_BPCNUM">400044</FLD></LIN>
  </TAB>
  <GRP ID="GRP2">
    <FLD NAM="I_NEW_STAGE">6</FLD>
  </GRP>
</PARAM>
```

`ID` matches the group code from the Mapping tab. Attributes use `NAM` (3 chars), not `NAME`.

## Pool / auth quirks

- Each pool worker has multiple X3 sessions. Only the first session in a worker to receive a CHGUSR for a given user gets that user; subsequent sessions stay as the pool's default user (admin).
- Result: without `multi` mode, ~1 successful call per pool restart. With `multi`, ~1 successful call per worker per cycle (≈2 with the default 2-channel install).
- **Design services as batch** (array input + 4GL loop) to sidestep the cap entirely. A single SOAP call can update N records.
- Pool config (Classic SOAP pools configuration in Syracuse admin):
  - **Lifetime (mn)** controls auto-respawn. Set to 5 in dev for fast cycling, 720+ in prod.
  - **Maximum size** doesn't reduce worker count below 2 on the Ramsden install — channels are architectural.
  - Stop/Start does NOT change worker PIDs; only Lifetime auto-respawn truly recycles processes.

## Deploy pipeline

Each change requires:

1. Update `.src` source — paste into Scripts editor (Folder=BUILD, Directory=TRT, Type=SRC), Compile (silent on success).
2. Update Subprograms dictionary entry if signature/dimensions changed.
3. **Click Publication** on the GESAWE Web Services record. Watch the *Published the* timestamp tick — if it doesn't, Publication didn't take. Re-clicking is sometimes needed.
4. Stop / Start the pool workers (Classic SOAP pools → Actions). Reminder: this doesn't actually replace processes; for a clean reload, wait for Lifetime auto-respawn.
5. In the next call's trace, confirm `WW_HORDAT` matches the new *Published the*.

## Direct URL navigation (when search is broken or menus are bare)

Pattern:

```
https://<host>/syracuse-main/html/main.html?url=%2Ftrans%2Fx3%2Ferp%2F<ENDPOINT>%2F%24sessions%3Ff%3D<FUNC>%252F2%252F%252FM%252F%26profile%3D~(loc~%27en-GB~role~%27<ROLE_GUID>~ep~%27<EP_GUID>~appConn~())
```

Fastest way to extract the right `profile=...` tail: open any working X3 function tab and copy its URL — everything except the `f%3D...` segment is reusable.

Common function codes:
- `GESAWE` — Classic SOAP web services / publication editor
- `ADOTRT` — Scripts editor (compile/edit `.src`)
- `GESAUS` — X3 user maintenance
- `GESADS` — Folders maintenance

## Diagnostics — reading the trace

In the response's `traceRequest` CDATA, look for:

- `Call X3 subprogram 'CHGUSR:CHGLOGINXTEND'` — present means user-switch fired.
- `Call X3 subprogram 'WJ<NAME>:<NAME>'` — present means the wrapper ran.
- `Result parameters: [...]` — populated `O_*` values come back here as `{"num":N, "resu":..., "descr":"...", "grp":"..."}` entries.
- `processReport` `[err]` lines — explicit error messages from the dispatcher.
- `Result (0)` with empty `Technical parameters: []` and `poolExecDuration ≈ 1ms` — wrapper short-circuited before subprog body ran (auth/cache/empty-input issue).

## Common error decoder

| Error message | Meaning | Fix |
|---|---|---|
| `Illegal character` (`val_anagram`) | 4GL syntax error — usually trailing `_` line continuation or wrong operator | Use `&` for line continuation; check operators |
| `Class nonexistent [F:BPC]` | File abbreviation not declared | Add `Local File BPCUSTOMER [BPC]` before any `[F:BPC]` reference |
| `File nonexistent ... BPC.fde` (compile / runtime open) | Used the abbreviation as the table code in `Local File` | Use the actual table code (`BPCUSTOMER`, not `BPC`) |
| `Cannot add field [FLD] under root node. Field [X] not found into X3 description.` | Field needs to be inside a GRP/TAB | Wrap in the right GRP/TAB based on the Mapping tab |
| `No attribute ID found into GRP tag.` | GRP missing `ID="..."` | Add `ID="GRPn"` matching the schema |
| `Group [X] has a dimension greater than 1. You have to use TAB Xml tag.` | Tried to use GRP for an array | Switch to `<TAB ID="...">` with `<LIN>` rows |
| `Change login error` | CHGUSR target user doesn't exist or is misconfigured | Check user exists in `GESAUS`, has password, is active |
| `Unknown web service (0)` | Pool can't resolve the service | Re-publish in GESAWE, restart pool |
| `Connection error - Incorrect user code or password` (pool start) | Pool's configured user has no valid X3-side credentials | Configure V6 connection info on the user, or use admin |

## Reference: scalar subprog

```
##############################################################################
# Set ZEMSTAGE on a single BP Customer.
##############################################################################

Subprog ZWEMSTAGE(I_BPCNUM, I_NEW_STAGE, O_RETCODE, O_ERRMSG)
Value   Char    I_BPCNUM()
Value   Integer I_NEW_STAGE
Variable Integer O_RETCODE
Variable Char    O_ERRMSG()

Local File BPCUSTOMER [BPC]

Trbegin [BPC]
Read [BPC]BPC0 = I_BPCNUM
If fstat
  O_RETCODE = 1
  O_ERRMSG  = "Customer not found"
  Rollback : Return
Endif
[F:BPC]ZEMSTAGE = I_NEW_STAGE
Rewrite [F:BPC]
If fstat
  O_RETCODE = 4
  O_ERRMSG  = "Write failed"
  Rollback : Return
Endif
Commit
O_RETCODE = 0
O_ERRMSG  = "OK"
Return

End
```

## Reference: batch subprog with array input (the `ZWEMSTAGE` shape)

```
##############################################################################
# ZWEMSTAGE - Set ZEMSTAGE on a batch of BP Customer records.
#
# Inputs  : I_BPCNUM     array of customer codes (up to 100)
#           I_NEW_STAGE  target stage applied to every customer in the batch
# Outputs : O_COUNT      number of records successfully updated
#           O_FAIL_LIST  comma-separated list of customer codes that failed
#           O_ERRMSG     human-readable summary
#
# Empty slots in I_BPCNUM stop the loop, so caller can leave trailing
# elements blank without padding.
##############################################################################

Subprog ZWEMSTAGE(I_BPCNUM, I_NEW_STAGE, O_COUNT, O_FAIL_LIST, O_ERRMSG)
Value   Char    I_BPCNUM()(0..100)
Value   Integer I_NEW_STAGE
Variable Integer O_COUNT
Variable Char    O_FAIL_LIST()
Variable Char    O_ERRMSG()

Local File BPCUSTOMER [BPC]
Local Integer WI, WTRIED

O_COUNT     = 0
O_FAIL_LIST = ""
WTRIED      = 0

For WI = 0 To 99
  If I_BPCNUM(WI) = "" : Break : Endif
  WTRIED = WTRIED + 1

  Trbegin [BPC]
  Read [BPC]BPC0 = I_BPCNUM(WI)
  If fstat
    Rollback
    O_FAIL_LIST = O_FAIL_LIST + I_BPCNUM(WI) + ","
  Else
    [F:BPC]ZEMSTAGE = I_NEW_STAGE
    Rewrite [F:BPC]
    If fstat
      Rollback
      O_FAIL_LIST = O_FAIL_LIST + I_BPCNUM(WI) + ","
    Else
      Commit
      O_COUNT = O_COUNT + 1
    Endif
  Endif
Next

O_ERRMSG = "Updated " + num$(O_COUNT) + " of " + num$(WTRIED) + " to stage " + num$(I_NEW_STAGE)
Return

End
```

## Reference: matching SOAP envelope (batch with TAB array)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:wss="http://www.adonix.com/WSS"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Header/>
  <soapenv:Body>
    <wss:run soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <callContext xsi:type="wss:CAdxCallContext">
        <codeLang xsi:type="xsd:string">ENG</codeLang>
        <poolAlias xsi:type="xsd:string">WSBUILD</poolAlias>
        <requestConfig xsi:type="xsd:string">adxwss.optiontype=adxwss.optiontype.multi&amp;adxwss.trace.on=on&amp;adxwss.beautify=true</requestConfig>
      </callContext>
      <publicName xsi:type="xsd:string">ZWEMSTAGE</publicName>
      <inputXml xsi:type="xsd:string"><![CDATA[<PARAM>
  <TAB ID="GRP1">
    <LIN><FLD NAM="I_BPCNUM">425073</FLD></LIN>
    <LIN><FLD NAM="I_BPCNUM">400044</FLD></LIN>
    <LIN><FLD NAM="I_BPCNUM">425099</FLD></LIN>
  </TAB>
  <GRP ID="GRP2">
    <FLD NAM="I_NEW_STAGE">6</FLD>
  </GRP>
</PARAM>]]></inputXml>
    </wss:run>
  </soapenv:Body>
</soapenv:Envelope>
```

## Reference: caller bat

```bat
@echo off
set X3_USER=MHE
set X3_PASS="<password>"
set X3_URL=https://x3.ramsden-international.com/soap-generic/syracuse/collaboration/syracuse/CAdxWebServiceXmlCC

curl -o response.txt -k -s -X POST ^
  -H "Content-Type: text/xml; charset=utf-8" ^
  -H "SOAPAction: \"\"" ^
  -u %X3_USER%:%X3_PASS% ^
  --data-binary "@envelope.xml" ^
  "%X3_URL%"
```

## Ramsden install specifics

- Folders: `X3` (reference), `SEED`, `BUILD` (development, full prod-like), `RAMDATA`, `RAMLIVE` (production financial system — off-limits for direct edits).
- Develop in `BUILD`. Pool used during dev: `WSBUILD`.
- The `BUILD` folder has BPCUSTOMER available via inheritance, but `BPC.fde` doesn't exist as a separate file — `BPC` is just the abbreviation for table `BPCUSTOMER`.
- Standard X3 BP table → abbreviation:
  - `BPCUSTOMER` → `BPC`
  - `BPSUPPLIER` → `BPS`
  - `BPARTNER` → `BPR`
- SOAP endpoint URL: `https://x3.ramsden-international.com/soap-generic/syracuse/collaboration/syracuse/CAdxWebServiceXmlCC`
- HTTP Basic Auth using the integration user's Syracuse credentials.
- Read EMStage back via the existing REST proxy:
  ```
  curl -s -H "APIKEY: <key>" "https://api.ramsden-international.com:8443/X3RestApiUAT/api/sagex3/customer?CustomerCode=425073" | jq -r ".responseData[0].customer.EMStage"
  ```
- Syracuse search server (Elasticsearch) intermittently unavailable on this install; use direct URLs (above) when search-by-function-code doesn't work.
