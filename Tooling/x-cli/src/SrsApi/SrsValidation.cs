// ModuleIndex: validates IDs and detects normalized ID collisions.
using System.Linq;
using System.Text.RegularExpressions;

namespace SrsApi;

public static class SrsValidation
{
    // Allow TEST-REQ-* IDs in tests; production IDs use FGC-REQ-*.
    private static readonly Regex IdPattern = new("^(?:FGC|TEST)-REQ-[A-Z-]+-\\d{3}$", RegexOptions.Compiled);

    public static bool IsValidId(string id) => IdPattern.IsMatch(SrsNormalization.NormalizeId(id));

    public static IEnumerable<string> FindCollisions(IEnumerable<ISrsDocument> docs) =>
        docs.GroupBy(d => SrsNormalization.NormalizeId(d.Id))
            .Where(g => g.Count() > 1)
            .Select(g => g.Key);
}
