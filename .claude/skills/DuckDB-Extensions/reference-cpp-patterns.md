# C++ Patterns for DuckDB Extensions

## Extension entry point

Function names in the `extern "C"` block must match the extension name: `{name}_init` and `{name}_version`. `DUCKDB_EXTENSION_API` ensures proper symbol visibility.

```cpp
#define DUCKDB_EXTENSION_MAIN

#include "duckdb.hpp"
#include "duckdb/main/extension_util.hpp"

namespace duckdb {

void RegisterMyTableFunction(DatabaseInstance &db);

static void LoadInternal(DatabaseInstance &instance) {
    RegisterMyTableFunction(instance);
}

void MyextensionExtensionLoad(DuckDB &db) {
    LoadInternal(*db.instance);
}

std::string MyextensionExtensionVersion() {
    return "v1.0.0";
}

} // namespace duckdb

extern "C" {
DUCKDB_EXTENSION_API void myextension_init(duckdb::DatabaseInstance &db) {
    duckdb::LoadInternal(db);
}
DUCKDB_EXTENSION_API const char *myextension_version() {
    return duckdb::MyextensionExtensionVersion().c_str();
}
}
```

## Table function (DuckDB 1.1+, const bind_data)

Bind data is immutable during execution; mutable state lives in `GlobalTableFunctionState`.

```cpp
#include "duckdb.hpp"
#include "duckdb/function/table_function.hpp"
#include "duckdb/main/extension_util.hpp"

namespace duckdb {

// Immutable bind data
struct MyTableBindData : public TableFunctionData {
    std::vector<std::string> items;
};

// Mutable execution state
struct MyTableState : public GlobalTableFunctionState {
    idx_t offset = 0;
};

static unique_ptr<FunctionData> MyTableBind(
    ClientContext &context,
    TableFunctionBindInput &input,
    vector<LogicalType> &return_types,
    vector<string> &names) {

    return_types.push_back(LogicalType::VARCHAR);
    names.push_back("item");

    auto result = make_uniq<MyTableBindData>();
    result->items = {"one", "two", "three"};
    return std::move(result);
}

static unique_ptr<GlobalTableFunctionState> MyTableInitGlobal(
    ClientContext &context, TableFunctionInitInput &input) {
    return make_uniq<MyTableState>();
}

static void MyTableExecute(
    ClientContext &context,
    TableFunctionInput &input,
    DataChunk &output) {

    auto &bind_data = input.bind_data->Cast<MyTableBindData>();
    auto &state = input.global_state->Cast<MyTableState>();

    idx_t count = 0;
    while (state.offset < bind_data.items.size() && count < STANDARD_VECTOR_SIZE) {
        output.SetValue(0, count, Value(bind_data.items[state.offset]));
        state.offset++;
        count++;
    }
    output.SetCardinality(count);
}

void RegisterMyTableFunction(DatabaseInstance &db) {
    TableFunction func("my_table", {}, MyTableExecute, MyTableBind);
    func.init_global = MyTableInitGlobal;
    ExtensionUtil::RegisterFunction(db, func);
}

} // namespace duckdb
```

## Registering custom settings

Settings only exist after the extension loads (hence LOAD before SET in `.duckdbrc`).

```cpp
#include "duckdb/main/config.hpp"

static void LoadInternal(DatabaseInstance &instance) {
    auto &config = DBConfig::GetConfig(instance);

    // Register string setting with default
    config.AddExtensionOption("myextension_host", "Server hostname",
                              LogicalType::VARCHAR, Value("localhost"));

    // Register integer setting
    config.AddExtensionOption("myextension_port", "Server port",
                              LogicalType::INTEGER, Value(50051));

    // Register functions...
}
```

Reading a setting:

```cpp
Value host_value;
if (context.TryGetCurrentSetting("myextension_host", host_value)) {
    std::string host = host_value.GetValue<std::string>();
}
```

## Loading during development

```sql
LOAD '/path/to/myextension.duckdb_extension';
-- or start with: duckdb -unsigned
```
