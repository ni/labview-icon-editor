// ModuleIndex: replays recorded JSONL logs to stdout/stderr with timing.
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace XCli.Replay;

public static class LogReplayCommand
{
    private sealed class Record
    {
        [JsonPropertyName("t")] public int DelayMs { get; set; }
        [JsonPropertyName("s")] public string? Stream { get; set; }
        [JsonPropertyName("m")] public string? Message { get; set; }
    }

    public static async Task<int> Run(string[] args)
    {
        string? source = null;
        bool strict = false;
        int maxDelayMs = -1;
        bool stdoutOnly = false;

        for (var i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a == "--from" && i + 1 < args.Length) { source = args[++i]; continue; }
            if (a == "--strict") { strict = true; continue; }
            if (a == "--max-delay-ms" && i + 1 < args.Length) { _ = int.TryParse(args[++i], out maxDelayMs); continue; }
            if (a == "--stdout-only") { stdoutOnly = true; continue; }
        }

        if (string.IsNullOrWhiteSpace(source) || !File.Exists(source))
        {
            Console.Error.WriteLine("x-cli: missing or invalid --from <path>");
            return 2;
        }

        var serializerOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            AllowTrailingCommas = true
        };

        var lineNumber = 0;
        foreach (var line in File.ReadLines(source))
        {
            lineNumber++;
            if (string.IsNullOrWhiteSpace(line))
                continue;

            Record? rec = null;
            try { rec = JsonSerializer.Deserialize<Record>(line, serializerOptions); }
            catch (Exception ex)
            {
                if (strict)
                {
                    Console.Error.WriteLine($"x-cli: invalid record on line {lineNumber}: {ex.Message}");
                    return 3;
                }
                continue;
            }

            if (rec?.Message is null)
            {
                if (strict)
                {
                    Console.Error.WriteLine($"x-cli: missing message on line {lineNumber}");
                    return 3;
                }
                continue;
            }

            var delay = Math.Max(0, rec.DelayMs);
            if (maxDelayMs >= 0)
                delay = Math.Min(delay, maxDelayMs);

            if (delay > 0)
                await Task.Delay(delay);

            var stream = stdoutOnly ? "stdout" : (rec.Stream ?? "stdout").Trim().ToLowerInvariant();
            if (stream == "stderr")
                Console.Error.WriteLine(rec.Message);
            else
                Console.WriteLine(rec.Message);
        }

        return 0;
    }
}
