import AppKit
import Foundation
import Network
import NetSwitchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let monitor = NWPathMonitor()
    private var tracker = ConnectionTracker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot = Self.snapshot(from: path)
            Task { @MainActor in self?.apply(snapshot) }
        }
        monitor.start(queue: DispatchQueue(label: "netswitchbar.path"))
    }

    private func apply(_ snapshot: NetworkSnapshot) {
        tracker.handle(.path(snapshot), at: ProcessInfo.processInfo.systemUptime)
        render(tracker.displayState)
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
