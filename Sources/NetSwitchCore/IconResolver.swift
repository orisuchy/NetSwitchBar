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
        }
    }
}
