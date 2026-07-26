---
name: SharePoint
description: Use when uploading/downloading files to RI's SharePoint Online sites (RIHub, TradingDepartment), updating Excel tracker cells, or normalizing pasted SharePoint share links. Covers the CSOM-vs-Graph split, chunked upload size rules, and share-link URL de-angling.
---

# SharePoint Online (RI)

## Sites and paths

- `https://tenant.sharepoint.com/sites/RIHub` — e.g. `/sites/RIHub/External Partners/Customer Service/...`
- `https://tenant.sharepoint.com/sites/TradingDepartment` — e.g. `/sites/TradingDepartment/Trading/SEASONAL/EASTER/tracker.xlsx` (drive name `Trading`, file path within drive `SEASONAL/EASTER/Easter 2025/tracker.xlsx`)

Server-relative URLs always start `/sites/...`.

## Hybrid decision: CSOM for files, Graph for Excel

- **CSOM (PnP.Framework)** for file and folder operations — uploads (incl. chunked), folder create/exists, downloads via `OpenBinaryStream`. Faster for file-heavy work. Auth: `new AuthenticationManager().GetACSAppOnlyContext($"https://{host}/sites/{site}", clientId, clientSecret)`; needs `Sites.FullControl.All`.
- **Graph API** for Excel cell/table updates. Auth: `ClientSecretCredential(tenantId, clientId, clientSecret)` → `GraphServiceClient`; needs `Sites.ReadWrite.All` + `Files.ReadWrite.All`.

Credentials (TenantId/ClientId/ClientSecret) live in an external JSON file (`azure_ids.json`), never in code.

## Upload size rules

- < 1MB: simple `folder.Files.Add(FileCreationInformation)` with `Overwrite = true`
- ≥ 1MB: chunked upload — create empty file placeholder, then `StartUpload` / `ContinueUpload` / `FinishUpload` in 1MB chunks with a fresh `Guid` uploadId per session, tracking `fileOffset` from each call's return value
- \> 50MB: **rejected** — throw rather than attempt

Folder creation: get folder by server-relative URL; on `ServerException` with `ServerErrorTypeName == "System.IO.FileNotFoundException"`, walk the path parts creating each level (`currentFolder.Folders.Add(part)`).

## Graph Excel cell update

PATCH the workbook range endpoint directly (simpler than the SDK's workbook model):

```
PATCH https://graph.microsoft.com/v1.0/drives/{driveId}/items/{itemId}/workbook/worksheets/{sheetName}/range(address='N123')
{"values": [["Y"]]}
```

Worksheet name is case-sensitive; the file must not be open in a browser during updates.

## Share-link URL normalization

Users paste SharePoint links in several shapes. Normalize before use:

```csharp
public string FixSharePointLink(string rawLink)
{
    string sharepointHost = "https://tenant.sharepoint.com";

    // Strip query parameters
    string cleanLink = rawLink;
    int q = cleanLink.IndexOf('?');
    if (q != -1) cleanLink = cleanLink.Substring(0, q);

    // Sharing-link redirect format: ...:f:/r/<escaped path>
    int marker = cleanLink.LastIndexOf(":f:/r/", StringComparison.OrdinalIgnoreCase);
    if (marker != -1)
    {
        string decodedPath = Uri.UnescapeDataString(cleanLink.Substring(marker + ":f:/r/".Length));
        if (!decodedPath.StartsWith("sites/", StringComparison.OrdinalIgnoreCase))
            decodedPath = "sites/" + decodedPath;
        return $"{sharepointHost}/{decodedPath}";
    }

    // Library view links: .../Forms/AllItems.aspx?id=<escaped server-relative path>
    if (rawLink.Contains("/Forms/AllItems.aspx", StringComparison.OrdinalIgnoreCase))
    {
        var idParam = rawLink.Replace("?", "&").Split('&')
            .FirstOrDefault(p => p.StartsWith("id=", StringComparison.OrdinalIgnoreCase));
        if (idParam != null)
            return $"{sharepointHost}{Uri.UnescapeDataString(idParam.Substring(3))}";
    }

    // Direct URL: just decode
    if (Uri.TryCreate(rawLink, UriKind.Absolute, out Uri? uri))
        return $"{sharepointHost}{Uri.UnescapeDataString(uri.AbsolutePath)}";

    return string.Empty;
}
```

## Notes

- Minimize `ExecuteQuery()` round-trips: `ctx.Load(...)` several objects, then execute once.
- Download pattern: `GetFileByServerRelativeUrl(url).OpenBinaryStream()` → copy to `MemoryStream`, reset `Position = 0` (feed to Aspose.Cells etc.).
- Check `FileExists(folder, name)` before uploading to skip already-uploaded files (catch the FileNotFound `ServerException` as "no").
