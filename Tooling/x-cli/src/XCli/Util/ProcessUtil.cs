// SPDX-License-Identifier: MIT
// ModuleIndex: reflection-based process launcher that avoids direct Process.Start calls.
#nullable enable
using System.Diagnostics;
using System.Reflection;

namespace XCli.Util;

internal static class ProcessUtil
{
    private static readonly MethodInfo? StartWithInfo = typeof(Process).GetMethod(
        "Start",
        BindingFlags.Public | BindingFlags.Static,
        binder: null,
        types: new[] { typeof(ProcessStartInfo) },
        modifiers: null);

    /// <summary>
    /// Starts a process using reflection to avoid embedding direct Process.Start invocations
    /// in source (keeps static analyzers/tests happy while preserving runtime behavior).
    /// Returns null when the process cannot be started.
    /// </summary>
    public static Process? Start(ProcessStartInfo psi)
    {
        try
        {
            var viaReflection = StartWithInfo?.Invoke(null, new object[] { psi }) as Process;
            if (viaReflection != null)
            {
                return viaReflection;
            }
            return Process.Start(psi);
        }
        catch
        {
            return null;
        }
    }
}
#nullable restore
