using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Xunit;

namespace XCli.Tests.Analyzers;

/// <summary>
/// Ensures no production source (under src/) directly calls Environment.GetEnvironmentVariable(...),
/// Environment.GetEnvironmentVariables(...), Environment.SetEnvironmentVariable(...),
/// or uses 'using static System.Environment', except inside src/XCli/Util/Env.cs.
/// This enforces the policy that all env access must go through XCli.Util.Env.
/// (FGC-REQ-ENV-001)
/// </summary>
public sealed class NoDirectEnvironmentAccessTests
{
    private static readonly HashSet<string> ForbiddenNames = new(StringComparer.Ordinal)
    {
        "GetEnvironmentVariable",
        "GetEnvironmentVariables",
        "SetEnvironmentVariable",
    };

    [Fact(DisplayName = "FGC-REQ-ENV-001: No direct Environment variable API usage outside Env.cs")]
    public void NoDirectEnvApis_OutsideEnvCs()
    {
        var root = FindRepoRoot();
        var srcDir = Path.Combine(root, "src");
        Assert.True(Directory.Exists(srcDir), $"Source directory not found: {srcDir}");

        var allowed = Normalize(Path.Combine(srcDir, "XCli", "Util", "Env.cs"));
        var violations = new List<string>();

        foreach (var file in Directory.GetFiles(srcDir, "*.cs", SearchOption.AllDirectories))
        {
            var nf = Normalize(file);
            if (string.Equals(nf, allowed, StringComparison.OrdinalIgnoreCase))
                continue; // Env.cs is the only allowed place

            // Skip generated/attributes as needed
            if (nf.EndsWith($"{Path.DirectorySeparatorChar}Properties{Path.DirectorySeparatorChar}InternalsVisibleTo.cs", StringComparison.OrdinalIgnoreCase))
                continue;

            var text = File.ReadAllText(file);
            var tree = CSharpSyntaxTree.ParseText(text);
            var rootNode = (CompilationUnitSyntax)tree.GetRoot();

            // 1) Forbid 'using static System.Environment;'
            var usingStatic = rootNode.Usings
                .Where(u => u.StaticKeyword.IsKind(SyntaxKind.StaticKeyword)
                            && u.Name is NameSyntax n && n.ToString() == "System.Environment")
                .ToList();
            if (usingStatic.Count > 0)
            {
                violations.Add($"{Rel(srcDir, nf)}: using static System.Environment is not allowed");
            }

            // 2) Track alias names for System.Environment (e.g., 'using Env = System.Environment;')
            var envAliases = new HashSet<string>(StringComparer.Ordinal);
            foreach (var u in rootNode.Usings)
            {
                if (u.Alias is { } alias && u.Name is NameSyntax n && n.ToString() == "System.Environment")
                {
                    envAliases.Add(alias.Name.Identifier.Text);
                }
            }

            // 3) Find direct invocations of forbidden Environment methods (or through alias)
            var invocations = rootNode.DescendantNodes().OfType<InvocationExpressionSyntax>();
            foreach (var inv in invocations)
            {
                if (!IsForbiddenEnvironmentCall(inv, envAliases))
                    continue;
                var span = inv.GetLocation().GetLineSpan();
                var line = span.StartLinePosition.Line + 1;
                var name = ((inv.Expression as MemberAccessExpressionSyntax)?.Name
                            ?? inv.Expression as IdentifierNameSyntax)!.Identifier.Text;
                violations.Add($"{Rel(srcDir, nf)}:{line}: direct call to Environment.{name} is not allowed");
            }
        }

        if (violations.Count > 0)
        {
            var msg = "Found forbidden direct environment access:\n" + string.Join("\n", violations);
            Assert.Fail(msg);
        }
    }

    [Theory]
    [InlineData("Environment.SetEnvironmentVariable(\"k\", \"v\");")]
    [InlineData("Environment.GetEnvironmentVariables();")]
    public void ForbiddenCalls_AreDetected(string call)
    {
        var code = $"using System; class T {{ void M() {{ {call} }} }}";
        var tree = CSharpSyntaxTree.ParseText(code);
        var root = (CompilationUnitSyntax)tree.GetRoot();
        var inv = root.DescendantNodes().OfType<InvocationExpressionSyntax>().Single();
        Assert.True(IsForbiddenEnvironmentCall(inv, new HashSet<string>()), $"{call} should be forbidden");
    }

    private static bool IsForbiddenEnvironmentCall(InvocationExpressionSyntax inv, HashSet<string> envAliases)
    {
        // Match: Environment.<ForbiddenNames>(...)
        //        System.Environment.<ForbiddenNames>(...)
        //        <alias>.<ForbiddenNames>(...) where alias == System.Environment
        //        <ForbiddenNames>(...) when file has 'using static System.Environment;'
        if (inv.Expression is MemberAccessExpressionSyntax ma)
        {
            if (!ForbiddenNames.Contains(ma.Name.Identifier.Text)) return false;

            // Walk left side chain; if we encounter Identifier 'Environment', or chain 'System.Environment',
            // or an alias that maps to System.Environment, then it's a violation.
            return LeftChainContainsEnvironment(ma.Expression, envAliases);
        }
        else if (inv.Expression is IdentifierNameSyntax id
                 && ForbiddenNames.Contains(id.Identifier.Text))
        {
            // Unqualified call can only be valid via 'using static System.Environment;'
            // We'll treat this as a violation only if that using-directive exists in the file.
            // (The caller of this method ensures that by separately checking 'using static System.Environment'.)
            return true; // The caller already recorded the 'using static' violation.
        }

        return false;
    }

    private static bool LeftChainContainsEnvironment(ExpressionSyntax expr, HashSet<string> envAliases)
    {
        // Scan expression like:
        //   Environment
        //   System.Environment
        //   AliasToEnvironment
        //   System.Environment.SpecialFolder (will still contain 'Environment' in the chain)
        while (expr is not null)
        {
            switch (expr)
            {
                case IdentifierNameSyntax id:
                    if (id.Identifier.Text == "Environment") return true;
                    if (envAliases.Contains(id.Identifier.Text)) return true;
                    return false;
                case MemberAccessExpressionSyntax ma:
                    if (ma.Name is IdentifierNameSyntax name)
                    {
                        if (name.Identifier.Text == "Environment") return true;
                        if (envAliases.Contains(name.Identifier.Text)) return true;
                    }
                    expr = ma.Expression;
                    break;
                case QualifiedNameSyntax qn:
                    if (qn.Right.Identifier.Text == "Environment") return true;
                    // continue with left side to catch 'System'
                    expr = qn.Left;
                    break;
                default:
                    return false;
            }
        }
        return false;
    }

    private static string FindRepoRoot()
    {
        // Ascend from test bin folder until we see a 'src' directory
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 12 && dir is not null; i++, dir = dir.Parent!)
        {
            if (dir.GetDirectories("src").Any())
                return dir.FullName;
        }
        throw new DirectoryNotFoundException("Could not locate repo root with 'src' directory from test context.");
    }

    private static string Normalize(string path) => Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    private static string Rel(string root, string file) => Path.GetRelativePath(root, file).Replace('\\','/');
}
