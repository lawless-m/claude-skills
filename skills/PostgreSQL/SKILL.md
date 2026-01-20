---
name: PostgreSQL
description: PostgreSQL database operations using PgQuery tool for DDL execution, schema management, and query operations
---

# PostgreSQL

This skill covers PostgreSQL database operations using the PgQuery command-line tool for executing DDL scripts, managing schemas, and running queries against PostgreSQL databases.

## Instructions

When helping users with PostgreSQL operations, follow these guidelines:

1. **Always Use PgQuery Tool**: Use `Y:/CSharpDLLs/PgQuery/PgQuery.exe` for all PostgreSQL operations. Never use `psql` or other PostgreSQL clients directly.

2. **Configuration Files**: PostgreSQL connection details are stored in JSON configuration files (typically in `R:/JsonParams/`). Common configs:
   - `x3rocs_db.json` - x3rocs database connection
   - `dw_db.json` - Data warehouse connection

3. **Command Format**: Use `--config` for database connection and either `--file` for SQL files or `--sql` for inline SQL:
   ```bash
   Y:/CSharpDLLs/PgQuery/PgQuery.exe --config "<config-path>" --file "<sql-file-path>"
   ```

4. **DDL Execution Order**: When executing multiple DDL scripts that have dependencies:
   - Create new tables before tables that reference them (foreign keys)
   - Drop tables in reverse order (dependent tables first)
   - Handle permission errors by checking if shared functions already exist

5. **Error Handling**: Common PostgreSQL errors:
   - `42501: must be owner of function` - Shared function already exists, skip recreation
   - `42P01: relation does not exist` - Table/view doesn't exist, check dependencies
   - `23503: foreign key violation` - Referenced table missing or data constraint violated

6. **Schema Organization**: Follow the project's schema organization:
   - `x3` schema - X3 integration data (customers, contacts, etc.)
   - `rocs` schema - ROCS application data (price discounts, etc.)
   - `public` schema - Shared utilities and functions

## Examples

### Example 1: Execute a DDL Script
```
User: Run the contact.sql DDL to create the new contact table

Claude: I'll execute the contact.sql DDL using PgQuery:
- Use the x3rocs database connection
- Execute the file from the Postgresql directory
- Handle any permission errors for shared functions

[Runs: Y:/CSharpDLLs/PgQuery/PgQuery.exe --config "R:/JsonParams/x3rocs_db.json" --file "c:/Users/matthew.heath/Git/RocsMiddleware/Postgresql/contact.sql"]
```

### Example 2: Execute Multiple Dependent DDL Files
```
User: We need to update the customer and contact tables - contact has a foreign key to customer

Claude: I'll execute these in the correct order:
1. First run customer.sql (parent table)
2. Then run contact.sql (child table with foreign key)
3. Report any errors

[Executes customer.sql first, then contact.sql]
```

### Example 3: Run Ad-Hoc Query
```
User: Check if the x3.contact table exists

Claude: I'll query the PostgreSQL information schema:

[Runs: Y:/CSharpDLLs/PgQuery/PgQuery.exe --config "R:/JsonParams/x3rocs_db.json" --sql "SELECT table_name FROM information_schema.tables WHERE table_schema = 'x3' AND table_name = 'contact'"]
```

---

# Reference Implementation Details

## PgQuery Tool

**Location**: `Y:/CSharpDLLs/PgQuery/PgQuery.exe` or `C:/Users/matthew.heath/Git/PgQuery`
**Purpose**: Command-line tool for executing PostgreSQL queries and DDL scripts with JSON configuration support

### Command Syntax

```bash
# Execute SQL file
Y:/CSharpDLLs/PgQuery/PgQuery.exe --config "<config-file>" --file "<sql-file>"

# Execute inline SQL
Y:/CSharpDLLs/PgQuery/PgQuery.exe --config "<config-file>" --sql "<sql-statement>"
```

**Parameters**:
- `--config` (required): Path to PostgreSQL connection config JSON file
- `--file`: Path to SQL file to execute
- `--sql`: Inline SQL statement to execute
- Must specify either `--file` or `--sql`, not both

### Configuration File Format

**Location**: `R:/JsonParams/*.json`

```json
{
  "host": "rivsprod01",
  "port": "5432",
  "database": "x3rocs",
  "username": "jordan",
  "password": "your-password"
}
```

## Common DDL Patterns

### Creating Tables with Foreign Keys

**Pattern**: Always create parent tables before child tables

```sql
-- Parent table (customer.sql)
DROP TABLE IF EXISTS x3.customer CASCADE;
CREATE TABLE x3.customer (
    customer_code VARCHAR(30) PRIMARY KEY,
    customer_name VARCHAR(50) NOT NULL,
    -- ... other fields
);

-- Child table (contact.sql) - references parent
DROP TABLE IF EXISTS x3.contact CASCADE;
CREATE TABLE x3.contact (
    customer_code VARCHAR(30) NOT NULL,
    contact_code VARCHAR(15) NOT NULL,
    -- ... other fields
    PRIMARY KEY (customer_code, contact_code),
    FOREIGN KEY (customer_code) REFERENCES x3.customer(customer_code) ON DELETE CASCADE
);
```

**Execution Order**:
1. Execute `customer.sql` first
2. Execute `contact.sql` second

### Hash-Based Change Detection

**Pattern**: Use MD5 hash triggers for detecting data changes

```sql
-- Hash column in table
CREATE TABLE x3.customer (
    customer_code VARCHAR(30) PRIMARY KEY,
    -- ... data fields
    x3_hash VARCHAR(32),  -- MD5 hash for change detection
    updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Hash calculation function
CREATE OR REPLACE FUNCTION x3.update_customer_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.x3_hash := md5(
        COALESCE(NEW.customer_code, '') || '|' ||
        COALESCE(NEW.customer_name, '') || '|' ||
        -- ... concatenate all fields for hashing
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate hash
CREATE TRIGGER trg_update_customer_x3hash
    BEFORE INSERT OR UPDATE ON x3.customer
    FOR EACH ROW
    EXECUTE FUNCTION x3.update_customer_hash();
```

**Key Points**:
- MD5 is sufficient for change detection (not security)
- 32 characters (VARCHAR(32)) for MD5 hex output
- Exclude timestamp and hash fields from hash calculation
- Use `||` for string concatenation with pipe delimiter

### Upsert Functions

**Pattern**: Stored procedures for INSERT ... ON CONFLICT DO UPDATE

```sql
CREATE OR REPLACE FUNCTION x3.upsert_contact(
    p_customer_code VARCHAR(30),
    p_contact_code VARCHAR(15),
    p_title VARCHAR(20),
    -- ... other parameters
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO x3.contact (
        customer_code, contact_code, title, -- ...
    ) VALUES (
        p_customer_code, p_contact_code, p_title, -- ...
    )
    ON CONFLICT (customer_code, contact_code)
    DO UPDATE SET
        title = EXCLUDED.title,
        -- ... update all fields
END;
$$ LANGUAGE plpgsql;
```

## Troubleshooting

### Permission Error: "must be owner of function"

**Cause**: Shared function already exists and is owned by another user

**Solution**: Skip recreating the shared function or comment it out in the DDL script

```sql
-- Comment out if function already exists
-- CREATE OR REPLACE FUNCTION x3.update_updated_column()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated = CURRENT_TIMESTAMP;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE 'plpgsql';
```

### Foreign Key Violation on Table Creation

**Cause**: Referenced table doesn't exist yet

**Solution**: Execute DDL files in dependency order (parent tables first)

### Cascade Drop Warning

**Cause**: `DROP TABLE ... CASCADE` will drop dependent objects

**Solution**: This is expected behavior. The CASCADE keyword is intentional for clean rebuilds.

## Best Practices

1. **Always Use Absolute Paths**: PgQuery requires absolute paths for `--file` parameter
2. **Test on Non-Production First**: Execute DDL on test databases before production
3. **Use CASCADE on DROP**: `DROP TABLE IF EXISTS x3.customer CASCADE` ensures clean drops
4. **Hash for Change Detection**: Use MD5 hashing to track when data changes between systems
5. **Composite Primary Keys**: Use format `(customer_code, contact_code)` for multi-column keys
6. **Foreign Key Cascades**: Use `ON DELETE CASCADE` for parent-child relationships
7. **Schema Namespacing**: Keep tables organized in schemas (`x3.`, `rocs.`, etc.)
8. **Timestamp Triggers**: Auto-update `updated` column with BEFORE UPDATE triggers
