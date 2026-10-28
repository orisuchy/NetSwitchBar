import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Network
import NetSwitchCore
import SystemConfiguration
import UserNotifications

private struct DefaultsIconStore: IconStore {
    func icon(for key: IconKey) -> String? { UserDefaults.standard.string(forKey: Self.name(key)) }
    func setIcon(_ icon: String?, for key: IconKey) { UserDefaults.standard.set(icon, forKey: Self.name(key)) }
    private static func name(_ key: IconKey) -> String {
        switch key {
        case .ethernet: "icon.ethernet"
        case .ssid(let s): "icon.ssid.\(s)"
        case .unknownWifi: "icon.unknownWifi"
        }
    }
}

private extension ActiveInterface {
    var label: String { self == .ethernet ? "Ethernet" : "Wi-Fi" }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate, CWEventDelegate, NSTextFieldDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let ethernetLine = NSMenuItem(title: "Ethernet: plugged in, not active", action: nil, keyEquivalent: "")
    private let locationItem = NSMenuItem(title: "Grant Location access to enable per-network icons", action: #selector(openLocationSettings), keyEquivalent: "")
    private let locationManager = CLLocationManager()
    private let monitor = NWPathMonitor()
    private var lastPath: (active: ActiveInterface, ethernet: Bool, wifi: Bool)?
    private var tracker = ConnectionTracker()
    private let iconStore = DefaultsIconStore()
    private let setIconItem = NSMenuItem(title: "Set icon for current connection…", action: #selector(setIcon), keyEquivalent: "")
    private var ssid: String?
    private var previewLabel: NSTextField?
    private let notificationsItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
    private var probeTimer: Timer?
    private var asleep = false
    private var routeUp = false
    private var lastActive: ActiveInterface?
    private var probeGeneration = 0  // newest probe wins; older results are stale
    private var notificationsOn = UserDefaults.standard.object(forKey: "notificationsOn") as? Bool ?? true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(statusLine)
        ethernetLine.isHidden = true
        menu.addItem(ethernetLine)
        locationItem.target = self
        locationItem.isHidden = true
        menu.addItem(locationItem)
        menu.addItem(.separator())
        setIconItem.target = self
        menu.addItem(setIconItem)
        notificationsItem.target = self
        notificationsItem.state = notificationsOn ? .on : .off
        menu.addItem(notificationsItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.pathUpdateHandler = { [weak self] path in
            let route = Self.route(from: path)
            Task { @MainActor in
                self?.lastPath = route
                self?.refresh()
            }
        }
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        updateLocationItem()
        let wifiClient = CWWiFiClient.shared()
        wifiClient.delegate = self
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
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

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateLocationItem()
            self.refresh()  // the SSID becomes readable once authorized
        }
    }

    private func updateLocationItem() {
        let status = locationManager.authorizationStatus
        locationItem.isHidden = status != .denied && status != .restricted
    }

    @objc private func openLocationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
    }

    private func refresh() {
        guard let p = lastPath else { return }
        // nil without Location authorization; everything else works without it
        let wifi = CWWiFiClient.shared().interface()
        let ssid = wifi?.ssid()
        let associated = p.wifi || ssid != nil || (wifi?.powerOn() == true && (wifi?.transmitRate() ?? 0) > 0)
        apply(NetworkSnapshot(activeInterface: p.active, ethernetLink: Self.ethernetHasLink(), wifiAssociated: associated, ssid: ssid))
    }

    /// Real link state: a wired Ethernet interface that is up and running, even with no route over it.
    private nonisolated static func ethernetHasLink() -> Bool {
        let names = (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []).compactMap { i -> String? in
            (SCNetworkInterfaceGetInterfaceType(i) as String?) == (kSCNetworkInterfaceTypeEthernet as String) ? SCNetworkInterfaceGetBSDName(i) as String? : nil
        }
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return false }
        defer { freeifaddrs(list) }
        let required = UInt32(IFF_UP | IFF_RUNNING)
        for p in sequence(first: list, next: { $0?.pointee.ifa_next }).compactMap({ $0?.pointee }) {
            if names.contains(String(cString: p.ifa_name)), p.ifa_flags & required == required { return true }
        }
        return false
    }

    private func apply(_ snapshot: NetworkSnapshot) {
        ssid = snapshot.ssid
        let alerts = tracker.handle(.path(snapshot), at: Date().timeIntervalSince1970)
        render(tracker.displayState)
        deliver(alerts)
        let routeChanged = snapshot.activeInterface != lastActive
        lastActive = snapshot.activeInterface
        routeUp = snapshot.activeInterface != .none
        updateProbing(probeNow: routeChanged)  // SSID and Location updates don't warrant a probe
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
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return false }
        // a captive portal answers 200 with its own page, so the body must be Apple's "Success" page
        return (response as? HTTPURLResponse)?.statusCode == 200 && String(decoding: data, as: UTF8.self).contains("Success")
    }

    @objc private func toggleNotifications() {
        notificationsOn.toggle()
        notificationsItem.state = notificationsOn ? .on : .off
        UserDefaults.standard.set(notificationsOn, forKey: "notificationsOn")
    }

    @objc private func setIcon() {
        guard let key = IconKey(state: tracker.displayState, ssid: ssid) else { return }
        let target = switch key {
        case .ethernet: "Ethernet"
        case .ssid(let s): "Wi-Fi “\(s)”"
        case .unknownWifi: "Wi-Fi without a known name"
        }
        let field = NSTextField(string: iconStore.icon(for: key) ?? "")
        field.placeholderString = "SF Symbol name or emoji"
        field.delegate = self
        let preview = NSTextField(labelWithString: "")
        preview.font = .systemFont(ofSize: 24)
        previewLabel = preview
        updatePreview(field.stringValue)
        let stack = NSStackView(views: [field, preview])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 70)
        field.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let alert = NSAlert()
        alert.messageText = "Icon for \(target)"
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset to Default")
        NSApp.activate(ignoringOtherApps: true)
        while true {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                let text = field.stringValue.trimmingCharacters(in: .whitespaces)
                guard Self.isValid(text) else {
                    alert.informativeText = text.isEmpty ? "Enter an SF Symbol name or an emoji." : "“\(text)” is not a known SF Symbol or emoji."
                    continue
                }
                iconStore.setIcon(text, for: key)
            case .alertThirdButtonReturn:
                iconStore.setIcon(nil, for: key)
            default: break
            }
            previewLabel = nil
            render(tracker.displayState)
            return
        }
    }

    private static func isValid(_ text: String) -> Bool {
        switch IconSpec(parsing: text) {
        case .emoji: true
        case .symbol(let name): !name.isEmpty && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        updatePreview((obj.object as? NSTextField)?.stringValue ?? "")
    }

    private func updatePreview(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        previewLabel?.attributedStringValue = NSAttributedString()
        guard Self.isValid(text) else { previewLabel?.stringValue = "–"; return }
        switch IconSpec(parsing: text) {
        case .emoji(let e): previewLabel?.stringValue = e
        case .symbol(let name):
            let attachment = NSTextAttachment()
            attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            previewLabel?.attributedStringValue = NSAttributedString(attachment: attachment)
        }
    }

    private func deliver(_ alerts: [Alert]) {
        guard notificationsOn else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = switch alert {
            case .switched(.wifi, let ssid): ssid.map { "Switched to Wi-Fi: \($0)" } ?? "Switched to Wi-Fi"
            case .switched(.ethernet, _): "Back on Ethernet"
            case .switched(.none, _), .offline: "Offline"
            case .backOnline: "Back online"
            case .noInternet(let interface): "Connected via \(interface.label), but no internet"
            case .unstable(let interface, let drops): "\(interface.label) unstable: \(drops) drops in the last minute"
            }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    private func render(_ state: DisplayState) {
        ethernetLine.isHidden = !tracker.ethernetPluggedNotActive
        setIconItem.isEnabled = IconKey(state: state, ssid: ssid) != nil
        switch IconResolver.icon(for: state, ssid: ssid, store: iconStore) {
        case .symbol(let name):
            // a stored name this macOS lacks must not leave the menu bar blank
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)
            image?.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.title = ""
        case .emoji(let text):
            statusItem.button?.image = nil
            statusItem.button?.title = text
        }
        statusItem.button?.alphaValue = IconResolver.isDimmed(state) ? 0.4 : 1
        statusLine.title = switch state {
        case .ethernet: "Active: Ethernet"
        case .wifi(let ssid): ssid.map { "Active: Wi-Fi — \($0)" } ?? "Active: Wi-Fi"
        case .offline: "Offline"
        case .noInternet(let interface): "\(interface.label): no internet"
        }
    }

    private nonisolated static func route(from path: NWPath) -> (active: ActiveInterface, ethernet: Bool, wifi: Bool) {
        guard path.status == .satisfied else { return (.none, false, false) }
        // availableInterfaces is in preference order; take the first one the path actually uses.
        let active: ActiveInterface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }.map {
            switch $0.type {
            case .wiredEthernet: .ethernet
            case .wifi: .wifi
            default: .none // ponytail: VPN/tethering show as offline until a later ticket gives them an icon
            }
        } ?? .none
        return (active, path.usesInterfaceType(.wiredEthernet), path.usesInterfaceType(.wifi))
    }
}
