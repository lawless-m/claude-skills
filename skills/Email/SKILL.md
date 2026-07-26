---
name: Email
description: Use when sending email from RI C# services - notifications, daily reports, or log files as attachments. Covers the internal SMTP host, reading log files that are still locked by the logging process, zip-then-attach with cleanup, and the MailMessage disposal gotcha.
---

# Email — SMTP with log attachments

## The key trick: FileShare.ReadWrite reads locked log files

Log files are held open by the running logging process; a normal `File.OpenRead` throws `IOException: The process cannot access the file...`. Open with `FileShare.ReadWrite` to read (and zip) them anyway:

```csharp
public static string ZipSingleFileFromStream(string filePath, string? outputPath = null)
{
    string zipPath = outputPath ?? Path.ChangeExtension(filePath, ".zip");
    if (File.Exists(zipPath)) File.Delete(zipPath);

    using (var zipArchive = ZipFile.Open(zipPath, ZipArchiveMode.Create))
    {
        var entry = zipArchive.CreateEntry(Path.GetFileName(filePath), CompressionLevel.Optimal);
        using var entryStream = entry.Open();
        using var fileStream = new FileStream(
            filePath, FileMode.Open, FileAccess.Read,
            FileShare.ReadWrite);   // <-- reads files another process has open for writing
        fileStream.CopyTo(entryStream);
    }
    return zipPath;
}
```

## Environment

- SMTP host: `smtp.nisainternational.local` (no auth) — `new SmtpClient("smtp.nisainternational.local")`
- Default sender: `services@ramsden-international.com`
- Get the current log path from `UTF8Writer.GetCurrentLogFilePath()` (see the Logging skill)

## Conventions for attachment sending

- **Graceful fallback**: if zipping throws, send the uncompressed original file instead — a big email beats no email.
- **Delete the temp zip in a finally block** (swallow deletion errors) or the disk fills with orphaned .zip files.
- **Dispose MailMessage** with `using`, and create `Attachment` objects inline (`mailMessage.Attachments.Add(new Attachment(path))` — no variable). Undisposed `MailMessage`/`Attachment` objects hold file handles until GC, so the zip cleanup in the finally block fails with the file "in use" — this persisted for 10+ minutes in production despite retry loops.

```csharp
string? zippedPath = null;
try
{
    using var mailMessage = new MailMessage(from, to, subject, body);  // using is load-bearing
    zippedPath = ZipSingleFileFromStream(logPath);
    mailMessage.Attachments.Add(new Attachment(zippedPath));           // inline, owned by message
    foreach (var extra in additionalAttachments.Where(File.Exists))
        mailMessage.Attachments.Add(new Attachment(extra));
    new SmtpClient("smtp.nisainternational.local").Send(mailMessage);
}
catch (Exception)
{
    return Send(from, logPath);   // fallback: uncompressed original
}
finally
{
    if (zippedPath != null && File.Exists(zippedPath))
        try { File.Delete(zippedPath); } catch { /* log only */ }
}
```
