---
name: Elasticsearch
description: Use when searching, indexing, bulk-loading, or rebuilding indices on RI's Elasticsearch cluster - which is locked at version 5.2 - via the ServiceLib.Elasticsearch HttpClient wrapper. Covers the timestamped-index/alias rebuild pattern, scroll cleanup, and the de-aliasing quirk for document operations.
---

# Elasticsearch (5.2, fixed)

The cluster runs **Elasticsearch 5.2 and will not change**. Use ES 5.2 API shapes: `_type` still exists in bulk metadata, `hits.total` is a plain int, and modern client libraries won't work. We do not use NEST — `ServiceLib.Elasticsearch` is a plain **HttpClient wrapper** over the REST API.

Working code in this folder: `Elasticsearch.cs` (the ServiceLib wrapper) and `ElasticsearchService.cs` (JordanPrice's use of it, including the full alias rebuild). Method-level detail: `reference-wrapper.md`.

## Conventions

- Search results are parsed as `dynamic` (Newtonsoft) and navigated by property name: `result.hits.hits[0]._source`, null-safe with `?.` and `?.ToString() ?? ""`. No typed models.
- Complex queries are raw string literals (`$$"""..."""`) with interpolated values.
- Wrapper methods return the string `"Error"` on failure rather than throwing — callers must check for it.
- Indices are created without explicit mappings — let ES auto-detect field types (matches production).
- Scroll downloads (`DownloadIndex`): 5000-doc batches, 1m timeout, and the scroll context is **always cleared in a finally block** — leaked scroll contexts hold resources on this old cluster.

## Index rebuild: timestamped index + alias (JordanPrice-proven)

Zero-downtime full rebuild, proven in JordanPrice:

1. Create timestamped index, e.g. `price_discount_20250116_123456`
2. Bulk-load all documents into it
3. Atomically switch alias `price_discount` in one `_aliases` call (remove `price_discount_*` + add new index)
4. On failure, delete the new index; rollback is just switching the alias back

**Architectural direction**: the legacy Java codebase writes whole timestamped indices and flips aliases as above. RI's stated direction for new work is **in-place overwrites and deletes** instead of full rebuilds — prefer that for new services, but the alias pattern remains the proven fallback for full reloads.

## De-aliasing for document operations

ES 5.2 misroutes single-document operations addressed to an alias. The wrapper's `DeAliasURL`/`ConcreteIndex` resolve an alias to its concrete index first and build URLs as `/{concrete_index}/{alias}/{id}`. Any direct document PUT/DELETE against a name that might be an alias must go through this (see `reference-wrapper.md`).

## Bulk format nulls (BulkToJson)

`BulkToJson` builds the NDJSON body with an asymmetry that matters: action metadata lines are serialized **keeping nulls**, document lines **ignoring nulls**. Keep that split when touching bulk code — dropping nulls from metadata or including them in documents both cause subtle diffs against the legacy Java output.
