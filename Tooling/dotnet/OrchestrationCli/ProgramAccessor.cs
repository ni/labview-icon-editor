using System;
using System.Collections.Generic;

public static class ProgramAccessor
{
    public static (Program.Options? value, string? error, bool help) InvokeParseArgs(string[] args)
        => Program.ParseArgsForTest(args);

    public static Program.CommandResult RunBindUnbindForTest(Program.Options opts, string repo, string bitness, string mode)
    {
        void Log(string _) { }
        return Program.RunBindUnbindForTest(Log, opts, repo, bitness, mode);
    }

    public static Program.CommandResult RunApplyDepsForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunApplyDepsForTest(Log, opts, repo, bitness);
    }

    public static Program.CommandResult RunRestoreForTest(Program.Options opts, string repo, string bitness, bool tokenPresent)
    {
        void Log(string _) { }
        return Program.RunRestoreForTest(Log, opts, repo, bitness, tokenPresent);
    }

    public static Program.CommandResult RunCloseLabVIEWForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunCloseLabVIEWForTest(Log, opts, repo, bitness, fakeExit: 0);
    }

    public static Program.CommandResult RunViAnalyzerForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunViAnalyzerForTest(Log, opts, repo, bitness, fakeExit: 0);
    }

    public static Program.CommandResult RunMissingCheckForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunMissingCheckForTest(Log, opts, repo, bitness, fakeExit: 0);
    }

    public static Program.CommandResult RunUnitTestsForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunUnitTestsForTest(Log, opts, repo, bitness, fakeExit: 0);
    }

    public static Program.CommandResult RunViCompareForTest(Program.Options opts, string repo, string bitness, bool useFakeExit = true)
    {
        void Log(string _) { }
        return Program.RunViCompareForTest(Log, opts, repo, bitness, fakeExit: useFakeExit ? 0 : null);
    }

    public static Program.CommandResult RunVipmVerifyForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunVipmVerifyForTest(Log, opts, repo, bitness);
    }

    public static Program.CommandResult RunVipmInstallForTest(Program.Options opts, string repo, string bitness)
    {
        void Log(string _) { }
        return Program.RunVipmInstallForTest(Log, opts, repo, bitness);
    }
}
