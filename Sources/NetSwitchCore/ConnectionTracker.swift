

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
    case tick
}

public enum DisplayState: Equatable, Sendable {
    case ethernet
    case wifi(ssid: String?)
    case offline
}

public enum Alert: Equatable, Sendable {
    case switched(to: ActiveInterface)
    case offline
    case backOnline
}

public struct ConnectionTracker: Sendable {
    public static let settleSeconds = 3.0

    public private(set) var displayState: DisplayState = .offline
    private var current: ActiveInterface = .none
    private var announced: ActiveInterface?  // nil until the first path, so launch never alerts
    private var heldSince = 0.0

    public init() {}

    @discardableResult
    public mutating func handle(_ event: ConnectionEvent, at time: Double) -> [Alert] {
        if case .path(let snapshot) = event {
            switch snapshot.activeInterface {
            case .ethernet: displayState = .ethernet
            case .wifi: displayState = .wifi(ssid: snapshot.ssid)
            case .none: displayState = .offline
            }
            if snapshot.activeInterface != current || announced == nil {
                current = snapshot.activeInterface
                heldSince = time
            }
        }
        guard let last = announced else {
            announced = current
            return []
        }
        guard current != last, time - heldSince >= Self.settleSeconds else { return [] }
        announced = current
        switch (last, current) {
        case (_, .none): return [.offline]
        case (.none, _): return [.backOnline]
        default: return [.switched(to: current)]
        }
    }
}
