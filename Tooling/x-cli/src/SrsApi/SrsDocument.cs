// ModuleIndex: record implementation of ISrsDocument.
namespace SrsApi;

public record SrsDocument(string Id, string Version, string Path) : ISrsDocument;
