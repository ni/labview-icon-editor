namespace XCli.Labview.Providers;

public static class LabviewProviderFactory
{
    public static ILabviewProvider CreateDefault() => new DefaultLabviewProvider();
}
