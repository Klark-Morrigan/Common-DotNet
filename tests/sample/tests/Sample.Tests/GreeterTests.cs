namespace Sample.Tests;

public class GreeterTests
{
    [Fact]
    public void GreetNamedRecipientReturnsPersonalizedMessage()
    {
        Assert.Equal("Hello, Alice!", Greeter.Greet("Alice"));
    }
}
