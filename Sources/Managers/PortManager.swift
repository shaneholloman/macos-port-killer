import Foundation
import SwiftUI

@Observable
@MainActor
final class PortManager {
    var ports: [PortInfo] = []
    var isScanning = false

    private let scanner = PortScanner()
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshEnabled = true
    private let refreshInterval: TimeInterval = 5.0

    init() {
        startAutoRefresh()
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let scannedPorts = await scanner.scanPorts()
        updatePorts(with: scannedPorts)
    }

    private func updatePorts(with newPorts: [PortInfo]) {
        // Create lookup by port+pid for stable comparison
        let newSet = Set(newPorts.map { "\($0.port)-\($0.pid)" })
        let oldSet = Set(ports.map { "\($0.port)-\($0.pid)" })

        // If same ports, no update needed
        if newSet == oldSet { return }

        // Remove ports that no longer exist
        ports.removeAll { !newSet.contains("\($0.port)-\($0.pid)") }

        // Add new ports
        let existingSet = Set(ports.map { "\($0.port)-\($0.pid)" })
        for port in newPorts where !existingSet.contains("\(port.port)-\(port.pid)") {
            ports.append(port)
        }

        // Sort by port number
        ports.sort { $0.port < $1.port }
    }

    func killPort(_ port: PortInfo) async {
        let success = await scanner.killProcessGracefully(pid: port.pid)
        if success {
            // Remove from list immediately
            ports.removeAll { $0.id == port.id }
            // Refresh to confirm
            await refresh()
        }
    }

    func killAll() async {
        for port in ports {
            _ = await scanner.killProcessGracefully(pid: port.pid)
        }
        ports.removeAll()
        await refresh()
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        autoRefreshEnabled = true

        refreshTask = Task {
            // Initial scan
            await refresh()

            while !Task.isCancelled && autoRefreshEnabled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                if !Task.isCancelled && autoRefreshEnabled {
                    await refresh()
                }
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshEnabled = false
        refreshTask?.cancel()
        refreshTask = nil
    }
}
