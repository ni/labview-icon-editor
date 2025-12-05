using System;
using System.Linq;
using System.Reflection;

namespace IntegrationEngineCli.Security;

/// <summary>
/// Lightweight guard to flag unexpected network dependencies.
/// Use IE_GUARD_DISABLE=1 to bypass.
/// </summary>
public static class IsolationGuard
{
    public static void Enforce(Assembly? assembly = null)
    {
        var bypass = Environment.GetEnvironmentVariable("IE_GUARD_DISABLE");
        if (!string.IsNullOrWhiteSpace(bypass) &&
            (bypass.Equals("1", StringComparison.OrdinalIgnoreCase) ||
             bypass.Equals("true", StringComparison.OrdinalIgnoreCase)))
        {
            return;
        }

        var asm = assembly ?? typeof(IsolationGuard).Assembly;
        var refs = asm.GetReferencedAssemblies();
        var networkPrefixes = new[]
        {
            "System.Net",
            "System.Net.Http",
            "System.Net.Sockets",
            "System.Net.WebSockets"
        };
        if (refs.Any(r => r.Name is { } name &&
                          networkPrefixes.Any(p => name.StartsWith(p, StringComparison.OrdinalIgnoreCase))))
        {
            throw new InvalidOperationException("Network assemblies referenced in IntegrationEngineCli.");
        }
    }
}
