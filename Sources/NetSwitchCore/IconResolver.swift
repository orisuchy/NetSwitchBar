public enum IconSpec: Equatable, Sendable {
    case symbol(String)
    case emoji(String)

    /// Emoji if it is a single character with an emoji scalar (digits and `#` are emoji too, but only as keycaps with U+FE0F); otherwise an SF Symbol name.
    public init(parsing text: String) {
        let isEmoji = text.count == 1 && text.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x7F) || $0.value == 0xFE0F
        }
        self = isEmoji ? .emoji(text) : .symbol(text)
    }
}

public enum IconKey: Hashable, Sendable {
    case ethernet
    case ssid(String)
    case unknownWifi

    /// The mapping the current connection edits; nil while offline. `ssid` covers `.noInternet`, which doesn't carry one.
    public init?(state: DisplayState, ssid: String? = nil) {
        switch state {
        case .ethernet, .noInternet(.ethernet): self = .ethernet
        case .wifi(let s): self = (s ?? ssid).map(IconKey.ssid) ?? .unknownWifi
        case .noInternet(.wifi): self = ssid.map(IconKey.ssid) ?? .unknownWifi
        case .offline, .noInternet(.none): return nil
        }
    }
}

public protocol IconStore {
    func icon(for key: IconKey) -> String?
    func setIcon(_ icon: String?, for key: IconKey)  // nil resets to default
}

public final class InMemoryIconStore: IconStore {
    private var icons: [IconKey: String] = [:]
    public init() {}
    public func icon(for key: IconKey) -> String? { icons[key] }
    public func setIcon(_ icon: String?, for key: IconKey) { icons[key] = icon }
}

public enum IconResolver {
    /// `ssid` supplies the network for `.noInternet`, which doesn't carry one.
    public static func icon(for state: DisplayState, ssid: String? = nil, store: IconStore? = nil) -> IconSpec {
        if let key = IconKey(state: state, ssid: ssid), let store {
            // a specific SSID falls back to the unknown-Wi-Fi mapping
            let fallback = key == .ethernet ? nil : store.icon(for: .unknownWifi)
            if let custom = store.icon(for: key) ?? fallback { return IconSpec(parsing: custom) }
        }
        switch state {
        case .ethernet: return .symbol("cable.connector")
        case .wifi: return .symbol("wifi")
        case .offline: return .symbol("wifi.slash")
        case .noInternet(let interface): return icon(for: interface == .ethernet ? .ethernet : .wifi(ssid: nil))
        }
    }

    public static func isDimmed(_ state: DisplayState) -> Bool {
        if case .noInternet = state { true } else { false }
    }
}
