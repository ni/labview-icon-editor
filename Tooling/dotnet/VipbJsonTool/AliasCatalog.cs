using System.Collections.Generic;
using YamlDotNet.Serialization;

namespace VipbJsonTool
{
    public record AliasCatalog
    {
        [YamlMember(Alias = "schema_version")]
        public int schema_version { get; init; }

        [YamlMember(Alias = "aliases")]
        public Dictionary<string, string> aliases { get; init; }
    }
}
