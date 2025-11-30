using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Microsoft.VisualBasic.FileIO;

internal static class Program
{
    private record Requirement(Dictionary<string, string> Fields);

    private static readonly string[] RequiredHeaders =
    {
        "ID",
        "Section",
        "Requirement Statement",
        "Type",
        "Priority",
        "Verification Methods (from SRS)",
        "Primary Method (select)",
        "Acceptance Criteria",
        "Agent Procedure (step-by-step)",
        "Evidence to Collect",
        "Owner/Role",
        "Phase/Gate",
        "Status",
        "Date Last Updated",
        "Test Case ID / Link",
        "Upstream Trace",
        "Downstream Trace",
        "Notes",
        "Rationale",
        "Risk",
        "Assumptions",
        "Constraints",
        "Version & Change Notes",
        "Verification Detail",
        "Verification Level",
    };

    public static int Main(string[] args)
    {
        string? GetArg(string name)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] == name)
                {
                    return args[i + 1];
                }
            }
            return null;
        }

        bool HasFlag(string name) => args.Any(a => a == name);

        var csvPath = GetArg("--csv") ?? "docs/requirements/requirements.csv";
        var rowsParam = int.TryParse(GetArg("--rows"), out var r) ? r : 5;
        var title = GetArg("--title") ?? "Requirements Checklist";
        var repo = GetArg("--repo") ?? Environment.GetEnvironmentVariable("GITHUB_REPOSITORY") ?? string.Empty;
        var summaryOutput = GetArg("--summary-output");
        var fullOutput = GetArg("--full-output");
        var jsonOutput = GetArg("--json-output");
        var htmlOutput = GetArg("--html-output");
        var summaryFull = HasFlag("--summary-full");
        var details = HasFlag("--details");
        var detailsOpen = HasFlag("--details-open");
        var detailsLabel = GetArg("--details-label");
        var filterPriority = GetArg("--filter-priority")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Select(s => s.ToLower()).ToHashSet();
        var filterStatus = GetArg("--filter-status")?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Select(s => s.ToLower()).ToHashSet();
        var sortFields = (GetArg("--sort") ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();
        var sectionDetails = HasFlag("--section-details");
        var sectionDetailsOpen = HasFlag("--section-details-open");

        if (!File.Exists(csvPath))
        {
            Console.Error.WriteLine($"CSV not found at {csvPath}");
            return 1;
        }

        var rawRows = ReadCsv(csvPath);
        var headerTitle = string.IsNullOrWhiteSpace(repo) ? title : $"{title} ({repo})";

        if (rawRows.Count == 0)
        {
            var msg = $"{csvPath} is empty.";
            if (!string.IsNullOrEmpty(summaryOutput))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(summaryOutput)!);
                File.WriteAllText(summaryOutput, msg + Environment.NewLine, Encoding.UTF8);
            }
            else
            {
                Console.WriteLine(msg);
            }
            return 0;
        }

        var header = rawRows[0];
        var missing = RequiredHeaders.Where(h => !header.Contains(h)).ToList();
        if (missing.Count > 0)
        {
            Console.Error.WriteLine("CSV missing required columns: " + string.Join(", ", missing));
            return 1;
        }

        var body = rawRows.Skip(1)
            .Select(row => new Requirement(header.Zip(row, (h, v) => (h, v)).ToDictionary(t => t.h, t => t.v)))
            .ToList();
        var displayHeaders = header.Where(h => !string.Equals(h, "Section", StringComparison.OrdinalIgnoreCase)).ToArray();

        IEnumerable<Requirement> Filtered(IEnumerable<Requirement> items)
        {
            var q = items;
            if (filterPriority is not null && filterPriority.Count > 0)
                q = q.Where(r => filterPriority.Contains((r.Fields.GetValueOrDefault("Priority") ?? string.Empty).ToLower()));
            if (filterStatus is not null && filterStatus.Count > 0)
                q = q.Where(r => filterStatus.Contains((r.Fields.GetValueOrDefault("Status") ?? string.Empty).ToLower()));
            return q;
        }

        var filtered = Filtered(body).ToList();

        IOrderedEnumerable<Requirement>? ordered = null;
        foreach (var sf in sortFields)
        {
            Func<Requirement, string> key = r => r.Fields.GetValueOrDefault(sf) ?? string.Empty;
            ordered = ordered is null ? filtered.OrderBy(key, StringComparer.OrdinalIgnoreCase) : ordered.ThenBy(key, StringComparer.OrdinalIgnoreCase);
        }
        var finalList = ordered?.ToList() ?? filtered;

        string summaryText = $"### {headerTitle}\n\n" + RenderMarkdownSummary(csvPath, headerTitle, displayHeaders, body, finalList, rowsParam, summaryFull, sectionDetails, sectionDetailsOpen);
        if (details)
        {
            var label = string.IsNullOrWhiteSpace(detailsLabel) ? headerTitle : detailsLabel!;
            var openAttr = detailsOpen ? " open" : string.Empty;
            summaryText = $"<details{openAttr}>\n<summary>{label}</summary>\n\n{summaryText}\n</details>\n";
        }

        if (!string.IsNullOrEmpty(summaryOutput))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(summaryOutput)!);
            File.WriteAllText(summaryOutput, summaryText, Encoding.UTF8);
        }
        else
        {
            Console.WriteLine(summaryText);
        }

        if (!string.IsNullOrEmpty(fullOutput))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(fullOutput)!);
            var fullSb = new StringBuilder();
            fullSb.AppendLine($"### {headerTitle} (Full)");
            fullSb.AppendLine();
            fullSb.Append(RenderMarkdownTable(displayHeaders, body));
            File.WriteAllText(fullOutput, fullSb.ToString(), Encoding.UTF8);
        }

        if (!string.IsNullOrEmpty(jsonOutput))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(jsonOutput)!);
            var json = JsonSerializer.Serialize(finalList.Select(r => r.Fields), new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            });
            File.WriteAllText(jsonOutput, json, Encoding.UTF8);
        }

        if (!string.IsNullOrEmpty(htmlOutput))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(htmlOutput)!);
            var html = RenderHtml(headerTitle, displayHeaders, finalList);
            File.WriteAllText(htmlOutput, html, Encoding.UTF8);
        }

        return 0;
    }

    private static IReadOnlyList<string[]> ReadCsv(string path)
    {
        var rows = new List<string[]>();
        using var parser = new TextFieldParser(path, Encoding.UTF8);
        parser.SetDelimiters(",");
        parser.HasFieldsEnclosedInQuotes = true;
        while (!parser.EndOfData)
        {
            var fields = parser.ReadFields();
            if (fields is not null)
            {
                rows.Add(fields);
            }
        }
        return rows;
    }

    private static string Clean(string value) => value.Replace("\r", "").Replace("\n", "<br>");

    private static string BadgePriority(string value) => value.ToLower() switch
    {
        "high" => "🔴 High",
        "medium" => "🟠 Medium",
        "low" => "🟢 Low",
        _ => value
    };

    private static string BadgeStatus(string value) => value.ToLower() switch
    {
        "completed" or "done" => "✅ Completed",
        "in progress" or "pending" => "⏳ Pending",
        "blocked" => "⛔ Blocked",
        _ => value
    };

    private static string RenderMarkdownTable(string[] header, IEnumerable<Requirement> items)
    {
        var sb = new StringBuilder();
        sb.AppendLine("| " + string.Join(" | ", header) + " |");
        sb.AppendLine("| " + string.Join(" | ", header.Select(_ => "---")) + " |");
        foreach (var req in items)
        {
            var cells = header.Select(h =>
            {
                var v = req.Fields.GetValueOrDefault(h) ?? string.Empty;
                var cleaned = Clean(v);
                if (h == "Priority") cleaned = BadgePriority(cleaned);
                if (h == "Status") cleaned = BadgeStatus(cleaned);
                return cleaned;
            });
            sb.AppendLine("| " + string.Join(" | ", cells) + " |");
        }
        sb.AppendLine();
        return sb.ToString();
    }

    private static string RenderMarkdownSummary(string csvPath, string headerTitle, string[] header, List<Requirement> all, List<Requirement> filtered, int rowsParam, bool summaryFull, bool sectionDetails, bool sectionDetailsOpen)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"- File: `{csvPath}`");
        sb.AppendLine($"- Rows: {all.Count + 1} (1 header + {all.Count} data)");
        sb.AppendLine($"- Filtered: {filtered.Count} of {all.Count}");
        sb.AppendLine($"- Columns: {header.Length}");
        sb.AppendLine();

        var grouped = filtered.GroupBy(r => r.Fields.GetValueOrDefault("Section") ?? "Unspecified")
                              .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase);

        foreach (var g in grouped)
        {
            if (sectionDetails)
            {
                var openAttr = sectionDetailsOpen ? " open" : string.Empty;
                sb.AppendLine($"<details{openAttr}>");
                sb.AppendLine($"<summary>Section: {g.Key} ({g.Count()})</summary>");
                sb.AppendLine();
            }
            else
            {
                sb.AppendLine($"#### Section: {g.Key} ({g.Count()})");
            }
            var take = summaryFull ? g : g.Take(rowsParam);
            sb.Append(RenderMarkdownTable(header, take));
            if (sectionDetails)
            {
                sb.AppendLine("</details>");
                sb.AppendLine();
            }
        }
        return sb.ToString();
    }

    private static string RenderHtml(string headerTitle, string[] header, IEnumerable<Requirement> items)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>");
        sb.AppendLine("body{font-family:Segoe UI,Arial,sans-serif;font-size:14px;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #ddd;padding:6px;} th{background:#f4f4f4;position:sticky;top:0;} tr:nth-child(even){background:#fafafa;} .badge{padding:2px 6px;border-radius:4px;}");
        sb.AppendLine("</style></head><body>");
        sb.AppendLine($"<h3>{headerTitle} (HTML)</h3>");
        sb.AppendLine("<table><thead><tr>");
        foreach (var h in header) sb.Append($"<th>{System.Net.WebUtility.HtmlEncode(h)}</th>");
        sb.AppendLine("</tr></thead><tbody>");
        foreach (var req in items)
        {
            sb.Append("<tr>");
            foreach (var h in header)
            {
                var v = req.Fields.GetValueOrDefault(h) ?? string.Empty;
                if (h == "Priority") v = BadgePriority(v);
                if (h == "Status") v = BadgeStatus(v);
                sb.Append("<td>" + v + "</td>");
            }
            sb.AppendLine("</tr>");
        }
        sb.AppendLine("</tbody></table></body></html>");
        return sb.ToString();
    }
}
