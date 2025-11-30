using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using Xunit;
using Xunit.Abstractions;
using Xunit.Sdk;
using XCli.Tests.Utilities;

[assembly: Xunit.TestFramework("XCli.Tests.TestTelemetry", "XCli.Tests")]

namespace XCli.Tests;

// Custom test framework to capture telemetry information for each test
public class TestTelemetry : XunitTestFramework
{
    public TestTelemetry(IMessageSink messageSink)
        : base(messageSink)
    {
    }

    protected override ITestFrameworkExecutor CreateExecutor(AssemblyName assemblyName)
        => new TelemetryExecutor(assemblyName, SourceInformationProvider, DiagnosticMessageSink);

    class TelemetryExecutor : XunitTestFrameworkExecutor
    {
        public TelemetryExecutor(
            AssemblyName assemblyName,
            ISourceInformationProvider sourceInformationProvider,
            IMessageSink diagnosticMessageSink)
            : base(assemblyName, sourceInformationProvider, diagnosticMessageSink)
        {
        }

        protected override async void RunTestCases(
            IEnumerable<IXunitTestCase> testCases,
            IMessageSink executionMessageSink,
            ITestFrameworkExecutionOptions executionOptions)
        {
            using var sink = new TelemetryMessageSink(executionMessageSink);
            using var assemblyRunner = new XunitTestAssemblyRunner(
                TestAssembly, testCases, DiagnosticMessageSink, sink, executionOptions);
            await assemblyRunner.RunAsync();
        }
    }

    class TelemetryMessageSink : LongLivedMarshalByRefObject, IMessageSink, IDisposable
    {
        readonly IMessageSink _inner;
        static readonly object s_lock = new object();

        public TelemetryMessageSink(IMessageSink inner)
        {
            _inner = inner;
        }

        public bool OnMessage(IMessageSinkMessage message)
        {
            if (message is ITestPassed passed)
                Log(passed.Test, "passed", passed.ExecutionTime, null, null);
            else if (message is ITestFailed failed)
            {
                var exType = failed.ExceptionTypes.FirstOrDefault();
                if (exType != null)
                    exType = exType.Split('.').Last();
                Log(
                    failed.Test,
                    "failed",
                    failed.ExecutionTime,
                    exType,
                    failed.Messages.FirstOrDefault());
            }
            else if (message is ITestSkipped skipped)
                Log(skipped.Test, "skipped", 0m, null, null);

            return _inner.OnMessage(message);
        }

        public void Dispose() { }

        static void Log(
            ITest test,
            string outcome,
            decimal duration,
            string? exceptionType,
            string? exceptionMessage)
        {
            var attrType = typeof(ExternalDependencyAttribute);
            var deps = new List<string>();
            deps.AddRange(test.TestCase.TestMethod.Method
                .GetCustomAttributes(attrType)
                .Select(a => a.GetNamedArgument<string>(nameof(ExternalDependencyAttribute.Description))));
            deps.AddRange(test.TestCase.TestMethod.TestClass.Class
                .GetCustomAttributes(attrType)
                .Select(a => a.GetNamedArgument<string>(nameof(ExternalDependencyAttribute.Description))));

            var entry = new Dictionary<string, object?>
            {
                ["test"] = test.TestCase.DisplayName,
                ["language"] = "dotnet",
                ["dependencies"] = deps,
                ["outcome"] = outcome,
                ["duration"] = (double)duration,
            };

            if (exceptionType != null)
                entry["exception_type"] = exceptionType;
            if (exceptionMessage != null)
                entry["exception_message"] = exceptionMessage;

            var root = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));
            var path = Path.Combine(root, "artifacts", "test-telemetry.jsonl");
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var line = JsonSerializer.Serialize(entry);
            lock (s_lock)
            {
                File.AppendAllText(path, line + Environment.NewLine);
            }
        }
    }
}

