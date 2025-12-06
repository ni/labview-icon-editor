namespace XCli.Reverse;

public static class ReverseCommand
{
    /// <summary>
    /// Reverses the provided <paramref name="text"/>.
    /// </summary>
    /// <param name="text">The text to reverse.</param>
    /// <returns>The reversed string.</returns>
    /// <exception cref="ArgumentNullException">Thrown when <paramref name="text"/> is null.</exception>
    public static string Execute(string text)
    {
        if (text is null)
            throw new ArgumentNullException(nameof(text));

        var chars = text.ToCharArray();
        Array.Reverse(chars);
        return new string(chars);
    }
}
