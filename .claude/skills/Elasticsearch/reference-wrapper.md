# ServiceLib.Elasticsearch wrapper — method reference

Companion to `SKILL.md`. Full source: `Elasticsearch.cs` (wrapper) and `ElasticsearchService.cs` (JordanPrice service) in this folder — copy from those, don't re-derive.

## Construction

```csharp
var client = new ServiceLib.Elasticsearch("http://localhost:9200", _logger);

// Source/destination pattern (ElastiCompare, JordanPrice)
var sourceClient = new ServiceLib.Elasticsearch(_settings.Elasticsearch.Source, _logger);
var destinationClient = new ServiceLib.Elasticsearch(_settings.Elasticsearch.Destination, _logger);
```

## Methods

| Method | Endpoint | Returns | Notes |
|---|---|---|---|
| `Search(index, query)` | `POST /{index}/_search` | `dynamic` | Query is a JSON string; throws on HTTP error |
| `DownloadIndex(index)` | scroll API | `List<dynamic>` of `_source` | 5000/batch, 1m timeout, clears scroll in finally |
| `BulkIndex(index, docs)` | `POST .../_bulk` | response or `"Error"` | De-aliases the index first |
| `IndexDocument(index, id, doc)` | `PUT` via `DeAliasURL` | response or `"Error"` | Serializes ignoring nulls |
| `DeleteDocument(index, id)` | `DELETE` via `DeAliasURL` | response or `"Error"` | |
| `UpdateByQuery(index, query)` | `POST /{index}/_update_by_query` | response or `"Error"` | Query + script JSON |
| `GetIndices()` | `GET /_cat/indices?format=json` | `dynamic` | |
| `IsAlias(name)` / `ConcreteIndex(name)` | `GET /_alias/{name}` | bool / concrete name | |
| `GetCanonicalJsonString(obj)` | — | canonical JSON | For diffing/hashing docs |

Static helpers: `BulkToJson`, `SerializeKeepingNulls`, `SerializeIgnoringNulls`, `ExtractIds(searchResults)`, `GetId(hit)`.

## BulkToJson

```csharp
public static string BulkToJson(string index, string type, IEnumerable<object> docs)
{
    var json = new StringBuilder();
    foreach (var doc in docs)
    {
        var meta = new { index = new { _index = index, _type = type } };
        json.AppendLine(SerializeKeepingNulls(meta));    // metadata: nulls KEPT
        json.AppendLine(SerializeIgnoringNulls(doc));    // document: nulls DROPPED
    }
    return json.ToString();
}
```

`BulkIndex` calls it as `BulkToJson(ConcreteIndex(index), index, docs)` — concrete index as `_index`, the alias name as `_type`. Batch size in callers: ~1000 docs per `_bulk` call (`priceDiscounts.Chunk(1000)`).

## De-aliasing

```csharp
private string DeAliasURL(string index, string id)
{
    var cleanBaseUrl = _baseUrl.TrimEnd('/');
    if (IsAlias(index))
    {
        var concreteIndex = ConcreteIndex(index);       // GET /_alias/{name}, first key
        return $"{cleanBaseUrl}/{concreteIndex}/{index}/{id}";
    }
    return $"{cleanBaseUrl}/{index}/{id}";
}
```

URL with alias: `/{concrete_index}/{alias}/{id}`; without: `/{index}/{id}`. Prevents routing errors on 5.2.

## Scroll download shape

Initial `POST /{index}/_search?scroll=1m` with `{"query":{"match_all":{}},"size":5000}`; loop `POST /_search/scroll` with `{"scroll":"1m","scroll_id":...}`, updating `scrollId` each page, break when `hits.hits.Count == 0`. Finally block sends `DELETE /_search/scroll` with `{"scroll_id":[scrollId]}` — always, even on error paths.

## Alias rebuild (JordanPrice ElasticsearchService.cs)

```csharp
private const string IndexPrefix = "price_discount_";
private const string AliasName = "price_discount";

// 1. InitializeIndexAsync: PUT /{IndexPrefix}{yyyyMMdd_HHmmss}  (no mapping body)
// 2. Bulk load in Chunk(1000) batches via BulkIndex
// 3. FinalizeIndexAsync: POST /_aliases with atomic actions:
//    remove {"index": "price_discount_*", "alias": "price_discount"}
//    add    {"index": "<new index>",      "alias": "price_discount"}
// 4. On any failure: DeleteNewIndexAsync (DELETE /{new index}), don't rethrow from cleanup
```

Rollback after a bad flip = re-run the `_aliases` action pointing at the previous timestamped index.

## Range query example (dates)

```csharp
var today = DateTime.Today.ToString("yyyy-MM-dd");
var query = $$"""
{ "query": { "bool": { "filter": [
    { "range": { "keyInStartDate": { "lte": "{{today}}" } } },
    { "range": { "keyInEndDate":   { "gte": "{{today}}" } } }
] } } }
""";
var result = client.Search("pricing_periods", query);
var source = result?.hits?.hits?.Count > 0 ? result.hits.hits[0]._source : null;
```

## GetCanonicalJsonString

For document comparison/deduplication: removes null/empty properties, orders keys ordinally, strips `\u0000` characters and trims strings, converts JSON nulls to empty strings. Used when diffing source vs destination documents (ElastiCompare).
