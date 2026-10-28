
import Testing
@testable import NetSwitchCore

private func state(after snapshot: NetworkSnapshot) -> DisplayState {
    var tracker = ConnectionTracker()
    tracker.handle(.path(snapshot), at: 0)
    return tracker.displayState
}

@Suite struct ConnectionTrackerTests {
    @Test func ethernetActive() {
        #expect(state(after: .init(activeInterface: .ethernet, ethernetLink: true)) == .ethernet)
    }

    @Test func wifiActive() {
        #expect(state(after: .init(activeInterface: .wifi, wifiAssociated: true, ssid: "Office")) == .wifi(ssid: "Office"))
    }

    @Test func noRouteIsOffline() {
        #expect(state(after: .init(activeInterface: .none)) == .offline)
    }

    @Test func bothUpEthernetActiveShowsEthernet() {
        let s = NetworkSnapshot(activeInterface: .ethernet, ethernetLink: true, wifiAssociated: true, ssid: "Office")
        #expect(state(after: s) == .ethernet)
    }

    @Test func followsRouteAcrossEvents() {
        var t = ConnectionTracker()
        t.handle(.path(.init(activeInterface: .ethernet, ethernetLink: true)), at: 0)
        t.handle(.path(.init(activeInterface: .wifi, wifiAssociated: true)), at: 1)
        #expect(t.displayState == .wifi(ssid: nil))
        t.handle(.path(.init(activeInterface: .none)), at: 2)
        #expect(t.displayState == .offline)
    }
}
