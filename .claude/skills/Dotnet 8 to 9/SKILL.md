---
name: Dotnet 8 to 9
description: Use when migrating a project from .NET 8 to .NET 9, or preparing .NET 8 code for that migration with only the .NET 8 SDK available (e.g. Claude for Web).
---

# .NET 8 → 9 Migration

Two modes — pick by what SDK is available:

## Mode A: Pre-migration prep (still on .NET 8)

Use this in environments without the .NET 9 SDK. All fixes below are compatible with both versions, so apply them now and the later migration is mostly a TargetFramework bump.

1. **Backticks in verbatim strings** (the big one — breaks compilation under .NET 9). Detect:
   ```bash
   grep -rn '@"[^"]*`' --include="*.cs"
   ```
   Typically JavaScript template literals embedded in C# `@"..."` strings. Fix by converting to JS string concatenation (see below).
2. **ImplicitUsings + explicit Main**: projects that define their own `Main` and have `<ImplicitUsings>enable</ImplicitUsings>` can hit CS0017 (multiple entry points) on .NET 9 — set `<ImplicitUsings>disable</ImplicitUsings>` in those projects.
3. **TestData compilation**: test projects with `.cs` files under `TestData\` compile them by accident. Exclude:
   ```xml
   <ItemGroup>
     <Compile Remove="TestData\**\*.cs" />
     <None Include="TestData\**\*" />
   </ItemGroup>
   ```
4. **Note (don't yet update) packages below the minimums** listed in Mode B.

## Mode B: Completing the migration (on .NET 9)

1. `<TargetFramework>net9.0</TargetFramework>` in all .csproj files.
2. Update packages — minimums that matter here:
   - `Microsoft.CodeAnalysis.*` (CSharp.Workspaces, Workspaces.MSBuild): **4.12.0+**
   - `Microsoft.Build.Locator`: **1.7.8+**
   - `System.Text.Json`: 9.0.0+
   - `Microsoft.CodeAnalysis.Workspaces.MSBuild` was implicitly available on .NET 8 but often needs an **explicit** PackageReference on .NET 9 (CS0234 on `Microsoft.CodeAnalysis.MSBuild` is the symptom).
3. Apply all Mode A fixes if not already done.
4. `dotnet clean && dotnet restore && dotnet build && dotnet test`.

## The template-literal fix (condensed)

CS1002/CS1056/CS1010 in a file that embeds JavaScript = backtick template literals inside a verbatim string.

```csharp
// Before (breaks on .NET 9):
return @"html += `<div class=""result"">${value}</div>`;";

// After (works on 8 and 9):
return @"html += '<div class=""result"">' + value + '</div>';";
```

Backticks → single quotes, `${expr}` → `' + expr + '`, keep `""` for HTML attributes inside the verbatim string.
