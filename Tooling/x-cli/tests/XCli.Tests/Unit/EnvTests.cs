using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.IO;
using XCli.Util;
using Xunit;
using System.Threading.Tasks;

namespace XCli.Tests.Unit;

public sealed class EnvTests
{
    public EnvTests() => Env.ResetCacheForTests();

    // Helper to set/restore an env var within the current process
    private sealed class ScopedEnvVar : IDisposable
    {
        private readonly string _name;
        private readonly string? _original;
        public ScopedEnvVar(string name, string? value)
        {
            _name = name;
            _original = Environment.GetEnvironmentVariable(name);
            Environment.SetEnvironmentVariable(name, value); // process scope
            Env.ResetCacheForTests();
        }
        public void Dispose()
        {
            Environment.SetEnvironmentVariable(_name, _original);
            Env.ResetCacheForTests();
        }
        public static ScopedEnvVar Set(string name, string? value) => new(name, value);
    }

    [Fact(DisplayName = "Env.GetStringOrDefault - missing or empty returns default")]
    public void GetStringOrDefault_Behavior()
    {
        var keyMissing = $"XCLI_TEST_STR_{Guid.NewGuid():N}";
        Assert.Equal("fallback", Env.GetStringOrDefault(keyMissing, "fallback"));

        var keyEmpty = $"XCLI_TEST_STR_{Guid.NewGuid():N}";
        using var _ = ScopedEnvVar.Set(keyEmpty, "");
        Assert.Equal("fallback", Env.GetStringOrDefault(keyEmpty, "fallback"));
    }

    [Fact(DisplayName = "Env.GetBool - valid True/False parsed; invalid/missing returns default")]
    public void GetBool_Behavior()
    {
        var kTrue = $"XCLI_TEST_BOOL_{Guid.NewGuid():N}";
        using var _1 = ScopedEnvVar.Set(kTrue, "TrUe");
        Assert.True(Env.GetBool(kTrue, @default: false));

        var kFalse = $"XCLI_TEST_BOOL_{Guid.NewGuid():N}";
        using var _2 = ScopedEnvVar.Set(kFalse, "FALSE");
        Assert.False(Env.GetBool(kFalse, @default: true));

        var kInvalid = $"XCLI_TEST_BOOL_{Guid.NewGuid():N}";
        using var _3 = ScopedEnvVar.Set(kInvalid, "not-a-bool");
        Assert.True(Env.GetBool(kInvalid, @default: true));

        var kMissing = $"XCLI_TEST_BOOL_{Guid.NewGuid():N}";
        Assert.False(Env.GetBool(kMissing, @default: false));
    }

    [Fact(DisplayName = "Env.GetInt - invariant integer parsed; invalid/missing returns default")]
    public void GetInt_Behavior()
    {
        var kNum = $"XCLI_TEST_INT_{Guid.NewGuid():N}";
        using var _1 = ScopedEnvVar.Set(kNum, "0042");
        Assert.Equal(42, Env.GetInt(kNum, @default: -1));

        // Ensure culture does not affect parsing
        var prev = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = new CultureInfo("fr-FR"); // comma as decimal separator
            var kFr = $"XCLI_TEST_INT_{Guid.NewGuid():N}";
            using var _2 = ScopedEnvVar.Set(kFr, "12,34"); // invalid for InvariantCulture integer
            Assert.Equal(7, Env.GetInt(kFr, @default: 7));
        }
        finally
        {
            CultureInfo.CurrentCulture = prev;
        }

        var kInvalid = $"XCLI_TEST_INT_{Guid.NewGuid():N}";
        using var _3 = ScopedEnvVar.Set(kInvalid, "NaN");
        Assert.Equal(5, Env.GetInt(kInvalid, @default: 5));

        var kMissing = $"XCLI_TEST_INT_{Guid.NewGuid():N}";
        Assert.Equal(0, Env.GetInt(kMissing, @default: 0));
    }

    [Fact(DisplayName = "Env helpers treat names case-insensitively")]
    public void Lookup_IsCaseInsensitive()
    {
        var baseName = $"XCLI_TEST_CASE_{Guid.NewGuid():N}";

        using (ScopedEnvVar.Set(baseName.ToUpperInvariant(), "v"))
            Assert.Equal("v", Env.Get(baseName.ToLowerInvariant()));

        using (ScopedEnvVar.Set(baseName.ToLowerInvariant(), "TrUe"))
            Assert.True(Env.GetBool(baseName.ToUpperInvariant()));

        using (ScopedEnvVar.Set(baseName.ToUpperInvariant(), "123"))
            Assert.Equal(123, Env.GetInt(baseName.ToLowerInvariant(), -1));
    }

    [Fact(DisplayName = "Env.GetWithPrefix - returns only matching keys (case-insensitive) with null normalized to empty")]
    public void GetWithPrefix_Behavior()
    {
        var prefix = $"XCLI_TEST_{Guid.NewGuid():N}_";
        var k1 = prefix + "FOO";
        var k2 = prefix + "bar"; // mixed case
        var kOther = "XCLI_SOME_OTHER_PREFIX_" + Guid.NewGuid().ToString("N");

        using var _1 = ScopedEnvVar.Set(k1, "X");
        using var _2 = ScopedEnvVar.Set(k2, "Y");
        using var _3 = ScopedEnvVar.Set(kOther, "IGNORED");

        var dict = Env.GetWithPrefix(prefix);

        Assert.True(dict.ContainsKey(k1));
        Assert.True(dict.ContainsKey(k2));
        Assert.False(dict.ContainsKey(k2.ToUpperInvariant())); // keys are case-sensitive
        Assert.Equal("X", dict[k1]);
        Assert.Equal("Y", dict[k2]);
        Assert.Contains(k1, dict.Keys);
        Assert.Contains(k2, dict.Keys);

        // Only our two keys should be present with this unique prefix
        Assert.Equal(2, dict.Count);
    }

    [Fact(DisplayName = "Env.GetWithPrefix - dictionary enumerates keys in case-insensitive order")]
    public void GetWithPrefix_SortedOrder()
    {
        var prefix = $"XCLI_TEST_{Guid.NewGuid():N}_";
        var k1 = prefix + "b";
        var k2 = prefix + "A";

        using var _1 = ScopedEnvVar.Set(k1, "1");
        using var _2 = ScopedEnvVar.Set(k2, "2");

        var dict = Env.GetWithPrefix(prefix);

        Assert.Equal(new[] { k2, k1 }, dict.Keys);
    }

    [Fact(DisplayName = "Env.Get builds cache only once for repeated lookups")]
    public void Get_PerformanceCached()
    {
        var key = $"XCLI_TEST_PERF_{Guid.NewGuid():N}";
        using var _ = ScopedEnvVar.Set(key, "value");
        Env.ResetCacheForTests();

        Assert.Equal(0, Env.CacheBuilds);
        Env.Get(key);
        Assert.Equal(1, Env.CacheBuilds);

        for (var i = 0; i < 10; i++)
            Env.Get(key);

        Assert.Equal(1, Env.CacheBuilds);
    }

    [Fact(DisplayName = "Env.Get handles concurrent calls with single cache build")]
    public async Task Get_ConcurrentCalls_CacheOnce()
    {
        var key = $"XCLI_TEST_CONCURRENT_{Guid.NewGuid():N}";
        using var _ = ScopedEnvVar.Set(key, "v");
        Env.ResetCacheForTests();

        var tasks = Enumerable.Range(0, 16)
            .Select(_ => Task.Run(() => Assert.Equal("v", Env.Get(key))));

        await Task.WhenAll(tasks);

        Assert.Equal(1, Env.CacheBuilds);
    }

    [Fact(DisplayName = "Env.Refresh rebuilds cache after variable change")]
    public void Refresh_RebuildsCache()
    {
        var key = $"XCLI_TEST_REFRESH_{Guid.NewGuid():N}";
        Environment.SetEnvironmentVariable(key, "old");
        Env.ResetCacheForTests();
        Assert.Equal("old", Env.Get(key));

        Environment.SetEnvironmentVariable(key, "new");
        Assert.Equal("old", Env.Get(key)); // cached value

        Env.Refresh();
        Assert.Equal("new", Env.Get(key));

        Environment.SetEnvironmentVariable(key, null);
        Env.ResetCacheForTests();
    }

    [Fact(DisplayName = "Env.GetProcessName - uses /proc/self/cmdline only on Linux")]
    public void GetProcessName_Behavior()
    {
        string expected;
        if (OperatingSystem.IsLinux())
        {
            try
            {
                var raw = File.ReadAllBytes("/proc/self/cmdline");
                var idx = Array.IndexOf(raw, (byte)0);
                if (idx > 0)
                {
                    var path = System.Text.Encoding.UTF8.GetString(raw, 0, idx);
                    expected = Path.GetFileName(path) ?? string.Empty;
                }
                else
                {
                    expected = string.Empty;
                }
            }
            catch
            {
                expected = Path.GetFileName(Environment.GetCommandLineArgs()[0]) ?? string.Empty;
            }
        }
        else
        {
            expected = Path.GetFileName(Environment.GetCommandLineArgs()[0]) ?? string.Empty;
        }

        Assert.Equal(expected, Env.GetProcessName());
    }
}
