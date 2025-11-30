namespace XCli.Upper;

/// <summary>
/// Provides a command that converts input text to uppercase.
/// </summary>
public static class UpperCommand
{
    /// <summary>
    /// Returns the uppercase representation of <paramref name="text"/>.
    /// </summary>
    /// <param name="text">Text to convert.</param>
    /// <returns>Uppercase version of <paramref name="text"/>.</returns>
    /// <exception cref="ArgumentNullException">Thrown when <paramref name="text"/> is null.</exception>
    public static string Execute(string text)
    {
        if (text is null)
            throw new ArgumentNullException(nameof(text));

        return text.ToUpperInvariant();
    }
}
