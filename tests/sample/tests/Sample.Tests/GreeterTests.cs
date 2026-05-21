namespace Sample.Tests;

public class GreeterTests
{
    [Fact]
    public void GreetNamedRecipientReturnsPersonalizedMessage()
    {
        Assert.Equal("Hello, Alice!", Greeter.Greet("Alice"));
    }

    [Fact]
    public void GreetEmptyNameFallsBackToWorldGreeting()
    {
        Assert.Equal("Hello, world!", Greeter.Greet(string.Empty));
    }
}
