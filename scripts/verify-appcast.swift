import CryptoKit
import Foundation

// Checks an appcast the way Sparkle in an installed app does: one enclosure, at the
// DMG's download URL, with its length, signed by the key whose public half the app
// ships (SPARKLE_PUBLIC_KEY). A wrong key or URL fails no build step; it fails every
// installed app's next update.
// usage: verify-appcast.swift <appcast.xml> <dmg> <download url> <public key>

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 5 else { fail("usage: verify-appcast.swift <appcast.xml> <dmg> <download url> <public key>") }
let (appcastPath, dmgPath, url, publicKey) = (args[1], args[2], args[3], args[4])

guard let keyData = Data(base64Encoded: publicKey),
    let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
else { fail("SPARKLE_PUBLIC_KEY is not a base64 Ed25519 public key") }

let appcast: XMLDocument
let dmg: Data
do {
    appcast = try XMLDocument(contentsOf: URL(fileURLWithPath: appcastPath))
    dmg = try Data(contentsOf: URL(fileURLWithPath: dmgPath))
} catch {
    fail("cannot read \(error.localizedDescription)")
}

guard let enclosures = try? appcast.nodes(forXPath: "//item/enclosure") as? [XMLElement],
    enclosures.count == 1
else { fail("\(appcastPath) needs exactly one enclosure") }
let enclosure = enclosures[0]

guard enclosure.attribute(forName: "url")?.stringValue == url else {
    fail("\(appcastPath) points at \(enclosure.attribute(forName: "url")?.stringValue ?? "nothing"), not \(url)")
}
guard enclosure.attribute(forName: "length")?.stringValue == String(dmg.count) else {
    fail("\(appcastPath) gives a length other than \(dmgPath)'s \(dmg.count) bytes")
}
guard
    let signature = enclosure.attribute(forName: "sparkle:edSignature")?.stringValue
        .flatMap({ Data(base64Encoded: $0) }),
    key.isValidSignature(signature, for: dmg)
else { fail("\(appcastPath) is not signed with the key matching SPARKLE_PUBLIC_KEY") }
