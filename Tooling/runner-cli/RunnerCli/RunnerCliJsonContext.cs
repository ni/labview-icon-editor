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
[JsonSerializable(typeof(RunnerCliManifest))]
[JsonSerializable(typeof(ConformanceCheckResult))]
[JsonSerializable(typeof(ConformanceCheckSummary))]
[JsonSerializable(typeof(ConformanceCheckEntry))]
internal partial class RunnerCliJsonContext : JsonSerializerContext
{
}
