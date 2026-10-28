public enum IconSpec: Equatable, Sendable {
    case symbol(String)
    case emoji(String)
}

public enum IconResolver {
    public static func icon(for state: DisplayState) -> IconSpec {
        switch state {
        case .ethernet: .symbol("cable.connector")
        case .wifi: .symbol("wifi")
        case .offline: .symbol("wifi.slash")
        case .noInternet(let interface): icon(for: interface == .ethernet ? .ethernet : .wifi(ssid: nil))
        }
    }

    public static func isDimmed(_ state: DisplayState) -> Bool {
        if case .noInternet = state { true } else { false }
    }
}
