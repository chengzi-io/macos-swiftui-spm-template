# Networking

`URLSession` with async/await and `Codable`; no networking library. The sandbox already
grants `com.apple.security.network.client` (Sparkle needs it). The protocol, the types
it returns, its error and its mock go in the Core of the domain that uses them; release
notes are about the app itself, so `Domains/Platform/ReleaseNotes/`:

```swift
public struct ReleaseNotes: Decodable, Sendable {
    public let title: String

    public init(title: String) { self.title = title }
}

public enum ReleaseNotesError: Error {
    case requestFailed(any Error)
    case badStatus(Int)
    case decodingFailed(any Error)
}

public protocol ReleaseNotesService: Sendable {
    func latest() async throws(ReleaseNotesError) -> ReleaseNotes
}

public struct MockReleaseNotesService: ReleaseNotesService {
    public var notes: ReleaseNotes

    public init(notes: ReleaseNotes = ReleaseNotes(title: "Preview")) { self.notes = notes }

    public func latest() async throws(ReleaseNotesError) -> ReleaseNotes { notes }
}
```

The request goes in `Domains/PlatformLive/ReleaseNotes/`:

```swift
import Foundation
import Platform

public struct LiveReleaseNotesService: ReleaseNotesService {
    let url: URL
    let session: URLSession

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    @concurrent
    public func latest() async throws(ReleaseNotesError) -> ReleaseNotes {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(from: url)
        } catch {
            throw .requestFailed(error)
        }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw .badStatus(status) }
        do {
            return try JSONDecoder().decode(ReleaseNotes.self, from: data)
        } catch {
            throw .decodingFailed(error)
        }
    }
}
```

`Platform` and `PlatformLive` are not MainActor by default, so `ReleaseNotes` decodes
off the main actor as it is. A `nonisolated async` function still runs on its caller's
actor; `@concurrent` moves the request and the decoding off the main actor a model
calls from. Tests and previews pass `MockReleaseNotesService`; they never hit the
network. What the live service decides itself, a bad status or a body that does not
decode, is tested in `PlatformTests` with a session whose configuration's
`protocolClasses` holds a `URLProtocol` that answers with canned responses.
