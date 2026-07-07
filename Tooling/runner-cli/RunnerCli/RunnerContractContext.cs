using System.Text.Json.Serialization;

namespace RunnerCli;

[JsonSerializable(typeof(RunnerContract))]
[JsonSourceGenerationOptions(WriteIndented = true, PropertyNameCaseInsensitive = true)]
internal partial class RunnerContractContext : JsonSerializerContext
{
}
