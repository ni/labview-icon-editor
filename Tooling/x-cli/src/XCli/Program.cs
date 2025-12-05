using System;
using System.Linq;

namespace XCli
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            if (args.Length == 0)
            {
                Console.Error.WriteLine("[x-cli] no command provided");
                return 1;
            }

            var command = args[0].ToLowerInvariant();
            switch (command)
            {
                case "vi-analyzer-run":
                    Console.WriteLine("[x-cli] vi-analyzer-run stub: returning success");
                    return 0;
                default:
                    Console.Error.WriteLine($"[x-cli] unknown command '{command}'");
                    return 1;
            }
        }
    }
}
