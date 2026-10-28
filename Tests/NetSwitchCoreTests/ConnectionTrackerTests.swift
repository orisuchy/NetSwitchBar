
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

@Suite struct FlappingTests {
    /// Drops `base` to `none` and recovers each second, starting at t=1.
    private func flap(_ t: inout ConnectionTracker, from base: NetworkSnapshot, drops: Int) -> [Alert] {
        var alerts: [Alert] = []
        for i in 0..<drops {
            alerts += t.handle(.path(none), at: Double(1 + 2 * i))
            alerts += t.handle(.path(base), at: Double(2 + 2 * i))
        }
        return alerts
    }

    private func tracker(on s: NetworkSnapshot) -> ConnectionTracker {
        var t = ConnectionTracker()
        t.handle(.path(s), at: 0)
        return t
    }

    @Test func ethernetFlapAlertsOnce() {
        var t = tracker(on: eth)
        #expect(flap(&t, from: eth, drops: 5) == [.unstable(.ethernet, drops: 4)])
    }

    @Test func wifiFlapAlertsOnce() {
        var t = tracker(on: wifi)
        #expect(flap(&t, from: wifi, drops: 5) == [.unstable(.wifi, drops: 4)])
    }

    @Test func threeDropsIsNotUnstable() {
        var t = tracker(on: eth)
        #expect(flap(&t, from: eth, drops: 3).isEmpty)
        #expect(t.handle(.tick, at: 20).isEmpty)
    }

    @Test func normalAlertsResumeAfterWindowClears() {
        var t = tracker(on: eth)
        _ = flap(&t, from: eth, drops: 4)
        #expect(t.handle(.tick, at: 30).isEmpty)  // still inside the window
        #expect(t.handle(.tick, at: 80).isEmpty)  // clears silently
        t.handle(.path(wifi), at: 90)
        #expect(t.handle(.tick, at: 93) == [.switched(to: .wifi)])
    }

    @Test func flapEndingOnDifferentInterfaceIsAnnounced() {
        var t = tracker(on: eth)
        _ = flap(&t, from: eth, drops: 4)
        t.handle(.path(wifi), at: 20)
        #expect(t.handle(.tick, at: 30).isEmpty)  // suppressed while the window is open
        #expect(t.handle(.tick, at: 81).isEmpty)  // the t=20 switch was a drop too; window clears here
        #expect(t.handle(.tick, at: 82) == [.switched(to: .wifi)])
    }

    @Test func ethernetFlapViaWifiDoesNotRaiseWifiAlert() {
        var t = tracker(on: eth)
        var alerts: [Alert] = []
        for i in 0..<5 {
            alerts += t.handle(.path(wifi), at: Double(1 + 2 * i))
            alerts += t.handle(.path(eth), at: Double(2 + 2 * i))
        }
        #expect(alerts == [.unstable(.ethernet, drops: 4)])
    }
}

@Suite struct NoInternetTests {
    private func tracker(on s: NetworkSnapshot) -> ConnectionTracker {
        var t = ConnectionTracker()
        t.handle(.path(s), at: 0)
        return t
    }

    @Test func oneFailureIsStillConnected() {
        var t = tracker(on: wifi)
        #expect(t.handle(.probe(succeeded: false), at: 10).isEmpty)
        #expect(t.displayState == .wifi(ssid: nil))
    }

    @Test func twoFailuresRaiseNoInternetOnce() {
        var t = tracker(on: wifi)
        t.handle(.probe(succeeded: false), at: 10)
        #expect(t.handle(.probe(succeeded: false), at: 40) == [.noInternet(.wifi)])
        #expect(t.displayState == .noInternet(.wifi))
        #expect(t.handle(.probe(succeeded: false), at: 70).isEmpty)
    }

    @Test func successBetweenFailuresResetsCount() {
        var t = tracker(on: eth)
        t.handle(.probe(succeeded: false), at: 10)
        t.handle(.probe(succeeded: true), at: 40)
        #expect(t.handle(.probe(succeeded: false), at: 70).isEmpty)
        #expect(t.displayState == .ethernet)
    }

    @Test func successClearsNoInternet() {
        var t = tracker(on: wifi)
        t.handle(.probe(succeeded: false), at: 10)
        t.handle(.probe(succeeded: false), at: 40)
        t.handle(.probe(succeeded: true), at: 70)
        #expect(t.displayState == .wifi(ssid: nil))
    }

    @Test func samePathUpdateKeepsNoInternet() {
        var t = tracker(on: wifi)
        t.handle(.probe(succeeded: false), at: 10)
        t.handle(.probe(succeeded: false), at: 40)
        t.handle(.path(wifi), at: 50)
        #expect(t.displayState == .noInternet(.wifi))
    }

    @Test func interfaceChangeClearsNoInternet() {
        var t = tracker(on: wifi)
        t.handle(.probe(succeeded: false), at: 10)
        t.handle(.probe(succeeded: false), at: 40)
        t.handle(.path(eth), at: 50)
        #expect(t.displayState == .ethernet)
    }

    @Test func probeResultsWhileOfflineAreIgnored() {
        var t = tracker(on: none)
        t.handle(.probe(succeeded: false), at: 10)
        #expect(t.handle(.probe(succeeded: false), at: 40).isEmpty)
        #expect(t.displayState == .offline)
        t.handle(.path(wifi), at: 50)
        t.handle(.tick, at: 53)  // drain the settled backOnline
        #expect(t.handle(.probe(succeeded: false), at: 60).isEmpty)  // count restarted
    }

    @Test func alertDuringFlappingIsDeferredUntilItClears() {
        var t = tracker(on: eth)
        for i in 0..<5 {
            t.handle(.path(none), at: Double(1 + 2 * i))
            t.handle(.path(eth), at: Double(2 + 2 * i))
        }
        t.handle(.probe(succeeded: false), at: 11)
        #expect(t.handle(.probe(succeeded: false), at: 12).isEmpty)
        #expect(t.displayState == .noInternet(.ethernet))
        #expect(t.handle(.tick, at: 70).isEmpty)  // flapping clears silently
        #expect(t.handle(.tick, at: 71) == [.noInternet(.ethernet)])
    }
}
