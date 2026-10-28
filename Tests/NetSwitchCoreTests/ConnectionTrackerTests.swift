
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

private let eth = NetworkSnapshot(activeInterface: .ethernet, ethernetLink: true)
private let wifi = NetworkSnapshot(activeInterface: .wifi, wifiAssociated: true)
private let none = NetworkSnapshot(activeInterface: .none)

@Suite struct SettleAlertTests {
    private func tracker(on s: NetworkSnapshot) -> ConnectionTracker {
        var t = ConnectionTracker()
        t.handle(.path(s), at: 0)
        return t
    }

    @Test func heldChangeAlertsOnce() {
        var t = tracker(on: eth)
        #expect(t.handle(.path(wifi), at: 10).isEmpty)
        #expect(t.handle(.tick, at: 12.9).isEmpty)
        #expect(t.handle(.tick, at: 13) == [.switched(to: .wifi)])
        #expect(t.handle(.tick, at: 20).isEmpty)
    }

    @Test func blipThatRevertsIsSilent() {
        var t = tracker(on: eth)
        t.handle(.path(wifi), at: 10)
        t.handle(.path(eth), at: 11)
        #expect(t.handle(.tick, at: 20).isEmpty)
    }

    @Test func offlineThenBackOnline() {
        var t = tracker(on: eth)
        t.handle(.path(none), at: 10)
        #expect(t.handle(.tick, at: 13) == [.offline])
        t.handle(.path(eth), at: 20)
        #expect(t.handle(.tick, at: 23) == [.backOnline])
    }

    @Test func iconUpdatesBeforeSettle() {
        var t = tracker(on: eth)
        t.handle(.path(wifi), at: 10)
        #expect(t.displayState == .wifi(ssid: nil))
    }

    @Test func launchDoesNotAlert() {
        var t = ConnectionTracker()
        #expect(t.handle(.path(eth), at: 0).isEmpty)
        #expect(t.handle(.tick, at: 10).isEmpty)
    }
}
