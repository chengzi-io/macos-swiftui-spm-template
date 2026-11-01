import Foundation

// Fails on property names this Xcode's Icon Composer (1.2) does not read. actool reports
// bad values, but it ignores an unknown name at the root, group or layer level, so a
// misspelled "glas", or "refractivity" from a newer Icon Composer, silently does nothing.
// Extend the lists when the repo moves to a newer Xcode.
// usage: lint-icon.swift <icon.json>

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// Names in files Icon Composer saves. Each can also vary by appearance or platform as
// "<name>-specializations": [{"value": …}, {"appearance": "dark", "value": …}, …].
let rootNames: Set = ["fill", "groups", "supported-platforms", "color-space-for-untagged-svg-colors"]
let groupNames: Set = [
    "layers", "name", "hidden", "blend-mode", "blur-material", "lighting", "opacity", "position", "shadow",
    "specular", "translucency",
]
let layerNames: Set = ["image-name", "name", "glass", "hidden", "blend-mode", "fill", "opacity", "position"]

guard CommandLine.arguments.count == 2 else { fail("usage: lint-icon.swift <icon.json>") }
let path = CommandLine.arguments[1]
let document: [String: Any]
do {
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))
    guard let dictionary = object as? [String: Any] else { fail("\(path) is not a JSON object") }
    document = dictionary
} catch {
    fail("cannot read \(path): \(error.localizedDescription)")
}

var problems: [String] = []
func check(_ object: [String: Any], _ names: Set<String>, at place: String) {
    for key in object.keys.sorted() {
        let base = key.hasSuffix("-specializations") ? String(key.dropLast("-specializations".count)) : key
        guard names.contains(base) else {
            problems.append("\(place): unknown property \"\(key)\"")
            continue
        }
        if key != base {
            for entry in object[key] as? [[String: Any]] ?? []
            where !Set(entry.keys).isSubset(of: ["appearance", "idiom", "value"]) {
                problems.append("\(place): \"\(key)\" entries take only \"appearance\", \"idiom\" and \"value\"")
            }
        }
    }
}

check(document, rootNames, at: "root")
for (g, group) in (document["groups"] as? [[String: Any]] ?? []).enumerated() {
    check(group, groupNames, at: "groups[\(g)]")
    for (l, layer) in (group["layers"] as? [[String: Any]] ?? []).enumerated() {
        check(layer, layerNames, at: "groups[\(g)].layers[\(l)]")
    }
}
guard problems.isEmpty else {
    fail(
        "\(path):\n  " + problems.joined(separator: "\n  ")
            + "\n  Fix the name, or drop it if a newer Icon Composer wrote it: this Xcode ignores it.")
}
