namespace XCli.Echo;

/// <summary>
/// Provides a simple echo command that returns the supplied text unchanged.
/// </summary>
public static class EchoCommand
{
    /// <summary>
    /// Returns <paramref name="text"/> exactly as provided.
    /// </summary>
    /// <param name="text">The text to echo back.</param>
    /// <returns>The same text supplied in <paramref name="text"/>.</returns>
    /// <exception cref="ArgumentNullException">Thrown when <paramref name="text"/> is null.</exception>
    public static string Execute(string text)
    {
        if (text is null)
            throw new ArgumentNullException(nameof(text));

        return text;
    }
}
