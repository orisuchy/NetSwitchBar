

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

public enum ConnectionEvent: Equatable, Sendable {
    case path(NetworkSnapshot)
    case tick
    case probe(succeeded: Bool)
}

public enum DisplayState: Equatable, Sendable {
    case ethernet
    case wifi(ssid: String?)
    case offline
    case noInternet(ActiveInterface)  // route exists, internet unreachable
}

public enum Alert: Equatable, Sendable {
    case switched(to: ActiveInterface, ssid: String? = nil)
    case offline
    case backOnline
    case noInternet(ActiveInterface)
    case unstable(ActiveInterface, drops: Int)
}

public struct ConnectionTracker: Sendable {
    public static let settleSeconds = 3.0
    public static let flapWindowSeconds = 60.0
    public static let flapThreshold = 3  // alert when drops exceed this within the window
    public static let probeFailureThreshold = 2

    public var displayState: DisplayState { noInternet ? .noInternet(current) : base }
    private var base: DisplayState = .offline
    private var noInternet = false
    private var probeFailures = 0
    private var noInternetPending = false  // alert owed; released once settled and not flapping
    public private(set) var ethernetPluggedNotActive = false
    private var current: ActiveInterface = .none
    private var currentSSID: String?  // only tracked while Wi-Fi is the active route
    private var announcedSSID: String?
    private var announced: ActiveInterface?  // nil until the first path, so launch never alerts
    private var heldSince = 0.0
    private var drops: [(interface: ActiveInterface, time: Double)] = []
    private var flapping = false

    public init() {}

    @discardableResult
    public mutating func handle(_ event: ConnectionEvent, at time: Double) -> [Alert] {
        if case .path(let snapshot) = event {
            switch snapshot.activeInterface {
            case .ethernet: base = .ethernet
            case .wifi: base = .wifi(ssid: snapshot.ssid)
            case .none: base = .offline
            }
            ethernetPluggedNotActive = snapshot.ethernetLink && snapshot.activeInterface != .ethernet
            let ssid = snapshot.activeInterface == .wifi ? snapshot.ssid : nil
            if snapshot.activeInterface == current, current == .wifi, ssid != currentSSID {
                // a vanished or newly readable SSID is not a network change; only name-to-name is
                if ssid != nil, let known = announcedSSID, ssid != known { heldSince = time }
                else if announcedSSID == nil { announcedSSID = ssid }
                currentSSID = ssid
            }
            if snapshot.activeInterface != current || announced == nil {
                currentSSID = ssid
                noInternet = false
                noInternetPending = false  // the new path gets probed afresh
                probeFailures = 0
                // a drop is losing or being demoted from an interface; Wi-Fi yielding to returning Ethernet is not one
                if current != .none, announced != nil, !(current == .wifi && snapshot.activeInterface == .ethernet) { drops.append((current, time)) }
                current = snapshot.activeInterface
                heldSince = time
            }
        }
        if case .probe(let succeeded) = event, current != .none {
            if succeeded {
                probeFailures = 0
                noInternet = false
                noInternetPending = false
            } else {
                probeFailures += 1
                if probeFailures >= Self.probeFailureThreshold, !noInternet {
                    noInternet = true
                    noInternetPending = true
                }
            }
        }
        guard let last = announced else {
            announced = current
            announcedSSID = currentSSID
            return []
        }
        drops.removeAll { time - $0.time > Self.flapWindowSeconds }
        if flapping {
            if drops.isEmpty, time - heldSince >= Self.settleSeconds {
                flapping = false  // announced is still the pre-flap state, so a different outcome alerts normally
            }
            return []  // a pending noInternet alert waits; the dimmed icon still shows
        }
        for interface in [ActiveInterface.ethernet, .wifi] {
            let count = drops.filter { $0.interface == interface }.count
            if count > Self.flapThreshold {
                flapping = true
                return [.unstable(interface, drops: count)]
            }
        }
        let ssidChanged = current == .wifi && last == .wifi && currentSSID != nil && announcedSSID != nil && currentSSID != announcedSSID
        guard current != last || ssidChanged else {
            guard noInternetPending else { return [] }
            noInternetPending = false
            return [.noInternet(current)]
        }
        guard time - heldSince >= Self.settleSeconds else { return [] }
        announced = current
        announcedSSID = currentSSID
        switch (last, current) {
        case (_, .none): return [.offline]
        case (.none, _): return [.backOnline]
        default: return [.switched(to: current, ssid: currentSSID)]
        }
    }
}
