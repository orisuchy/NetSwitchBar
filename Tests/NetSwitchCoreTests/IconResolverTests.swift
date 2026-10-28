import Testing
@testable import NetSwitchCore

@Suite struct IconResolverTests {
    @Test func defaults() {
        #expect(IconResolver.icon(for: .ethernet) == .symbol("cable.connector"))
        #expect(IconResolver.icon(for: .wifi(ssid: "Office")) == .symbol("wifi"))
        #expect(IconResolver.icon(for: .offline) == .symbol("wifi.slash"))
    }
}
