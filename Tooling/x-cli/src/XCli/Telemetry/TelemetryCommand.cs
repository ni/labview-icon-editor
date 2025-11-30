// ModuleIndex: telemetry subcommands (summarize, write, check, validate).
using System.Text.Json;
using XCli.Telemetry.Summary;
using XCli.Util;

namespace XCli.Telemetry;

    public static class TelemetryCommand
    {
        private static int Validate(string[] args)
        {
            string? summary = null;
            string? eventsPath = null;
            string? schemaPath = null;
            for (int i = 0; i < args.Length; i++)
            {
                var a = args[i];
                if (a == "--summary" && i + 1 < args.Length) { summary = args[++i]; continue; }
                if (a == "--events" && i + 1 < args.Length) { eventsPath = args[++i]; continue; }
                if (a == "--schema" && i + 1 < args.Length) { schemaPath = args[++i]; continue; }
            }
            if (string.IsNullOrWhiteSpace(summary) && string.IsNullOrWhiteSpace(eventsPath))
            {
                Console.Error.WriteLine("telemetry validate: --summary PATH or --events PATH required");
                return 2;
            }
            Json.Schema.JsonSchema? schema = null;
            if (!string.IsNullOrWhiteSpace(schemaPath))
            {
                try
                {
                    var schemaText = File.ReadAllText(schemaPath!);
                    schema = Json.Schema.JsonSchema.FromText(schemaText);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"telemetry validate: failed to load schema: {ex.Message}");
                    return 2;
                }
            }
            try
            {
                if (!string.IsNullOrWhiteSpace(summary))
                {
                    if (!File.Exists(summary)) { Console.Error.WriteLine($"summary not found: {summary}"); return 2; }
                    var summaryText = File.ReadAllText(summary!);
                    // If a schema is provided, validate the JSON first so tests see the expected message
                    if (schema is not null)
                    {
                        var node = System.Text.Json.Nodes.JsonNode.Parse(summaryText);
                        var result = schema.Evaluate(node!, new Json.Schema.EvaluationOptions { OutputFormat = Json.Schema.OutputFormat.Hierarchical });
                        if (!result.IsValid)
                        {
                            Console.Error.WriteLine("summary: schema validation failed");
                            PrintSchemaErrors(result);
                            return 2;
                        }
                    }
                    using var doc = JsonDocument.Parse(summaryText);
                    var root = doc.RootElement;
                    if (root.ValueKind != JsonValueKind.Object) { Console.Error.WriteLine("summary must be a JSON object"); return 2; }
                    if (!root.TryGetProperty("counts", out var counts) || counts.ValueKind != JsonValueKind.Object)
                    { Console.Error.WriteLine("summary: counts missing or not an object"); return 2; }
                    if (!root.TryGetProperty("total", out var total) || total.ValueKind != JsonValueKind.Number)
                    { Console.Error.WriteLine("summary: total missing or not a number"); return 2; }
                    if (!root.TryGetProperty("totalFailures", out var totalFailures) || totalFailures.ValueKind != JsonValueKind.Number)
                    { Console.Error.WriteLine("summary: totalFailures missing or not a number"); return 2; }
                }
                if (!string.IsNullOrWhiteSpace(eventsPath))
                {
                    if (!File.Exists(eventsPath)) { Console.Error.WriteLine($"events not found: {eventsPath}"); return 2; }
                    int lineNo = 0;
                    foreach (var line in File.ReadLines(eventsPath!))
                    {
                        lineNo++;
                        var ln = line.Trim(); if (ln.Length == 0) continue;
                        try
                        {
                            using var doc = JsonDocument.Parse(ln);
                            var root = doc.RootElement;
                            if (!root.TryGetProperty("step", out var step) || string.IsNullOrWhiteSpace(step.GetString()))
                            {
                                // Not an event line; skip
                                continue;
                            }
                            if (!root.TryGetProperty("status", out var status) || string.IsNullOrWhiteSpace(status.GetString()))
                            { Console.Error.WriteLine($"events: line {lineNo}: missing status"); return 2; }
                            if (schema is not null)
                            {
                                var node = System.Text.Json.Nodes.JsonNode.Parse(ln);
                                var result = schema.Evaluate(node!, new Json.Schema.EvaluationOptions { OutputFormat = Json.Schema.OutputFormat.Hierarchical });
                                if (!result.IsValid)
                                {
                                    Console.Error.WriteLine($"events: line {lineNo}: schema validation failed");
                                    PrintSchemaErrors(result);
                                    return 2;
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.Error.WriteLine($"events: line {lineNo}: invalid JSON: {ex.Message}");
                            return 2;
                        }
                    }
                }
                Console.WriteLine("telemetry: validation OK");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"telemetry validate: {ex.Message}");
                return 2;
            }
        }
    private static int Write(string[] args)
    {
        string? outPath = null;
        string? step = null;
        string? status = null;
        long? durationMs = null;
        long? start = null;
        long? end = null;
        var meta = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        for (int i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a == "--out" && i + 1 < args.Length) { outPath = args[++i]; continue; }
            if (a == "--step" && i + 1 < args.Length) { step = args[++i]; continue; }
            if (a == "--status" && i + 1 < args.Length) { status = args[++i]; continue; }
            if (a == "--duration-ms" && i + 1 < args.Length && long.TryParse(args[i+1], out var d)) { durationMs = d; i++; continue; }
            if (a == "--start" && i + 1 < args.Length && long.TryParse(args[i+1], out var s)) { start = s; i++; continue; }
            if (a == "--end" && i + 1 < args.Length && long.TryParse(args[i+1], out var e)) { end = e; i++; continue; }
            if (a == "--meta" && i + 1 < args.Length)
            {
                var kv = args[++i];
                var eq = kv.IndexOf('=');
                if (eq > 0)
                {
                    var k = kv.Substring(0, eq);
                    var v = kv.Substring(eq + 1);
                    meta[k] = v;
                }
                continue;
            }
        }
        if (string.IsNullOrWhiteSpace(outPath) || string.IsNullOrWhiteSpace(step) || string.IsNullOrWhiteSpace(status))
        {
            Console.Error.WriteLine("telemetry write: --out PATH, --step NAME, and --status (pass|fail) are required");
            return 2;
        }
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        start ??= now;
        end ??= now;
        durationMs ??= Math.Max(0, (end.Value - start.Value));
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outPath!))!);
        var rec = new {
            step,
            status,
            duration_ms = durationMs,
            start,
            end,
            meta = meta.Count > 0 ? meta : null
        };
        using var fs = new FileStream(outPath!, FileMode.Append, FileAccess.Write, FileShare.Read);
        using var sw = new StreamWriter(fs, new System.Text.UTF8Encoding(false));
        sw.WriteLine(JsonSerializer.Serialize(rec, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
        return 0;
    }

    private static void PrintSchemaErrors(Json.Schema.EvaluationResults res)
    {
        try
        {
            var q = new Queue<Json.Schema.EvaluationResults>();
            q.Enqueue(res);
            while (q.Count > 0)
            {
                var r = q.Dequeue();
                if (!r.IsValid)
                {
                    var inst = r.InstanceLocation?.ToString() ?? string.Empty;
                    var sch = r.SchemaLocation?.ToString() ?? string.Empty;
                    Console.Error.WriteLine($" - instance={inst} schema={sch}");
                }
                foreach (var d in r.Details)
                    q.Enqueue(d);
            }
        }
        catch { /* ignore printing issues */ }
    }

    private static int Check(string[] args)
    {
        string? summaryPath = null;
        int? maxFailures = null;
        var perStep = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a == "--summary" && i + 1 < args.Length) { summaryPath = args[++i]; continue; }
            if (a == "--max-failures" && i + 1 < args.Length && int.TryParse(args[i+1], out var m)) { maxFailures = m; i++; continue; }
            if (a == "--max-failures-step" && i + 1 < args.Length)
            {
                var spec = args[++i];
                var eq = spec.IndexOf('=');
                if (eq > 0 && int.TryParse(spec[(eq+1)..], out var val))
                {
                    var step = spec[..eq];
                    if (!string.IsNullOrWhiteSpace(step)) perStep[step] = val;
                }
                continue;
            }
        }
        if (string.IsNullOrWhiteSpace(summaryPath) || (maxFailures is null && perStep.Count == 0))
        {
            Console.Error.WriteLine("telemetry check: --summary PATH and either --max-failures N or --max-failures-step step=N (repeatable) are required");
            return 2;
        }
        if (!File.Exists(summaryPath))
        {
            Console.Error.WriteLine($"telemetry check: summary not found: {summaryPath}");
            return 2;
        }
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(summaryPath!));
            var root = doc.RootElement;
            var tf = root.TryGetProperty("totalFailures", out var p) ? p.GetInt32() : 0;
            if (maxFailures is not null)
            {
                if (tf > maxFailures)
                {
                    Console.Error.WriteLine($"Telemetry gate: totalFailures={tf} exceeds max-failures={maxFailures}");
                    return 1;
                }
                Console.WriteLine($"Telemetry gate OK: totalFailures={tf} <= max-failures={maxFailures}");
            }
            if (perStep.Count > 0)
            {
                var failures = root.TryGetProperty("failureCounts", out var fc) && fc.ValueKind == JsonValueKind.Object ? fc : default;
                foreach (var kv in perStep)
                {
                    var step = kv.Key; var limit = kv.Value;
                    var count = 0;
                    if (failures.ValueKind == JsonValueKind.Object && failures.TryGetProperty(step, out var v) && v.TryGetInt32(out var vi))
                        count = vi;
                    if (count > limit)
                    {
                        Console.Error.WriteLine($"Telemetry gate: step '{step}' failures={count} exceeds limit={limit}");
                        return 1;
                    }
                    Console.WriteLine($"Telemetry gate OK: step '{step}' failures={count} <= limit={limit}");
                }
            }
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"telemetry check: failed to parse summary: {ex.Message}");
            return 2;
        }
    }
    private static int Summarize(string[] args)
    {
        string? input = null;
        string? output = null;
        string? history = null;
        string? runId = Env.Get("GITHUB_RUN_ID") ?? Env.Get("RUN_ID");

        for (int i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a == "--in" && i + 1 < args.Length) { input = args[++i]; continue; }
            if (a == "--out" && i + 1 < args.Length) { output = args[++i]; continue; }
            if (a == "--history" && i + 1 < args.Length) { history = args[++i]; continue; }
        }
        if (string.IsNullOrWhiteSpace(input) || string.IsNullOrWhiteSpace(output))
        {
            Console.Error.WriteLine("telemetry summarize: --in PATH and --out PATH are required");
            return 2;
        }
        var summary = SummaryBuilder.BuildFromJsonl(input!);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output!))!);
        var json = JsonSerializer.Serialize(summary, new JsonSerializerOptions(JsonSerializerDefaults.Web) { WriteIndented = true });
        File.WriteAllText(output!, json);
        if (!string.IsNullOrWhiteSpace(history))
        {
            SummaryBuilder.AppendHistory(history!, summary, runId);
        }
        return 0;
    }

    public static int Run(string[] payloadArgs)
    {
        if (payloadArgs.Length == 0)
        {
            Console.Error.WriteLine("telemetry: expected subcommand (summarize)");
            return 2;
        }
        var sub = payloadArgs[0];
        var rest = payloadArgs.Skip(1).ToArray();
        return sub switch
        {
            "summarize" => Summarize(rest),
            "write" => Write(rest),
            "check" => Check(rest),
            "validate" => Validate(rest),
            _ => Unknown(sub)
        };
    }

    private static int Unknown(string sub)
    {
        Console.Error.WriteLine($"telemetry: unknown subcommand '{sub}'. Supported: summarize");
        return 2;
    }
}
