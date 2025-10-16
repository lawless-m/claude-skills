---
name: Databases
description: RDBMS access patterns for DuckDB, MySQL (keycloak), PostgreSQL (dw, x3rocs), SQL Server (sage1000, x3), and DBISAM (Exportmaster) using ODBC and native drivers
---

# Databases

## Instructions

When helping users work with database access in C#, follow these guidelines:

1. **Library Selection**:
   - **DuckDB**: Use `System.Data.Odbc` with DSN=DuckDB
   - **PostgreSQL**: Use `Npgsql` for direct access (recommended) or ODBC for legacy
   - **MySQL**: Use `MySql.Data` for native access or ODBC
   - **SQL Server/X3/Sage1000**: Use `System.Data.Odbc`
   - **Exportmaster (DBISAM)**: Use `System.Data.Odbc`

2. **Parameter Styles**:
   - ODBC connections: `?` placeholders
   - Native MySQL: `@parameter` style
   - Native PostgreSQL: `$1, $2, $3` positional parameters

3. **ExecuteAndMap Pattern**: Use the ServiceLib ODBC wrapper with lambda mappers for type-safe result mapping

4. **Connection Management**: Always use `using` statements for connections and commands

5. **Timeout Handling**: Set `CommandTimeout = 60` for long-running queries (especially DuckDB)

6. **Null Safety**: Always check `IsDBNull()` before reading values, provide sensible defaults

7. **PostgreSQL Arrays**: For native PostgreSQL, use native array support. For ODBC, use the array literal helper functions

8. **PgQuery Tool**: Reference the PgQuery tool (`C:\Users\matthew.heath\Git\RocsMiddleware\PgQuery`) for executing ad-hoc PostgreSQL queries

## Examples

### Example 1: Query DuckDB Parquet Files
```
User: Help me query a Parquet file using DuckDB

Claude: I'll use DuckDB's ODBC driver to query the Parquet file directly:
- Connection: DSN=DuckDB
- Feature: read_parquet() function
- Parameters: ? placeholders
- Timeout: 60 seconds for large files

[Provides implementation using the DuckDB pattern from reference material below]
```

### Example 2: Direct PostgreSQL Access
```
User: I need to query PostgreSQL with array parameters

Claude: I'll use Npgsql for direct PostgreSQL access:
- Native array support
- Positional parameters ($1, $2)
- Better performance than ODBC
- Proper PostgreSQL type handling

[Provides implementation using the Npgsql pattern from reference material below]
```

### Example 3: Execute Ad-Hoc PostgreSQL Query
```
User: Can you run this query on PostgreSQL and show me the results?

Claude: I'll use the PgQuery tool to execute your query:
- Command: PgQuery "YOUR SQL QUERY"
- Can save to file with -o flag
- Formatted table output

[Executes: PgQuery "SELECT * FROM products LIMIT 10"]
```

### Example 4: Type-Safe Mapping with ExecuteAndMap
```
User: How do I safely map database results to C# objects?

Claude: I'll use the ExecuteAndMap pattern with null-safe mapping:
- Lambda mapper for type conversion
- IsDBNull checks with defaults
- Automatic connection management

[Provides implementation using the ExecuteAndMap pattern from reference material below]
```

---

# Reference Implementation Details

The sections below contain proven working code from production systems that the examples above reference.

**Reference Files in This Folder**:
- `ODBC.cs` - ServiceLib ODBC wrapper with ExecuteAndMap pattern
- `PgQuery.cs` - Command-line tool for ad-hoc PostgreSQL queries

# RDBMS Access Patterns

**Primary Libraries**:
- `System.Data.Odbc` (versions 8.0.0 - 9.0.2) for ODBC connections
- `Npgsql` for direct PostgreSQL access
- `MySql.Data` for native MySQL access

## Database Access Patterns by System

### DuckDB ODBC Access

**Connection String**: `DSN=DuckDB`
**Parameter Style**: `?` placeholders
**Projects**: BPQuery, CRMPollerFixer, JordanPrice, ElastiCompare

```csharp
using var connection = new OdbcConnection("DSN=DuckDB");
connection.Open();

string sql = @"
SELECT username, TYPE, ERROR, MAX(EVENT_TIME) as EVENT_TIME
FROM read_parquet('C:\RI Services\Outputs\Parquets\rocs\event_entity.parquet')
WHERE TYPE NOT IN ('CODE_TO_TOKEN', 'LOGOUT')
  AND EVENT_TIME >= ?
GROUP BY username, TYPE, ERROR
ORDER BY EVENT_TIME DESC
LIMIT 40";

using var command = new OdbcCommand(sql, connection);
command.CommandTimeout = 60;
command.Parameters.Add(new OdbcParameter("p1", minTimestamp));
```

**DuckDB Features**:
- Direct Parquet file reading: `read_parquet('path')`
- JSON extraction: `json_extract_string(DETAILS_JSON, '$.username')`
- Complex aggregations and window functions
- Unix timestamp handling

### Exportmaster ODBC Access (DBISAM)

**Connection String**: `DSN=Exportmaster`
**Parameter Style**: `?` placeholders
**Projects**: CRMPollerFixer, JordanPrice, CS-EM2Parquet

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
    PriceProfile = reader.IsDBNull(reader.GetOrdinal("PriceProfile")) ? "0" : reader.GetValue(reader.GetOrdinal("PriceProfile")).ToString(),
    ListType = reader.IsDBNull(reader.GetOrdinal("ListType")) ? "0" : reader.GetValue(reader.GetOrdinal("ListType")).ToString(),
    ListBreakValue1 = reader.IsDBNull(reader.GetOrdinal("ListBreakValue1")) ? 0 : Convert.ToDecimal(reader.GetValue(reader.GetOrdinal("ListBreakValue1")))
});
```

**Exportmaster Key Tables**:
- `PRICES` - Main pricing data
- `PRICDETL` - Price detail records
- `STOCK` - Product information

### X3 MS SQL Server Access

**Connection String**: `DSN=OCS1;UID=sa;PWD=1NT3rn@t10n@l;`
**Parameter Style**: `?` placeholders
**Projects**: BPQuery

```csharp
using var connection = new OdbcConnection(connectionString);
connection.Open();

string sql = @"
SELECT Person.Pers_CompanyId, Person.Pers_AccountId, Person.Pers_FirstName,
       Person.Pers_LastName, Person.Pers_EmailAddress, Account.Acc_Name,
       Person.pers_webusername, Person.pers_webaccesslevel
FROM Person
    LEFT OUTER JOIN Company ON Person.Pers_CompanyId = Company.Comp_CompanyId
    LEFT OUTER JOIN Account ON Person.Pers_AccountId = Account.Acc_AccountID
WHERE Person.Pers_EmailAddress LIKE ?
   OR Person.pers_webusername LIKE ?
   OR Account.acc_code LIKE ?";

using var command = new OdbcCommand(sql, connection);
command.Parameters.Add(new OdbcParameter("p1", $"%{searchTerm}%"));
command.Parameters.Add(new OdbcParameter("p2", $"%{searchTerm}%"));
command.Parameters.Add(new OdbcParameter("p3", $"%{searchTerm}%"));
```

**X3 Key Tables**:
- `Person` - User/contact data
- `Company` - Company information
- `Account` - Account information

### Sage1000 ODBC Access

**Connection String**: `DSN=OCS1;UID=sa;PWD=1NT3rn@t10n@l;`
**Parameter Style**: `?` placeholders
**Projects**: BPQuery, CS-EM2Parquet (configured)
**Note**: Same connection as X3, but server will be deprecated soon

```csharp
using var connection = new OdbcConnection(connectionString);
connection.Open();

string sql = @"
SELECT Person.Pers_PersonId, Person.Pers_FirstName, Person.Pers_LastName,
       Person.Pers_EmailAddress, Person.pers_webusername, Person.pers_webaccesslevel,
       Person.pers_WebAllowBannedProducts, Person.pers_WebOrderBannedProducts,
       Account.Acc_Name, Account.acc_code, Company.Comp_Name
FROM Person
    LEFT OUTER JOIN Company ON Person.Pers_CompanyId = Company.Comp_CompanyId
    LEFT OUTER JOIN Account ON Person.Pers_AccountId = Account.Acc_AccountID
WHERE Person.Pers_Status = 1
  AND Person.Pers_Deleted IS NULL";

using var command = new OdbcCommand(sql, connection);
```

**Sage1000 Permission Fields**:
- `pers_webaccesslevel` - User access level
- `pers_WebAllowBannedProducts` - Banned product access
- `pers_WebOrderBannedProducts` - Order banned products
- `pers_WebExportProducts` - Export permissions
- `pers_WebDownloadImages` - Image download rights

### MySQL Access Patterns

**Connection String (Native)**: `Server=rocs-production-es.ramsden-international.com;Port=6033;Database=keycloak;Uid=crm;Pwd=CrmP0ller;`
**Parameter Style**: `@parameter` (native) or `?` (ODBC)
**Projects**: BPQuery, CS-EM2Parquet

```csharp
// Native MySQL connection
using var connection = new MySqlConnection(connectionString);
connection.Open();

string sql = @"
SELECT EVENT_TIME, TYPE, ERROR, IP_ADDRESS, CLIENT_ID, DETAILS_JSON
FROM EVENT_ENTITY
WHERE JSON_EXTRACT(DETAILS_JSON, '$.username') = @username
  AND EVENT_TIME > @minTime
ORDER BY EVENT_TIME DESC
LIMIT 50000";

using var command = new MySqlCommand(sql, connection);
command.Parameters.AddWithValue("@username", username);
command.Parameters.AddWithValue("@minTime", minTimestamp);
```

**MySQL Features**:
- JSON_EXTRACT for complex data
- Unix timestamp handling
- Large batch processing (50k records)
- Incremental sync with time-based filtering

### PostgreSQL Direct Access (Npgsql - Recommended)

**Connection String**: `Host=rivsprod01;Database=x3rocs;Username=jordan`
**Parameter Style**: `$1, $2, $3` positional parameters
**Library**: `Npgsql`
**Projects**: PgQuery (command-line tool)

```csharp
using Npgsql;

// Direct PostgreSQL connection with native features
using var conn = new NpgsqlConnection("Host=rivsprod01;Database=x3rocs;Username=jordan");
conn.Open();

// Native array support - no special handling needed!
string sql = "SELECT * FROM products WHERE category = ANY($1) AND active = $2";
using var cmd = new NpgsqlCommand(sql, conn);
cmd.Parameters.AddWithValue(new[] { "electronics", "computers" });
cmd.Parameters.AddWithValue(true);

using var reader = cmd.ExecuteReader();
while (reader.Read())
{
    var id = reader.GetInt32(0);
    var name = reader.GetString(1);
    var category = reader.GetString(2);
}
```

**Key Benefits**:
- Native array support (no manual ARRAY[] construction)
- Better performance than ODBC
- PostgreSQL-specific features (JSON, arrays, etc.)
- Proper parameter typing
- Simpler code

### PostgreSQL ODBC Access (Legacy)

**Connection String**: ODBC DSN-based (specific DSN varies)
**Parameter Style**: `?` with special array handling
**Projects**: CRMPollerFixer, JordanPrice (via ServiceLib)
**Note**: Use Npgsql for new development

```csharp
// Legacy ODBC array parameter handling - only use for existing ODBC code
public static string CreatePostgresArrayLiteral(IEnumerable<string> values)
{
    var escapedValues = values.Select(v => "'" + v.Replace("'", "''") + "'");
    return $"ARRAY[{string.Join(", ", escapedValues)}]";
}

public static string PreparePostgresQuery(string sqlQuery, Dictionary<string, object> parameters)
{
    string result = sqlQuery;
    foreach (var param in parameters)
    {
        string paramValue;
        if (param.Value is IEnumerable<string> stringArray)
        {
            paramValue = CreatePostgresArrayLiteral(stringArray);
        }
        else if (param.Value is bool boolValue)
        {
            paramValue = boolValue ? "true" : "false";
        }
        else if (param.Value is string stringValue)
        {
            paramValue = "'" + stringValue.Replace("'", "''") + "'";
        }
        else
        {
            paramValue = param.Value?.ToString() ?? "NULL";
        }

        int pos = result.IndexOf('?');
        if (pos >= 0)
        {
            result = result.Substring(0, pos) + paramValue + result.Substring(pos + 1);
        }
    }
    return result;
}
```

## PgQuery Command-Line Tool

**Location**: `C:\Users\matthew.heath\Git\RocsMiddleware\PgQuery`
**Purpose**: Ad-hoc PostgreSQL query execution with formatted output
**Connection**: `Host=rivsprod01;Database=x3rocs;Username=jordan`

### Usage Patterns

```bash
# Execute SQL directly
PgQuery "SELECT * FROM products LIMIT 10"

# Execute SQL from file
PgQuery -f query.sql

# Save output to file
PgQuery "SELECT * FROM products" -o results.txt
PgQuery -f query.sql -o results.txt
```

### Implementation (PgQuery/Program.cs)

```csharp
using Npgsql;

var connString = "Host=rivsprod01;Database=x3rocs;Username=jordan";

using var conn = new NpgsqlConnection(connString);
conn.Open();

using var cmd = new NpgsqlCommand(sql, conn);
using var reader = cmd.ExecuteReader();

// Formatted table output
for (int i = 0; i < reader.FieldCount; i++)
{
    Console.Write(reader.GetName(i).PadRight(25));
}
Console.WriteLine();

while (reader.Read())
{
    for (int i = 0; i < reader.FieldCount; i++)
    {
        var value = reader.IsDBNull(i) ? "NULL" : reader.GetValue(i).ToString();
        Console.Write((value ?? "NULL").PadRight(25));
    }
    Console.WriteLine();
}
```

**When to Use PgQuery**:
- Quick ad-hoc queries during development
- Testing SQL before integrating into code
- Exploring database schema and data
- Generating reports to file

## ExecuteAndMap Pattern Implementation

### Core Implementation (ServiceLib/ODBC.cs)

```csharp
public class ODBC : IDisposable
{
    private readonly OdbcConnection _connection;
    private readonly ILogger _logger;

    public ODBC(string connectionString, ILogger logger)
    {
        _connectionString = connectionString;
        _connection = new OdbcConnection(connectionString);
        _logger = logger;
    }

    public List<TResult> ExecuteAndMap<TResult>(
        string query,
        Dictionary<string, object>? parameters,
        Func<IDataReader, TResult> mapper
    )
    {
        var results = new List<TResult>();

        try
        {
            Open();
            using var reader = ExecuteReader(query, parameters);
            while (reader.Read())
            {
                results.Add(mapper(reader));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing query: {Query}", query);
            throw;
        }
        finally
        {
            Close();
        }

        return results;
    }

    private IDataReader ExecuteReader(string query, Dictionary<string, object>? parameters)
    {
        var command = new OdbcCommand(query, _connection);

        if (parameters != null)
        {
            foreach (var param in parameters)
            {
                command.Parameters.Add(new OdbcParameter(param.Key, param.Value));
            }
        }

        return command.ExecuteReader();
    }
}
```

### Usage Patterns

```csharp
// Simple mapping
var users = odbc.ExecuteAndMap("SELECT * FROM Person WHERE Pers_Status = ?",
    new Dictionary<string, object> { {"status", 1} },
    reader => new User
    {
        Id = reader.GetInt32("Pers_PersonId"),
        FirstName = reader.GetString("Pers_FirstName"),
        LastName = reader.GetString("Pers_LastName"),
        Email = reader.GetString("Pers_EmailAddress")
    });

// Safe null handling
var prices = odbc.ExecuteAndMap(query, null, reader => new PriceData
{
    ProductCode = reader.IsDBNull(4) ? "" : reader.GetValue(4).ToString() ?? "",
    ListPrice = reader.IsDBNull(18) ? 0 : Convert.ToDecimal(reader.GetValue(18)),
    EffectiveDate = reader.IsDBNull(16) ? DateTime.MinValue : Convert.ToDateTime(reader.GetValue(16))
});

// Complex data transformation
var events = odbc.ExecuteAndMap(eventQuery, null, reader => new EventData
{
    Username = JsonExtract(reader.GetString("DETAILS_JSON"), "$.username"),
    EventTime = UnixTimeStampToDateTime(reader.GetInt64("EVENT_TIME")),
    EventType = reader.GetString("TYPE"),
    HasError = !string.IsNullOrEmpty(reader.GetString("ERROR"))
});
```

## Parameter Styles by Database System

| Database | Parameter Style | Example | Notes |
|----------|----------------|---------|--------|
| **DuckDB** | `?` placeholders | `WHERE EVENT_TIME >= ?` | ODBC standard |
| **Exportmaster** | `?` placeholders | `WHERE SPHKEY1 IN (?)` | DBISAM system |
| **X3 SQL Server** | `?` placeholders | `WHERE Person.Pers_EmailAddress LIKE ?` | Via ODBC |
| **Sage1000** | `?` placeholders | `WHERE Person.Pers_Status = ?` | Via ODBC |
| **MySQL (Native)** | `@parameter` style | `WHERE username = @username` | MySqlCommand |
| **MySQL (ODBC)** | `?` placeholders | `WHERE username = ?` | Standard ODBC |
| **PostgreSQL (Npgsql)** | `$1, $2, $3` positional | `WHERE category = ANY($1)` | **Recommended** |
| **PostgreSQL (ODBC)** | `?` with literals | `WHERE category = ANY(ARRAY['val1'])` | Legacy only |

## Database-Specific Considerations

### Connection Management
```csharp
// Standard pattern for all ODBC connections
using var connection = new OdbcConnection(connectionString);
connection.Open();

// Timeout handling
using var command = new OdbcCommand(sql, connection);
command.CommandTimeout = 60; // DuckDB needs longer timeouts
```

### Batch Processing
```csharp
// MySQL batch processing (50k records)
const int batchSize = 50000;
string sql = "SELECT * FROM EVENT_ENTITY WHERE EVENT_TIME > @minTime LIMIT @batchSize OFFSET @offset";

// DuckDB batch processing (40 records for UI)
string sql = "SELECT * FROM read_parquet('file.parquet') ORDER BY EVENT_TIME DESC LIMIT 40";

// Exportmaster incremental processing
var maxDate = existingData.Max(x => x.EffectiveDate);
string sql = "SELECT * FROM PRICDETL WHERE SpdDateEff > ?";
```

### Error Handling Patterns
```csharp
try
{
    var results = odbc.ExecuteAndMap(query, parameters, mapper);
    _logger.LogInformation($"Retrieved {results.Count} records from {databaseName}");
    return results;
}
catch (OdbcException ex)
{
    _logger.LogError(ex, "ODBC error executing query against {Database}: {Query}", databaseName, query);
    throw;
}
catch (Exception ex)
{
    _logger.LogError(ex, "Unexpected error executing query against {Database}", databaseName);
    throw;
}
```

## Migration Recommendations

### ODBC to Native Driver Migration

**PostgreSQL (ODBC → Npgsql)**:
- ✅ Direct access implemented and proven (PgQuery)
- ✅ Native array support simplifies code
- ✅ Better performance
- **Action**: Use Npgsql for all new PostgreSQL development

**MySQL (ODBC → MySql.Data)**:
- Already using native driver in production (BPQuery)
- Use native driver for new development


**DuckDB**:
- Continue using ODBC
- No native C# driver available
- ODBC provides all needed features

**Exportmaster**
- Continue using ODBC
- Proprietary systems with limited driver options

**X3/Sage1000**
- Microsoft SQL Server
- use native driver