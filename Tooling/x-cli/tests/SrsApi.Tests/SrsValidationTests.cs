using SrsApi;
using Xunit;

public class SrsValidationTests
{
    // TEST-REQ-TEST-001 is a placeholder requirement ID used for validation tests.
    private const string TestId = "TEST-REQ-TEST-001";
    private const string TestIdLower = "test-req-test-001";
    private const string TestIdNbHyphen = "TEST\u2011REQ\u2011TEST\u2011001";
    private const string TestIdShort = "TEST-REQ-TEST-1";

    [Theory]
    [InlineData(TestId, true)]
    [InlineData(TestIdLower, true)]
    [InlineData(TestIdNbHyphen, true)]
    [InlineData(TestIdShort, false)]
    public void ValidatesIdFormat(string id, bool expected)
    {
        Assert.Equal(expected, SrsValidation.IsValidId(id));
    }

    [Fact]
    public void DetectsCollisions()
    {
        var docs = new ISrsDocument[]
        {
            new SrsDocument(TestId, "1.0", "a"),
            new SrsDocument(TestId, "1.0", "b"),
        };
        var dupes = SrsValidation.FindCollisions(docs);
        Assert.Contains(TestId, dupes);
    }
}
