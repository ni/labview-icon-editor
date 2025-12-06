using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using XCli.Simulation;

namespace XCli.ViCompare;

public static class ViCompareVerifyCommand
{
    private static readonly (string Flag, string Label)[] AttributeMap =
    {
        ("ignoreFrontPanel", "Front Panel"),
        ("ignoreFrontPanelPosition", "Front Panel Position/Size"),
        ("ignoreBlockDiagram", "Block Diagram Functional"),
        ("ignoreBlockDiagramCosmetics", "Block Diagram Cosmetic"),
        ("ignoreAttributes", "VI Attribute"),
    };

    private static readonly Regex AttributeRegex = new("<li\\s+class=\"(?<cls>[^\"]+)\">(?<label>[^<]+)</li>",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public static SimulationResult Run(string[] args)
    {
        string? summaryPath = null;
        bool verbose = false;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--summary" && i + 1 < args.Length)
            {
                summaryPath = args[++i];
            }
            else if (arg == "--verbose")
            {
                verbose = true;
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] vi-compare-verify: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(summaryPath))
        {
            Console.Error.WriteLine("[x-cli] vi-compare-verify: --summary PATH is required.");
            return new SimulationResult(false, 1);
        }

        summaryPath = Path.GetFullPath(summaryPath);
        if (!File.Exists(summaryPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-verify: summary not found at '{summaryPath}'.");
            return new SimulationResult(false, 1);
        }

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(File.ReadAllText(summaryPath));
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-verify: failed to parse summary JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        using var _ = doc;
        var root = doc.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
        {
            Console.Error.WriteLine("[x-cli] vi-compare-verify: summary root must be an object.");
            return new SimulationResult(false, 1);
        }

        var expectedStates = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        if (root.TryGetProperty("suppression", out var suppression))
        {
            foreach (var (flag, label) in AttributeMap)
            {
                var suppressed = suppression.TryGetProperty(flag, out var flagValue)
                    && flagValue.ValueKind == JsonValueKind.True;
                expectedStates[label] = !suppressed;
            }
        }
        else
        {
            Console.Error.WriteLine("[x-cli] vi-compare-verify: summary missing 'suppression' block.");
            return new SimulationResult(false, 1);
        }

        if (!root.TryGetProperty("requests", out var requests) || requests.ValueKind != JsonValueKind.Array)
        {
            Console.Error.WriteLine("[x-cli] vi-compare-verify: summary missing 'requests' array.");
            return new SimulationResult(false, 1);
        }

        var summaryDir = Path.GetDirectoryName(summaryPath)!;
        var reportsChecked = 0;
        var failures = 0;

        foreach (var request in requests.EnumerateArray())
        {
            if (request.ValueKind != JsonValueKind.Object)
                continue;

            if (!request.TryGetProperty("artifacts", out var artifacts) || artifacts.ValueKind != JsonValueKind.Object)
                continue;

            if (!artifacts.TryGetProperty("reportHtml", out var reportProp) || reportProp.ValueKind != JsonValueKind.String)
                continue;

            var reportRelative = reportProp.GetString();
            if (string.IsNullOrWhiteSpace(reportRelative))
                continue;

            var reportPath = Path.IsPathRooted(reportRelative)
                ? reportRelative
                : Path.Combine(summaryDir, reportRelative.Replace('/', Path.DirectorySeparatorChar));
            reportPath = Path.GetFullPath(reportPath);

            if (!File.Exists(reportPath))
            {
                Console.Error.WriteLine($"[x-cli] vi-compare-verify: report HTML not found at '{reportPath}'.");
                failures++;
                continue;
            }

            string html;
            try
            {
                html = File.ReadAllText(reportPath);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[x-cli] vi-compare-verify: failed to read '{reportPath}': {ex.Message}");
                failures++;
                continue;
            }

            var actualStates = ParseIncludedAttributes(html);
            reportsChecked++;

            foreach (var (flag, label) in AttributeMap)
            {
                if (!expectedStates.TryGetValue(label, out var expectChecked))
                    continue;

                if (!actualStates.TryGetValue(label, out var actualChecked))
                {
                    Console.Error.WriteLine($"[x-cli] vi-compare-verify: report '{reportPath}' missing attribute '{label}'.");
                    failures++;
                    continue;
                }

                if (actualChecked != expectChecked)
                {
                    var expectedState = expectChecked ? "checked" : "unchecked";
                    var actualState = actualChecked ? "checked" : "unchecked";
                    Console.Error.WriteLine(
                        $"[x-cli] vi-compare-verify: '{label}' expected {expectedState} but report is {actualState} ({reportPath}).");
                    failures++;
                }
                else if (verbose)
                {
                    var state = actualChecked ? "checked" : "unchecked";
                    Console.WriteLine($"[x-cli] vi-compare-verify: '{label}' verified as {state} ({reportPath}).");
                }
            }
        }

        if (reportsChecked == 0)
        {
            Console.Error.WriteLine("[x-cli] vi-compare-verify: no reportHtml artifacts found in summary.");
            return new SimulationResult(false, 1);
        }

        if (failures > 0)
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-verify: {failures} verification failure(s) detected across {reportsChecked} report(s).");
            return new SimulationResult(false, 1);
        }

        Console.WriteLine($"[x-cli] vi-compare-verify: verified {reportsChecked} report(s).");
        return new SimulationResult(true, 0);
    }

    private static Dictionary<string, bool> ParseIncludedAttributes(string html)
    {
        var result = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrEmpty(html))
            return result;

        var section = ExtractAttributeSection(html);
        foreach (Match match in AttributeRegex.Matches(section))
        {
            var label = match.Groups["label"].Value.Trim();
            if (string.IsNullOrEmpty(label))
                continue;

            var cls = match.Groups["cls"].Value;
            var isUnchecked = cls.IndexOf("unchecked", StringComparison.OrdinalIgnoreCase) >= 0;
            var isChecked = !isUnchecked;
            result[label] = isChecked;
        }
        return result;
    }

    private static string ExtractAttributeSection(string html)
    {
        const string Marker = "<div class=\"included-attributes\">";
        var idx = html.IndexOf(Marker, StringComparison.OrdinalIgnoreCase);
        if (idx < 0)
            return html;

        var start = idx + Marker.Length;
        var end = html.IndexOf("</div>", start, StringComparison.OrdinalIgnoreCase);
        if (end < 0)
            end = html.Length;
        return html[start..end];
    }
}
