using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

var root = Directory.GetCurrentDirectory();
string jsonOut = Path.Combine("docs", "module-index.json");
string mdOut = Path.Combine("docs", "module-index.md");

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--root" when i + 1 < args.Length:
            root = Path.GetFullPath(args[++i]);
            break;
        case "--json-out" when i + 1 < args.Length:
            jsonOut = args[++i];
            break;
        case "--md-out" when i + 1 < args.Length:
            mdOut = args[++i];
            break;
    }
}

var searchDirs = new[]
{
    Path.Combine(root, "src", "XCli"),
    Path.Combine(root, "src", "Telemetry"),
    Path.Combine(root, "src", "SrsApi"),
    Path.Combine(root, "scripts")
}.Where(Directory.Exists).ToArray();

var exts = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
{ ".cs", ".py", ".ps1", ".sh" };

static string? DetectLang(string path)
{
    var ext = Path.GetExtension(path).ToLowerInvariant();
    return ext switch
    {
        ".cs" => "cs",
        ".py" => "py",
        ".ps1" => "ps1",
        ".sh" => "sh",
        _ => null
    };
}

static IEnumerable<string> EnumerateFiles(string dir, HashSet<string> exts)
{
    foreach (var file in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories))
    {
        try
        {
            if (exts.Contains(Path.GetExtension(file)))
                yield return file;
        }
        catch { }
    }
}

var re = new Regex("^\\s*(//|#)\\s*ModuleIndex:\\s*(.*)$", RegexOptions.Compiled);
var entries = new List<Dictionary<string, string?>>();

foreach (var d in searchDirs)
{
    foreach (var f in EnumerateFiles(d, exts))
    {
        string[] lines;
        try { lines = File.ReadAllLines(f); } catch { continue; }
        foreach (var ln in lines)
        {
            var m = re.Match(ln);
            if (!m.Success) continue;
            var rel = Path.GetRelativePath(root, f).Replace(Path.DirectorySeparatorChar, '/');
            var desc = (m.Groups[2].Value ?? string.Empty).Trim();
            entries.Add(new Dictionary<string, string?>
            {
                ["path"] = rel,
                ["desc"] = desc,
                ["lang"] = DetectLang(f)
            });
        }
    }
}

entries = entries
    .OrderBy(e => e["path"], StringComparer.Ordinal)
    .ToList();

// Load previous generatedAt if present to reduce noise
string generatedAt = "1970-01-01T00:00:00.000Z";
try
{
    if (File.Exists(jsonOut))
    {
        using var prev = JsonDocument.Parse(File.ReadAllText(jsonOut));
        if (prev.RootElement.TryGetProperty("generatedAt", out var ga) && ga.ValueKind == JsonValueKind.String)
            generatedAt = ga.GetString() ?? generatedAt;
    }
}
catch { }

var doc = new Dictionary<string, object?>
{
    ["$schema"] = "docs/schemas/v1/module-index.schema.json",
    ["version"] = "1.0",
    ["generatedAt"] = generatedAt,
    ["entries"] = entries
};

Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(jsonOut))!);
var json = JsonSerializer.Serialize(doc, new JsonSerializerOptions { WriteIndented = true });
File.WriteAllText(jsonOut, json + Environment.NewLine, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

// Render Markdown
var ndash = "–";
var sb = new StringBuilder();
sb.AppendLine("# Module Index");
sb.AppendLine();
foreach (var e in entries)
{
    var pathRel = e["path"] ?? string.Empty;
    var desc = e["desc"] ?? string.Empty;
    sb.AppendLine($"- `{pathRel}` {ndash} {desc}");
}
sb.AppendLine();
File.WriteAllText(mdOut, sb.ToString(), new UTF8Encoding(false));

return 0;

