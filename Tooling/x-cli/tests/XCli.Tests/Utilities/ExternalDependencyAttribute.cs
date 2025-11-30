using System;

namespace XCli.Tests.Utilities;

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = true)]
public sealed class ExternalDependencyAttribute : Attribute
{
    public ExternalDependencyAttribute(string description)
    {
        Description = description;
    }

    public string Description { get; }
}

