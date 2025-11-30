
using System.Collections.Generic;
using YamlDotNet.Serialization;
using Newtonsoft.Json.Linq;

namespace VipbJsonTool {
    public static class PatchApplier {
        public static void ApplyYamlPatch(JObject root, string yaml) {
            var deserializer = new DeserializerBuilder().Build();
            var patchMap = deserializer.Deserialize<Dictionary<string, object>>(yaml);
            if (patchMap == null) return;
            if (patchMap.ContainsKey("schema_version")) patchMap.Remove("schema_version");
            if (patchMap.ContainsKey("patch")) {
                var inner = patchMap["patch"] as Dictionary<object, object>;
                patchMap.Clear();
                foreach(var kv in inner) patchMap[(string)kv.Key] = kv.Value;
            }
            foreach(var kvp in patchMap) {
                var path = kvp.Key;
                var value = kvp.Value == null ? null : JToken.FromObject(kvp.Value);
                ApplyPath(root, path.Split('.'), 0, value);
            }
        }

        private static void ApplyPath(JToken node, string[] parts, int idx, JToken value) {
            if (idx == parts.Length) return;
            var part = parts[idx];
            if (part.Contains('[')) {
                var name = part.Substring(0, part.IndexOf('['));
                var posStr = part.Substring(part.IndexOf('[')+1).TrimEnd(']');
                var pos = int.Parse(posStr);
                var arr = node[name] as JArray;
                if (arr == null) {
                    arr = new JArray();
                    node[name] = arr;
                }
                while (arr.Count <= pos) arr.Add(new JObject());
                if (idx == parts.Length-1) {
                    arr[pos] = value;
                } else {
                    ApplyPath(arr[pos], parts, idx+1, value);
                }
            } else {
                if (idx == parts.Length-1) {
                    node[part] = value;
                } else {
                    var child = node[part];
                    if (child == null || child.Type != JTokenType.Object) {
                        child = new JObject();
                        node[part] = child;
                    }
                    ApplyPath(child, parts, idx+1, value);
                }
            }
        }
    }
}
