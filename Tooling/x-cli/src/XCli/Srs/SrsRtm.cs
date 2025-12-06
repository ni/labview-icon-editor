using System.Text;

namespace XCli.Srs;

public static class SrsRtm
{
    public static void WriteMarkdown(string path, IReadOnlyList<Requirement> requirements)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        var sb = new StringBuilder();
        sb.AppendLine("# Requirements Traceability Matrix (pilot)");
        sb.AppendLine();
        sb.AppendLine("| ID | Section | Text | Priority | Verification (primary) | Downstream |");
        sb.AppendLine("| --- | --- | --- | --- | --- | --- |");
        foreach (var r in requirements)
        {
            var downstream = r.Trace?.Downstream is { } d && d.Any() ? string.Join("<br>", d) : "";
            var text = r.Text.Replace("|", "\\|");
            var verification = $"{r.Verification.Primary} ({string.Join(", ", r.Verification.Methods)})";
            sb.AppendLine($"| {r.Id} | {r.Section} | {text} | {r.Priority} | {verification} | {downstream} |");
        }
        File.WriteAllText(path, sb.ToString());
    }
}
