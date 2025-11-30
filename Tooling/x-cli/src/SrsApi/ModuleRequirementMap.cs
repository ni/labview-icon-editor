// ModuleIndex: loads `docs/module-srs-map.yaml` and resolves requirement IDs for module path prefixes.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace SrsApi;

public class ModuleRequirementMap
{
    private readonly Dictionary<string, string[]> _map;

    public ModuleRequirementMap(string yamlPath)
    {
        _map = Load(yamlPath);
    }

    private static Dictionary<string, string[]> Load(string path)
    {
        var dict = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        if (!File.Exists(path))
            return new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        string? current = null;
        foreach (var line in File.ReadLines(path))
        {
            if (string.IsNullOrWhiteSpace(line))
                continue;
            var trimmed = line.Trim();
            if (trimmed.StartsWith("#"))
                continue;
            if (!char.IsWhiteSpace(line[0]) && trimmed.EndsWith(":"))
            {
                current = trimmed.TrimEnd(':');
                if (!current.EndsWith('/'))
                    current += '/';
                dict[current] = new List<string>();
            }
            else if (line.StartsWith("  - ") && current is not null)
            {
                var id = SrsNormalization.NormalizeId(trimmed.Substring(2).Trim());
                if (!SrsValidation.IsValidId(id))
                    throw new InvalidDataException($"Module requirement map '{path}' contains invalid requirement ID '{id}'.");
                dict[current].Add(id);
            }
        }

        return dict.ToDictionary(kvp => kvp.Key, kvp => kvp.Value.Distinct().ToArray(), StringComparer.OrdinalIgnoreCase);
    }

    public IReadOnlyCollection<string> GetRequirementsForModule(string path)
    {
        var normalized = path.Replace('\\', '/');
        var result = new HashSet<string>();
        foreach (var (prefix, ids) in _map)
        {
            if (normalized.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                foreach (var id in ids)
                    result.Add(id);
        }
        return result.ToArray();
    }
}
