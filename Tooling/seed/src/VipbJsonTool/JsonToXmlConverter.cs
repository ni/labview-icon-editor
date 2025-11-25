using System.Linq;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    /// <summary>
    /// Converts between XML (.vipb) and JSON, always omitting XML-declaration node.
    /// </summary>
    public static class JsonToXmlConverter
    {
        /// <summary>
        /// Serialize an XmlDocument to JSON, omitting the XML declaration
        /// and optionally omitting the root wrapper (default = true).
        /// </summary>
        public static string XmlToJson(
            XmlDocument doc,
            bool omitRootObject = true,
            Newtonsoft.Json.Formatting formatting = Newtonsoft.Json.Formatting.Indented)
        {
            // --- Strip XML declaration ----------------------------------
            foreach (XmlNode node in doc.ChildNodes.Cast<XmlNode>().ToList())
            {
                if (node.NodeType == XmlNodeType.XmlDeclaration)
                {
                    doc.RemoveChild(node);
                }
            }
            // --- Serialize to JSON --------------------------------------
            return JsonConvert.SerializeXmlNode(doc, formatting, omitRootObject);
        }
    }
}
