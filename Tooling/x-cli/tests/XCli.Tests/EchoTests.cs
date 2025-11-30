using System;
using XCli.Echo;
using Xunit;

namespace XCli.Tests;

public class EchoTests
{
    [Fact]
    public void Execute_ReturnsInput()
    {
        var result = EchoCommand.Execute("ping");
        Assert.Equal("ping", result);
    }

    [Fact]
    public void Execute_Null_Throws()
    {
        Assert.Throws<ArgumentNullException>(() => EchoCommand.Execute(null!));
    }
}
