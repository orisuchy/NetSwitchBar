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
