using System.Text.Json.Serialization;

namespace RunnerCli;

[JsonSourceGenerationOptions(
    PropertyNameCaseInsensitive = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    WriteIndented = false)]
[JsonSerializable(typeof(LabVIEWVersionInfo))]
[JsonSerializable(typeof(PylaviOffendersReport))]
[JsonSerializable(typeof(PylaviScanSummary))]
[JsonSerializable(typeof(PylaviSummarizeOutput))]
internal partial class RunnerCliJsonContext : JsonSerializerContext
{
}
