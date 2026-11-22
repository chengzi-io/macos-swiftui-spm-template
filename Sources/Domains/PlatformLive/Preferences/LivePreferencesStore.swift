import Foundation
import Platform

/// Stores preferences in UserDefaults under each key's name; in the sandbox that is the
/// app's own defaults in its container.
@MainActor
public final class LivePreferencesStore: PreferencesStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public subscript<Value>(key: PreferenceKey<Value>) -> Value {
        get { defaults.object(forKey: key.name).flatMap(Value.init(propertyListValue:)) ?? key.defaultValue }
        set {
            if let value = newValue.propertyListValue {
                defaults.set(value, forKey: key.name)
            } else {
                defaults.removeObject(forKey: key.name)
            }
        }
    }

    public func removeValue<Value>(for key: PreferenceKey<Value>) {
        defaults.removeObject(forKey: key.name)
    }
}
