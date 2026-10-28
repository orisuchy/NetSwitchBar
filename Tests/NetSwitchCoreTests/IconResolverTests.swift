import Testing
@testable import NetSwitchCore

@Suite struct IconResolverTests {
    @Test func defaults() {
        #expect(IconResolver.icon(for: .ethernet) == .symbol("cable.connector"))
        #expect(IconResolver.icon(for: .wifi(ssid: "Office")) == .symbol("wifi"))
        #expect(IconResolver.icon(for: .offline) == .symbol("wifi.slash"))
    }

    @Test func noInternetUsesInterfaceIconDimmed() {
        #expect(IconResolver.icon(for: .noInternet(.wifi)) == .symbol("wifi"))
        #expect(IconResolver.icon(for: .noInternet(.ethernet)) == .symbol("cable.connector"))
        #expect(IconResolver.isDimmed(.noInternet(.wifi)))
        #expect(!IconResolver.isDimmed(.wifi(ssid: nil)))
        #expect(!IconResolver.isDimmed(.offline))
    }
}

@Suite struct CustomIconTests {
    let store = InMemoryIconStore()

    @Test func ssidMappingBeatsUnknownWifiFallback() {
        store.setIcon("🏠", for: .ssid("Home"))
        store.setIcon("antenna.radiowaves.left.and.right", for: .unknownWifi)
        #expect(IconResolver.icon(for: .wifi(ssid: "Home"), store: store) == .emoji("🏠"))
    }

    @Test func fallbackForUnmappedAndNilSSID() {
        store.setIcon("star", for: .unknownWifi)
        #expect(IconResolver.icon(for: .wifi(ssid: "Cafe"), store: store) == .symbol("star"))
        #expect(IconResolver.icon(for: .wifi(ssid: nil), store: store) == .symbol("star"))
    }

    @Test func ethernetMappingAndDefaults() {
        #expect(IconResolver.icon(for: .ethernet, store: store) == .symbol("cable.connector"))
        #expect(IconResolver.icon(for: .wifi(ssid: "Home"), store: store) == .symbol("wifi"))
        store.setIcon("briefcase", for: .ethernet)
        #expect(IconResolver.icon(for: .ethernet, store: store) == .symbol("briefcase"))
        store.setIcon(nil, for: .ethernet)
        #expect(IconResolver.icon(for: .ethernet, store: store) == .symbol("cable.connector"))
    }

    @Test func noInternetKeepsCustomIconDimmed() {
        store.setIcon("🏠", for: .ssid("Home"))
        #expect(IconResolver.icon(for: .noInternet(.wifi), ssid: "Home", store: store) == .emoji("🏠"))
        #expect(IconResolver.isDimmed(.noInternet(.wifi)))
    }

    @Test func classification() {
        #expect(IconSpec(parsing: "🏠") == .emoji("🏠"))
        #expect(IconSpec(parsing: "briefcase") == .symbol("briefcase"))
        #expect(IconSpec(parsing: "wifi.circle") == .symbol("wifi.circle"))
        #expect(IconSpec(parsing: "1.circle") == .symbol("1.circle"))
        #expect(IconSpec(parsing: "1️⃣") == .emoji("1️⃣"))
        #expect(IconSpec(parsing: "👨‍👩‍👧") == .emoji("👨‍👩‍👧"))
        #expect(IconSpec(parsing: "abc🏠") == .symbol("abc🏠"))
    }

    @Test func keyForCurrentConnection() {
        #expect(IconKey(state: .ethernet) == .ethernet)
        #expect(IconKey(state: .wifi(ssid: "A")) == .ssid("A"))
        #expect(IconKey(state: .wifi(ssid: nil)) == .unknownWifi)
        #expect(IconKey(state: .noInternet(.wifi), ssid: "A") == .ssid("A"))
        #expect(IconKey(state: .offline) == nil)
    }
}
