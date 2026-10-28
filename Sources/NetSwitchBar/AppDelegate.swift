import AppKit
import Foundation
import Network
import NetSwitchCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let monitor = NWPathMonitor()
    private var tracker = ConnectionTracker()
    private let notificationsItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
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
        monitor.start(queue: DispatchQueue(label: "netswitchbar.path"))
    }

    private func apply(_ snapshot: NetworkSnapshot) {
        let alerts = tracker.handle(.path(snapshot), at: Date().timeIntervalSince1970)
        render(tracker.displayState)
        deliver(alerts)
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
            case .unstable(let interface, let drops): "\(interface == .ethernet ? "Ethernet" : "Wi-Fi") unstable: \(drops) drops in the last minute"
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
        statusLine.title = switch state {
        case .ethernet: "Active: Ethernet"
        case .wifi: "Active: Wi-Fi"
        case .offline: "Offline"
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
