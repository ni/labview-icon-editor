// ModuleIndex: contract for SRS document metadata (ID, Version, Path).
namespace SrsApi;

public interface ISrsDocument
{
    string Id { get; }
    string Version { get; }
    string Path { get; }
}
