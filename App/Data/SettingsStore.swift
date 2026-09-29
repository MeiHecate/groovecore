import Foundation
import Observation
import GrooveKit

@MainActor @Observable
final class SettingsStore {
    private enum Keys {
        static let settings = "settings.v1"
        static let onboarded = "onboarded.v1"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var settings: GrooveSettings {
        didSet { defaults.set(try? JSONEncoder().encode(settings), forKey: Keys.settings) }
    }

    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.settings),
           let decoded = try? JSONDecoder().decode(GrooveSettings.self, from: data) {
            settings = decoded
        } else {
            settings = GrooveSettings()
        }
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
    }
}
