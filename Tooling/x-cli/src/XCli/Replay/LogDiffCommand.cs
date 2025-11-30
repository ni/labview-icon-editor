// ModuleIndex: compares two JSONL logs and prints timing deltas (text/JSON).
using System.Text.Json;
using System.Text.Json.Serialization;

namespace XCli.Replay;

public static class LogDiffCommand
{
    private sealed record Record(
        [property: JsonPropertyName("t")] int DelayMs,
        [property: JsonPropertyName("s")] string? Stream,
        [property: JsonPropertyName("m")] string? Message,
        [property: JsonPropertyName("test")] string? Test);

    public static int Run(string[] args)
    {
        string? baseline = null;
        string? candidate = null;
        var format = "text";
        var groupBy = "test";

        for (var i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a == "--baseline" && i + 1 < args.Length) { baseline = args[++i]; continue; }
            if (a == "--candidate" && i + 1 < args.Length) { candidate = args[++i]; continue; }
            if (a == "--format" && i + 1 < args.Length) { format = args[++i]; continue; }
            if (a == "--by" && i + 1 < args.Length) { groupBy = args[++i]; continue; }
        }

        if (string.IsNullOrWhiteSpace(baseline) || !File.Exists(baseline) ||
            string.IsNullOrWhiteSpace(candidate) || !File.Exists(candidate))
        {
            Console.Error.WriteLine("x-cli: log-diff requires --baseline and --candidate pointing to files");
            return 2;
        }

        groupBy = groupBy.Equals("test", StringComparison.OrdinalIgnoreCase) ? "test" : "all";

        var serializerOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            AllowTrailingCommas = true
        };

        var baselineRecs = Load(baseline, serializerOptions);
        var candidateRecs = Load(candidate, serializerOptions);

        var baselineSummary = Summarise(baselineRecs, groupBy);
        var candidateSummary = Summarise(candidateRecs, groupBy);

        var keys = new SortedSet<string>(baselineSummary.Keys, StringComparer.OrdinalIgnoreCase);
        foreach (var key in candidateSummary.Keys)
            keys.Add(key);

        var totalBaseline = baselineSummary.Values.Sum();
        var totalCandidate = candidateSummary.Values.Sum();

        if (format.Equals("json", StringComparison.OrdinalIgnoreCase))
        {
            var rows = keys
                .Select(k => new
                {
                    key = k,
                    baselineMs = baselineSummary.GetValueOrDefault(k, 0),
                    candidateMs = candidateSummary.GetValueOrDefault(k, 0),
                    deltaMs = candidateSummary.GetValueOrDefault(k, 0) - baselineSummary.GetValueOrDefault(k, 0)
                });

            var payload = new
            {
                by = groupBy,
                rows,
                totals = new
                {
                    baselineMs = totalBaseline,
                    candidateMs = totalCandidate,
                    deltaMs = totalCandidate - totalBaseline
                }
            };

            Console.WriteLine(JsonSerializer.Serialize(payload, serializerOptions));
            return 0;
        }

        var keyHeader = groupBy == "test" ? "Test" : "All";
        var keyWidth = Math.Max(keyHeader.Length, keys.Any() ? keys.Max(k => k.Length) : 3);
        keyWidth = Math.Min(keyWidth, 40);
        Console.WriteLine($"Diff by {groupBy}:");
        Console.WriteLine($"{keyHeader.PadRight(keyWidth)}  Baseline  Candidate  Delta");
        Console.WriteLine(new string('-', keyWidth + 27));

        foreach (var key in keys)
        {
            var b = baselineSummary.GetValueOrDefault(key, 0);
            var c = candidateSummary.GetValueOrDefault(key, 0);
            var d = c - b;
            Console.WriteLine($"{key.PadRight(keyWidth)}  {FormatMs(b),9}  {FormatMs(c),9}  {FormatWithSign(d),7}");
        }

        Console.WriteLine(new string('-', keyWidth + 27));
        Console.WriteLine($"Totals{new string(' ', Math.Max(0, keyWidth - 6))}  {FormatMs(totalBaseline),9}  {FormatMs(totalCandidate),9}  {FormatWithSign(totalCandidate - totalBaseline),7}");
        return 0;
    }

    private static List<Record> Load(string path, JsonSerializerOptions options)
    {
        var list = new List<Record>();
        var lineNumber = 0;
        foreach (var line in File.ReadLines(path))
        {
            lineNumber++;
            if (string.IsNullOrWhiteSpace(line))
                continue;
            try
            {
                var rec = JsonSerializer.Deserialize<Record>(line, options);
                if (rec != null)
                    list.Add(rec);
            }
            catch
            {
                // Ignore malformed lines; strict mode can be added later if needed.
            }
        }
        return list;
    }

    private static Dictionary<string, long> Summarise(IEnumerable<Record> records, string groupBy)
    {
        var map = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        foreach (var rec in records)
        {
            var key = groupBy == "test" ? (rec.Test ?? "<unknown>") : "<all>";
            var delay = Math.Max(0, rec.DelayMs);
            map[key] = map.GetValueOrDefault(key, 0) + delay;
        }
        return map;
    }

    private static string FormatMs(long ms) => $"{ms}ms";

    private static string FormatWithSign(long value)
    {
        var sign = value > 0 ? "+" : value < 0 ? "-" : " ";
        return $"{sign}{Math.Abs(value)}ms";
    }
}
