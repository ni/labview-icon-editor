// SPDX-License-Identifier: MIT
// ModuleIndex: centralized helpers for reading environment variables.
// Hardened environment access helpers for x-cli
#nullable enable
using System.Collections;
using System.Globalization;
using System.IO;
using System.Linq;

namespace XCli.Util;

/// <summary>
/// Centralized, null-safe helpers for reading environment variables used by x-cli.
/// This change eliminates nullable warnings without altering runtime behavior.
/// (FGC-REQ-ENV-001)
/// </summary>
internal static class Env
{
    private static Lazy<Dictionary<string, string>> _cache = new(BuildCache);
    internal static int CacheBuilds { get; private set; }

    private static Dictionary<string, string> Vars => _cache.Value;

    private static Dictionary<string, string> BuildCache()
    {
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (DictionaryEntry e in Environment.GetEnvironmentVariables(EnvironmentVariableTarget.Process))
        {
            if (e.Key is string k)
                dict[k] = e.Value as string ?? string.Empty;
        }
        CacheBuilds++;
        return dict;
    }

    internal static void ResetCacheForTests()
    {
        _cache = new(BuildCache);
        CacheBuilds = 0;
    }

    /// <summary>
    /// Rebuilds the cached environment variable dictionary so that
    /// subsequent lookups reflect any in-process changes.
    /// </summary>
    public static void Refresh()
    {
        _cache = new(BuildCache);
        _ = _cache.Value; // force cache rebuild immediately
    }

    /// <summary>
    /// Returns the raw environment variable value (or null if not present).
    /// Performs a case-insensitive search of process-level variables to provide
    /// consistent behavior across platforms.
    /// </summary>
    public static string? Get(string name)
    {
        return Vars.TryGetValue(name, out var v) ? v : null;
    }

    /// <summary>
    /// Returns the environment variable value, or the provided default when missing.
    /// </summary>
    public static string GetStringOrDefault(string name, string @default = "") =>
        Get(name) ?? @default;

    /// <summary>
    /// Parses a boolean environment variable. Accepts only "True"/"False" (case-insensitive).
    /// Returns <paramref name="default"/> when missing or invalid.
    /// </summary>
    public static bool GetBool(string name, bool @default = false)
    {
        var raw = Get(name);
        return bool.TryParse(raw, out var v) ? v : @default;
    }

    /// <summary>
    /// Parses an integer environment variable using InvariantCulture.
    /// Returns <paramref name="default"/> when missing or invalid.
    /// </summary>
    public static int GetInt(string name, int @default = 0)
    {
        var raw = Get(name);
        return int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : @default;
    }

    /// <summary>
    /// Returns the invocation name of the current process.
    /// Uses argv[0] instead of <see cref="Environment.ProcessPath"/> so that
    /// symlinked executions report the link name rather than the target.
    /// </summary>
    public static string GetProcessName()
    {
        // On Unix-like systems, Environment.GetCommandLineArgs()[0] returns the
        // managed entrypoint (Foo.dll) rather than the executable name. The
        // original argv[0] (which preserves symlink names) is available via
        // /proc/self/cmdline.
        try
        {
            if (OperatingSystem.IsLinux())
            {
                var raw = File.ReadAllBytes("/proc/self/cmdline");
                var idx = Array.IndexOf(raw, (byte)0);
                if (idx > 0)
                {
                    var path = System.Text.Encoding.UTF8.GetString(raw, 0, idx);
                    return Path.GetFileName(path);
                }
            }
        }
        catch
        {
            // Ignore and fall back to Environment.GetCommandLineArgs().
        }

        var argv0 = Environment.GetCommandLineArgs();
        if (argv0.Length > 0)
            return Path.GetFileName(argv0[0]) ?? string.Empty;
        return string.Empty;
    }

    /// <summary>
    /// Returns a dictionary of environment variables that start with
    /// the specified prefix (default "XCLI_") using a case-insensitive prefix
    /// match, preserving the original casing of each key. Null values are
    /// normalized to "".
    /// </summary>
    public static IReadOnlyDictionary<string, string> GetWithPrefix(string prefix = "XCLI_")
    {
        return Vars
            .Where(kv => kv.Key.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            .OrderBy(kv => kv.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.Ordinal);
    }
}
#nullable restore

