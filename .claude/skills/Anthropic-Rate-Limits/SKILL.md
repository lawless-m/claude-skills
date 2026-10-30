---
name: Anthropic-Rate-Limits
description: Anthropic API rate limit handling - retry logic, backoff, throttling for batch workloads against Claude models
---

# Anthropic API Rate Limits

When writing code that calls the Anthropic API (especially batch/bulk workloads), you must handle rate limits correctly. The org `c68886dd-ecbd-45f6-83c8-0c5af631b760` has a **10,000 output tokens per minute** limit on Haiku.

## Instructions

1. **Always retry 429 responses**. The API returns HTTP 429 when rate-limited. This is transient and must be retried with backoff — never treat it as a fatal error.

2. **Respect `retry-after` header**. If the 429 response includes a `retry-after` header (seconds), use that value. Otherwise fall back to exponential backoff.

3. **Use exponential backoff with jitter**. Start at 2s, double each retry, cap at ~60s. Add small random jitter to avoid thundering herd.

4. **Throttle proactively between batches**. Don't just react to 429s — add a delay between batches to stay under the limit. For Haiku with 10k output tokens/min:
   - Each batch of 20 addresses produces ~150 output tokens
   - That's ~66 batches before hitting the limit
   - A 1-second delay between batches keeps throughput safe

5. **Retry these status codes**: 429 (rate limit), 529 (overloaded), 500 (server error). Fail immediately on 400 (bad request) and 401 (auth).

6. **Cap retries**. Use a maximum of 8 retries. After that, fail the batch and continue with the next one — don't block the entire job.

7. **Log retries to stderr**. Always log the status code, retry delay, and attempt number so the user can see what's happening.

## Examples

### Example 1: C# HttpClient with rate limit retry
```
User: Write code to call the Anthropic API with retry logic

Claude: I'll add exponential backoff for 429/529/500 with retry-after header support:

[Provides implementation using the C# Retry Pattern below]
```

### Example 2: Batch processing with throttle
```
User: Process 1000 items through the Anthropic API

Claude: With the 10k output token/min limit, I'll add a 1-second delay between
batches to stay under the limit, plus 429 retry as a safety net.

[Adds Task.Delay(1000) between batches in the processing loop]
```

---

# Reference Implementation Details

## C# Retry Pattern

**Purpose**: Retry with exponential backoff, respecting retry-after header

```csharp
const int maxRetries = 8;

for (var attempt = 0; ; attempt++)
{
    var response = await _http.PostAsync(url, content);

    if (response.IsSuccessStatusCode)
        return await response.Content.ReadAsStringAsync();

    var status = (int)response.StatusCode;

    // Fail immediately on non-retryable errors
    if (status == 400 || status == 401)
    {
        var errorBody = await response.Content.ReadAsStringAsync();
        throw new HttpRequestException($"API error {status}: {errorBody}");
    }

    // Retry on 429 (rate limit), 529 (overloaded), or 500
    if ((status == 429 || status == 529 || status == 500) && attempt < maxRetries)
    {
        var delay = 2000 * (1 << attempt); // 2s, 4s, 8s, 16s, ...
        if (response.Headers.TryGetValues("retry-after", out var values) &&
            int.TryParse(values.FirstOrDefault(), out var retryAfter))
        {
            delay = retryAfter * 1000;
        }

        Console.Error.WriteLine(
            $"API returned {status}, retrying in {delay / 1000}s (attempt {attempt + 1}/{maxRetries})...");
        await Task.Delay(delay);
        content = new StringContent(json, Encoding.UTF8, "application/json");
        continue;
    }

    var body = await response.Content.ReadAsStringAsync();
    throw new HttpRequestException($"API error {status} after {attempt + 1} attempts: {body}");
}
```

## Rate Limits Quick Reference

| Model | Output tokens/min | Requests/min | Input tokens/min |
|-------|-------------------|--------------|------------------|
| Haiku 4.5 | 10,000 | varies | varies |

**Key Points**:
- The output token limit is usually the bottleneck for batch workloads
- 429 errors are normal and expected under load — always handle them
- Proactive throttling (delay between batches) is better than reactive retry
