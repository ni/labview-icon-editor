namespace XCli.Foo;

/// <summary>
/// Demo command that appends an exclamation mark to the provided text.
/// Mirrors the simple patterns used by Echo/Upper/Reverse commands.
/// </summary>
public static class FooCommand
{
    /// <summary>
    /// Returns <paramref name="text"/> with a trailing '!'.
    /// </summary>
    /// <param name="text">Input text.</param>
    /// <returns><paramref name="text"/> followed by '!'.</returns>
    /// <exception cref="ArgumentNullException">When <paramref name="text"/> is null.</exception>
    public static string Execute(string text)
    {
        if (text is null)
            throw new ArgumentNullException(nameof(text));
        return text + "!";
    }
}
