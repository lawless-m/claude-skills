---
name: Databases
description: Use when querying or writing any RI database — Exportmaster (DBISAM sem01/sem04), PostgreSQL x3rocs, X3/Sage1000 SQL Server, keycloak MySQL, or Parquet. DuckDB is the primary read path.
---

# Databases

Environment map, dialect quirks, and tools for RI's databases. Fuller schemas, worked queries, and PgQuery usage: see `reference-databases.md`. Working C# in this folder: `ODBC.cs` (ServiceLib ODBC wrapper), `PgQuery.cs`.

## Hosts and connections

| System | Host | Connection | Notes |
|---|---|---|---|
| Exportmaster (DBISAM) | RIVSEM01 (prod), RIVSEM04 (dev) | DuckDB `sem01.<table>` (reads), `DSN=Exportmaster` ODBC (writes) | Proprietary; DuckDB is the primary read path |
| PostgreSQL | rivsprod01 | `Host=rivsprod01;Database=x3rocs;Username=<from vault>` | Use Npgsql for new code; kdbx entry `Postgres/x3rocs` |
| X3 / Sage1000 (SQL Server) | OCS1 | `DSN=OCS1;UID=sa;PWD=<from vault>;` | Same DSN for both; server to be deprecated |
| MySQL (keycloak) | rocs-production-es.ramsden-international.com:6033 | `Server=...;Port=6033;Database=keycloak;Uid=crm;Pwd=<from vault>;` | Native MySql.Data |
| DuckDB | local | `DSN=DuckDB` (ODBC) or CLI below | Reads Parquet directly; no native C# driver |

Passwords marked `<from vault>` are not recorded here: get them from the RI KeePass vault (KdbxCredentials — see the ri-service-toolkit skill) or the deployed config of a service that already uses that connection; ask Matt if neither pans out.

ODBC uses `?` placeholders; native MySQL uses `@param`; Npgsql uses `$1, $2` positional.

## DuckDB (primary read path for Exportmaster)

The custom **dbisam extension** lets DuckDB ATTACH live Exportmaster directly; both platforms come pre-wired to attach `sem01` (rivsem01/NISAINT_CS, **prod**) and `sem04` (rivsem04/NISAINT_CS, **dev**) read-only — just reference `sem01.<table>`:

- **Linux (this box)**: plain `duckdb` — `~/.duckdbrc` does the `LOAD dbisam` + ATTACHes (credentials live there too). Extension installed under `~/.duckdb/extensions/v{version}/linux_amd64/`; source repo `~/Git/Dbisam_fdw` (also has `sem01_views.sql`, `init.sql`). After a DuckDB version bump the extension must be rebuilt — see the DuckDB-Extensions skill.
- **Windows**: launcher `Y:\Data Warehouse\duckdb\duckdb.bat` (`duckdb.exe -unsigned --init init.sql`).

```bash
duckdb -c "SELECT * FROM sem01.profile WHERE SppCode = 'WAYPROMO'"
duckdb -c "DESCRIBE sem01.profile"
duckdb -f query.sql
```

Read-only — for writes use the e3 application or ODBC. Full DuckDB SQL works on top (joins, aggregates, `read_parquet()` overlays). The Linux install also has `postgres_scanner`, `mysql_scanner`, and `httpfs` extensions, so DuckDB can front reads on the other databases too.

## Exportmaster / DBISAM

Key tables: `PRICES` (header), `PRICDETL` (detail; join `SphLink = SpdLink`), `STOCK`, `CUSTOMER` (incl. `Profile` + `UF_AltProf1..11`), `PROFILE` (`SppGroup`+`SppCode` key; `SppPrice1/2`, `SppDiscount1/2` = list types). Details and worked queries in `reference-databases.md`.

DBISAM SQL dialect quirks (it is not standard SQL):
- No `DELETE ... JOIN` — scope deletes with `DELETE FROM t WHERE key IN (SELECT ...)`
- `TOP` goes last, not after SELECT
- No `TRIM` function
- `SELECT` requires a `FROM` clause

To verify what the dialect actually accepts, use the DCG grammar companion and engine-verified corpus in `~/Git/Dibdog` (repo name is **Dibdog** — autocorrects to "Dingo"/"Dindog"); corpus at `dbisam-dcg-project/corpus/`. Official dialect docs: https://www.elevatesoft.com/manual?action=topics&id=dbisam4&product=rsdelphi&version=XE&section=sql_reference

## PostgreSQL gotcha: fixed-length VARCHAR params

Calling a PostgreSQL function whose signature has `VARCHAR(n)` parameters fails with "function does not exist" unless you cast explicitly in the SQL: `$1::VARCHAR(15)`. Also set `NpgsqlDbType.Varchar` on the C# parameter (including for `DBNull.Value`). INTEGER/NUMERIC/TEXT need no cast. Full example in `reference-databases.md`.

## PgQuery (ad-hoc PostgreSQL from the command line)

- Production: `Y:\CSharpDLLs\PgQuery\PgQuery.exe`; source: `C:\Users\matthew.heath\Git\PgQuery` (repo `gogs@dw.ramsden-international.com:matthew.heath/PgQuery.git`)
- `PgQuery --config <config.json> --sql "..."` or `--file script.sql`, optional `--output results.txt`
- Config JSON: `{"host": "rivsprod01", "database": "x3rocs", "username": "<from vault: Postgres/x3rocs>", "password": null, "port": 5432}` — examples live in `R:\JsonParams\` (e.g. `CRMPollerFixer.config.json`)

## X3 / Sage1000

`Person` / `Company` / `Account` tables (join `Pers_CompanyId`, `Pers_AccountId`). Web permission fields on `Person`: `pers_webaccesslevel`, `pers_WebAllowBannedProducts`, `pers_WebOrderBannedProducts`, `pers_WebExportProducts`, `pers_WebDownloadImages`. Active users: `Pers_Status = 1 AND Pers_Deleted IS NULL`.

## ExecuteAndMap (optional wrapper)

Existing services (CRMPollerFixer, JordanPrice) use the ServiceLib ODBC wrapper with lambda mappers — see `ODBC.cs` in this folder. Optional for new code; plain ADO.NET is fine. Set `CommandTimeout = 60` for long DuckDB queries, and check `IsDBNull()` before reading — Exportmaster data is full of nulls.
