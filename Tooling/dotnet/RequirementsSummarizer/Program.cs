using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Collections.Generic;
using System.Linq;

class Program
{
    static int Main(string[] args)
    {
        try
        {
            var csvPath = "docs/requirements/requirements.csv";
            var fullOutput = "";
            var jsonOutput = "";
            var htmlOutput = "";
            var summaryOutput = "";
            var repo = "";
            var title = "Requirements";
            
            // Parse arguments
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--csv" && i + 1 < args.Length)
                    csvPath = args[++i];
                else if (args[i] == "--full-output" && i + 1 < args.Length)
                    fullOutput = args[++i];
                else if (args[i] == "--json-output" && i + 1 < args.Length)
                    jsonOutput = args[++i];
                else if (args[i] == "--html-output" && i + 1 < args.Length)
                    htmlOutput = args[++i];
                else if (args[i] == "--summary-output" && i + 1 < args.Length)
                    summaryOutput = args[++i];
                else if (args[i] == "--repo" && i + 1 < args.Length)
                    repo = args[++i];
                else if (args[i] == "--title" && i + 1 < args.Length)
                    title = args[++i];
            }
            
            if (!File.Exists(csvPath))
            {
                Console.Error.WriteLine($"CSV file not found: {csvPath}");
                return 1;
            }
            
            // Read and parse CSV
            var lines = File.ReadAllLines(csvPath);
            if (lines.Length == 0)
            {
                Console.Error.WriteLine($"CSV file is empty: {csvPath}");
                return 1;
            }
            
            var headers = ParseCsvLine(lines[0]);
            var requirements = new List<Dictionary<string, string>>();
            
            for (int i = 1; i < lines.Length; i++)
            {
                if (string.IsNullOrWhiteSpace(lines[i])) continue;
                
                var values = ParseCsvLine(lines[i]);
                if (values.Length == headers.Length)
                {
                    var req = new Dictionary<string, string>();
                    for (int j = 0; j < headers.Length; j++)
                    {
                        req[headers[j]] = values[j];
                    }
                    requirements.Add(req);
                }
            }
            
            Console.WriteLine($"Loaded {requirements.Count} requirements from {csvPath}");
            
            // Generate outputs
            if (!string.IsNullOrEmpty(fullOutput))
            {
                GenerateMarkdown(fullOutput, requirements, title, headers);
            }
            
            if (!string.IsNullOrEmpty(jsonOutput))
            {
                GenerateJson(jsonOutput, requirements);
            }
            
            if (!string.IsNullOrEmpty(htmlOutput))
            {
                GenerateHtml(htmlOutput, requirements, title, headers);
            }
            
            if (!string.IsNullOrEmpty(summaryOutput))
            {
                GenerateMarkdown(summaryOutput, requirements, title, headers, maxRows: 5);
            }
            
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }
    }
    
    static void GenerateMarkdown(string path, List<Dictionary<string, string>> requirements, string title, string[] headers, int? maxRows = null)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }
        
        var sb = new StringBuilder();
        sb.AppendLine($"# {title}");
        sb.AppendLine();
        sb.AppendLine($"Total requirements: {requirements.Count}");
        sb.AppendLine();
        
        var displayReqs = maxRows.HasValue ? requirements.Take(maxRows.Value) : requirements;
        
        // Create table
        sb.AppendLine("| " + string.Join(" | ", headers) + " |");
        sb.AppendLine("| " + string.Join(" | ", headers.Select(_ => "---")) + " |");
        
        foreach (var req in displayReqs)
        {
            var row = headers.Select(h => req.ContainsKey(h) ? req[h] : "").ToArray();
            sb.AppendLine("| " + string.Join(" | ", row) + " |");
        }
        
        File.WriteAllText(path, sb.ToString());
        Console.WriteLine($"Generated Markdown: {path}");
    }
    
    static void GenerateJson(string path, List<Dictionary<string, string>> requirements)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }
        
        var json = JsonSerializer.Serialize(requirements, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(path, json);
        Console.WriteLine($"Generated JSON: {path}");
    }
    
    static void GenerateHtml(string path, List<Dictionary<string, string>> requirements, string title, string[] headers)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }
        
        var sb = new StringBuilder();
        sb.AppendLine("<!DOCTYPE html>");
        sb.AppendLine("<html>");
        sb.AppendLine("<head>");
        sb.AppendLine($"    <title>{title}</title>");
        sb.AppendLine("    <style>");
        sb.AppendLine("        body { font-family: Arial, sans-serif; margin: 20px; }");
        sb.AppendLine("        table { border-collapse: collapse; width: 100%; }");
        sb.AppendLine("        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }");
        sb.AppendLine("        th { background-color: #4CAF50; color: white; }");
        sb.AppendLine("        tr:nth-child(even) { background-color: #f2f2f2; }");
        sb.AppendLine("    </style>");
        sb.AppendLine("</head>");
        sb.AppendLine("<body>");
        sb.AppendLine($"    <h1>{title}</h1>");
        sb.AppendLine($"    <p>Total requirements: {requirements.Count}</p>");
        sb.AppendLine("    <table>");
        sb.AppendLine("        <tr>");
        foreach (var header in headers)
        {
            sb.AppendLine($"            <th>{header}</th>");
        }
        sb.AppendLine("        </tr>");
        
        foreach (var req in requirements)
        {
            sb.AppendLine("        <tr>");
            foreach (var header in headers)
            {
                var value = req.ContainsKey(header) ? req[header] : "";
                sb.AppendLine($"            <td>{value}</td>");
            }
            sb.AppendLine("        </tr>");
        }
        
        sb.AppendLine("    </table>");
        sb.AppendLine("</body>");
        sb.AppendLine("</html>");
        
        File.WriteAllText(path, sb.ToString());
        Console.WriteLine($"Generated HTML: {path}");
    }
    
    static string[] ParseCsvLine(string line)
    {
        var fields = new List<string>();
        var inQuotes = false;
        var currentField = new StringBuilder();
        
        for (int i = 0; i < line.Length; i++)
        {
            char c = line[i];
            
            if (c == '"')
            {
                if (inQuotes && i + 1 < line.Length && line[i + 1] == '"')
                {
                    // Escaped quote
                    currentField.Append('"');
                    i++;
                }
                else
                {
                    // Toggle quote state
                    inQuotes = !inQuotes;
                }
            }
            else if (c == ',' && !inQuotes)
            {
                // Field delimiter
                fields.Add(currentField.ToString());
                currentField.Clear();
            }
            else
            {
                currentField.Append(c);
            }
        }
        
        // Add the last field
        fields.Add(currentField.ToString());
        
        return fields.ToArray();
    }
}
