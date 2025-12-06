// ModuleIndex: validates IDs and detects normalized ID collisions.
using System.Linq;
using System.Text.RegularExpressions;

namespace SrsApi;

public static class SrsValidation
{
    // IDs follow PREFIX[-SUBPREFIX...]-NNN or PREFIX[-SUBPREFIX...]-NNNX where prefix parts are alphanumeric (e.g., TRW-001, TRW-006C, LOG-001, COMP-005, R-BUILD-ARTIFACTS-001).
    private static readonly Regex IdPattern = new("^[A-Z0-9]+(?:-[A-Z0-9]+)*-\\d{3}[A-Z]?$", RegexOptions.Compiled);

    public static bool IsValidId(string id) => IdPattern.IsMatch(SrsNormalization.NormalizeId(id));

    public static IEnumerable<string> FindCollisions(IEnumerable<ISrsDocument> docs) =>
        docs.GroupBy(d => SrsNormalization.NormalizeId(d.Id))
            .Where(g => g.Count() > 1)
            .Select(g => g.Key);
}
