using System;
using System.IO;
using System.Threading;

if (args.Length == 0) return;
var path = args[0];
if (OperatingSystem.IsWindows() || OperatingSystem.IsLinux())
{
    using var fs = new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.ReadWrite);
    fs.Lock(0, long.MaxValue);
    Console.WriteLine("locked");
    Console.Out.Flush();
    Console.ReadLine();
}
else
{
    Console.WriteLine("File locking is unsupported on this platform.");
    return;
}
