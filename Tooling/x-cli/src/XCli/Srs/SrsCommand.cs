using System.Text.Json;
using XCli.Util;

namespace XCli.Srs;

public static class SrsCommand
{
    public static int Run(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("srs: missing action (validate|import-csv|export-csv|export-rtm)");
            return 1;
        }

        var action = args[0];
        var options = ParseOptions(args.Skip(1).ToArray());
        try
        {
            return action switch
            {
                "validate" => Validate(options),
                "import-csv" => ImportCsv(options),
                "export-csv" => ExportCsv(options),
                "export-rtm" => ExportRtm(options),
                _ => Unknown(action)
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[srs] error: {ex.Message}");
            if (Env.GetBool("XCLI_DEBUG", false))
                Console.Error.WriteLine(ex);
            return 1;
        }
    }

    private static int Validate(Dictionary<string, string> opts)
    {
        if (!opts.TryGetValue("input", out var input))
            throw new ArgumentException("--input is required");

        opts.TryGetValue("output-json", out var outputJsonPath);
        var schemaStrict = opts.ContainsKey("schema-strict");

        var reqs = SrsIo.LoadRequirements(input);
        SrsIo.ValidateIdsAndCollisions(reqs);

        var schemaValid = true;
        var schemaReport = string.Empty;
        if (opts.TryGetValue("schema", out var schemaPath))
        {
            var result = SrsIo.ValidateAgainstSchema(schemaPath, reqs);
            schemaValid = result.IsValid;
            schemaReport = result.Report;

            if (!result.IsValid)
            {
                Console.Error.WriteLine("[srs] schema validation failed:");
                Console.Error.WriteLine(result.Report);
                if (schemaStrict)
                    return 1;
            }
        }

        Console.WriteLine($"[srs] validate ok ({reqs.Count} requirements)");

        if (!string.IsNullOrWhiteSpace(outputJsonPath))
        {
            var summary = new
            {
                status = schemaValid ? "ok" : "schema-failed",
                requirements = reqs.Count,
                schema = new
                {
                    valid = schemaValid,
                    report = schemaReport,
                    path = opts.TryGetValue("schema", out var schemaPathOut) ? schemaPathOut : null
                }
            };

            var dir = Path.GetDirectoryName(outputJsonPath);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);

            var json = JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(outputJsonPath, json);
        }

        return 0;
    }

    private static int ImportCsv(Dictionary<string, string> opts)
    {
        if (!opts.TryGetValue("input", out var input))
            throw new ArgumentException("--input is required");
        if (!opts.TryGetValue("output", out var output))
            throw new ArgumentException("--output is required");

        var reqs = SrsCsv.Import(input);
        SrsIo.ValidateIdsAndCollisions(reqs);

        var ext = Path.GetExtension(output).ToLowerInvariant();
        if (ext is ".yaml" or ".yml")
            SrsIo.SaveRequirementsAsYaml(output, reqs);
        else
            SrsIo.SaveRequirementsAsJson(output, reqs);

        Console.WriteLine($"[srs] imported {reqs.Count} requirements -> {output}");
        return 0;
    }

    private static int ExportCsv(Dictionary<string, string> opts)
    {
        if (!opts.TryGetValue("input", out var input))
            throw new ArgumentException("--input is required");
        if (!opts.TryGetValue("output", out var output))
            throw new ArgumentException("--output is required");

        var reqs = SrsIo.LoadRequirements(input);
        SrsIo.ValidateIdsAndCollisions(reqs);
        SrsCsv.Export(output, reqs);
        Console.WriteLine($"[srs] exported {reqs.Count} requirements -> {output}");
        return 0;
    }

    private static int ExportRtm(Dictionary<string, string> opts)
    {
        if (!opts.TryGetValue("input", out var input))
            throw new ArgumentException("--input is required");
        if (!opts.TryGetValue("output", out var output))
            throw new ArgumentException("--output is required");

        var reqs = SrsIo.LoadRequirements(input);
        SrsIo.ValidateIdsAndCollisions(reqs);
        SrsRtm.WriteMarkdown(output, reqs);
        Console.WriteLine($"[srs] wrote RTM markdown -> {output}");
        return 0;
    }

    private static int Unknown(string action)
    {
        Console.Error.WriteLine($"srs: unknown action '{action}' (expected validate|import-csv|export-csv|export-rtm)");
        return 1;
    }

    private static Dictionary<string, string> ParseOptions(string[] args)
    {
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (!arg.StartsWith("--"))
                continue;
            var key = arg.TrimStart('-');
            var value = (i + 1 < args.Length && !args[i + 1].StartsWith("--")) ? args[++i] : string.Empty;
            dict[key] = value;
        }
        return dict;
    }
}
