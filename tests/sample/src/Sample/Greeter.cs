namespace Sample;

// Trivial library type. Exists solely so ci-dotnet.yml has something to
// build and measure coverage against; replaced when this repo gains
// real shared .NET code.
public static class Greeter
{
    public static string Greet(string name) =>
        string.IsNullOrWhiteSpace(name)
            ? "Hello, world!"
            : $"Hello, {name}!";
}
