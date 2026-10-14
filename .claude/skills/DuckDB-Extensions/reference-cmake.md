# CMake Reference for DuckDB Extensions

## Full CMakeLists.txt template

```cmake
cmake_minimum_required(VERSION 3.21)

set(TARGET_NAME myextension)
set(EXTENSION_NAME ${TARGET_NAME}_extension)
set(LOADABLE_EXTENSION_NAME ${TARGET_NAME}_loadable_extension)

project(${TARGET_NAME})

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

# Extension sources
set(EXTENSION_SOURCES
    src/myextension.cpp
    src/table_functions.cpp
)

# Fetch DuckDB - use exact version tag
FetchContent_Declare(
    duckdb
    GIT_REPOSITORY https://github.com/duckdb/duckdb.git
    GIT_TAG v1.2.1
)
FetchContent_MakeAvailable(duckdb)

include_directories(${duckdb_SOURCE_DIR}/src/include)

# Build loadable extension
add_library(${LOADABLE_EXTENSION_NAME} SHARED ${EXTENSION_SOURCES})

# Required for static linking
set_target_properties(${LOADABLE_EXTENSION_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)

target_link_libraries(${LOADABLE_EXTENSION_NAME}
    PRIVATE
    duckdb_static
    -Wl,--gc-sections
    -Wl,--exclude-libs,ALL
)

target_include_directories(${LOADABLE_EXTENSION_NAME}
    PRIVATE
    ${CMAKE_SOURCE_DIR}/src/include
)

target_compile_definitions(${LOADABLE_EXTENSION_NAME} PUBLIC -DDUCKDB_BUILD_LOADABLE_EXTENSION)

set_target_properties(${LOADABLE_EXTENSION_NAME} PROPERTIES
    OUTPUT_NAME ${TARGET_NAME}
    PREFIX ""
    SUFFIX ".duckdb_extension"
)

# Version must match FetchContent tag
set(DUCKDB_VERSION_NORMALIZED "v1.2.1")
set(NULL_FILE ${duckdb_SOURCE_DIR}/scripts/null.txt)

# Add metadata (REQUIRED for DuckDB to load the extension)
add_custom_command(
    TARGET ${LOADABLE_EXTENSION_NAME}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        -DABI_TYPE=CPP
        -DEXTENSION=$<TARGET_FILE:${LOADABLE_EXTENSION_NAME}>
        -DPLATFORM_FILE=${duckdb_BINARY_DIR}/duckdb_platform_out
        -DVERSION_FIELD=${DUCKDB_VERSION_NORMALIZED}
        -DEXTENSION_VERSION=${DUCKDB_VERSION_NORMALIZED}
        -DNULL_FILE=${NULL_FILE}
        -P ${duckdb_SOURCE_DIR}/scripts/append_metadata.cmake
)
add_dependencies(${LOADABLE_EXTENSION_NAME} duckdb_platform)
```

Key points:
- `FetchContent_MakeAvailable(duckdb)` provides `duckdb_SOURCE_DIR` and `duckdb_BINARY_DIR`
- The `duckdb_platform` target generates the `duckdb_platform_out` file needed for metadata
- Version string MUST include the `v` prefix (e.g. `v1.2.1` not `1.2.1`)

## Troubleshooting

### Version mismatch

**Error**: "built specifically for DuckDB version 'X' and can only be loaded with that version"

**Fix**: ensure `DUCKDB_VERSION_NORMALIZED` matches the FetchContent tag AND includes the `v` prefix.

### PIC / relocation

**Error**: "relocation R_X86_64_PC32 against symbol... recompile with -fPIC"

**Cause**: a static library is being linked into the shared extension without position-independent code.

**Fix**: on every such static library target:
```cmake
set_target_properties(mylib PROPERTIES POSITION_INDEPENDENT_CODE ON)
```

### Missing duckdb_platform dependency

**Error**: `duckdb_platform_out` file not found during metadata append.

**Fix**: ensure `add_dependencies(${TARGET_NAME} duckdb_platform)` is present.
