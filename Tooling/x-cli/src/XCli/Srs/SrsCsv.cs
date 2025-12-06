using CsvHelper;
using CsvHelper.Configuration;
using System.Globalization;

namespace XCli.Srs;

public static class SrsCsv
{
    public static IReadOnlyList<Requirement> Import(string csvPath)
    {
        if (!File.Exists(csvPath))
            throw new FileNotFoundException($"csv not found: {csvPath}");

        using var reader = new StreamReader(csvPath);
        using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = true,
            IgnoreBlankLines = true,
            TrimOptions = TrimOptions.Trim,
        });

        // Read the header once so named lookups work for subsequent rows.
        if (!csv.Read())
            return new List<Requirement>();
        csv.ReadHeader();

        var records = new List<Requirement>();
        while (csv.Read())
        {
            var req = new Requirement
            {
                Id = csv.GetField("ID") ?? string.Empty,
                Section = csv.GetField("Section") ?? string.Empty,
                Text = csv.GetField("Requirement Statement") ?? string.Empty,
                Type = csv.GetField("Type") ?? string.Empty,
                Priority = csv.GetField("Priority") ?? string.Empty,
                Verification = new Verification
                {
                    Methods = Split(csv.GetField("Verification Methods (from SRS)")),
                    Primary = csv.GetField("Primary Method (select)") ?? string.Empty,
                    Detail = csv.GetField("Verification Detail"),
                    Level = csv.GetField("Verification Level")
                },
                Acceptance = csv.GetField("Acceptance Criteria") ?? string.Empty,
                Owner = csv.GetField("Owner/Role"),
                Phase = csv.GetField("Phase/Gate"),
                Status = csv.GetField("Status"),
                Evidence = Split(csv.GetField("Evidence to Collect")),
                Notes = csv.GetField("Notes"),
                Rationale = csv.GetField("Rationale"),
                Risk = csv.GetField("Risk"),
                Constraints = Split(csv.GetField("Constraints")),
                Version = csv.GetField("Version & Change Notes"),
                AcceptanceCriteria = csv.GetField("Acceptance Criteria"),
                VerificationDetail = csv.GetField("Verification Detail"),
                VerificationLevel = csv.GetField("Verification Level"),
                Trace = new Trace
                {
                    Upstream = Split(csv.GetField("Upstream Trace")),
                    Downstream = Split(csv.GetField("Downstream Trace"))
                }
            };
            records.Add(req);
        }
        return records;
    }

    public static void Export(string csvPath, IReadOnlyList<Requirement> requirements)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(csvPath) ?? ".");
        using var writer = new StreamWriter(csvPath);
        using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = true
        });

        WriteHeader(csv);
        foreach (var r in requirements)
        {
            csv.WriteField(r.Id);
            csv.WriteField(r.Section);
            csv.WriteField(r.Text);
            csv.WriteField(r.Type);
            csv.WriteField(r.Priority);
            csv.WriteField(string.Join(", ", r.Verification.Methods));
            csv.WriteField(r.Verification.Primary);
            csv.WriteField(r.Acceptance);
            csv.WriteField(r.Trace?.Upstream is { } u ? string.Join("; ", u) : string.Empty);
            csv.WriteField(r.Trace?.Downstream is { } d ? string.Join("; ", d) : string.Empty);
            csv.WriteField(r.Notes ?? string.Empty);
            csv.WriteField(r.Rationale ?? string.Empty);
            csv.WriteField(r.Risk ?? string.Empty);
            csv.WriteField(r.Evidence is { } ev ? string.Join("; ", ev) : string.Empty);
            csv.WriteField(r.Owner ?? string.Empty);
            csv.WriteField(r.Phase ?? string.Empty);
            csv.WriteField(r.Status ?? string.Empty);
            csv.WriteField(r.Constraints is { } c ? string.Join("; ", c) : string.Empty);
            csv.WriteField(r.Version ?? string.Empty);
            csv.WriteField(r.VerificationDetail ?? string.Empty);
            csv.WriteField(r.VerificationLevel ?? string.Empty);
            csv.NextRecord();
        }
    }

    private static void WriteHeader(CsvWriter csv)
    {
        csv.WriteField("ID");
        csv.WriteField("Section");
        csv.WriteField("Requirement Statement");
        csv.WriteField("Type");
        csv.WriteField("Priority");
        csv.WriteField("Verification Methods (from SRS)");
        csv.WriteField("Primary Method (select)");
        csv.WriteField("Acceptance Criteria");
        csv.WriteField("Upstream Trace");
        csv.WriteField("Downstream Trace");
        csv.WriteField("Notes");
        csv.WriteField("Rationale");
        csv.WriteField("Risk");
        csv.WriteField("Evidence to Collect");
        csv.WriteField("Owner/Role");
        csv.WriteField("Phase/Gate");
        csv.WriteField("Status");
        csv.WriteField("Constraints");
        csv.WriteField("Version & Change Notes");
        csv.WriteField("Verification Detail");
        csv.WriteField("Verification Level");
        csv.NextRecord();
    }

    private static List<string> Split(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return new List<string>();
        return value
            .Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim())
            .Where(s => s.Length > 0)
            .ToList();
    }
}
