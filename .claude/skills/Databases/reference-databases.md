# Databases — worked examples and detail

Companion to `SKILL.md`. Proven code from production projects (BPQuery, CRMPollerFixer, JordanPrice, CS-EM2Parquet, ElastiCompare).

## Exportmaster (DBISAM) query pattern

Prices join and mapping via the ServiceLib ODBC wrapper (`ODBC.cs` in this folder):

```csharp
using var exportMasterOdbc = new ODBC(_exportMasterConnectionString, _logger);

var query = $@"
SELECT p.SphType AS PriceProfile,
       p.SphRt AS ListType,
       p.SphBasis AS RangeIdentifier,
       p.SphKey1 AS Sphkey1,
       pd.SpdDateEff AS EffectiveDate,
       pd.SpdValue1 AS ListBreakValue1
FROM PRICES p
JOIN PRICDETL pd ON p.SphLink = pd.SpdLink
WHERE p.SphRt IN (144, 244)
  AND p.SphPeriod = 1
  AND p.SphKey1 IN ({inClause})
ORDER BY p.SphKey1, pd.SpdDateEff";

var results = exportMasterOdbc.ExecuteAndMap(query, null, reader => new PriceDiscountDocument
{
    Sphkey1 = reader.IsDBNull(reader.GetOrdinal("Sphkey1")) ? "" : reader.GetValue(reader.GetOrdinal("Sphkey1")).ToString(),
    ListBreakValue1 = reader.IsDBNull(reader.GetOrdinal("ListBreakValue1")) ? 0 : Convert.ToDecimal(reader.GetValue(reader.GetOrdinal("ListBreakValue1")))
});
```

Notes:
- `SphRt IN (144, 244)` = per-customer discount list types; `SphKey1` holds the customer code.
- Verify a customer's per-customer discounts in the DuckDB CLI: join `sem01.prices` → `sem01.pricdetl` on `SphLink = SpdLink`, filter `SPHKEY1 = '<customer>'` and `SPHRT IN (144, 244)`.
- Identifiers are case-insensitive in DuckDB; DBISAM column casing (`SpdValue1`) shows in output but need not be matched on input.
- Incremental sync pattern: `SELECT * FROM PRICDETL WHERE SpdDateEff > ?` using the max already-loaded date.

## Exportmaster key tables

- `PRICES` — pricing header. `SphType` (price profile), `SphRt` (list type), `SphBasis` (range identifier), `SphKey1`, `SphPeriod`, `SphLink` (join key)
- `PRICDETL` — price detail. `SpdLink` (joins to `PRICES.SphLink`), `SpdDateEff` (effective date), `SpdValue1`
- `STOCK` — product information
- `CUSTOMER` — customer records, incl. `Profile` + `UF_AltProf1..11` range-profile assignments
- `PROFILE` — pricing profiles. Key is `SppGroup`+`SppCode`; `SppPrice1/2`, `SppDiscount1/2` are list types

## PostgreSQL: VARCHAR(n) function-call casts (full example)

PostgreSQL treats `VARCHAR` without a length as a different type from `VARCHAR(n)`, so a function defined as e.g.

```sql
CREATE FUNCTION upsert_price_discount(
    p_price_profile VARCHAR(15),
    p_sphkey1 VARCHAR(20),
    p_currency_code VARCHAR(10),
    p_quantity INTEGER,
    p_amount NUMERIC(9,2)
) RETURNS VOID ...
```

must be called with casts matching the signature:

```csharp
await using var cmd = new NpgsqlCommand(@"
    SELECT rocs.upsert_price_discount(
        $1::VARCHAR(15),
        $2::VARCHAR(20),
        $3::VARCHAR(10),
        $4, $5
    )", connection);

cmd.Parameters.Add(new NpgsqlParameter { Value = doc.PriceProfile, NpgsqlDbType = NpgsqlDbType.Varchar });
cmd.Parameters.Add(new NpgsqlParameter { Value = doc.Sphkey1, NpgsqlDbType = NpgsqlDbType.Varchar });

// Nullable VARCHAR: specify the type even for NULL
cmd.Parameters.Add(new NpgsqlParameter
{
    Value = string.IsNullOrEmpty(doc.CurrencyCode) ? DBNull.Value : doc.CurrencyCode,
    NpgsqlDbType = NpgsqlDbType.Varchar
});

cmd.Parameters.AddWithValue(doc.Quantity);  // INTEGER - inferred, no cast
cmd.Parameters.AddWithValue(doc.Amount);    // NUMERIC - inferred, no cast
```

Error symptom: `function ... does not exist` mentioning `character varying`, with hint "You might need to add explicit type casts" — that means missing `::VARCHAR(n)` casts.

Legacy ODBC PostgreSQL code (CRMPollerFixer, JordanPrice via ServiceLib) substitutes `?` placeholders with escaped literals and `ARRAY[...]` strings — only maintain that pattern where it already exists; use Npgsql for anything new.

## PgQuery usage

```bash
PgQuery --config "R:\JsonParams\mydb.config.json" --sql "SELECT * FROM products LIMIT 10"
PgQuery --config "R:\JsonParams\mydb.config.json" --file query.sql
PgQuery -c "R:\JsonParams\mydb.config.json" -s "SELECT * FROM products" -o results.txt
PgQuery --config "R:\JsonParams\mydb.config.json" --sql "UPDATE orders SET status = 'shipped' WHERE order_id = 12345"
```

SELECTs print a formatted table with row count; UPDATE/INSERT/DELETE/CREATE/DROP/ALTER/TRUNCATE print `(n row(s) affected)`. Release builds deploy to `\\rivsts05\Software\CSharpDLLs\PgQuery\` (mapped `Y:\CSharpDLLs\PgQuery\`). Source: `PgQuery.cs` in this folder.

## DuckDB from C#

`DSN=DuckDB` over `System.Data.Odbc`, `?` placeholders, `CommandTimeout = 60` for large files. Reads Parquet directly:

```csharp
string sql = @"
SELECT username, TYPE, ERROR, MAX(EVENT_TIME) as EVENT_TIME
FROM read_parquet('C:\RI Services\Outputs\Parquets\rocs\event_entity.parquet')
WHERE TYPE NOT IN ('CODE_TO_TOKEN', 'LOGOUT')
  AND EVENT_TIME >= ?
GROUP BY username, TYPE, ERROR
ORDER BY EVENT_TIME DESC
LIMIT 40";
```

Also useful: `json_extract_string(DETAILS_JSON, '$.username')`. The bare CLI exe is `Y:\Data Warehouse\duckdb\duckdb.exe` (but prefer the `.bat` launcher, which wires up the Exportmaster ATTACHes).

## keycloak MySQL

Native MySql.Data, `@param` style. `EVENT_ENTITY` is the main table; `JSON_EXTRACT(DETAILS_JSON, '$.username')` for user filtering, unix-timestamp `EVENT_TIME`, batches up to 50k rows with time-based incremental sync.

## X3 / Sage1000 query shape

```sql
SELECT Person.Pers_PersonId, Person.Pers_FirstName, Person.Pers_LastName,
       Person.Pers_EmailAddress, Person.pers_webusername, Person.pers_webaccesslevel,
       Account.Acc_Name, Account.acc_code, Company.Comp_Name
FROM Person
    LEFT OUTER JOIN Company ON Person.Pers_CompanyId = Company.Comp_CompanyId
    LEFT OUTER JOIN Account ON Person.Pers_AccountId = Account.Acc_AccountID
WHERE Person.Pers_Status = 1
  AND Person.Pers_Deleted IS NULL
```
