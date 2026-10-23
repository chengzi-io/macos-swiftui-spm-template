import GreetingFeature
import Observation
import Services

/// Root of the model tree: owns each feature's model and the services they share.
@Observable
public final class AppModel {
    public let greeting = GreetingModel()
    public let updater: any UpdaterService

    public init(updater: any UpdaterService) {
        self.updater = updater
    }
}
