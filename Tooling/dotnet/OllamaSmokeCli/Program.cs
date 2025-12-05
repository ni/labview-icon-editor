using System.Diagnostics;
using System.Linq;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Net;

internal static class Program
{
    private const int ExitSuccess = 0;
    private const int ExitUnexpected = 1;
    private const int ExitHttpError = 2;
    private const int ExitTimeout = 3;
    private const int ExitModelMissing = 4;
    private const int ExitSizeExceeded = 5;
    private const int ExitEmptyResponse = 6;

    private sealed record ChatMessage(string Role, string Content);
    private sealed record Header(string Key, string Value);

    private sealed record Options(
        string Endpoint,
        string Model,
        string Prompt,
        int TimeoutSec,
        bool Stream,
        string Mode,
        string Format,
        bool CheckModel,
        int Retries,
        int RetryDelayMs,
        bool Verbose,
        string? SaveBodyPath,
        IReadOnlyList<ChatMessage>? Messages,
        int MaxBytes,
        string? StopToken,
        string? OutputPath,
        int ExpectStatus,
        bool ExitOnEmpty,
        bool Trace,
        bool SkipCertCheck,
        string? Proxy,
        IReadOnlyList<Header> Headers);

    private static int Main(string[] args)
    {
        try
        {
            var opts = Parse(args);
            return RunAsync(opts).GetAwaiter().GetResult();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"error: {ex.Message}");
            return ExitUnexpected;
        }
    }

    private static async Task<int> RunAsync(Options opts)
    {
        var sw = Stopwatch.StartNew();
        var baseUri = opts.Endpoint.EndsWith("/") ? opts.Endpoint : $"{opts.Endpoint}/";
        var path = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase)
            ? "api/chat"
            : opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase)
                ? "api/embed"
                : "api/generate";
        var uri = new Uri(new Uri(baseUri), path);

        var handler = new HttpClientHandler();
        if (opts.SkipCertCheck)
        {
            handler.ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator;
        }
        if (!string.IsNullOrWhiteSpace(opts.Proxy))
        {
            handler.Proxy = new WebProxy(opts.Proxy);
            handler.UseProxy = true;
        }
        using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(opts.TimeoutSec > 0 ? opts.TimeoutSec : 30) };

        if (opts.CheckModel && !await EnsureModelAsync(client, baseUri, opts.Model))
        {
            return ExitModelMissing;
        }

        var isChat = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase);
        var chatList = isChat
            ? (opts.Messages != null ? opts.Messages.ToList() : new List<ChatMessage> { new("user", opts.Prompt) })
            : new List<ChatMessage>();
        var chatMessages = chatList.Select(m => new { role = m.Role, content = m.Content }).ToArray();

        if (opts.MaxBytes > 0)
        {
            var totalBytes = isChat
                ? Utf8ByteCount(chatList.Select(m => m.Content))
                : Utf8ByteCount(new[] { opts.Prompt });
            if (totalBytes > opts.MaxBytes)
            {
                Console.Error.WriteLine($"fail: payload size {totalBytes} bytes exceeds max {opts.MaxBytes}");
                return ExitSizeExceeded;
            }
        }

        var stopArr = string.IsNullOrWhiteSpace(opts.StopToken) ? null : new[] { opts.StopToken };

        var payload = isChat
            ? JsonSerializer.Serialize(new
            {
                model = opts.Model,
                messages = chatMessages,
                stream = opts.Stream,
                stop = stopArr
            })
            : opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase)
                ? JsonSerializer.Serialize(new { model = opts.Model, input = opts.Prompt })
                : JsonSerializer.Serialize(new { model = opts.Model, prompt = opts.Prompt, stream = opts.Stream, stop = stopArr });
        var payloadString = payload;

        if (opts.Verbose)
        {
            Console.WriteLine($"[verbose] POST {uri} mode={opts.Mode} stream={opts.Stream} retries={opts.Retries} retryDelayMs={opts.RetryDelayMs} skipCertCheck={opts.SkipCertCheck} proxy={opts.Proxy ?? "<none>"}");
            Console.WriteLine($"[verbose] payload: {payloadString}");
        }

        if (opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase))
        {
            return await RunEmbedAsync(client, uri, payloadString, opts, sw);
        }

        if (opts.Stream)
        {
            return await RunStreamAsync(client, uri, payloadString, opts, sw);
        }

        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payloadString, opts.Headers), stream: false, opts.Retries, opts.RetryDelayMs, opts.Trace);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }

        var body = await response.Content.ReadAsStringAsync();
        if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
        {
            File.WriteAllText(opts.SaveBodyPath, body);
        }
        var elapsed = sw.ElapsedMilliseconds;

        if (!response.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(body);
            }
            return ExitHttpError;
        }
        if (opts.ExpectStatus > 0 && (int)response.StatusCode != opts.ExpectStatus)
        {
            Console.Error.WriteLine($"fail: expected status {opts.ExpectStatus}, got {(int)response.StatusCode}");
            return ExitHttpError;
        }

        var text = ExtractResponseText(body);
        if (opts.ExitOnEmpty && string.IsNullOrWhiteSpace(text))
        {
            Console.Error.WriteLine("fail: empty response");
            return ExitEmptyResponse;
        }
        if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine(text);
            WriteOutput(opts.OutputPath, text);
            return ExitSuccess;
        }

        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
            mode = opts.Mode,
            stream = opts.Stream,
            elapsedMs = elapsed,
            response = text
        };

        var jsonOut = JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(jsonOut);
        WriteOutput(opts.OutputPath, jsonOut);
        return ExitSuccess;
    }

    private static async Task<int> RunEmbedAsync(HttpClient client, Uri uri, string payload, Options opts, Stopwatch sw)
    {
        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payload, opts.Headers), stream: false, opts.Retries, opts.RetryDelayMs, opts.Trace);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }

        var body = await response.Content.ReadAsStringAsync();
        if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
        {
            File.WriteAllText(opts.SaveBodyPath, body);
        }
        var elapsed = sw.ElapsedMilliseconds;

        if (!response.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(body);
            }
            return ExitHttpError;
        }
        if (opts.ExpectStatus > 0 && (int)response.StatusCode != opts.ExpectStatus)
        {
            Console.Error.WriteLine($"fail: expected status {opts.ExpectStatus}, got {(int)response.StatusCode}");
            return ExitHttpError;
        }

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            var vec = ExtractEmbedding(root);
            if (vec == null || vec.Length == 0)
            {
                Console.Error.WriteLine("fail: embed response missing embedding data");
                Console.Error.WriteLine(body);
                return ExitUnexpected;
            }

            var hash = Sha256String(string.Join(",", vec.Select(v => v.ToString("G17"))));
            if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine($"len={vec.Length} sha256={hash}");
                WriteOutput(opts.OutputPath, $"len={vec.Length} sha256={hash}");
                return ExitSuccess;
            }

            var output = new
            {
                endpoint = uri.ToString(),
                model = opts.Model,
                prompt = opts.Prompt,
                mode = opts.Mode,
                elapsedMs = elapsed,
                length = vec.Length,
                sha256 = hash
            };
            var jsonOut = JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true });
            Console.WriteLine(jsonOut);
            WriteOutput(opts.OutputPath, jsonOut);
            return ExitSuccess;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"fail: embed parse error: {ex.Message}");
            Console.Error.WriteLine(body);
            return ExitUnexpected;
        }
    }

    private static async Task<int> RunStreamAsync(HttpClient client, Uri uri, string payload, Options opts, Stopwatch sw)
    {
        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payload, opts.Headers), stream: true, opts.Retries, opts.RetryDelayMs, opts.Trace);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }
        if (!response.IsSuccessStatusCode)
        {
            var errBody = await response.Content.ReadAsStringAsync();
            if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
            {
                File.WriteAllText(opts.SaveBodyPath, errBody);
            }
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(errBody);
            }
            return ExitHttpError;
        }
        if (opts.ExpectStatus > 0 && (int)response.StatusCode != opts.ExpectStatus)
        {
            Console.Error.WriteLine($"fail: expected status {opts.ExpectStatus}, got {(int)response.StatusCode}");
            return ExitHttpError;
        }

        var sb = new StringBuilder();
        await using var stream = await response.Content.ReadAsStreamAsync();
        using var reader = new StreamReader(stream);

        while (!reader.EndOfStream)
        {
            var line = await reader.ReadLineAsync();
            if (string.IsNullOrWhiteSpace(line)) { continue; }
            try
            {
                using var doc = JsonDocument.Parse(line);
                var chunk = ExtractResponseText(doc.RootElement);
                if (!string.IsNullOrEmpty(chunk))
                {
                    sb.Append(chunk);
                    Console.Write(chunk);
                }
                if (doc.RootElement.TryGetProperty("done", out var doneProp) && doneProp.ValueKind == JsonValueKind.True)
                {
                    break;
                }
            }
            catch
            {
                // fall back to raw line
                sb.Append(line);
                Console.Write(line);
            }
        }

        var elapsed = sw.ElapsedMilliseconds;
        Console.WriteLine(); // end streamed tokens
        var streamedText = sb.ToString();
        if (opts.ExitOnEmpty && string.IsNullOrWhiteSpace(streamedText))
        {
            Console.Error.WriteLine("fail: empty response");
            return ExitEmptyResponse;
        }
        if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
        {
            WriteOutput(opts.OutputPath, streamedText);
            return 0;
        }

        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
            mode = opts.Mode,
            stream = true,
            elapsedMs = elapsed,
            response = streamedText
        };
        var jsonOut = JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(jsonOut);
        WriteOutput(opts.OutputPath, jsonOut);
        return 0;
    }

    private static HttpRequestMessage BuildPost(Uri uri, string payload, IReadOnlyList<Header> headers)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, uri);
        request.Content = new StringContent(payload, Encoding.UTF8, "application/json");
        if (headers != null)
        {
            foreach (var h in headers)
            {
                request.Headers.TryAddWithoutValidation(h.Key, h.Value);
            }
        }
        return request;
    }

    private static async Task<(HttpResponseMessage? Response, bool Timeout)> SendWithRetry(
        HttpClient client,
        Func<HttpRequestMessage> requestFactory,
        bool stream,
        int retries,
        int retryDelayMs,
        bool trace)
    {
        HttpResponseMessage? resp = null;
        for (var attempt = 0; attempt <= retries; attempt++)
        {
            resp?.Dispose();
            var req = requestFactory();
            try
            {
                var attemptSw = Stopwatch.StartNew();
                resp = await client.SendAsync(req, stream ? HttpCompletionOption.ResponseHeadersRead : HttpCompletionOption.ResponseContentRead);
                attemptSw.Stop();
                if (trace)
                {
                    Console.WriteLine($"[trace] attempt {attempt} status={(int)resp.StatusCode} elapsedMs={attemptSw.ElapsedMilliseconds}");
                }
                if ((int)resp.StatusCode >= 500 && attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                return (resp, false);
            }
            catch (TaskCanceledException)
            {
                if (attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                return (null, true);
            }
            catch
            {
                if (attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                throw;
            }
        }

        return (resp, false);
    }

    private static string ExtractResponseText(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            return ExtractResponseText(doc.RootElement);
        }
        catch
        {
            return body;
        }
    }

    private static string ExtractResponseText(JsonElement root)
    {
        if (root.ValueKind == JsonValueKind.Object)
        {
            if (root.TryGetProperty("response", out var resp) && resp.ValueKind == JsonValueKind.String)
            {
                return resp.GetString() ?? string.Empty;
            }
            if (root.TryGetProperty("message", out var msg) && msg.ValueKind == JsonValueKind.Object &&
                msg.TryGetProperty("content", out var content) && content.ValueKind == JsonValueKind.String)
            {
                return content.GetString() ?? string.Empty;
            }
        }
        return string.Empty;
    }

    private static async Task<bool> EnsureModelAsync(HttpClient client, string baseUri, string model)
    {
        var uri = new Uri(new Uri(baseUri), "api/tags");
        try
        {
            var response = await client.GetAsync(uri);
            if (!response.IsSuccessStatusCode)
            {
                Console.Error.WriteLine($"fail: model check status={(int)response.StatusCode} reason={response.ReasonPhrase}");
                return false;
            }
            var body = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("models", out var models) && models.ValueKind == JsonValueKind.Array)
            {
                foreach (var m in models.EnumerateArray())
                {
                    var name = m.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var modelField = m.TryGetProperty("model", out var mf) ? mf.GetString() : null;
                    if (string.Equals(name, model, StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(modelField, model, StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(name, $"{model}:latest", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(modelField, $"{model}:latest", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }
            }
            Console.Error.WriteLine($"fail: model '{model}' not found in tags");
            return false;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"fail: model check error: {ex.Message}");
            return false;
        }
    }

    private static List<ChatMessage> LoadMessagesFromFile(string path)
    {
        var text = File.ReadAllText(path);
        try
        {
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("messages file must be a JSON array");
            }
            var list = new List<ChatMessage>();
            foreach (var item in doc.RootElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object) continue;
                var role = item.TryGetProperty("role", out var r) ? r.GetString() : null;
                var content = item.TryGetProperty("content", out var c) ? c.GetString() : null;
                if (string.IsNullOrWhiteSpace(role) || string.IsNullOrWhiteSpace(content)) continue;
                list.Add(new ChatMessage(role!, content!));
            }
            if (list.Count == 0)
            {
                throw new ArgumentException("messages file contained no valid role/content pairs");
            }
            return list;
        }
        catch (JsonException ex)
        {
            throw new ArgumentException($"messages file parse error: {ex.Message}");
        }
    }

    private static List<ChatMessage> LoadMessagesFromBase64(string base64)
    {
        var text = DecodeBase64(base64);
        var tmp = Path.GetTempFileName();
        File.WriteAllText(tmp, text);
        try
        {
            return LoadMessagesFromFile(tmp);
        }
        finally
        {
            try { File.Delete(tmp); } catch { }
        }
    }

    private static string DecodeBase64(string data)
    {
        var bytes = Convert.FromBase64String(data);
        return Encoding.UTF8.GetString(bytes);
    }

    private static double[]? ExtractEmbedding(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object) return null;
        if (root.TryGetProperty("embedding", out var emb) && emb.ValueKind == JsonValueKind.Array)
        {
            return emb.EnumerateArray().Select(e => e.GetDouble()).ToArray();
        }
        if (root.TryGetProperty("embeddings", out var embs) && embs.ValueKind == JsonValueKind.Array)
        {
            var first = embs.EnumerateArray().FirstOrDefault();
            if (first.ValueKind == JsonValueKind.Array)
            {
                return first.EnumerateArray().Select(e => e.GetDouble()).ToArray();
            }
        }
        return null;
    }

    private static string Sha256String(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var hash = SHA256.HashData(bytes);
        return BitConverter.ToString(hash).Replace("-", string.Empty).ToLowerInvariant();
    }

    private static int Utf8ByteCount(IEnumerable<string> values)
    {
        var encoder = Encoding.UTF8;
        var total = 0;
        foreach (var v in values)
        {
            if (v == null) continue;
            total += encoder.GetByteCount(v);
        }
        return total;
    }

    private static void WriteOutput(string? path, string content)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(dir))
        {
            Directory.CreateDirectory(dir);
        }
        File.WriteAllText(path, content);
    }

    private static Options Parse(string[] args)
    {
        var endpoint = "http://localhost:11435";
        var model = "llama3-8b-local";
        var prompt = "Hello smoke";
        var timeoutSec = 30;
        var stream = false;
        var mode = "generate";
        var format = "json";
        var checkModel = false;
        var retries = 0;
        var retryDelayMs = 1000;
        var verbose = false;
        string? saveBodyPath = null;
        string? promptFile = null;
        string? messagesFile = null;
        List<ChatMessage>? messages = null;
        var maxBytes = 0;
        string? stopToken = null;
        string? outputPath = null;
        int expectStatus = 0;
        var exitOnEmpty = false;
        var trace = false;
        string? promptBase64 = null;
        string? messagesBase64 = null;
        var skipCertCheck = false;
        string? proxy = null;
        var headers = new List<Header>();
        string? bearerToken = null;
        string? bearerTokenFile = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "-e":
                case "--endpoint":
                    endpoint = Next(args, ref i, arg);
                    break;
                case "-m":
                case "--model":
                    model = Next(args, ref i, arg);
                    break;
                case "-p":
                case "--prompt":
                    prompt = Next(args, ref i, arg);
                    break;
                case "-t":
                case "--timeout-sec":
                    var raw = Next(args, ref i, arg);
                    if (!int.TryParse(raw, out timeoutSec) || timeoutSec <= 0)
                    {
                        throw new ArgumentException($"Invalid timeout: {raw}");
                    }
                    break;
                case "--stream":
                    stream = true;
                    break;
                case "--chat":
                    mode = "chat";
                    break;
                case "--format":
                    format = Next(args, ref i, arg);
                    if (!format.Equals("json", StringComparison.OrdinalIgnoreCase) && !format.Equals("text", StringComparison.OrdinalIgnoreCase))
                    {
                        throw new ArgumentException($"Invalid format: {format} (expected json|text)");
                    }
                    break;
                case "--embed":
                    mode = "embed";
                    break;
                case "--check-model":
                    checkModel = true;
                    break;
                case "--retries":
                    var rawRetries = Next(args, ref i, arg);
                    if (!int.TryParse(rawRetries, out retries) || retries < 0)
                    {
                        throw new ArgumentException($"Invalid retries: {rawRetries}");
                    }
                    break;
                case "--retry-delay-ms":
                    var rawDelay = Next(args, ref i, arg);
                    if (!int.TryParse(rawDelay, out retryDelayMs) || retryDelayMs < 0)
                    {
                        throw new ArgumentException($"Invalid retry delay: {rawDelay}");
                    }
                    break;
                case "--verbose":
                    verbose = true;
                    break;
                case "--save-body":
                    saveBodyPath = Next(args, ref i, arg);
                    break;
                case "--prompt-file":
                    promptFile = Next(args, ref i, arg);
                    break;
                case "--prompt-base64":
                    promptBase64 = Next(args, ref i, arg);
                    break;
                case "--messages-file":
                    messagesFile = Next(args, ref i, arg);
                    mode = "chat";
                    break;
                case "--messages-base64":
                    messagesBase64 = Next(args, ref i, arg);
                    mode = "chat";
                    break;
                case "--max-bytes":
                    var rawMax = Next(args, ref i, arg);
                    if (!int.TryParse(rawMax, out maxBytes) || maxBytes <= 0)
                    {
                        throw new ArgumentException($"Invalid max-bytes: {rawMax}");
                    }
                    break;
                case "--stop":
                    stopToken = Next(args, ref i, arg);
                    break;
                case "--output":
                    outputPath = Next(args, ref i, arg);
                    break;
                case "--expect-status":
                    var rawExpect = Next(args, ref i, arg);
                    if (!int.TryParse(rawExpect, out expectStatus) || expectStatus <= 0)
                    {
                        throw new ArgumentException($"Invalid expect-status: {rawExpect}");
                    }
                    break;
                case "--exit-on-empty":
                    exitOnEmpty = true;
                    break;
                case "--trace":
                    trace = true;
                    break;
                case "--skip-cert-check":
                    skipCertCheck = true;
                    break;
                case "--proxy":
                    proxy = Next(args, ref i, arg);
                    break;
                case "--header":
                    var rawHeader = Next(args, ref i, arg);
                    var parsedHeader = ParseHeader(rawHeader);
                    headers.Add(parsedHeader);
                    break;
                case "--bearer":
                    bearerToken = Next(args, ref i, arg);
                    break;
                case "--bearer-file":
                    bearerTokenFile = Next(args, ref i, arg);
                    break;
                case "-h":
                case "--help":
                    PrintUsage();
                    Environment.Exit(0);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        if (!string.IsNullOrWhiteSpace(promptFile))
        {
            prompt = File.ReadAllText(promptFile);
        }
        if (!string.IsNullOrWhiteSpace(promptBase64))
        {
            prompt = DecodeBase64(promptBase64);
        }
        if (!string.IsNullOrWhiteSpace(messagesFile))
        {
            messages = LoadMessagesFromFile(messagesFile);
        }
        if (!string.IsNullOrWhiteSpace(messagesBase64))
        {
            messages = LoadMessagesFromBase64(messagesBase64);
        }

        if (!string.IsNullOrWhiteSpace(bearerTokenFile))
        {
            bearerToken = File.ReadAllText(bearerTokenFile).Trim();
        }
        if (!string.IsNullOrWhiteSpace(bearerToken))
        {
            headers.Add(new Header("Authorization", $"Bearer {bearerToken}"));
        }

        return new Options(endpoint, model, prompt, timeoutSec, stream, mode, format, checkModel, retries, retryDelayMs, verbose, saveBodyPath, messages, maxBytes, stopToken, outputPath, expectStatus, exitOnEmpty, trace, skipCertCheck, proxy, headers);
    }

    private static string Next(string[] args, ref int index, string name)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {name}");
        }
        index++;
        return args[index];
    }

    private static Header ParseHeader(string raw)
    {
        var parts = raw.Split(new[] { ':', '=' }, 2, StringSplitOptions.TrimEntries);
        if (parts.Length < 2 || string.IsNullOrWhiteSpace(parts[0]) || string.IsNullOrWhiteSpace(parts[1]))
        {
            throw new ArgumentException($"Invalid header '{raw}', expected key:value");
        }
        return new Header(parts[0], parts[1]);
    }

    private static void PrintUsage()
    {
        Console.WriteLine("OllamaSmokeCli");
        Console.WriteLine("Usage:");
        Console.WriteLine("  OllamaSmokeCli --endpoint <url> --model <name> --prompt <text> [--chat|--embed] [--timeout-sec 30] [--stream] [--format json|text] [--check-model] [--retries N] [--retry-delay-ms 1000] [--verbose] [--save-body <path>] [--prompt-file <path>] [--prompt-base64 <b64>] [--messages-file <path>] [--messages-base64 <b64>] [--max-bytes N] [--stop <token>] [--expect-status N] [--exit-on-empty] [--trace] [--skip-cert-check] [--proxy <url>] [--header k:v] [--bearer <token>|--bearer-file <path>] [--output <path>]");
        Console.WriteLine("Defaults: endpoint http://localhost:11435, model llama3-8b-local, prompt \"Hello smoke\", timeout 30s, mode generate, stream false, format json, retries 0, retry delay 1000ms, verbose off, no max-bytes, no stop token, no expect-status, no trace, cert check enforced, no proxy, no headers.");
    }
}
