# SwiftData

`@Query` keeps a view's list current as the store changes; a service in front of the
store would give that up. So SwiftData is the one store without a service: a view reads
with `@Query`, the feature's model writes through a `ModelContext`, and tests use an
in-memory store in place of a mock. The model types belong to a domain, so they go in
its Core, which imports SwiftData. A `Library` domain that keeps bookmarks, in
`Sources/Library/Core/Bookmark/`:

```swift
import Foundation
import SwiftData

@Model
public final class Bookmark {
    public var title: String
    public var createdAt: Date

    public init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }
}

extension ModelContainer {
    /// The library on disk, in the app's container.
    public static func library() throws -> ModelContainer {
        try ModelContainer(for: Bookmark.self)
    }

    /// An empty library in memory, for UI tests, previews and tests. Only a schema that
    /// SwiftData cannot use makes it fail, and no run recovers from that.
    public static func libraryInMemory() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Bookmark.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("library schema: \(error)")
        }
    }
}
```

`App/Application/MainApp.swift` builds the container, `.libraryInMemory()` under
`UI_TESTING=1` and `try .library()` otherwise, and stops with `fatalError` when the
library cannot open: the migration plan below is what keeps that from happening. It
passes the container to `AppModel`, which keeps it and builds
`BookmarksModel(context: container.mainContext)`; `AppScenes` sets
`.modelContainer(model.library)` on the scene. The feature's model makes every change
and saves it, with a `Log.swift` that declares a `bookmarks` category:

```swift
import Library
import OSLog
import Observation
import SwiftData

@Observable
public final class BookmarksModel {
    public private(set) var saveFailed = false
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func add(title: String) {
        context.insert(Bookmark(title: title))
        save()
    }

    public func delete(_ bookmark: Bookmark) {
        context.delete(bookmark)
        save()
    }

    // SwiftData autosaves when it chooses. Save each change, and undo it when the store
    // refuses, so the list never shows what was not stored.
    private func save() {
        do {
            try context.save()
            saveFailed = false
        } catch {
            Log.bookmarks.error("save failed: \(String(describing: error))")
            context.rollback()
            saveFailed = true
        }
    }
}
```

The view reads with `@Query` and hands every change to the model. Its preview, like its
render tests, sets an in-memory container; without one it fails when it runs, not when
it builds:

```swift
import Library
import SwiftData
import SwiftUI

struct BookmarksView: View {
    let model: BookmarksModel
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        List(bookmarks) { bookmark in
            Text(bookmark.title)
                .contextMenu {
                    Button(role: .destructive) {
                        model.delete(bookmark)
                    } label: {
                        Text("Delete", bundle: .module)
                    }
                }
        }
        .safeAreaInset(edge: .bottom) {
            if model.saveFailed {
                Text("The change could not be saved.", bundle: .module)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

#Preview {
    let container = ModelContainer.libraryInMemory()
    container.mainContext.insert(Bookmark(title: "Grapefruit"))
    return BookmarksView(model: BookmarksModel(context: container.mainContext))
        .modelContainer(container)
}
```

Tests run the model against an in-memory library. A second context sees only what was
saved:

```swift
import BookmarksFeature
import Library
import SwiftData
import Testing

@MainActor
struct BookmarksModelTests {
    let container = ModelContainer.libraryInMemory()

    @Test func addedBookmarkIsSaved() throws {
        let model = BookmarksModel(context: container.mainContext)
        model.add(title: "Grapefruit")
        let saved = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
        #expect(saved.map(\.title) == ["Grapefruit"])
        #expect(!model.saveFailed)
    }
}
```

The rest:

- A `@Model` instance and a `ModelContext` stay on the actor that fetched them. Another
  actor gets the instance's `persistentModelID`, which is temporary until the first
  save, and fetches it again.
- Before the first release, version the schema: a `VersionedSchema` for each shipped
  schema and a `SchemaMigrationPlan` for `library()`, so that a later change migrates
  the user's store instead of failing to open it. Give each relationship an explicit
  delete rule and inverse.
- Long work (an import, a sync) runs in a `@ModelActor` in the domain's Live, on its own
  context. On macOS 14, check that the views show what it saves: early SwiftData did
  not always refresh `@Query` after another context saved.
- Add the strings to the feature's catalog. Paul Hudson's
  [SwiftData skill](https://github.com/twostraws/SwiftData-Agent-Skill) lists the
  predicates that crash at run time and other traps; an app built on SwiftData can add
  it to `.agents/skills/`.
