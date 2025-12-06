// ModuleIndex: registry contract for lookup and enumeration.
namespace SrsApi;

public interface ISrsRegistry
{
    IReadOnlyCollection<ISrsDocument> Documents { get; }
    ISrsDocument? Get(string id);
}
