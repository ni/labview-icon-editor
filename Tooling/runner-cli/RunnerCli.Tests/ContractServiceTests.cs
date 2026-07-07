using RunnerCli;

namespace RunnerCli.Tests;

public class ContractServiceTests : IDisposable
{
    private readonly string _tempDir;

    public ContractServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"lvie-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }

    // ── Load / Save round-trip ──────────────────────────────────────

    [Fact]
    public void Save_and_Load_roundtrip_preserves_all_fields()
    {
        var path = Path.Combine(_tempDir, "contract.json");
        var contract = new RunnerContract
        {
            Version = 1,
            RunnerRoot = _tempDir,
            WorkRoot = _tempDir,
            WorktreeRoot = Path.Combine(_tempDir, "w"),
            ArtifactRoot = Path.Combine(_tempDir, "artifacts"),
            LockRoot = Path.Combine(_tempDir, "locks"),
            LogRoot = Path.Combine(_tempDir, "logs"),
            RunnerLabel = "test-label",
            RunnerLabels = new List<string> { "test-label", "extra" },
            CanonicalRunnerLabel = "test-label",
            UpdatedAtUtc = "2025-01-01T00:00:00Z",
            CreatedAtUtc = "2025-01-01T00:00:00Z"
        };

        ContractService.Save(path, contract);
        Assert.True(File.Exists(path));

        var loaded = ContractService.Load(path);
        Assert.Equal(1, loaded.Version);
        Assert.Equal(_tempDir, loaded.RunnerRoot);
        Assert.Equal("test-label", loaded.RunnerLabel);
        Assert.Contains("test-label", loaded.RunnerLabels);
        Assert.Contains("extra", loaded.RunnerLabels);
        Assert.Equal("test-label", loaded.CanonicalRunnerLabel);
    }

    [Fact]
    public void Save_creates_parent_directories()
    {
        var nested = Path.Combine(_tempDir, "sub", "dir", "contract.json");
        var contract = new RunnerContract { RunnerRoot = _tempDir };

        ContractService.Save(nested, contract);
        Assert.True(File.Exists(nested));
    }

    [Fact]
    public void Load_throws_for_nonexistent_file()
    {
        var path = Path.Combine(_tempDir, "nope.json");
        Assert.Throws<FileNotFoundException>(() => ContractService.Load(path));
    }

    [Fact]
    public void Load_throws_for_empty_path()
    {
        Assert.Throws<ArgumentException>(() => ContractService.Load(""));
    }

    [Fact]
    public void Load_throws_for_invalid_json()
    {
        var path = Path.Combine(_tempDir, "bad.json");
        File.WriteAllText(path, "not json at all");
        Assert.ThrowsAny<Exception>(() => ContractService.Load(path));
    }

    // ── Validate ────────────────────────────────────────────────────

    [Fact]
    public void Validate_returns_empty_when_all_dirs_exist()
    {
        // Create all required directories
        var dirs = new[]
        {
            Path.Combine(_tempDir, "runner"),
            Path.Combine(_tempDir, "work"),
            Path.Combine(_tempDir, "worktree"),
            Path.Combine(_tempDir, "artifacts"),
            Path.Combine(_tempDir, "locks"),
            Path.Combine(_tempDir, "logs")
        };
        foreach (var d in dirs) Directory.CreateDirectory(d);

        var contract = new RunnerContract
        {
            RunnerRoot = dirs[0],
            WorkRoot = dirs[1],
            WorktreeRoot = dirs[2],
            ArtifactRoot = dirs[3],
            LockRoot = dirs[4],
            LogRoot = dirs[5]
        };

        var errors = ContractService.Validate(contract);
        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_reports_missing_directory()
    {
        var existing = Path.Combine(_tempDir, "exists");
        Directory.CreateDirectory(existing);

        var contract = new RunnerContract
        {
            RunnerRoot = existing,
            WorkRoot = existing,
            WorktreeRoot = Path.Combine(_tempDir, "does-not-exist"),
            ArtifactRoot = existing,
            LockRoot = existing,
            LogRoot = existing
        };

        var errors = ContractService.Validate(contract);
        Assert.Single(errors);
        Assert.Contains("worktree_root", errors[0]);
    }

    [Fact]
    public void Validate_reports_empty_field()
    {
        var existing = Path.Combine(_tempDir, "exists");
        Directory.CreateDirectory(existing);

        var contract = new RunnerContract
        {
            RunnerRoot = "",
            WorkRoot = existing,
            WorktreeRoot = existing,
            ArtifactRoot = existing,
            LockRoot = existing,
            LogRoot = existing
        };

        var errors = ContractService.Validate(contract);
        Assert.Single(errors);
        Assert.Contains("runner_root", errors[0]);
    }

    [Fact]
    public void Validate_reports_multiple_errors()
    {
        var contract = new RunnerContract
        {
            RunnerRoot = "",
            WorkRoot = "",
            WorktreeRoot = "",
            ArtifactRoot = "",
            LockRoot = "",
            LogRoot = ""
        };

        var errors = ContractService.Validate(contract);
        Assert.Equal(6, errors.Count);
    }

    // ── NormalizeLabels ─────────────────────────────────────────────

    [Fact]
    public void NormalizeLabels_deduplicates_and_trims()
    {
        var raw = new[] { "  label-a ", "label-b", "label-a", "", "  ", "label-c" };
        var result = ContractService.NormalizeLabels(raw);
        Assert.Equal(3, result.Count);
        Assert.Contains("label-a", result);
        Assert.Contains("label-b", result);
        Assert.Contains("label-c", result);
    }

    [Fact]
    public void NormalizeLabels_case_insensitive_dedup()
    {
        var raw = new[] { "Label-A", "label-a", "LABEL-A" };
        var result = ContractService.NormalizeLabels(raw);
        Assert.Single(result);
    }

    [Fact]
    public void NormalizeLabels_returns_empty_for_null()
    {
        var result = ContractService.NormalizeLabels(null);
        Assert.Empty(result);
    }

    // ── ParseLabels ─────────────────────────────────────────────────

    [Fact]
    public void ParseLabels_splits_csv()
    {
        var result = ContractService.ParseLabels("label-a, label-b , label-c");
        Assert.Equal(3, result.Count);
        Assert.Equal("label-a", result[0]);
        Assert.Equal("label-b", result[1]);
        Assert.Equal("label-c", result[2]);
    }

    [Fact]
    public void ParseLabels_returns_empty_for_whitespace()
    {
        var result = ContractService.ParseLabels("   ");
        Assert.Empty(result);
    }

    [Fact]
    public void ParseLabels_returns_empty_for_null()
    {
        var result = ContractService.ParseLabels(null);
        Assert.Empty(result);
    }
}
