import Foundation

/// A value a preference can hold: it converts to and from a property-list value, which is
/// what UserDefaults stores. `Bool`, `Int`, `Double`, `String`, `Data` and `Date` conform;
/// an enum with one of those as its raw value conforms with an empty extension, a
/// `Codable` type through `CodablePreferenceValue`.
public protocol PreferenceValue: Sendable {
    /// nil from a value that cannot be read back, such as one an older version wrote.
    init?(propertyListValue: Any)
    /// nil removes the stored value, so the key reads as its default.
    var propertyListValue: Any? { get }
}

/// A preference's name in the store and the value it has until the user changes it.
/// Declare one where the setting's owner is, as a computed static property, so a call
/// site reads `preferences[.appearance]`:
///
/// ```swift
/// extension PreferenceKey where Value == Appearance {
///     public static var appearance: Self { Self("appearance", default: .system) }
/// }
/// ```
public struct PreferenceKey<Value: PreferenceValue>: Sendable {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// The app's plain preferences: values the app only stores and reads back. A setting that
/// changes the system or calls an API on change gets its own service as well, which the
/// model calls after writing the preference.
@MainActor
public protocol PreferencesStore: AnyObject {
    /// The stored value, or the key's default when none is stored or it cannot be read.
    subscript<Value>(key: PreferenceKey<Value>) -> Value { get set }
    /// Back to the default.
    func removeValue<Value>(for key: PreferenceKey<Value>)
}

/// Keeps values in memory, converted the way the live store converts them, so a value that
/// would not survive UserDefaults fails a test too.
@MainActor
public final class MockPreferencesStore: PreferencesStore {
    private var values: [String: Any]

    /// `values` by key name, as property-list values: `["appearance": "dark"]`.
    public init(values: [String: Any] = [:]) {
        self.values = values
    }

    public subscript<Value>(key: PreferenceKey<Value>) -> Value {
        get { values[key.name].flatMap(Value.init(propertyListValue:)) ?? key.defaultValue }
        set { values[key.name] = newValue.propertyListValue }
    }

    public func removeValue<Value>(for key: PreferenceKey<Value>) {
        values[key.name] = nil
    }
}

// MARK: - Values

extension Bool: PreferenceValue {}
extension Int: PreferenceValue {}
extension Double: PreferenceValue {}
extension String: PreferenceValue {}
extension Data: PreferenceValue {}
extension Date: PreferenceValue {}

extension PreferenceValue {
    public init?(propertyListValue: Any) {
        guard let value = propertyListValue as? Self else { return nil }
        self = value
    }

    public var propertyListValue: Any? { self }
}

extension PreferenceValue where Self: RawRepresentable, RawValue: PreferenceValue {
    public init?(propertyListValue: Any) {
        guard let rawValue = RawValue(propertyListValue: propertyListValue) else { return nil }
        self.init(rawValue: rawValue)
    }

    public var propertyListValue: Any? { rawValue.propertyListValue }
}

/// A `Codable` value stored as JSON `Data`. A stored value that no longer decodes reads as
/// the key's default.
public protocol CodablePreferenceValue: PreferenceValue, Codable {}

extension CodablePreferenceValue {
    public init?(propertyListValue: Any) {
        guard let data = propertyListValue as? Data,
            let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = value
    }

    public var propertyListValue: Any? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            // Only a value JSON cannot express (a non-finite Double) gets here.
            assertionFailure("\(Self.self) does not encode as JSON: \(error)")
            return nil
        }
    }
}
