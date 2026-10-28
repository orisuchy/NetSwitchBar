

public enum ActiveInterface: Equatable, Sendable {
    case ethernet, wifi, none
}

public struct NetworkSnapshot: Equatable, Sendable {
    public var activeInterface: ActiveInterface
    public var ethernetLink: Bool
    public var wifiAssociated: Bool
    public var ssid: String?

    public init(activeInterface: ActiveInterface, ethernetLink: Bool = false, wifiAssociated: Bool = false, ssid: String? = nil) {
        self.activeInterface = activeInterface
        self.ethernetLink = ethernetLink
        self.wifiAssociated = wifiAssociated
        self.ssid = ssid
    }
}

/// `probe` and `tick` get added here by later tickets.
public enum ConnectionEvent: Equatable, Sendable {
    case path(NetworkSnapshot)
}

public enum DisplayState: Equatable, Sendable {
    case ethernet
    case wifi(ssid: String?)
    case offline
}

public struct ConnectionTracker: Sendable {
    public private(set) var displayState: DisplayState = .offline

    public init() {}

    /// Time (seconds, any monotonic origin) is supplied by the caller, never read from a clock here.
    public mutating func handle(_ event: ConnectionEvent, at time: Double) {
        switch event {
        case .path(let snapshot):
            switch snapshot.activeInterface {
            case .ethernet: displayState = .ethernet
            case .wifi: displayState = .wifi(ssid: snapshot.ssid)
            case .none: displayState = .offline
            }
        }
    }
}
