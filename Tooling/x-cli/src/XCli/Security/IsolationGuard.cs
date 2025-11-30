// ModuleIndex: guards against network assemblies and Process.Start invocations.
namespace XCli.Security;

using System;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;

public static class IsolationGuard
{
    private static readonly OpCode[] SingleByteOpCodes = new OpCode[0x100];
    private static readonly OpCode[] MultiByteOpCodes = new OpCode[0x100];

    static IsolationGuard()
    {
        foreach (var fi in typeof(OpCodes).GetFields(BindingFlags.Public | BindingFlags.Static))
        {
            if (fi.GetValue(null) is OpCode op)
            {
                var value = (ushort)op.Value;
                if (value < 0x100)
                    SingleByteOpCodes[value] = op;
                else if ((value & 0xff00) == 0xfe00)
                    MultiByteOpCodes[value & 0xff] = op;
            }
        }
    }

    public static void Enforce(Assembly? assembly = null)
    {
        var bypass = Environment.GetEnvironmentVariable("XCLI_ALLOW_PROCESS_START");
        if (!string.IsNullOrWhiteSpace(bypass) &&
            (bypass.Equals("1", StringComparison.OrdinalIgnoreCase) ||
             bypass.Equals("true", StringComparison.OrdinalIgnoreCase)))
        {
            return;
        }

        var asm = assembly ?? typeof(IsolationGuard).Assembly;
        var refs = asm.GetReferencedAssemblies();
        var networkPrefixes = new[]
        {
            "System.Net",
            "System.Net.Http",
            "System.Net.Sockets",
            "System.Net.WebSockets"
        };
        if (refs.Any(r => r.Name is { } name &&
                          networkPrefixes.Any(p => name.StartsWith(p, StringComparison.OrdinalIgnoreCase))))
            throw new InvalidOperationException("Network assemblies referenced");

        Type[] types;
        try
        {
            types = asm.GetTypes();
        }
        catch (ReflectionTypeLoadException ex)
        {
            types = ex.Types.Where(t => t != null).Select(t => t!).ToArray();
        }

        foreach (var type in types)
        {
            var flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static;
            foreach (var ctor in type.GetConstructors(flags))
            {
                if (CallsProcessStart(ctor))
                    throw new InvalidOperationException("Process.Start invocation detected");
            }
            foreach (var method in type.GetMethods(flags))
            {
                if (CallsProcessStart(method))
                    throw new InvalidOperationException("Process.Start invocation detected");
            }
        }
    }

    private static bool CallsProcessStart(MethodBase method)
    {
        var body = method.GetMethodBody();
        if (body == null)
            return false;
        var il = body.GetILAsByteArray();
        if (il == null)
            return false;
        var module = method.Module;

        for (int i = 0; i < il.Length;)
        {
            OpCode op;
            byte code = il[i++];
            if (code == 0xfe)
            {
                op = MultiByteOpCodes[il[i++]];
            }
            else
            {
                op = SingleByteOpCodes[code];
            }

            int operandSize = GetOperandSize(op.OperandType);
            if ((op == OpCodes.Call || op == OpCodes.Callvirt) && operandSize == 4)
            {
                int token = BitConverter.ToInt32(il, i);
                MethodBase? target;
                try { target = module.ResolveMethod(token); }
                catch { target = null; }
                if (target?.DeclaringType?.FullName == "System.Diagnostics.Process" && target.Name == "Start")
                    return true;
            }
            i += operandSize;
        }

        return false;
    }

    private static int GetOperandSize(OperandType operandType) => operandType switch
    {
        OperandType.InlineNone => 0,
        OperandType.ShortInlineBrTarget or OperandType.ShortInlineI or OperandType.ShortInlineVar => 1,
        OperandType.InlineVar => 2,
        OperandType.InlineI or OperandType.InlineBrTarget or OperandType.InlineField or OperandType.InlineMethod or OperandType.InlineSig or OperandType.InlineString or OperandType.InlineTok or OperandType.InlineType or OperandType.ShortInlineR => 4,
        OperandType.InlineI8 or OperandType.InlineR => 8,
        _ => 0,
    };
}
