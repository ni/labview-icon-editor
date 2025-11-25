using System;
using System.IO;
using System.Xml;
using Newtonsoft.Json;

namespace LvprojJsonTool
{
    class Program
    {
        static int Main(string[] args)
        {
            // Show usage if no arguments provided
            if (args.Length == 0)
            {
                Console.Error.WriteLine("Usage: LvprojJsonTool <mode> --input <file> --output <file>");
                Console.Error.WriteLine("Run with --help for more information on modes and options.");
                return 1;
            }
            // Show detailed help if requested
            if (args[0] == "--help" || args[0] == "-h")
            {
                Console.WriteLine("Usage: LvprojJsonTool <mode> --input <file> --output <file>");
                Console.WriteLine();
                Console.WriteLine("Modes:");
                Console.WriteLine("  lvproj2json   Convert a LabVIEW .lvproj (XML) file to JSON format.");
                Console.WriteLine("  json2lvproj   Convert a LabVIEW project JSON file back to .lvproj (XML).");
                return 0;
            }

            string mode = null;
            string inputPath = null;
            string outputPath = null;

            // Parse arguments for mode, input and output
            for (int i = 0; i < args.Length; i++)
            {
                string arg = args[i];
                if (arg == "--input" || arg == "-i")
                {
                    if (i == args.Length - 1)
                    {
                        Console.Error.WriteLine("ERROR: Missing value for --input option");
                        return 1;
                    }
                    inputPath = args[++i];
                }
                else if (arg == "--output" || arg == "-o")
                {
                    if (i == args.Length - 1)
                    {
                        Console.Error.WriteLine("ERROR: Missing value for --output option");
                        return 1;
                    }
                    outputPath = args[++i];
                }
                else if (!arg.StartsWith("-") && mode == null)
                {
                    mode = arg.ToLowerInvariant();
                }
                else
                {
                    Console.Error.WriteLine($"ERROR: Unknown argument '{arg}'");
                    return 1;
                }
            }

            if (string.IsNullOrEmpty(mode) || string.IsNullOrEmpty(inputPath) || string.IsNullOrEmpty(outputPath))
            {
                Console.Error.WriteLine("Usage: LvprojJsonTool <mode> --input <file> --output <file>");
                return 1;
            }

            // Ensure the output directory exists
            string outputDir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(outputDir))
            {
                Directory.CreateDirectory(outputDir);
            }

            try
            {
                switch (mode)
                {
                    case "lvproj2json":
                        ConvertXmlToJson(inputPath, outputPath, "Project");
                        break;
                    case "json2lvproj":
                        ConvertJsonToXml(inputPath, outputPath, "Project");
                        break;
                    default:
                        Console.Error.WriteLine($"ERROR: Unknown mode '{mode}'");
                        return 1;
                }

                Console.WriteLine($"Successfully executed {mode}");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR: {ex.Message}");
                return 1;
            }
        }

        // Convert XML (.lvproj) to JSON
        private static void ConvertXmlToJson(string xmlPath, string jsonPath, string rootElementName)
        {
            if (!File.Exists(xmlPath))
                throw new FileNotFoundException($"Input file not found: {xmlPath}");

            var doc = new XmlDocument { PreserveWhitespace = true };
            doc.Load(xmlPath);

            if (doc.DocumentElement?.Name != rootElementName)
                throw new InvalidOperationException($"Invalid root element. Expected '{rootElementName}'.");

            string json = JsonConvert.SerializeXmlNode(
                doc,
                Newtonsoft.Json.Formatting.Indented,
                /* omitRootObject: */ false);

            File.WriteAllText(jsonPath, json);
        }

        // Convert JSON to XML (.lvproj)
        private static void ConvertJsonToXml(string jsonPath, string xmlPath, string rootElementName)
        {
            if (!File.Exists(jsonPath))
                throw new FileNotFoundException($"Input file not found: {jsonPath}");

            string jsonContent = File.ReadAllText(jsonPath);
            var xmlDoc = JsonConvert.DeserializeXmlNode(jsonContent);

            if (xmlDoc.DocumentElement?.Name != rootElementName)
                throw new InvalidOperationException($"Invalid root element. Expected '{rootElementName}'.");

            using var writer = XmlWriter.Create(xmlPath, new XmlWriterSettings { Indent = true });
            xmlDoc.Save(writer);
        }
    }
}
