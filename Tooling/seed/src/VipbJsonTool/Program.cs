using System;
using System.IO;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 3)
            {
                Console.Error.WriteLine("Usage: VipbJsonTool <mode> <input> <output>");
                return 1;
            }

            string mode       = args[0].ToLower();
            string inputPath  = args[1];
            string outputPath = args[2];

            // Ensure the output directory exists
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);

            try
            {
                switch (mode)
                {
                    case "vipb2json":      ConvertXmlToJson(inputPath, outputPath, "Package"); break;
                    case "json2vipb":      ConvertJsonToXml(inputPath, outputPath, "Package"); break;
                    case "lvproj2json":    ConvertXmlToJson(inputPath, outputPath, "Project"); break;
                    case "json2lvproj":    ConvertJsonToXml(inputPath, outputPath, "Project"); break;
                    case "buildspec2json": ConvertBuildSpecToJson(inputPath, outputPath);       break;
                    case "json2buildspec": ConvertJsonToBuildSpec(inputPath, outputPath);       break;
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

        //----------------------------------------------------------------------
        // XML ➜ JSON
        //----------------------------------------------------------------------

        private static void ConvertXmlToJson(string xmlPath, string jsonPath, string rootElementName)
        {
            if (!File.Exists(xmlPath))
                throw new FileNotFoundException($"Input file not found: {xmlPath}");

            var doc = new XmlDocument { PreserveWhitespace = true };
            doc.Load(xmlPath);

            if (doc.DocumentElement?.Name != rootElementName)
                throw new InvalidOperationException($"Invalid root element. Expected '{rootElementName}'.");

            // Use fully-qualified enum to avoid ambiguity
            string json = JsonConvert.SerializeXmlNode(
                doc,
                Newtonsoft.Json.Formatting.Indented,  // specify the JSON Formatting
                /* omitRootObject: */ false);
            File.WriteAllText(jsonPath, json);
        }

        //----------------------------------------------------------------------
        // JSON ➜ XML
        //----------------------------------------------------------------------

        private static void ConvertJsonToXml(string jsonPath, string xmlPath, string rootElementName)
        {
            if (!File.Exists(jsonPath))
                throw new FileNotFoundException($"Input file not found: {jsonPath}");

            string json = File.ReadAllText(jsonPath);

            var xmlDoc = JsonConvert.DeserializeXmlNode(json)!;

            if (xmlDoc.DocumentElement?.Name != rootElementName)
                throw new InvalidOperationException($"Invalid root element. Expected '{rootElementName}'.");

            using var writer = XmlWriter.Create(xmlPath, new XmlWriterSettings { Indent = true });
            xmlDoc.Save(writer);
        }

        //----------------------------------------------------------------------
        // Build‑spec helpers (unchanged)
        //----------------------------------------------------------------------

        private static void ConvertBuildSpecToJson(string inputPath, string outputPath)
        {
            string ext = Path.GetExtension(inputPath).ToLowerInvariant();
            if (ext == ".vipb")      ConvertXmlToJson(inputPath, outputPath, "Package");
            else if (ext == ".lvproj") ConvertXmlToJson(inputPath, outputPath, "Project");
            else throw new InvalidOperationException("Unsupported input file type for buildspec2json. Must be .vipb or .lvproj");
        }

        private static void ConvertJsonToBuildSpec(string inputPath, string outputPath)
        {
            string ext = Path.GetExtension(outputPath).ToLowerInvariant();
            if (ext == ".vipb")      ConvertJsonToXml(inputPath, outputPath, "Package");
            else if (ext == ".lvproj") ConvertJsonToXml(inputPath, outputPath, "Project");
            else throw new InvalidOperationException("Unsupported output file type for json2buildspec. Must be .vipb or .lvproj");
        }
    }
}
