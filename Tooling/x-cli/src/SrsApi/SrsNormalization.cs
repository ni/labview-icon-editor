// ModuleIndex: normalizes requirement IDs (hyphen variants, case).
using System.Linq;

namespace SrsApi;

public static class SrsNormalization
{
    public static string NormalizeId(string id)
    {
        var normalized = id
            .Replace('\u2010', '-')
            .Replace('\u2011', '-')
            .Replace('\u2012', '-')
            .Replace('\u2013', '-')
            .Replace('\u2014', '-');

        return string.Join('-', normalized
            .Split('-', System.StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.ToUpperInvariant()));
    }
}
