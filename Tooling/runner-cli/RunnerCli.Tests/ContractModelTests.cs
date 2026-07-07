using RunnerCli;

namespace RunnerCli.Tests;

public class ContractModelTests
{
    [Fact]
    public void DefaultContract_HasVersion1()
    {
        var contract = new RunnerContract();
        Assert.Equal(1, contract.Version);
    }

    [Fact]
    public void DefaultContract_HasEmptyLabels()
    {
        var contract = new RunnerContract();
        Assert.NotNull(contract.RunnerLabels);
        Assert.Empty(contract.RunnerLabels);
    }

    [Fact]
    public void DefaultContract_HasTimestampPlaceholders()
    {
        var contract = new RunnerContract();
        Assert.Equal("0001-01-01T00:00:00Z", contract.UpdatedAtUtc);
        Assert.Equal("0001-01-01T00:00:00Z", contract.CreatedAtUtc);
    }
}
