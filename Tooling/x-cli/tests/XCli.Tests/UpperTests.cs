using System;
using XCli.Upper;
using Xunit;

namespace XCli.Tests;

public class UpperTests
{
    [Fact]
    public void Execute_ConvertsTextToUppercase()
    {
        var result = UpperCommand.Execute("abc");
        Assert.Equal("ABC", result);
    }

    [Fact]
    public void Execute_Null_Throws()
    {
        Assert.Throws<ArgumentNullException>(() => UpperCommand.Execute(null!));
    }
}
