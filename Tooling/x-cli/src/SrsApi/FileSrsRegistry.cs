// ModuleIndex: file-backed registry scanning `docs/srs/*.md`, normalizes IDs, parses Version, detects duplicates/missing IDs.
using System.Text.RegularExpressions;
using System.IO;

namespace SrsApi;

public class FileSrsRegistry : ISrsRegistry
{
    private readonly string _root;
    private readonly Dictionary<string, ISrsDocument> _docs = new();

    public FileSrsRegistry(string root)
    {
        _root = root;
        Reload();
    }

    public IReadOnlyCollection<ISrsDocument> Documents => _docs.Values;

    public ISrsDocument? Get(string id)
    {
        var norm = SrsNormalization.NormalizeId(id);
        return _docs.TryGetValue(norm, out var doc) ? doc : null;
    }

    public void Reload()
    {
        _docs.Clear();
        if (!Directory.Exists(_root)) return;
        foreach (var file in Directory.EnumerateFiles(_root, "*.md"))
        {
            var id = ExtractId(file);
            if (id is null)
            {
                var fileName = Path.GetFileNameWithoutExtension(file);
                if (fileName.StartsWith("FGC-REQ-", StringComparison.OrdinalIgnoreCase) ||
                    fileName.StartsWith("TEST-REQ-", StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException($"SRS document '{file}' is missing a valid requirement ID.");
                continue;
            }
            var version = ParseVersion(file);
            if (version is null)
                throw new InvalidDataException($"SRS document '{file}' is missing a Version line.");
            if (_docs.ContainsKey(id))
                throw new InvalidDataException($"Duplicate SRS document ID '{id}' found in '{file}' and '{_docs[id].Path}'.");
            _docs[id] = new SrsDocument(id, version, file);
        }
    }

    private static string? ParseVersion(string path)
    {
        foreach (var line in File.ReadLines(path))
        {
            var match = Regex.Match(line, @"^Version:\s*(.+)$");
            if (match.Success)
                return match.Groups[1].Value.Trim();
        }
        return null;
    }

    private static string? ExtractId(string path)
    {
        var fileName = Path.GetFileNameWithoutExtension(path);
        var id = SrsNormalization.NormalizeId(fileName);
        if (SrsValidation.IsValidId(id))
            return id;

        if (!(fileName.StartsWith("FGC-REQ-", StringComparison.OrdinalIgnoreCase) ||
              fileName.StartsWith("TEST-REQ-", StringComparison.OrdinalIgnoreCase)))
            return null;

        foreach (var line in File.ReadLines(path))
        {
            var match = Regex.Match(line, @"(?:FGC|TEST)-REQ-[A-Z-]+-\d{3}");
            if (match.Success)
            {
                var candidate = SrsNormalization.NormalizeId(match.Value);
                if (SrsValidation.IsValidId(candidate))
                    return candidate;
            }
        }

        return null;
    }
}
