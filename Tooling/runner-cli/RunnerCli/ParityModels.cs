using System.Text.Json.Serialization;

namespace RunnerCli;

public sealed class ParityContractDefinition
{
    [JsonPropertyName("project_relative_path")]
    public string ProjectRelativePath { get; set; } = "lv_icon_editor.lvproj";

    [JsonPropertyName("target_dir_relative_path")]
    public string TargetDirRelativePath { get; set; } = "Test/Templates";

    [JsonPropertyName("build_output_relative_path")]
    public string BuildOutputRelativePath { get; set; } = "resource/plugins/lv_icon.lvlibp";

    [JsonPropertyName("build_spec_name")]
    public string BuildSpecName { get; set; } = "Editor Packed Library";

    [JsonPropertyName("target_name")]
    public string TargetName { get; set; } = "My Computer";

    [JsonPropertyName("exclude_files")]
    public List<string> ExcludeFiles { get; set; } = new() { "Polymorphic Template.vi" };

    [JsonPropertyName("default_release_suffix")]
    public string DefaultReleaseSuffix { get; set; } = "q1";
}

public sealed class ParityContext
{
    [JsonPropertyName("repo_root")]
    public string RepoRoot { get; set; } = string.Empty;

    [JsonPropertyName("contract_path")]
    public string ContractPath { get; set; } = string.Empty;

    [JsonPropertyName("project_path")]
    public string ProjectPath { get; set; } = string.Empty;

    [JsonPropertyName("project_relative_path")]
    public string ProjectRelativePath { get; set; } = string.Empty;

    [JsonPropertyName("target_dir_rel")]
    public string TargetDirRel { get; set; } = string.Empty;

    [JsonPropertyName("build_output_relative_path")]
    public string BuildOutputRelativePath { get; set; } = string.Empty;

    [JsonPropertyName("lvversion_raw")]
    public string LvVersionRaw { get; set; } = string.Empty;

    [JsonPropertyName("labview_year")]
    public string LabVIEWYear { get; set; } = string.Empty;

    [JsonPropertyName("lv_release_resolved")]
    public string LvReleaseResolved { get; set; } = string.Empty;

    [JsonPropertyName("build_spec_name")]
    public string BuildSpecName { get; set; } = string.Empty;

    [JsonPropertyName("target_name")]
    public string TargetName { get; set; } = string.Empty;

    [JsonPropertyName("exclude_files")]
    public List<string> ExcludeFiles { get; set; } = new();
}

public sealed class ParityRunResult
{
    [JsonPropertyName("mode")]
    public string Mode { get; set; } = string.Empty;

    [JsonPropertyName("repo_root")]
    public string RepoRoot { get; set; } = string.Empty;

    [JsonPropertyName("project_path")]
    public string ProjectPath { get; set; } = string.Empty;

    [JsonPropertyName("build_output_path")]
    public string BuildOutputPath { get; set; } = string.Empty;

    [JsonPropertyName("labview_year")]
    public string LabVIEWYear { get; set; } = string.Empty;

    [JsonPropertyName("lv_release_resolved")]
    public string LvReleaseResolved { get; set; } = string.Empty;

    [JsonPropertyName("build_spec_enabled")]
    public bool BuildSpecEnabled { get; set; }

    [JsonPropertyName("exit_code")]
    public int ExitCode { get; set; }
}
