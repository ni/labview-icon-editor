using System.Reflection;

namespace XCli.Cli;

public static class VersionInfo
{
    public static string Version => Assembly.GetExecutingAssembly()
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0.0.0";
}
