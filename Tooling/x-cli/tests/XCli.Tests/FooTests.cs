using System;
using XCli.Foo;
using Xunit;

namespace XCli.Tests;

public class FooTests
{
    [Fact]
    public void Execute_AppendsExclamation()
    {
        var result = FooCommand.Execute("bar");
        Assert.Equal("bar!", result);
    }

    [Fact]
    public void Execute_Null_Throws()
    {
        Assert.Throws<ArgumentNullException>(() => FooCommand.Execute(null!));
    }
}
