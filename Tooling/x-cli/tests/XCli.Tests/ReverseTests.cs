using System;
using XCli.Reverse;
using Xunit;

namespace XCli.Tests;

public class ReverseTests
{
    [Fact]
    public void Execute_ReversesInput()
    {
        var result = ReverseCommand.Execute("abcd");
        Assert.Equal("dcba", result);
    }

    [Fact]
    public void Execute_Null_Throws()
    {
        Assert.Throws<ArgumentNullException>(() => ReverseCommand.Execute(null!));
    }
}
