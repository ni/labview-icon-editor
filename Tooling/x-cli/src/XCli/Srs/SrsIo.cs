using System.Text.Json;
using System.Text.Json.Nodes;
using Json.Schema;
using SrsApi;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace XCli.Srs;

public static class SrsIo
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    public static IReadOnlyList<Requirement> LoadRequirements(string path)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException($"requirements file not found: {path}");

        var ext = Path.GetExtension(path).ToLowerInvariant();
        if (ext is ".yaml" or ".yml")
        {
            var yaml = File.ReadAllText(path);
            var deserializer = new DeserializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .IgnoreUnmatchedProperties()
                .Build();
            var list = deserializer.Deserialize<List<Requirement>>(yaml) ?? new();
            return list;
        }

        var jsonText = File.ReadAllText(path);
        var reqs = JsonSerializer.Deserialize<List<Requirement>>(jsonText, JsonOptions) ?? new();
        return reqs;
    }

    public static void SaveRequirementsAsYaml(string path, IReadOnlyList<Requirement> requirements)
    {
        var serializer = new SerializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .ConfigureDefaultValuesHandling(DefaultValuesHandling.OmitNull)
            .Build();
        var yaml = serializer.Serialize(requirements);
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        File.WriteAllText(path, yaml);
    }

    public static void SaveRequirementsAsJson(string path, IReadOnlyList<Requirement> requirements)
    {
        var json = JsonSerializer.Serialize(requirements, JsonOptions);
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        File.WriteAllText(path, json);
    }

    public static ValidationResult ValidateAgainstSchema(string schemaPath, IReadOnlyList<Requirement> requirements)
    {
        if (!File.Exists(schemaPath))
            throw new FileNotFoundException($"schema file not found: {schemaPath}");

        var schemaText = File.ReadAllText(schemaPath);
        var schema = JsonSchema.FromText(schemaText);
        var jsonNode = JsonSerializer.SerializeToNode(requirements, JsonOptions) ?? new JsonArray();
        var result = schema.Evaluate(jsonNode);
        var detailsProperty = result.GetType().GetProperty("Details");
        var details = detailsProperty?.GetValue(result);
        var report = details is not null
            ? JsonSerializer.Serialize(details, JsonOptions)
            : JsonSerializer.Serialize(result, JsonOptions);
        return new ValidationResult(result.IsValid, report);
    }

    public static void ValidateIdsAndCollisions(IEnumerable<Requirement> requirements)
    {
        var missingFields = new List<string>();
        foreach (var r in requirements)
        {
            if (string.IsNullOrWhiteSpace(r.Id))
                missingFields.Add("id");
            if (string.IsNullOrWhiteSpace(r.Text))
                missingFields.Add("text");
            if (!SrsValidation.IsValidId(r.Id))
                throw new InvalidDataException($"Invalid requirement id '{r.Id}'");
            if (r.Verification.Methods == null || !r.Verification.Methods.Any())
                throw new InvalidDataException($"Requirement '{r.Id}' is missing verification.methods");
            if (string.IsNullOrWhiteSpace(r.Verification.Primary))
                throw new InvalidDataException($"Requirement '{r.Id}' is missing verification.primary");
            if (string.IsNullOrWhiteSpace(r.Acceptance))
                throw new InvalidDataException($"Requirement '{r.Id}' is missing acceptance criteria");
        }

        var collisions = SrsValidation.FindCollisions(requirements.Select(r => new SrsDocument(r.Id, r.Version ?? string.Empty, string.Empty)));
        if (collisions.Any())
            throw new InvalidDataException($"Duplicate normalized requirement IDs: {string.Join(", ", collisions)}");
    }
}

public record ValidationResult(bool IsValid, string Report);
