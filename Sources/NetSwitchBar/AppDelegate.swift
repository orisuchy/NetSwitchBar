import AppKit
import Foundation
import Network
import NetSwitchCore
import UserNotifications

private extension ActiveInterface {
    var label: String { self == .ethernet ? "Ethernet" : "Wi-Fi" }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let monitor = NWPathMonitor()
    private var tracker = ConnectionTracker()
    private let notificationsItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
    private var probeTimer: Timer?
    private var asleep = false
    private var routeUp = false
    private var probeGeneration = 0  // newest probe wins; older results are stale
    private var notificationsOn = UserDefaults.standard.object(forKey: "notificationsOn") as? Bool ?? true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(.separator())
        notificationsItem.target = self
        notificationsItem.state = notificationsOn ? .on : .off
        menu.addItem(notificationsItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot = Self.snapshot(from: path)
            Task { @MainActor in self?.apply(snapshot) }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.deliver(self?.tracker.handle(.tick, at: Date().timeIntervalSince1970) ?? []) }
        }
        RunLoop.main.add(ticker, forMode: .common) // .common so ticks keep firing while the menu is open
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.asleep = true; self?.updateProbing() }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            // no immediate probe: the path update after wake probes once the network is back
            MainActor.assumeIsolated { self?.asleep = false; self?.updateProbing() }
        }
        monitor.start(queue: DispatchQueue(label: "netswitchbar.path"))
    }

    private func apply(_ snapshot: NetworkSnapshot) {
        let alerts = tracker.handle(.path(snapshot), at: Date().timeIntervalSince1970)
        render(tracker.displayState)
        deliver(alerts)
        routeUp = snapshot.activeInterface != .none
        updateProbing(probeNow: true)
    }

    /// Probe every 30 s while a route exists and the Mac is awake; never while offline or asleep.
    private func updateProbing(probeNow: Bool = false) {
        guard routeUp, !asleep else {
            probeTimer?.invalidate()
            probeTimer = nil
            return
        }
        if probeTimer == nil {
            let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.probe() }
            }
            RunLoop.main.add(timer, forMode: .common)
            probeTimer = timer
        }
        if probeNow { probe() }
    }

    private func probe() {
        probeGeneration += 1
        let generation = probeGeneration
        Task { @MainActor in
            let succeeded = await Self.reachesInternet()
            guard routeUp, !asleep, generation == probeGeneration else { return }  // outlived its route or was superseded
            let alerts = tracker.handle(.probe(succeeded: succeeded), at: Date().timeIntervalSince1970)
            render(tracker.displayState)
            deliver(alerts)
        }
    }

    private nonisolated static func reachesInternet() async -> Bool {
        var request = URLRequest(url: URL(string: "http://captive.apple.com/hotspot-detect.html")!, timeoutInterval: 5)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    @objc private func toggleNotifications() {
        notificationsOn.toggle()
        notificationsItem.state = notificationsOn ? .on : .off
        UserDefaults.standard.set(notificationsOn, forKey: "notificationsOn")
    }

    private func deliver(_ alerts: [Alert]) {
        guard notificationsOn else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = switch alert {
            case .switched(.wifi): "Switched to Wi-Fi"
            case .switched(.ethernet): "Back on Ethernet"
            case .switched(.none), .offline: "Offline"
            case .backOnline: "Back online"
            case .noInternet(let interface): "Connected via \(interface.label), but no internet"
            case .unstable(let interface, let drops): "\(interface.label) unstable: \(drops) drops in the last minute"
            }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func render(_ state: DisplayState) {
        switch IconResolver.icon(for: state) {
        case .symbol(let name):
            statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            statusItem.button?.title = ""
        case .emoji(let text):
            statusItem.button?.image = nil
            statusItem.button?.title = text
        }
        statusItem.button?.alphaValue = IconResolver.isDimmed(state) ? 0.4 : 1
        statusLine.title = switch state {
        case .ethernet: "Active: Ethernet"
        case .wifi: "Active: Wi-Fi"
        case .offline: "Offline"
        case .noInternet(let interface): "\(interface.label): no internet"
        }
    }

    private nonisolated static func snapshot(from path: NWPath) -> NetworkSnapshot {
        guard path.status == .satisfied else { return NetworkSnapshot(activeInterface: .none) }
        let ethernet = path.usesInterfaceType(.wiredEthernet)
        let wifi = path.usesInterfaceType(.wifi)
        // availableInterfaces is in preference order; take the first one the path actually uses.
        let active: ActiveInterface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }.map {
            switch $0.type {
            case .wiredEthernet: .ethernet
            case .wifi: .wifi
            default: .none // ponytail: VPN/tethering show as offline until a later ticket gives them an icon
            }
        } ?? .none
        return NetworkSnapshot(activeInterface: active, ethernetLink: ethernet, wifiAssociated: wifi)
    }
}
