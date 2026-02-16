using System.IO.Compression;
using System.Net.Http.Headers;
using System.Text.Json;

namespace RunnerCli;

public sealed record PylaviFetchOptions(
    string? Repo,
    string? Token,
    string Workflow,
    string? Sha,
    long RunId,
    string? Branch,
    string? Label,
    string ArtifactPrefix,
    string RepoRoot,
    string OutDir,
    string PreferLabel
);

public sealed record PylaviFetchResult(
    string LatestPath,
    string Label,
    long RunId,
    string? Sha
);

public static class PylaviFetchService
{
    public static PylaviFetchResult Fetch(PylaviFetchOptions options)
    {
        var repo = GitHubRepoResolver.Resolve(options.Repo, options.RepoRoot);
        var token = ResolveToken(options.Token);
        using var client = CreateClient(token);

        var workflowId = GetWorkflowId(client, repo, options.Workflow);
        var run = GetRun(client, repo, workflowId, options.RunId, options.Sha, options.Branch);
        var runId = GetLong(run, "id");
        var runSha = GetString(run, "head_sha");

        var artifacts = GetArtifacts(client, repo, runId);
        var filtered = FilterArtifacts(artifacts, options.ArtifactPrefix, options.Label, options.Sha);
        if (filtered.Count == 0)
        {
            throw new InvalidOperationException($"No pylavi offenders artifacts found for run {runId}.");
        }

        var outDir = Path.IsPathRooted(options.OutDir) ? options.OutDir : Path.Combine(options.RepoRoot, options.OutDir);
        Directory.CreateDirectory(outDir);

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
        var downloaded = new List<(string Label, string Path)>();

        foreach (var artifact in filtered)
        {
            var name = GetString(artifact, "name") ?? "runner-cli";
            var label = name.Substring(options.ArtifactPrefix.Length).TrimStart('-');
            if (string.IsNullOrWhiteSpace(label))
            {
                label = "unknown";
            }

            var reportJson = DownloadArtifact(client, GetString(artifact, "archive_download_url")!);

            var latestLabel = Path.Combine(outDir, $"pylavi-offenders.latest.{label}.json");
            var datedLabel = Path.Combine(outDir, $"pylavi-offenders.{label}.{timestamp}.json");
            File.WriteAllText(latestLabel, reportJson);
            File.WriteAllText(datedLabel, reportJson);

            if (!string.IsNullOrWhiteSpace(runSha))
            {
                var shaLabel = Path.Combine(outDir, $"pylavi-offenders.{label}.{runSha}.json");
                File.WriteAllText(shaLabel, reportJson);
            }

            downloaded.Add((label, latestLabel));
        }

        var canonical = ResolveCanonical(downloaded, options.Label, options.PreferLabel);
        var latestPath = Path.Combine(outDir, "pylavi-offenders.latest.json");
        File.Copy(canonical.Path, latestPath, true);

        if (!string.IsNullOrWhiteSpace(runSha))
        {
            var shaPath = Path.Combine(outDir, $"pylavi-offenders.{runSha}.json");
            File.Copy(canonical.Path, shaPath, true);
        }

        Console.WriteLine("PYLAVI_OFFENDERS_FETCHED=1");
        Console.WriteLine($"PYLAVI_OFFENDERS_FILE={latestPath}");
        Console.WriteLine($"PYLAVI_OFFENDERS_LABEL={canonical.Label}");
        Console.WriteLine($"PYLAVI_OFFENDERS_RUN_ID={runId}");
        if (!string.IsNullOrWhiteSpace(runSha))
        {
            Console.WriteLine($"PYLAVI_OFFENDERS_SHA={runSha}");
        }
        Console.WriteLine($"PYLAVI_OFFENDERS_WORKFLOW={options.Workflow}");
        Console.WriteLine($"PYLAVI_OFFENDERS_BRANCH={options.Branch}");

        return new PylaviFetchResult(latestPath, canonical.Label, runId, runSha);
    }

    private static string ResolveToken(string? token)
    {
        if (!string.IsNullOrWhiteSpace(token))
            return token.Trim();
        var env = Environment.GetEnvironmentVariable("GH_TOKEN");
        if (!string.IsNullOrWhiteSpace(env))
            return env.Trim();
        env = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
        if (!string.IsNullOrWhiteSpace(env))
            return env.Trim();
        throw new InvalidOperationException("GitHub token not provided. Set --token, GH_TOKEN, or GITHUB_TOKEN.");
    }

    private static HttpClient CreateClient(string token)
    {
        var client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("lvie-pylavi-offenders", "1.0"));
        client.DefaultRequestHeaders.Add("X-GitHub-Api-Version", "2022-11-28");
        return client;
    }

    private static long GetWorkflowId(HttpClient client, string repo, string workflow)
    {
        var url = $"https://api.github.com/repos/{repo}/actions/workflows/{workflow}";
        var doc = GetJson(client, url);
        return GetLong(doc.RootElement, "id");
    }

    private static JsonElement GetRun(HttpClient client, string repo, long workflowId, long runId, string? sha, string? branch)
    {
        if (runId > 0 && !string.IsNullOrWhiteSpace(sha))
        {
            throw new InvalidOperationException("Provide only one of --run-id or --sha.");
        }

        if (runId > 0)
        {
            var url = $"https://api.github.com/repos/{repo}/actions/runs/{runId}";
            var doc = GetJson(client, url);
            var workflowIdInRun = GetLong(doc.RootElement, "workflow_id");
            if (workflowIdInRun != workflowId)
            {
                throw new InvalidOperationException($"RunId {runId} does not belong to workflow {workflowId}.");
            }
            return doc.RootElement;
        }

        var query = "status=completed&per_page=20";
        if (!string.IsNullOrWhiteSpace(branch))
        {
            query += $"&branch={Uri.EscapeDataString(branch)}";
        }
        if (!string.IsNullOrWhiteSpace(sha))
        {
            query += $"&head_sha={Uri.EscapeDataString(sha)}";
        }

        var runsUrl = $"https://api.github.com/repos/{repo}/actions/workflows/{workflowId}/runs?{query}";
        var runsDoc = GetJson(client, runsUrl);
        if (!runsDoc.RootElement.TryGetProperty("workflow_runs", out var runs) || runs.GetArrayLength() == 0)
        {
            var detail = !string.IsNullOrWhiteSpace(sha) ? $"sha {sha}" : $"branch {branch}";
            throw new InvalidOperationException($"No completed workflow runs found for {repo} ({workflowId}) for {detail}.");
        }
        return runs[0];
    }

    private static List<JsonElement> GetArtifacts(HttpClient client, string repo, long runId)
    {
        var url = $"https://api.github.com/repos/{repo}/actions/runs/{runId}/artifacts";
        var doc = GetJson(client, url);
        if (!doc.RootElement.TryGetProperty("artifacts", out var artifacts))
            return new List<JsonElement>();
        return artifacts.EnumerateArray().ToList();
    }

    private static List<JsonElement> FilterArtifacts(List<JsonElement> artifacts, string prefix, string? label, string? sha)
    {
        var filtered = artifacts.Where(a =>
        {
            var name = GetString(a, "name");
            return !string.IsNullOrWhiteSpace(name) && name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
        }).ToList();

        if (!string.IsNullOrWhiteSpace(label))
        {
            var target = $"{prefix}-{label}";
            filtered = filtered.Where(a => string.Equals(GetString(a, "name"), target, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(sha))
        {
            var match = filtered.Where(a => (GetString(a, "name") ?? string.Empty).Contains(sha, StringComparison.OrdinalIgnoreCase)).ToList();
            if (match.Count > 0)
            {
                return match;
            }
            Console.Error.WriteLine($"WARNING: No artifacts matched SHA '{sha}' by name; falling back to prefix match.");
        }

        return filtered;
    }

    private static (string Label, string Path) ResolveCanonical(List<(string Label, string Path)> entries, string? label, string preferLabel)
    {
        if (!string.IsNullOrWhiteSpace(label))
        {
            var explicitMatch = entries.FirstOrDefault(e => string.Equals(e.Label, label, StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(explicitMatch.Label))
                return explicitMatch;
        }

        if (!string.IsNullOrWhiteSpace(preferLabel))
        {
            var preferred = entries.FirstOrDefault(e => string.Equals(e.Label, preferLabel, StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(preferred.Label))
                return preferred;
        }

        return entries[0];
    }

    internal static string ExtractOffendersJson(byte[] zipBytes)
    {
        using var stream = new MemoryStream(zipBytes);
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
        var entry = archive.Entries.FirstOrDefault(e => string.Equals(Path.GetFileName(e.FullName), "vi_validate_offenders.json", StringComparison.OrdinalIgnoreCase));
        if (entry is null)
        {
            throw new InvalidOperationException("Expected vi_validate_offenders.json not found in artifact.");
        }
        using var entryStream = entry.Open();
        using var reader = new StreamReader(entryStream);
        return reader.ReadToEnd();
    }

    private static string DownloadArtifact(HttpClient client, string url)
    {
        var bytes = client.GetByteArrayAsync(url).GetAwaiter().GetResult();
        return ExtractOffendersJson(bytes);
    }

    private static JsonDocument GetJson(HttpClient client, string url)
    {
        var json = client.GetStringAsync(url).GetAwaiter().GetResult();
        return JsonDocument.Parse(json);
    }

    private static string? GetString(JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out var value))
            return null;
        return value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
    }

    private static long GetLong(JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out var value))
            return 0;
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number))
            return number;
        var text = value.GetString();
        return long.TryParse(text, out var parsed) ? parsed : 0;
    }
}
