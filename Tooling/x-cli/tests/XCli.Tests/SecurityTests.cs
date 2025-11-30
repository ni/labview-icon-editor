using System;
using System.IO;
using System.Linq;
using System.Reflection;
using XCli.Security;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Xunit;

public class SecurityTests
{
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));

    [Fact]
    public void NoSystemNetReferencesAndNoProcessStartCalls()
    {
        var configuration = new DirectoryInfo(AppContext.BaseDirectory).Parent!.Name;
        var buildRoot = Path.Combine(ProjectDir, "bin", configuration, "net8.0");
        var ridDir = Directory.GetDirectories(buildRoot).First();
        var dllPath = Path.Combine(ridDir, "XCli.dll");
        var asm = Assembly.LoadFile(dllPath);
        var refs = asm.GetReferencedAssemblies();
        Assert.DoesNotContain(refs, r => r.Name != null && r.Name.StartsWith("System.Net", StringComparison.OrdinalIgnoreCase));
        var srcFiles = Directory.GetFiles(ProjectDir, "*.cs", SearchOption.AllDirectories);
        foreach (var file in srcFiles)
            Assert.DoesNotContain("Process.Start(", File.ReadAllText(file));
    }

    [Fact]
    public void IsolationGuardDoesNotThrowWhenNoForbiddenReferences()
    {
        var ex = Record.Exception(() => IsolationGuard.Enforce());
        Assert.Null(ex);
    }

    [Fact]
    public void IsolationGuardThrowsWhenSystemNetHttpReferenced()
    {
        const string source = @"
using System.Net.Http;

namespace Temp;
public static class UsesHttp
{
    public static void Run() { using var _ = new HttpClient(); }
}
";

        var syntaxTree = CSharpSyntaxTree.ParseText(source);
        var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!).Split(Path.PathSeparator)
            .Select(p => MetadataReference.CreateFromFile(p));
        var compilation = CSharpCompilation.Create(
            "TempAssemblyNet",
            new[] { syntaxTree },
            references,
            new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

        using var ms = new MemoryStream();
        var result = compilation.Emit(ms);
        Assert.True(result.Success, string.Join(Environment.NewLine, result.Diagnostics));
        ms.Position = 0;
        var asm = Assembly.Load(ms.ToArray());
        Assert.Contains("System.Net.Http", asm.GetReferencedAssemblies().Select(r => r.Name));
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardThrowsWhenSystemNetSocketsReferenced()
    {
        const string source = @"
using System.Net.Sockets;

namespace Temp;
public static class UsesSockets
{
    public static void Run() { using var _ = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp); }
}
";

        var syntaxTree = CSharpSyntaxTree.ParseText(source);
        var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!).Split(Path.PathSeparator)
            .Select(p => MetadataReference.CreateFromFile(p));
        var compilation = CSharpCompilation.Create(
            "TempAssemblySockets",
            new[] { syntaxTree },
            references,
            new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

        using var ms = new MemoryStream();
        var result = compilation.Emit(ms);
        Assert.True(result.Success, string.Join(Environment.NewLine, result.Diagnostics));
        ms.Position = 0;
        var asm = Assembly.Load(ms.ToArray());
        Assert.Contains("System.Net.Sockets", asm.GetReferencedAssemblies().Select(r => r.Name));
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardThrowsWhenSystemNetWebSocketsReferenced()
    {
        const string source = @"
using System.Net.WebSockets;

namespace Temp;
public static class UsesWebSockets
{
    public static void Run() { using var _ = new ClientWebSocket(); }
}
";

        var syntaxTree = CSharpSyntaxTree.ParseText(source);
        var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!).Split(Path.PathSeparator)
            .Select(p => MetadataReference.CreateFromFile(p));
        var compilation = CSharpCompilation.Create(
            "TempAssemblyWebSockets",
            new[] { syntaxTree },
            references,
            new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

        using var ms = new MemoryStream();
        var result = compilation.Emit(ms);
        Assert.True(result.Success, string.Join(Environment.NewLine, result.Diagnostics));
        ms.Position = 0;
        var asm = Assembly.Load(ms.ToArray());
        Assert.Contains(asm.GetReferencedAssemblies().Select(r => r.Name),
            n => n != null && n.StartsWith("System.Net.WebSockets", StringComparison.Ordinal));
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardThrowsWhenMixedCaseNetworkAssemblyReferenced()
    {
        var asm = new StubAssembly("SyStEm.NeT.Http");
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardThrowsWhenProcessStartReferenced()
    {
        const string source = @"
using System.Diagnostics;

namespace Temp;
public static class UsesProcess
{
    public static void Run() { Process.Start(""echo"", ""hi""); }
}
";

        var syntaxTree = CSharpSyntaxTree.ParseText(source);
        var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!).Split(Path.PathSeparator)
            .Select(p => MetadataReference.CreateFromFile(p));
        var compilation = CSharpCompilation.Create(
            "TempAssemblyProcess",
            new[] { syntaxTree },
            references,
            new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

        using var ms = new MemoryStream();
        var result = compilation.Emit(ms);
        Assert.True(result.Success, string.Join(Environment.NewLine, result.Diagnostics));
        ms.Position = 0;
        var asm = Assembly.Load(ms.ToArray());
        Assert.Contains("System.Diagnostics.Process", asm.GetReferencedAssemblies().Select(r => r.Name));
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardThrowsWhenProcessStartInConstructor()
    {
        const string source = @"
using System.Diagnostics;

namespace Temp;
public class UsesProcess
{
    public UsesProcess() { Process.Start(""echo"", ""hi""); }
}
";

        var syntaxTree = CSharpSyntaxTree.ParseText(source);
        var references = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!).Split(Path.PathSeparator)
            .Select(p => MetadataReference.CreateFromFile(p));
        var compilation = CSharpCompilation.Create(
            "TempAssemblyCtor",
            new[] { syntaxTree },
            references,
            new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary));

        using var ms = new MemoryStream();
        var result = compilation.Emit(ms);
        Assert.True(result.Success, string.Join(Environment.NewLine, result.Diagnostics));
        ms.Position = 0;
        var asm = Assembly.Load(ms.ToArray());
        Assert.Contains("System.Diagnostics.Process", asm.GetReferencedAssemblies().Select(r => r.Name));
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    [Fact]
    public void IsolationGuardScansLoadedTypesWhenTypeLoadFails()
    {
        var asm = new PartialLoadAssembly(new[] { typeof(UsesProcessStart), null });
        Assert.Throws<InvalidOperationException>(() => IsolationGuard.Enforce(asm));
    }

    private sealed class StubAssembly : Assembly
    {
        private readonly AssemblyName[] _refs;
        public StubAssembly(string name) => _refs = new[] { new AssemblyName(name) };
        public override AssemblyName[] GetReferencedAssemblies() => _refs;
        public override Type[] GetTypes() => Array.Empty<Type>();
    }

    private sealed class PartialLoadAssembly : Assembly
    {
        private readonly Type?[] _types;
        public PartialLoadAssembly(Type?[] types) => _types = types;
        public override AssemblyName[] GetReferencedAssemblies() => Array.Empty<AssemblyName>();
        public override Type[] GetTypes() => throw new ReflectionTypeLoadException(_types, new Exception[_types.Length]);
    }

    public class UsesProcessStart
    {
        public static void Run() => System.Diagnostics.Process.Start("echo", "hi");
    }
}
