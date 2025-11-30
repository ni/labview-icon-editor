using SrsApi;
using Xunit;

public class SrsNormalizationTests
{
    // TEST-REQ-ABC-001 is a placeholder requirement ID used only for normalization tests.
    [Theory]
    [InlineData("TEST\u2010REQ\u2010ABC\u2010001")]
    [InlineData("TEST\u2011REQ\u2011ABC\u2011001")]
    [InlineData("TEST\u2012REQ\u2012ABC\u2012001")]
    [InlineData("TEST\u2013REQ\u2013ABC\u2013001")]
    [InlineData("TEST\u2014REQ\u2014ABC\u2014001")]
    public void NormalizesVariousDashes(string id)
    {
        var normalized = SrsNormalization.NormalizeId(id);
        Assert.Equal("TEST-REQ-ABC-001", normalized);
    }
}
