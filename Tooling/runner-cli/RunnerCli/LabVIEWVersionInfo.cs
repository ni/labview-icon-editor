namespace RunnerCli;

public sealed record LabVIEWVersionInfo(
    string Raw,
    string Year,
    int MinorRevision,
    int NumericMajor,
    string NumericVersion
);
