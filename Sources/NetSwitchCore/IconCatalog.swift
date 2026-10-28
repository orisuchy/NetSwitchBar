import Foundation
public enum IconCatalog {
    /// Curated SF Symbols for networks and places. The app filters out names the running macOS lacks.
    public static let symbols: [String] = [
        "house", "house.fill", "building", "building.2", "building.columns", "briefcase", "briefcase.fill",
        "cup.and.saucer", "cup.and.saucer.fill", "fork.knife", "airplane", "tram", "bus", "car", "car.fill",
        "bicycle", "bed.double", "books.vertical", "graduationcap", "cart", "cart.fill", "cross.case",
        "cross", "globe", "network", "wifi", "wifi.circle", "wifi.router", "wifi.slash",
        "wifi.exclamationmark", "cable.connector", "antenna.radiowaves.left.and.right", "personalhotspot",
        "phone", "iphone", "laptopcomputer", "desktopcomputer", "display", "server.rack", "externaldrive",
        "printer", "tv", "lock", "lock.fill", "lock.shield", "shield", "shield.fill", "star", "star.fill",
        "heart", "heart.fill", "flag", "flag.fill", "bolt", "bolt.fill", "leaf", "leaf.fill", "moon",
        "moon.fill", "sun.max", "sun.max.fill", "cloud", "flame", "drop", "pawprint", "gamecontroller",
        "music.note", "camera", "map", "mappin.and.ellipse", "location", "key", "gearshape", "wrench.and.screwdriver",
        "hammer", "tent", "mountain.2", "beach.umbrella", "ferry", "sailboat", "figure.walk", "person.2",
        "person.3", "bag", "gift", "bell",
    ]

    /// Case-insensitive substring match on the symbol name; blank query returns everything.
    public static func filter(_ names: [String], query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? names : names.filter { $0.lowercased().contains(q) }
    }
}
