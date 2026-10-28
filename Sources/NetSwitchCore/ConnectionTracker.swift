

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
    case unstable(ActiveInterface, drops: Int)
}

public struct ConnectionTracker: Sendable {
    public static let settleSeconds = 3.0
    public static let flapWindowSeconds = 60.0
    public static let flapThreshold = 3  // alert when drops exceed this within the window

    public private(set) var displayState: DisplayState = .offline
    private var current: ActiveInterface = .none
    private var announced: ActiveInterface?  // nil until the first path, so launch never alerts
    private var heldSince = 0.0
    private var drops: [(interface: ActiveInterface, time: Double)] = []
    private var flapping = false

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
                // a drop is losing or being demoted from an interface; Wi-Fi yielding to returning Ethernet is not one
                if current != .none, announced != nil, !(current == .wifi && snapshot.activeInterface == .ethernet) { drops.append((current, time)) }
                current = snapshot.activeInterface
                heldSince = time
            }
        }
        guard let last = announced else {
            announced = current
            return []
        }
        drops.removeAll { time - $0.time > Self.flapWindowSeconds }
        if flapping {
            if drops.isEmpty, time - heldSince >= Self.settleSeconds {
                flapping = false  // announced is still the pre-flap state, so a different outcome alerts normally
            }
            return []
        }
        for interface in [ActiveInterface.ethernet, .wifi] {
            let count = drops.filter { $0.interface == interface }.count
            if count > Self.flapThreshold {
                flapping = true
                return [.unstable(interface, drops: count)]
            }
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
